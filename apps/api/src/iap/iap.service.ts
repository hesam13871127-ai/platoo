import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash, randomUUID } from 'node:crypto';
import { PoolConnection, RowDataPacket } from 'mysql2/promise';
import { MysqlService } from '../database/mysql.service';
import { conflict, forbidden, invalid, notFound, unavailable } from '../common/errors';
import { IapProvider, VerifyPurchaseDto } from './iap.dto';
import {
  AppleAppStoreVerifier,
  DevReceiptVerifier,
  GooglePlayVerifier,
  ReceiptVerificationError,
  ReceiptVerifier,
  VerifiedPurchase,
} from './verifiers';

interface ProductRow extends RowDataPacket {
  id: string;
  sku: string;
  store_product_id: string;
  provider: string;
  coins: number;
  bonus_coins: number;
  price_micros: number;
  currency: string;
  sort_order: number;
}

interface PurchaseRow extends RowDataPacket {
  id: string;
  user_id: string;
  product_id: string;
  provider: string;
  store_product_id: string;
  transaction_id: string;
  status: string;
  coins_granted: number;
  verify_attempts: number;
}

interface WalletRow extends RowDataPacket {
  coins: number;
  pips: number;
}

const MAX_VERIFY_ATTEMPTS = 10;

/**
 * Real-money coin top-ups. Safety properties:
 *
 * - The store (Apple/Google API over TLS) is the source of truth, never the client.
 * - The coin grant comes from OUR `iap_products` catalog row, never from client input.
 * - UNIQUE(provider, transaction_id) + a SELECT ... FOR UPDATE credit step mean a store
 *   transaction credits exactly one user exactly once, even under concurrent retries.
 * - A second safety net: the ledger row uses idempotency_key `iap:<provider>:<tx>`.
 * - Only `coins` are ever granted; the pips economy is untouched.
 */
@Injectable()
export class IapService implements OnModuleInit {
  private readonly logger = new Logger(IapService.name);

  constructor(private readonly mysql: MysqlService, private readonly config: ConfigService) {}

  async onModuleInit(): Promise<void> {
    await this.ensureLedgerType();
  }

  /**
   * Self-heal for databases created before the IAP foundation: appending a value to the
   * END of an ENUM is metadata-only in MySQL 8 (no table rebuild, no downtime).
   */
  private async ensureLedgerType(): Promise<void> {
    const rows = await this.mysql.query<RowDataPacket[]>(
      `SELECT COLUMN_TYPE AS columnType FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'wallet_transactions' AND COLUMN_NAME = 'type'`,
    );
    const columnType = String(rows[0]?.columnType ?? '');
    if (!columnType || columnType.includes("'iap_credit'")) return;
    this.logger.log('Adding iap_credit to the wallet ledger type...');
    await this.mysql.execute(
      `ALTER TABLE wallet_transactions MODIFY COLUMN type ENUM('signup','purchase','match_entry','match_reward','gift_sent','gift_received','admin_adjustment','refund','season_reward','iap_credit') NOT NULL`,
    );
  }

  private verifierFor(provider: IapProvider): ReceiptVerifier {
    if (this.config.get<boolean>('iap.devEnabled', false) && this.config.get<string>('nodeEnv') !== 'production') {
      return new DevReceiptVerifier(provider);
    }
    if (provider === 'apple') {
      return new AppleAppStoreVerifier({
        issuerId: this.config.get<string>('iap.apple.issuerId', ''),
        keyId: this.config.get<string>('iap.apple.keyId', ''),
        privateKey: this.config.get<string>('iap.apple.privateKey', ''),
        bundleId: this.config.get<string>('iap.apple.bundleId', ''),
        sandbox: this.config.get<boolean>('iap.apple.sandbox', true),
      });
    }
    return new GooglePlayVerifier({
      serviceAccountEmail: this.config.get<string>('iap.google.serviceAccountEmail', ''),
      privateKey: this.config.get<string>('iap.google.privateKey', ''),
      packageName: this.config.get<string>('iap.google.packageName', ''),
    });
  }

  private expectedPackage(provider: IapProvider): string {
    return provider === 'apple'
      ? this.config.get<string>('iap.apple.bundleId', '')
      : this.config.get<string>('iap.google.packageName', '');
  }

  async products(provider?: IapProvider) {
    const rows = await this.mysql.query<ProductRow[]>(
      `SELECT id, sku, store_product_id AS storeProductId, provider, coins, bonus_coins AS bonusCoins, price_micros AS priceMicros, currency, sort_order AS sortOrder FROM iap_products WHERE is_active = TRUE${provider ? ' AND provider = ?' : ''} ORDER BY sort_order, coins`,
      provider ? [provider] : [],
    );
    return rows.map((row) => ({
      ...row,
      coins: Number(row.coins),
      bonusCoins: Number(row.bonusCoins),
      totalCoins: Number(row.coins) + Number(row.bonusCoins),
      priceMicros: Number(row.priceMicros),
    }));
  }

  async history(userId: string, limit = 50) {
    const rows = await this.mysql.query<RowDataPacket[]>(
      `SELECT p.id, p.provider, p.store_product_id AS storeProductId, p.transaction_id AS transactionId, p.status, p.coins_granted AS coinsGranted, p.verified_at AS verifiedAt, p.credited_at AS creditedAt, p.created_at AS createdAt, pr.sku, pr.coins, pr.bonus_coins AS bonusCoins FROM iap_purchases p JOIN iap_products pr ON pr.id = p.product_id WHERE p.user_id = ? ORDER BY p.created_at DESC LIMIT ?`,
      [userId, Math.min(Math.max(limit, 1), 100)],
    );
    return rows.map((row) => ({ ...row, coinsGranted: Number(row.coinsGranted), coins: Number(row.coins), bonusCoins: Number(row.bonusCoins) }));
  }

  async verify(userId: string, dto: VerifyPurchaseDto) {
    const provider = dto.provider;
    const product = await this.findProduct(provider, dto.storeProductId);
    const verifier = this.verifierFor(provider);
    const receiptHash = createHash('sha256').update(dto.receipt).digest('hex');

    const claim = await this.claimPurchase(userId, product, dto, receiptHash);
    if (claim.replayed) {
      const balance = await this.balance(userId);
      return {
        success: true,
        credited: true,
        replayed: true,
        purchaseId: claim.row.id,
        coins: Number(claim.row.coins_granted),
        balance,
      };
    }

    let verified: VerifiedPurchase;
    try {
      verified = await verifier.verify({
        userId,
        storeProductId: product.store_product_id,
        transactionId: dto.transactionId,
        receipt: dto.receipt,
        expectedPackage: this.expectedPackage(provider),
      });
    } catch (error) {
      await this.recordVerifyFailure(claim.id, error);
    }

    // The store confirmed payment: record it before crediting so a crash between the
    // two steps leaves a `verified` row that a retry can safely complete.
    await this.mysql.execute(`UPDATE iap_purchases SET status = 'verified', verified_at = UTC_TIMESTAMP(3), last_error = NULL WHERE id = ?`, [claim.id]);

    // The store's authoritative product must equal the claimed catalog row. (The
    // verifier already enforces this; this is defense in depth at the credit step.)
    if (verified!.storeProductId !== product.store_product_id) {
      await this.mysql.execute(`UPDATE iap_purchases SET status = 'failed', last_error = ? WHERE id = ?`, ['Product mismatch at credit time.', claim.id]);
      throw invalid('This transaction is for a different product.');
    }

    const grant = Number(product.coins) + Number(product.bonus_coins);
    const result = await this.mysql.transaction(async (connection) => {
      const [rows] = await connection.query<PurchaseRow[]>(`SELECT id, status FROM iap_purchases WHERE id = ? FOR UPDATE`, [claim.id]);
      const current = rows[0];
      if (!current) throw notFound('Purchase not found.');
      if (current.status === 'credited') {
        // Lost a race with a concurrent verify: the other attempt credited already.
        const purchase = await this.findPurchaseById(claim.id);
        return { replayed: true, purchaseId: claim.id, coins: Number(purchase?.coins_granted ?? grant), balance: await this.balanceOnConnection(connection, userId) };
      }
      await connection.execute(`INSERT IGNORE INTO wallets (user_id) VALUES (?)`, [userId]);
      const [walletRows] = await connection.query<WalletRow[]>(`SELECT coins, pips FROM wallets WHERE user_id = ? FOR UPDATE`, [userId]);
      if (!walletRows[0]) throw notFound('Wallet not found.');
      const after = Number(walletRows[0].coins) + grant;
      await connection.execute(`UPDATE wallets SET coins = ?, version = version + 1 WHERE user_id = ?`, [after, userId]);
      await connection.execute(
        `INSERT INTO wallet_transactions (id, user_id, currency, amount, balance_after, type, reference_type, reference_id, idempotency_key, metadata) VALUES (?, ?, 'coins', ?, ?, 'iap_credit', 'iap_purchase', ?, ?, ?)`,
        [
          randomUUID(),
          userId,
          grant,
          after,
          claim.id,
          `iap:${provider}:${dto.transactionId}`,
          JSON.stringify({ provider, storeProductId: product.store_product_id, transactionId: dto.transactionId, environment: verified!.environment }),
        ],
      );
      await connection.execute(
        `UPDATE iap_purchases SET status = 'credited', coins_granted = ?, credited_at = UTC_TIMESTAMP(3), last_error = NULL WHERE id = ?`,
        [grant, claim.id],
      );
      return { replayed: false, purchaseId: claim.id, coins: grant, balance: { coins: after, pips: Number(walletRows[0].pips) } };
    });

    // Google auto-refunds purchases left unacknowledged for 3 days. A failed
    // acknowledgement must NEVER revoke the credit: log loudly so ops can reconcile.
    if (verifier.acknowledge) {
      try {
        await verifier.acknowledge({
          userId,
          storeProductId: product.store_product_id,
          transactionId: dto.transactionId,
          receipt: dto.receipt,
          expectedPackage: this.expectedPackage(provider),
        });
      } catch (error) {
        this.logger.warn(`Credited ${result.coins} coins for ${provider}:${dto.transactionId} but Play acknowledgement failed: ${(error as Error).message}`);
      }
    }

    return { success: true, credited: true, ...result, product: { sku: product.sku, coins: Number(product.coins), bonusCoins: Number(product.bonus_coins) } };
  }

  private async findProduct(provider: IapProvider, storeProductId: string): Promise<ProductRow> {
    const rows = await this.mysql.query<ProductRow[]>(
      `SELECT id, sku, store_product_id, provider, coins, bonus_coins, price_micros, currency, sort_order FROM iap_products WHERE provider = ? AND store_product_id = ? AND is_active = TRUE LIMIT 1`,
      [provider, storeProductId],
    );
    if (!rows[0]) throw invalid('This product is not available for purchase.');
    return rows[0];
  }

  private async findPurchaseById(id: string): Promise<PurchaseRow | null> {
    const rows = await this.mysql.query<PurchaseRow[]>(`SELECT id, user_id, product_id, provider, store_product_id, transaction_id, status, coins_granted, verify_attempts FROM iap_purchases WHERE id = ? LIMIT 1`, [id]);
    return rows[0] ?? null;
  }

  /**
   * Claims the single canonical row for a store transaction. Concurrent verifies of the
   * same transaction converge here: exactly one INSERT wins, the rest read the winner.
   */
  private async claimPurchase(
    userId: string,
    product: ProductRow,
    dto: VerifyPurchaseDto,
    receiptHash: string,
  ): Promise<{ replayed: true; row: PurchaseRow } | { replayed: false; id: string }> {
    const id = randomUUID();
    try {
      await this.mysql.execute(
        `INSERT INTO iap_purchases (id, user_id, product_id, provider, store_product_id, transaction_id, receipt_hash, receipt) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [id, userId, product.id, dto.provider, dto.storeProductId, dto.transactionId, receiptHash, dto.receipt],
      );
      return { replayed: false, id };
    } catch (error) {
      if ((error as { code?: string })?.code !== 'ER_DUP_ENTRY') throw error;
      const rows = await this.mysql.query<PurchaseRow[]>(
        `SELECT id, user_id, product_id, provider, store_product_id, transaction_id, status, coins_granted, verify_attempts FROM iap_purchases WHERE provider = ? AND transaction_id = ? LIMIT 1`,
        [dto.provider, dto.transactionId],
      );
      const existing = rows[0];
      if (!existing) throw error;
      // Check ownership before status so failures do not leak another account's state.
      if (existing.user_id !== userId) throw forbidden('This purchase belongs to a different account.');
      if (existing.status === 'credited') return { replayed: true, row: existing };
      if (existing.status === 'refunded') throw conflict('This purchase was refunded and cannot be redeemed again.');
      if (Number(existing.verify_attempts) >= MAX_VERIFY_ATTEMPTS) {
        throw invalid('Too many verification attempts for this purchase. Contact support.');
      }
      // Retry with the latest client receipt (it may have been corrected).
      await this.mysql.execute(`UPDATE iap_purchases SET receipt_hash = ?, receipt = ? WHERE id = ?`, [receiptHash, dto.receipt, existing.id]);
      return { replayed: false, id: existing.id };
    }
  }

  private async recordVerifyFailure(purchaseId: string, error: unknown): Promise<never> {
    const terminal = error instanceof ReceiptVerificationError && error.kind === 'invalid';
    const message = error instanceof Error ? error.message : 'Verification failed.';
    await this.mysql.execute(`UPDATE iap_purchases SET verify_attempts = verify_attempts + 1, status = ?, last_error = ? WHERE id = ?`, [
      terminal ? 'failed' : 'pending',
      message.slice(0, 500),
      purchaseId,
    ]);
    if (terminal) throw invalid(message);
    throw unavailable(error instanceof ReceiptVerificationError ? error.message : 'Store verification is temporarily unavailable. Try again in a moment.');
  }

  private async balance(userId: string) {
    const rows = await this.mysql.query<WalletRow[]>(`SELECT coins, pips FROM wallets WHERE user_id = ?`, [userId]);
    return { coins: Number(rows[0]?.coins ?? 0), pips: Number(rows[0]?.pips ?? 0) };
  }

  private async balanceOnConnection(connection: PoolConnection, userId: string) {
    const [rows] = await connection.query<WalletRow[]>(`SELECT coins, pips FROM wallets WHERE user_id = ?`, [userId]);
    return { coins: Number(rows[0]?.coins ?? 0), pips: Number(rows[0]?.pips ?? 0) };
  }
}
