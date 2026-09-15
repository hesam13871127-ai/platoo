import { Injectable, Logger, Optional } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { PoolConnection, ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import { MysqlService } from '../database/mysql.service';
import { conflict, forbidden, invalid, notFound } from '../common/errors';
import { ChatService } from '../chat/chat.service';
import { BuyItemDto, EquipItemDto, GiftItemDto } from './wallet.dto';

interface WalletRow extends RowDataPacket { coins: number; pips: number; version: number; }
interface ItemRow extends RowDataPacket { id: string; sku: string; name: string; description: string; category: string; price_coins: number; price_pips: number; asset_key: string; is_giftable: number; is_active: number; stock: number | null; metadata: unknown; starts_at: string | null; ends_at: string | null; }

/** `shop_items.metadata.grants`: what a bundle hands over the moment it is bought. */
export interface BundleGrants { coins: number; pips: number; items: Array<{ itemId: string; quantity: number }>; }

export interface BundleContentItem { id: string; name: string; category: string; assetKey: string; quantity: number; }

export interface CatalogEntry {
  id: string; sku: string; name: string; description: string; category: string; assetKey: string;
  priceCoins: number; pricePips: number; price: number; currency: 'coins' | 'pips';
  isLimited: boolean; isGiftable: boolean; stock: number | null; endsAt: string | null;
  owned: boolean; ownedQuantity: number; equipped: boolean; equippable: boolean;
  bundle: { coins: number; pips: number; items: BundleContentItem[] } | null;
}

/** Categories that can be worn/selected. A bundle is a container, never a cosmetic. */
const EQUIPPABLE_CATEGORIES = new Set(['avatar', 'frame', 'emote', 'table', 'dice']);

@Injectable()
export class WalletService {
  private readonly logger = new Logger(WalletService.name);

  /**
   * ChatService is optional: gifting still works (and the inventory still moves)
   * when the chat module is not wired, the recipient simply gets no bell.
   */
  constructor(private readonly mysql: MysqlService, @Optional() private readonly chat?: ChatService) {}

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

  /**
   * The shop window for the signed-in player: every purchasable item, annotated with
   * what the player already owns and whether it can be equipped right now. Bundle
   * contents are resolved to real item names so the UI can show "what is inside".
   */
  async catalog(userId: string): Promise<CatalogEntry[]> {
    const rows = await this.mysql.query<RowDataPacket[]>(
      `SELECT s.id, s.sku, s.name, s.description, s.category, s.price_coins AS priceCoins, s.price_pips AS pricePips, s.asset_key AS assetKey, s.is_limited AS isLimited, s.is_giftable AS isGiftable, s.stock, s.metadata, s.ends_at AS endsAt, COALESCE(i.quantity, 0) AS ownedQuantity, COALESCE(i.equipped, FALSE) AS equipped
         FROM shop_items s
         LEFT JOIN inventory_items i ON i.shop_item_id = s.id AND i.user_id = ?
        WHERE s.is_active = TRUE AND (s.starts_at IS NULL OR s.starts_at <= UTC_TIMESTAMP(3)) AND (s.ends_at IS NULL OR s.ends_at > UTC_TIMESTAMP(3))
        ORDER BY FIELD(s.category, 'avatar', 'frame', 'emote', 'table', 'dice', 'bundle'), s.price_coins, s.price_pips, s.name`,
      [userId],
    );
    const entries: CatalogEntry[] = rows.map((row) => {
      const category = String(row.category);
      const priceCoins = Number(row.priceCoins ?? 0);
      const pricePips = Number(row.pricePips ?? 0);
      const currency: 'coins' | 'pips' = priceCoins > 0 ? 'coins' : 'pips';
      const ownedQuantity = Number(row.ownedQuantity ?? 0);
      const grants = this.bundleGrants(this.parseJson<Record<string, unknown>>(row.metadata, {}));
      return {
        id: String(row.id),
        sku: String(row.sku),
        name: String(row.name),
        description: String(row.description ?? ''),
        category,
        assetKey: String(row.assetKey ?? category),
        priceCoins,
        pricePips,
        price: currency === 'coins' ? priceCoins : pricePips,
        currency,
        isLimited: Boolean(row.isLimited),
        isGiftable: Boolean(row.isGiftable),
        stock: row.stock === null || row.stock === undefined ? null : Number(row.stock),
        endsAt: row.endsAt ?? null,
        owned: ownedQuantity > 0,
        ownedQuantity,
        equipped: Boolean(row.equipped),
        equippable: this.isEquippable(category),
        bundle: grants ? { coins: grants.coins, pips: grants.pips, items: grants.items.map((grant) => ({ id: grant.itemId, name: '', category: '', assetKey: '', quantity: grant.quantity })) } : null,
      };
    });
    await this.attachBundleContents(entries);
    return entries;
  }

  async inventory(userId: string) {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT i.id, i.shop_item_id AS itemId, i.quantity, i.equipped, i.acquired_at AS acquiredAt, i.expires_at AS expiresAt, s.sku, s.name, s.description, s.category, s.asset_key AS assetKey, s.is_giftable AS isGiftable FROM inventory_items i JOIN shop_items s ON s.id = i.shop_item_id WHERE i.user_id = ? AND i.quantity > 0 AND (i.expires_at IS NULL OR i.expires_at > UTC_TIMESTAMP(3)) ORDER BY i.equipped DESC, i.acquired_at DESC`, [userId]);
    return rows.map((row) => ({
      ...row,
      quantity: Number(row.quantity),
      equipped: this.toBool(row.equipped),
      isGiftable: this.toBool(row.isGiftable),
      equippable: this.isEquippable(String(row.category)),
    }));
  }

  /** Recent gifts in both directions, so "who did I send this to" is answerable. */
  async gifts(userId: string, limit = 30) {
    const safeLimit = Math.min(Math.max(limit, 1), 100);
    const rows = await this.mysql.query<RowDataPacket[]>(
      `(SELECT g.id, g.quantity, g.note, g.created_at AS createdAt, 'sent' AS direction, u.id AS counterpartId, u.display_name AS counterpartName, s.id AS itemId, s.name AS itemName, s.category, s.asset_key AS assetKey
          FROM gift_transactions g JOIN users u ON u.id = g.recipient_id JOIN shop_items s ON s.id = g.shop_item_id
         WHERE g.sender_id = ?)
       UNION ALL
       (SELECT g.id, g.quantity, g.note, g.created_at AS createdAt, 'received' AS direction, u.id AS counterpartId, u.display_name AS counterpartName, s.id AS itemId, s.name AS itemName, s.category, s.asset_key AS assetKey
          FROM gift_transactions g JOIN users u ON u.id = g.sender_id JOIN shop_items s ON s.id = g.shop_item_id
         WHERE g.recipient_id = ?)
       ORDER BY createdAt DESC LIMIT ?`,
      [userId, userId, safeLimit],
    );
    return rows.map((row) => ({ ...row, quantity: Number(row.quantity), note: row.note ?? null }));
  }

  /**
   * Buying is a single transaction: idempotency replay -> sale window -> stock ->
   * wallet -> inventory -> ledger (-> bundle grants). A retry with the same
   * idempotency key can never charge twice, and a stock race can never charge at all.
   */
  async buy(userId: string, dto: BuyItemDto) {
    return this.mysql.transaction(async (connection) => {
      if (dto.idempotencyKey) {
        const [already] = await connection.query<RowDataPacket[]>(`SELECT id, reference_id AS referenceId FROM wallet_transactions WHERE user_id = ? AND idempotency_key = ? LIMIT 1`, [userId, dto.idempotencyKey]);
        if (already[0]) {
          if (already[0].referenceId && String(already[0].referenceId) !== dto.itemId) throw conflict('That purchase key was already used for a different item.');
          return { success: true, replayed: true, transactionId: already[0].id, balance: await this.balanceOnConnection(connection, userId) };
        }
      }
      const item = await this.lockItem(connection, dto.itemId);
      const currency = Number(item.price_coins) > 0 ? 'coins' : 'pips';
      const price = (currency === 'coins' ? Number(item.price_coins) : Number(item.price_pips));
      if (price <= 0) throw invalid('This item is not available for direct purchase.');
      const balance = await this.lockWallet(connection, userId);
      const current = Number(balance[currency]);
      if (current < price) throw forbidden(`Not enough ${currency}.`);
      if (item.stock !== null) {
        const [stockUpdate] = await connection.execute<ResultSetHeader>(`UPDATE shop_items SET stock = stock - 1 WHERE id = ? AND stock > 0`, [dto.itemId]);
        if (!stockUpdate.affectedRows) throw conflict('This item just sold out.');
      }
      const after = current - price;
      await connection.execute(`UPDATE wallets SET ${currency} = ?, version = version + 1 WHERE user_id = ?`, [after, userId]);
      await connection.execute(`INSERT INTO inventory_items (id, user_id, shop_item_id) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE quantity = quantity + 1`, [randomUUID(), userId, dto.itemId]);
      const txId = randomUUID();
      await connection.execute(`INSERT INTO wallet_transactions (id, user_id, currency, amount, balance_after, type, reference_type, reference_id, idempotency_key) VALUES (?, ?, ?, ?, ?, 'purchase', 'shop_item', ?, ?)`, [txId, userId, currency, -price, after, dto.itemId, dto.idempotencyKey ?? null]);
      const grants = this.bundleGrants(this.parseJson<Record<string, unknown>>(item.metadata, {}));
      const granted = grants ? await this.grantBundle(connection, userId, item.id, grants) : null;
      return {
        success: true,
        replayed: false,
        transactionId: txId,
        item: { id: item.id, name: item.name, category: item.category },
        granted,
        balance: await this.balanceOnConnection(connection, userId),
      };
    });
  }

  /**
   * Equip (or `equipped: false` to take it off). One item per category stays
   * equipped, and a stack that was gifted away to zero can never stay "equipped".
   */
  async equip(userId: string, dto: EquipItemDto) {
    const shouldEquip = dto.equipped !== false;
    await this.mysql.transaction(async (connection) => {
      const [rows] = await connection.query<RowDataPacket[]>(`SELECT s.category, i.quantity FROM inventory_items i JOIN shop_items s ON s.id = i.shop_item_id WHERE i.user_id = ? AND i.shop_item_id = ? FOR UPDATE`, [userId, dto.itemId]);
      const row = rows[0];
      if (!row) throw notFound('You do not own this item.');
      if (Number(row.quantity) < 1) throw conflict('You no longer own this item.');
      if (!shouldEquip) {
        await connection.execute(`UPDATE inventory_items SET equipped = FALSE WHERE user_id = ? AND shop_item_id = ?`, [userId, dto.itemId]);
        return;
      }
      if (!this.isEquippable(String(row.category))) throw invalid('This item cannot be equipped.');
      await connection.execute(`UPDATE inventory_items i JOIN shop_items s ON s.id = i.shop_item_id SET i.equipped = FALSE WHERE i.user_id = ? AND s.category = ?`, [userId, row.category]);
      await connection.execute(`UPDATE inventory_items SET equipped = TRUE WHERE user_id = ? AND shop_item_id = ?`, [userId, dto.itemId]);
    });
    return this.inventory(userId);
  }

  /**
   * Moving a cosmetic to another player's inventory. The sender keeps the equipped
   * flag only while a copy remains, the receipt is written to `gift_transactions`,
   * and the recipient gets a chat card when chat is available (best effort only).
   */
  async gift(senderId: string, dto: GiftItemDto) {
    if (senderId === dto.recipientId) throw invalid('You cannot gift yourself.');
    const quantity = Math.max(1, Math.floor(dto.quantity ?? 1));
    const note = dto.note?.trim() ? dto.note.trim() : null;
    const outcome = await this.mysql.transaction(async (connection) => {
      const [recipientRows] = await connection.query<RowDataPacket[]>(`SELECT id, display_name AS displayName FROM users WHERE id = ? AND status = 'active'`, [dto.recipientId]);
      const recipient = recipientRows[0];
      if (!recipient) throw notFound('Recipient not found.');
      const item = await this.lockItem(connection, dto.itemId);
      if (!this.toBool(item.is_giftable)) throw invalid('This item cannot be gifted.');
      const [ownedRows] = await connection.query<RowDataPacket[]>(`SELECT quantity FROM inventory_items WHERE user_id = ? AND shop_item_id = ? FOR UPDATE`, [senderId, dto.itemId]);
      const owned = Number(ownedRows[0]?.quantity ?? 0);
      if (owned < quantity) throw forbidden('You do not own enough of this item.');
      const left = owned - quantity;
      await connection.execute(`UPDATE inventory_items SET quantity = quantity - ?, equipped = IF(? > 0, equipped, FALSE) WHERE user_id = ? AND shop_item_id = ?`, [quantity, left, senderId, dto.itemId]);
      await connection.execute(`INSERT INTO inventory_items (id, user_id, shop_item_id, quantity) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity)`, [randomUUID(), dto.recipientId, dto.itemId, quantity]);
      const giftId = randomUUID();
      await connection.execute(`INSERT INTO gift_transactions (id, sender_id, recipient_id, shop_item_id, quantity, note) VALUES (?, ?, ?, ?, ?, ?)`, [giftId, senderId, dto.recipientId, dto.itemId, quantity, note]);
      return { giftId, itemName: String(item.name), category: String(item.category), recipientName: String(recipient.displayName ?? 'Player'), quantity };
    });
    await this.announceGift(senderId, dto.recipientId, dto.itemId, outcome.itemName, outcome.quantity, note);
    return { success: true, giftId: outcome.giftId, item: outcome.itemName, quantity: outcome.quantity, recipient: { id: dto.recipientId, displayName: outcome.recipientName } };
  }

  /** Bundles: credit the coins and drop the granted cosmetics into the inventory. */
  private async grantBundle(connection: PoolConnection, userId: string, bundleId: string, grants: BundleGrants) {
    let coins = 0;
    let pips = 0;
    if (grants.coins > 0) {
      const wallet = await this.lockWallet(connection, userId);
      coins = Number(wallet.coins) + grants.coins;
      await connection.execute(`UPDATE wallets SET coins = ?, version = version + 1 WHERE user_id = ?`, [coins, userId]);
      await connection.execute(`INSERT INTO wallet_transactions (id, user_id, currency, amount, balance_after, type, reference_type, reference_id, metadata) VALUES (?, ?, 'coins', ?, ?, 'purchase', 'shop_item', ?, ?)`, [randomUUID(), userId, grants.coins, coins, bundleId, JSON.stringify({ bundleGrant: true })]);
    }
    if (grants.pips > 0) {
      const wallet = await this.lockWallet(connection, userId);
      pips = Number(wallet.pips) + grants.pips;
      await connection.execute(`UPDATE wallets SET pips = ?, version = version + 1 WHERE user_id = ?`, [pips, userId]);
      await connection.execute(`INSERT INTO wallet_transactions (id, user_id, currency, amount, balance_after, type, reference_type, reference_id, metadata) VALUES (?, ?, 'pips', ?, ?, 'purchase', 'shop_item', ?, ?)`, [randomUUID(), userId, grants.pips, pips, bundleId, JSON.stringify({ bundleGrant: true })]);
    }
    const wanted = new Map<string, number>();
    for (const grant of grants.items) wanted.set(grant.itemId, (wanted.get(grant.itemId) ?? 0) + grant.quantity);
    const items: BundleContentItem[] = [];
    if (wanted.size) {
      const known = await this.itemNames(connection, [...wanted.keys()]);
      for (const [itemId, count] of wanted) {
        const meta = known.get(itemId);
        if (!meta) continue;
        await connection.execute(`INSERT INTO inventory_items (id, user_id, shop_item_id, quantity) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity)`, [randomUUID(), userId, itemId, count]);
        items.push({ id: itemId, name: meta.name, category: meta.category, assetKey: meta.assetKey, quantity: count });
      }
    }
    return { coins: grants.coins, pips: grants.pips, items };
  }

  private async itemNames(connection: PoolConnection, ids: string[]) {
    const names = new Map<string, { name: string; category: string; assetKey: string }>();
    if (!ids.length) return names;
    const placeholders = ids.map(() => '?').join(', ');
    const [rows] = await connection.query<RowDataPacket[]>(`SELECT id, name, category, asset_key AS assetKey FROM shop_items WHERE id IN (${placeholders})`, ids);
    for (const row of rows) names.set(String(row.id), { name: String(row.name), category: String(row.category), assetKey: String(row.assetKey ?? '') });
    return names;
  }

  private async attachBundleContents(entries: CatalogEntry[]) {
    const ids = new Set<string>();
    for (const entry of entries) entry.bundle?.items.forEach((item) => { if (item.id) ids.add(item.id); });
    if (!ids.size) return;
    const names = new Map<string, { name: string; category: string; assetKey: string }>();
    const list = [...ids];
    const placeholders = list.map(() => '?').join(', ');
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT id, name, category, asset_key AS assetKey FROM shop_items WHERE id IN (${placeholders})`, list);
    for (const row of rows) names.set(String(row.id), { name: String(row.name), category: String(row.category), assetKey: String(row.assetKey ?? '') });
    for (const entry of entries) {
      if (!entry.bundle) continue;
      entry.bundle.items = entry.bundle.items
        .filter((item) => names.has(item.id))
        .map((item) => ({ ...item, ...names.get(item.id)! }));
    }
  }

  /** A bundle is only a bundle when its metadata actually grants something. */
  private bundleGrants(metadata: Record<string, unknown>): BundleGrants | null {
    const grants = metadata['grants'];
    if (!grants || typeof grants !== 'object') return null;
    const raw = grants as Record<string, unknown>;
    const coins = Math.max(0, Math.floor(Number(raw['coins'] ?? 0) || 0));
    const pips = Math.max(0, Math.floor(Number(raw['pips'] ?? 0) || 0));
    const items: Array<{ itemId: string; quantity: number }> = [];
    const list = Array.isArray(raw['items']) ? raw['items'] : [];
    for (const entry of list) {
      if (typeof entry === 'string' && entry) { items.push({ itemId: entry, quantity: 1 }); continue; }
      if (!entry || typeof entry !== 'object') continue;
      const record = entry as Record<string, unknown>;
      const itemId = typeof record['itemId'] === 'string' ? record['itemId'] : typeof record['id'] === 'string' ? record['id'] : '';
      const quantity = Math.max(1, Math.floor(Number(record['quantity'] ?? 1) || 1));
      if (itemId) items.push({ itemId, quantity });
    }
    if (!coins && !pips && !items.length) return null;
    return { coins, pips, items };
  }

  private async lockItem(connection: PoolConnection, itemId: string): Promise<ItemRow> {
    const [rows] = await connection.query<ItemRow[]>(`SELECT * FROM shop_items WHERE id = ? LIMIT 1 FOR UPDATE`, [itemId]);
    const item = rows[0];
    if (!item || !this.toBool(item.is_active)) throw notFound('Shop item not found.');
    if (!this.withinSaleWindow(item)) throw conflict('This item is not for sale right now.');
    return item;
  }

  private withinSaleWindow(item: ItemRow): boolean {
    const now = Date.now();
    const startsAt = item.starts_at ? Date.parse(String(item.starts_at)) : Number.NaN;
    const endsAt = item.ends_at ? Date.parse(String(item.ends_at)) : Number.NaN;
    if (!Number.isNaN(startsAt) && startsAt > now) return false;
    if (!Number.isNaN(endsAt) && endsAt <= now) return false;
    return true;
  }

  /** Best-effort chat card: a failed notification never fails or reverts the gift. */
  private async announceGift(senderId: string, recipientId: string, itemId: string, itemName: string, quantity: number, note: string | null) {
    if (!this.chat) return;
    try {
      const conversation = await this.chat.createPrivate(senderId, recipientId) as { id?: string };
      if (!conversation?.id) return;
      const body = `🎁 ${quantity > 1 ? `${quantity}× ` : ''}${itemName}${note ? ` — “${note}”` : ''}`;
      await this.chat.send(senderId, { conversationId: conversation.id, body, kind: 'gift', giftItemId: itemId });
    } catch (error) {
      this.logger.warn(`Gift ${itemId} was delivered without a chat notification: ${(error as Error).message}`);
    }
  }

  private isEquippable(category: string): boolean { return EQUIPPABLE_CATEGORIES.has(category); }

  private toBool(value: unknown): boolean { return value === true || value === 1 || value === '1'; }

  private parseJson<T>(value: unknown, fallback: T): T {
    if (value === null || value === undefined) return fallback;
    if (typeof value !== 'string') return value as T;
    try { return JSON.parse(value) as T; } catch { return fallback; }
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
