import { IapService } from '../src/iap/iap.service';

const PRODUCT = {
  id: 'prod-1',
  sku: 'coins-500',
  store_product_id: 'com.vibetable.coins500',
  provider: 'apple',
  coins: 500,
  bonus_coins: 0,
  price_micros: 990000,
  currency: 'USD',
  sort_order: 1,
};
const USER_ID = 'user-1';

const testReceipt = (transactionId: string, productId: string, userId: string) =>
  JSON.stringify({ test: true, transactionId, productId, userId });

const dto = (overrides: Record<string, unknown> = {}) => ({
  provider: 'apple',
  storeProductId: 'com.vibetable.coins500',
  transactionId: 'tx-1',
  receipt: testReceipt('tx-1', 'com.vibetable.coins500', USER_ID),
  ...overrides,
});

function configMock(values: Record<string, unknown>) {
  return { get: (key: string, fallback?: unknown) => (key in values ? values[key] : fallback) };
}

const devConfig = () => configMock({ nodeEnv: 'test', 'iap.devEnabled': true });
const prodLikeConfig = () => configMock({ nodeEnv: 'test', 'iap.devEnabled': false });

const ok = [{ affectedRows: 1 }, []] as any;

describe('iap purchase verification', () => {
  it('credits a fresh test purchase once through an iap_credit ledger row', async () => {
    const executed: Array<{ sql: string; params: unknown[] }> = [];
    const connection = {
      query: jest.fn(async (sql: string) => {
        if (sql.includes('FROM iap_purchases')) return [[{ id: 'p-1', status: 'verified' }]];
        if (sql.includes('FROM wallets')) return [[{ coins: 1000, pips: 5 }]];
        return [[]];
      }),
      execute: jest.fn(async (sql: string, params: unknown[]) => {
        executed.push({ sql, params });
        return ok;
      }),
    };
    const mysql = {
      query: jest.fn(async () => [PRODUCT]),
      execute: jest.fn(async () => ok),
      transaction: jest.fn(async (callback: (connection: unknown) => Promise<unknown>) => callback(connection)),
    };
    const service = new IapService(mysql as any, devConfig() as any);

    const result: any = await service.verify(USER_ID, dto() as any);

    expect(result).toMatchObject({ success: true, credited: true, replayed: false, coins: 500, balance: { coins: 1500, pips: 5 } });
    expect(mysql.execute.mock.calls.some(([sql]: string[]) => sql.includes('INSERT INTO iap_purchases'))).toBe(true);
    expect(executed.some(({ sql, params }) => sql.includes('UPDATE wallets SET coins') && params[0] === 1500)).toBe(true);
    const ledger = executed.find(({ sql }) => sql.includes('INSERT INTO wallet_transactions'));
    expect(ledger?.sql).toContain("'iap_credit'");
    expect(ledger?.params).toContain('iap:apple:tx-1');
    // Only coins move; pips are never granted by IAP.
    expect(ledger?.sql).toContain("'coins'");
    expect(executed.some(({ sql, params }) => sql.includes("status = 'credited'") && params[0] === 500)).toBe(true);
  });

  it('replays an already-credited transaction without touching the wallet', async () => {
    const mysql = {
      query: jest.fn(async (sql: string) => {
        if (sql.includes('FROM iap_products')) return [PRODUCT];
        if (sql.includes('FROM iap_purchases')) {
          return [{ id: 'p-9', user_id: USER_ID, status: 'credited', coins_granted: 500, verify_attempts: 1 }];
        }
        if (sql.includes('FROM wallets')) return [{ coins: 1500, pips: 5 }];
        return [];
      }),
      execute: jest.fn(async (sql: string) => {
        if (sql.includes('INSERT INTO iap_purchases')) throw Object.assign(new Error('Duplicate entry'), { code: 'ER_DUP_ENTRY' });
        return ok;
      }),
      transaction: jest.fn(),
    };
    const service = new IapService(mysql as any, devConfig() as any);

    const result: any = await service.verify(USER_ID, dto() as any);

    expect(result).toMatchObject({ success: true, credited: true, replayed: true, coins: 500, balance: { coins: 1500, pips: 5 } });
    expect(mysql.transaction).not.toHaveBeenCalled();
  });

  it('rejects a transaction owned by a different account', async () => {
    const mysql = {
      query: jest.fn(async (sql: string) => {
        if (sql.includes('FROM iap_products')) return [PRODUCT];
        return [{ id: 'p-9', user_id: 'user-2', status: 'credited', coins_granted: 500, verify_attempts: 1 }];
      }),
      execute: jest.fn(async (sql: string) => {
        if (sql.includes('INSERT INTO iap_purchases')) throw Object.assign(new Error('Duplicate entry'), { code: 'ER_DUP_ENTRY' });
        return ok;
      }),
      transaction: jest.fn(),
    };
    const service = new IapService(mysql as any, devConfig() as any);

    await expect(service.verify(USER_ID, dto() as any)).rejects.toThrow('different account');
    expect(mysql.transaction).not.toHaveBeenCalled();
  });

  it('rejects unknown products before claiming a row or calling any store', async () => {
    const mysql = { query: jest.fn(async () => []), execute: jest.fn(), transaction: jest.fn() };
    const service = new IapService(mysql as any, devConfig() as any);

    await expect(service.verify(USER_ID, dto({ storeProductId: 'com.vibetable.nope' }) as any)).rejects.toThrow('not available');
    expect(mysql.execute).not.toHaveBeenCalled();
  });

  it('rejects test receipts bound to a different user and marks the attempt failed', async () => {
    const executed: Array<{ sql: string; params: unknown[] }> = [];
    const mysql = {
      query: jest.fn(async () => [PRODUCT]),
      execute: jest.fn(async (sql: string, params: unknown[]) => {
        executed.push({ sql, params });
        return ok;
      }),
      transaction: jest.fn(),
    };
    const service = new IapService(mysql as any, devConfig() as any);

    await expect(
      service.verify(USER_ID, dto({ receipt: testReceipt('tx-1', 'com.vibetable.coins500', 'user-2') }) as any),
    ).rejects.toThrow('different user');
    expect(executed.some(({ sql, params }) => sql.includes('UPDATE iap_purchases SET') && params.includes('failed'))).toBe(true);
    expect(mysql.transaction).not.toHaveBeenCalled();
  });

  it('fails closed with 503 when the real store verifier has no credentials', async () => {
    const executed: Array<{ sql: string; params: unknown[] }> = [];
    const mysql = {
      query: jest.fn(async () => [PRODUCT]),
      execute: jest.fn(async (sql: string, params: unknown[]) => {
        executed.push({ sql, params });
        return ok;
      }),
      transaction: jest.fn(),
    };
    const service = new IapService(mysql as any, prodLikeConfig() as any);

    const error: any = await service.verify(USER_ID, dto() as any).catch((err) => err);
    expect(error.getStatus()).toBe(503);
    expect(error.message).toContain('not configured');
    // Misconfiguration must not burn the purchase: it stays pending for a later retry.
    expect(executed.some(({ sql, params }) => sql.includes('UPDATE iap_purchases SET') && params.includes('pending'))).toBe(true);
    expect(mysql.transaction).not.toHaveBeenCalled();
  });

  it('self-heals the ledger ENUM only when iap_credit is missing', async () => {
    const missing = { query: jest.fn(async () => [{ columnType: "enum('signup','purchase')" }]), execute: jest.fn(async (_sql: string) => ok) };
    await (new IapService(missing as any, devConfig() as any) as any).ensureLedgerType();
    expect(missing.execute).toHaveBeenCalledTimes(1);
    expect(String(missing.execute.mock.calls[0][0])).toContain("'iap_credit'");

    const present = { query: jest.fn(async () => [{ columnType: "enum('signup','iap_credit')" }]), execute: jest.fn() };
    await (new IapService(present as any, devConfig() as any) as any).ensureLedgerType();
    expect(present.execute).not.toHaveBeenCalled();
  });
});
