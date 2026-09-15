import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { PoolConnection, RowDataPacket } from 'mysql2/promise';
import { MysqlService } from '../database/mysql.service';
import { conflict, forbidden, invalid, notFound } from '../common/errors';
import { BuyItemDto, EquipItemDto, GiftItemDto } from './wallet.dto';

interface WalletRow extends RowDataPacket { coins: number; pips: number; version: number; }
interface ItemRow extends RowDataPacket { id: string; sku: string; name: string; description: string; category: string; price_coins: number; price_pips: number; asset_key: string; is_giftable: number; is_active: number; is_limited: number; stock: number | null; }

@Injectable()
export class WalletService {
  constructor(private readonly mysql: MysqlService) {}

  async balance(userId: string) {
    const rows = await this.mysql.query<WalletRow[]>(`SELECT coins, pips, version FROM wallets WHERE user_id = ?`, [userId]);
    if (!rows[0]) {
      await this.mysql.execute(`INSERT IGNORE INTO wallets (user_id) VALUES (?)`, [userId]);
      return { coins: 0, pips: 0 };
    }
    return { coins: Number(rows[0].coins), pips: Number(rows[0].pips) };
  }

  async ledger(userId: string, limit = 50) {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT id, currency, amount, balance_after AS balanceAfter, type, reference_type AS referenceType, reference_id AS referenceId, metadata, created_at AS createdAt FROM wallet_transactions WHERE user_id = ? ORDER BY created_at DESC LIMIT ?`, [userId, Math.min(Math.max(limit, 1), 100)]);
    return rows.map((row) => ({ ...row, amount: Number(row.amount), balanceAfter: Number(row.balanceAfter) }));
  }

  async catalog() {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT id, sku, name, description, category, price_coins AS priceCoins, price_pips AS pricePips, asset_key AS assetKey, is_limited AS isLimited, is_giftable AS isGiftable, stock FROM shop_items WHERE is_active = TRUE AND (starts_at IS NULL OR starts_at <= UTC_TIMESTAMP(3)) AND (ends_at IS NULL OR ends_at > UTC_TIMESTAMP(3)) ORDER BY category, price_coins, price_pips`);
    return rows.map((row) => ({
      ...row,
      priceCoins: Number(row.priceCoins),
      pricePips: Number(row.pricePips),
      isLimited: Boolean(row.isLimited),
      isGiftable: Boolean(row.isGiftable),
      stock: row.stock === null ? null : Number(row.stock),
    }));
  }

  async inventory(userId: string) {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT i.id, i.shop_item_id AS itemId, i.quantity, i.equipped, i.acquired_at AS acquiredAt, i.expires_at AS expiresAt, s.sku, s.name, s.description, s.category, s.asset_key AS assetKey, s.is_giftable AS isGiftable FROM inventory_items i JOIN shop_items s ON s.id = i.shop_item_id WHERE i.user_id = ? AND i.quantity > 0 AND (i.expires_at IS NULL OR i.expires_at > UTC_TIMESTAMP(3)) ORDER BY i.acquired_at DESC`, [userId]);
    return rows.map((row) => ({
      ...row,
      quantity: Number(row.quantity),
      equipped: Boolean(row.equipped),
      isGiftable: Boolean(row.isGiftable),
    }));
  }

  async gifts(userId: string) {
    const received = await this.mysql.query<RowDataPacket[]>(
      `SELECT g.id, g.sender_id AS senderId, u.display_name AS senderName, u.avatar_url AS senderAvatarUrl, g.shop_item_id AS itemId, s.name AS itemName, s.category, s.asset_key AS assetKey, g.quantity, g.note, g.created_at AS createdAt FROM gift_transactions g JOIN users u ON u.id = g.sender_id JOIN shop_items s ON s.id = g.shop_item_id WHERE g.recipient_id = ? ORDER BY g.created_at DESC LIMIT 25`,
      [userId],
    );
    const sent = await this.mysql.query<RowDataPacket[]>(
      `SELECT g.id, g.recipient_id AS recipientId, u.display_name AS recipientName, u.avatar_url AS recipientAvatarUrl, g.shop_item_id AS itemId, s.name AS itemName, s.category, s.asset_key AS assetKey, g.quantity, g.note, g.created_at AS createdAt FROM gift_transactions g JOIN users u ON u.id = g.recipient_id JOIN shop_items s ON s.id = g.shop_item_id WHERE g.sender_id = ? ORDER BY g.created_at DESC LIMIT 25`,
      [userId],
    );
    return {
      received: received.map((r) => ({ ...r, quantity: Number(r.quantity) })),
      sent: sent.map((s) => ({ ...s, quantity: Number(s.quantity) })),
    };
  }

  async buy(userId: string, dto: BuyItemDto) {
    return this.mysql.transaction(async (connection) => {
      if (dto.idempotencyKey) {
        const [already] = await connection.query<RowDataPacket[]>(`SELECT id, metadata FROM wallet_transactions WHERE user_id = ? AND idempotency_key = ? LIMIT 1`, [userId, dto.idempotencyKey]);
        if (already[0]) {
          return {
            success: true,
            replayed: true,
            transactionId: already[0].id,
            balance: await this.balanceOnConnection(connection, userId),
          };
        }
      }

      const item = await this.lockItem(connection, dto.itemId);
      const quantity = Math.max(1, dto.quantity ?? 1);

      let currency: 'coins' | 'pips' = 'coins';
      if (dto.currency) {
        currency = dto.currency;
      } else {
        currency = Number(item.price_coins) > 0 ? 'coins' : 'pips';
      }

      const unitPrice = currency === 'coins' ? Number(item.price_coins) : Number(item.price_pips);
      if (unitPrice <= 0) throw invalid('This item is not available for direct purchase in this currency.');
      const totalPrice = unitPrice * quantity;

      if (item.stock !== null && item.stock < quantity) {
        throw conflict('This item is sold out or does not have enough stock remaining.');
      }

      const balance = await this.lockWallet(connection, userId);
      const current = Number(balance[currency]);
      if (current < totalPrice) {
        throw forbidden(`Not enough ${currency}. Need ${totalPrice}, have ${current}.`);
      }

      const after = current - totalPrice;
      await connection.execute(`UPDATE wallets SET ${currency} = ?, version = version + 1 WHERE user_id = ?`, [after, userId]);

      if (item.stock !== null) {
        await connection.execute(`UPDATE shop_items SET stock = stock - ? WHERE id = ? AND stock >= ?`, [quantity, dto.itemId, quantity]);
      }

      await connection.execute(
        `INSERT INTO inventory_items (id, user_id, shop_item_id, quantity) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity)`,
        [randomUUID(), userId, dto.itemId, quantity],
      );

      const txId = randomUUID();
      await connection.execute(
        `INSERT INTO wallet_transactions (id, user_id, currency, amount, balance_after, type, reference_type, reference_id, idempotency_key) VALUES (?, ?, ?, ?, ?, 'purchase', 'shop_item', ?, ?)`,
        [txId, userId, currency, -totalPrice, after, dto.itemId, dto.idempotencyKey ?? null],
      );

      return {
        success: true,
        replayed: false,
        transactionId: txId,
        item: { id: item.id, name: item.name, sku: item.sku, category: item.category },
        quantity,
        currency,
        totalPrice,
        balance: await this.balanceOnConnection(connection, userId),
      };
    });
  }

  async equip(userId: string, dto: EquipItemDto) {
    const rows = await this.mysql.query<RowDataPacket[]>(
      `SELECT i.equipped, s.category FROM inventory_items i JOIN shop_items s ON s.id = i.shop_item_id WHERE i.user_id = ? AND i.shop_item_id = ? AND i.quantity > 0`,
      [userId, dto.itemId],
    );
    if (!rows[0]) throw notFound('You do not own this item.');

    const currentlyEquipped = Boolean(rows[0].equipped);
    const targetEquipped = dto.equipped !== undefined ? Boolean(dto.equipped) : !currentlyEquipped;

    await this.mysql.transaction(async (connection) => {
      if (targetEquipped) {
        await connection.execute(
          `UPDATE inventory_items i JOIN shop_items s ON s.id = i.shop_item_id SET i.equipped = FALSE WHERE i.user_id = ? AND s.category = ?`,
          [userId, rows[0].category],
        );
        await connection.execute(
          `UPDATE inventory_items SET equipped = TRUE WHERE user_id = ? AND shop_item_id = ?`,
          [userId, dto.itemId],
        );
      } else {
        await connection.execute(
          `UPDATE inventory_items SET equipped = FALSE WHERE user_id = ? AND shop_item_id = ?`,
          [userId, dto.itemId],
        );
      }
    });

    return this.inventory(userId);
  }

  async gift(senderId: string, dto: GiftItemDto) {
    if (senderId === dto.recipientId) throw invalid('You cannot gift yourself.');
    const quantity = Math.max(1, dto.quantity ?? 1);

    return this.mysql.transaction(async (connection) => {
      const [recipientRows] = await connection.query<RowDataPacket[]>(`SELECT id, display_name AS displayName FROM users WHERE id = ? AND status = 'active'`, [dto.recipientId]);
      const recipient = recipientRows[0];
      if (!recipient) throw notFound('Recipient not found or account is inactive.');

      const item = await this.lockItem(connection, dto.itemId);
      if (!item.is_giftable) throw invalid('This item cannot be gifted.');

      const [ownedRows] = await connection.query<RowDataPacket[]>(
        `SELECT quantity, equipped FROM inventory_items WHERE user_id = ? AND shop_item_id = ? FOR UPDATE`,
        [senderId, dto.itemId],
      );
      const owned = Number(ownedRows[0]?.quantity ?? 0);

      const shouldBuyDirect = dto.buyDirect === true || owned < quantity;

      if (shouldBuyDirect) {
        const currency = Number(item.price_coins) > 0 ? 'coins' : 'pips';
        const unitPrice = currency === 'coins' ? Number(item.price_coins) : Number(item.price_pips);
        if (unitPrice <= 0) throw invalid('This item is not available for purchase as a gift.');
        const totalPrice = unitPrice * quantity;

        if (item.stock !== null && item.stock < quantity) {
          throw conflict('Not enough stock available to gift this item.');
        }

        const balance = await this.lockWallet(connection, senderId);
        const current = Number(balance[currency]);
        if (current < totalPrice) {
          throw forbidden(`Not enough ${currency} to purchase this gift. Need ${totalPrice}, have ${current}.`);
        }

        const after = current - totalPrice;
        await connection.execute(`UPDATE wallets SET ${currency} = ?, version = version + 1 WHERE user_id = ?`, [after, senderId]);

        if (item.stock !== null) {
          await connection.execute(`UPDATE shop_items SET stock = stock - ? WHERE id = ? AND stock >= ?`, [quantity, dto.itemId, quantity]);
        }

        const txId = randomUUID();
        await connection.execute(
          `INSERT INTO wallet_transactions (id, user_id, currency, amount, balance_after, type, reference_type, reference_id) VALUES (?, ?, ?, ?, ?, 'gift_sent', 'shop_item', ?)`,
          [txId, senderId, currency, -totalPrice, after, dto.itemId],
        );

        await connection.execute(
          `INSERT INTO inventory_items (id, user_id, shop_item_id, quantity) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity)`,
          [randomUUID(), dto.recipientId, dto.itemId, quantity],
        );

        const giftId = randomUUID();
        await connection.execute(
          `INSERT INTO gift_transactions (id, sender_id, recipient_id, shop_item_id, quantity, note) VALUES (?, ?, ?, ?, ?, ?)`,
          [giftId, senderId, dto.recipientId, dto.itemId, quantity, dto.note?.trim() ?? null],
        );

        return {
          success: true,
          giftId,
          item: item.name,
          quantity,
          recipientName: recipient.displayName,
          boughtDirect: true,
          currency,
          totalPrice,
          balance: await this.balanceOnConnection(connection, senderId),
        };
      } else {
        const remaining = owned - quantity;
        if (remaining <= 0) {
          await connection.execute(
            `UPDATE inventory_items SET quantity = 0, equipped = FALSE WHERE user_id = ? AND shop_item_id = ?`,
            [senderId, dto.itemId],
          );
        } else {
          await connection.execute(
            `UPDATE inventory_items SET quantity = quantity - ? WHERE user_id = ? AND shop_item_id = ?`,
            [quantity, senderId, dto.itemId],
          );
        }

        await connection.execute(
          `INSERT INTO inventory_items (id, user_id, shop_item_id, quantity) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity)`,
          [randomUUID(), dto.recipientId, dto.itemId, quantity],
        );

        const giftId = randomUUID();
        await connection.execute(
          `INSERT INTO gift_transactions (id, sender_id, recipient_id, shop_item_id, quantity, note) VALUES (?, ?, ?, ?, ?, ?)`,
          [giftId, senderId, dto.recipientId, dto.itemId, quantity, dto.note?.trim() ?? null],
        );

        return {
          success: true,
          giftId,
          item: item.name,
          quantity,
          recipientName: recipient.displayName,
          boughtDirect: false,
        };
      }
    });
  }

  private async lockItem(connection: PoolConnection, itemId: string): Promise<ItemRow> {
    const [rows] = await connection.query<ItemRow[]>(`SELECT * FROM shop_items WHERE id = ? AND is_active = TRUE LIMIT 1 FOR UPDATE`, [itemId]);
    if (!rows[0]) throw notFound('Shop item not found.');
    return rows[0];
  }

  private async lockWallet(connection: PoolConnection, userId: string): Promise<WalletRow> {
    await connection.execute(`INSERT IGNORE INTO wallets (user_id) VALUES (?)`, [userId]);
    const [rows] = await connection.query<WalletRow[]>(`SELECT coins, pips, version FROM wallets WHERE user_id = ? FOR UPDATE`, [userId]);
    if (!rows[0]) throw notFound('Wallet not found.');
    return rows[0];
  }

  private async balanceOnConnection(connection: PoolConnection, userId: string) {
    const [rows] = await connection.query<WalletRow[]>(`SELECT coins, pips FROM wallets WHERE user_id = ?`, [userId]);
    return { coins: Number(rows[0]?.coins ?? 0), pips: Number(rows[0]?.pips ?? 0) };
  }
}
