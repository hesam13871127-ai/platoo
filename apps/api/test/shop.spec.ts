import { WalletService } from '../src/wallet/wallet.service';

const USER = 'user-1';
const FRIEND = 'user-2';

const avatarItem = (overrides: Record<string, unknown> = {}) => ({
  id: 'item-1',
  sku: 'avatar-neon',
  name: 'Neon Nova',
  description: 'A bright neon profile avatar.',
  category: 'avatar',
  price_coins: 500,
  price_pips: 0,
  asset_key: 'avatar_neon',
  is_giftable: 1,
  is_active: 1,
  stock: null,
  metadata: null,
  starts_at: null,
  ends_at: null,
  ...overrides,
});

const bundleItem = (overrides: Record<string, unknown> = {}) =>
  avatarItem({
    id: 'bundle-1',
    sku: 'bundle-starter',
    name: 'Starter Vibe Pack',
    category: 'bundle',
    price_coins: 0,
    price_pips: 150,
    asset_key: 'bundle_starter',
    metadata: { grants: { coins: 1500, pips: 0, items: [{ itemId: 'item-1', quantity: 1 }] } },
    ...overrides,
  });

/** Catalogue row as the SQL aliases it (camelCase), plus ownership columns. */
const catalogRow = (overrides: Record<string, unknown> = {}) => ({
  id: 'item-1',
  sku: 'avatar-neon',
  name: 'Neon Nova',
  description: 'A bright neon profile avatar.',
  category: 'avatar',
  priceCoins: 500,
  pricePips: 0,
  assetKey: 'avatar_neon',
  isLimited: 0,
  isGiftable: 1,
  stock: null,
  metadata: null,
  endsAt: null,
  ownedQuantity: 0,
  equipped: 0,
  ...overrides,
});

interface HarnessOptions {
  item?: Record<string, unknown>;
  catalogRows?: Record<string, unknown>[];
  inventoryRows?: Record<string, unknown>[];
  wallet?: { coins: number; pips: number; version?: number };
  ownRows?: Record<string, unknown>[];
  ledgerRows?: Record<string, unknown>[];
  stockRows?: number;
}

function harness(options: HarnessOptions = {}) {
  const executed: Array<{ sql: string; params: unknown[] }> = [];
  const item = options.item ?? avatarItem();
  const connection = {
    query: jest.fn(async (sql: string, params: unknown[] = []) => {
      if (sql.includes('FROM shop_items WHERE id IN')) {
        return [params.map((id) => ({ id: String(id), name: id === 'item-1' ? 'Neon Nova' : String(item.name), category: id === 'item-1' ? 'avatar' : String(item.category), assetKey: id === 'item-1' ? 'avatar_neon' : String(item.asset_key) }))];
      }
      if (sql.includes('FROM shop_items')) return [[item]];
      if (sql.includes('FROM wallets')) return [[options.wallet ?? { coins: 1000, pips: 40, version: 1 }]];
      if (sql.includes('FROM inventory_items')) return [options.ownRows ?? []];
      if (sql.includes('FROM users')) return [[{ id: 'user-2', displayName: 'Mina' }]];
      if (sql.includes('FROM wallet_transactions')) return [options.ledgerRows ?? []];
      return [[]];
    }),
    execute: jest.fn(async (sql: string, params: unknown[] = []): Promise<[Record<string, unknown>, unknown[]]> => {
      executed.push({ sql, params });
      if (sql.includes('UPDATE shop_items SET stock')) return [{ affectedRows: options.stockRows ?? 1 }, []];
      return [{ affectedRows: 1 }, []];
    }),
  };
  const mysql = {
    // MysqlService.query already unwraps `[rows, fields]`, so this returns rows directly.
    query: jest.fn(async (sql: string, _params: unknown[] = []) => (sql.includes('FROM inventory_items') ? options.inventoryRows ?? [] : options.catalogRows ?? [])),
    execute: jest.fn(async (sql: string, params: unknown[] = []) => {
      executed.push({ sql, params });
      return { affectedRows: 1 };
    }),
    transaction: jest.fn(async (callback: (connection: unknown) => Promise<unknown>) => callback(connection)),
  };
  return { mysql, connection, executed };
}

const find = (executed: Array<{ sql: string; params: unknown[] }>, needle: string) => executed.find((entry) => entry.sql.includes(needle));

describe('shop catalogue', () => {
  it('annotates items with ownership, currency and equippability, and resolves bundle contents', async () => {
    const { mysql } = harness({
      catalogRows: [
        catalogRow({ ownedQuantity: 1, equipped: 1 }),
        catalogRow({ id: 'bundle-1', name: 'Starter Vibe Pack', category: 'bundle', priceCoins: 0, pricePips: 150, metadata: { grants: { coins: 1500, items: ['item-1'] } } }),
      ],
    });
    const service = new WalletService(mysql as any);

    const catalog: any[] = await service.catalog(USER);

    expect(catalog).toHaveLength(2);
    expect(catalog[0]).toMatchObject({ id: 'item-1', price: 500, currency: 'coins', owned: true, ownedQuantity: 1, equipped: true, equippable: true, bundle: null });
    expect(catalog[1]).toMatchObject({ id: 'bundle-1', price: 150, currency: 'pips', owned: false, equippable: false });
    expect(catalog[1].bundle).toMatchObject({ coins: 1500, pips: 0 });
    expect(catalog[1].bundle.items).toEqual([{ id: 'item-1', name: 'Neon Nova', category: 'avatar', assetKey: 'avatar_neon', quantity: 1 }]);
    // The catalogue is user-aware: ownership is joined on the signed-in player.
    expect(mysql.query.mock.calls[0][1]).toEqual([USER]);
  });

  it('hides items with no grants from the bundle view', async () => {
    const { mysql } = harness({ catalogRows: [catalogRow({ category: 'bundle', metadata: '{"other":true}' })] });
    const service = new WalletService(mysql as any);

    const [entry] = await service.catalog(USER) as any[];

    expect(entry.bundle).toBeNull();
  });
});

describe('shop purchase', () => {
  it('charges the wallet, stocks out one unit and writes the ledger row', async () => {
    const { mysql, executed } = harness({ item: avatarItem({ stock: 5 }) });
    const service = new WalletService(mysql as any);

    const result: any = await service.buy(USER, { itemId: 'item-1', idempotencyKey: 'key-1' } as any);

    expect(result).toMatchObject({ success: true, replayed: false, item: { id: 'item-1', name: 'Neon Nova' } });
    expect(find(executed, 'UPDATE shop_items SET stock = stock - 1')?.params).toEqual(['item-1']);
    expect(find(executed, 'UPDATE wallets SET coins = ?')?.params).toEqual([500, USER]);
    expect(find(executed, 'INSERT INTO inventory_items')).toBeTruthy();
    const ledger = find(executed, 'INSERT INTO wallet_transactions');
    expect(ledger?.params).toEqual([expect.any(String), USER, 'coins', -500, 500, 'item-1', 'key-1']);
  });

  it('refuses a purchase the wallet cannot cover without touching money', async () => {
    const { mysql, executed } = harness({ wallet: { coins: 100, pips: 0, version: 1 } });
    const service = new WalletService(mysql as any);

    await expect(service.buy(USER, { itemId: 'item-1' } as any)).rejects.toThrow('Not enough coins.');
    expect(find(executed, 'UPDATE wallets SET')).toBeUndefined();
    expect(find(executed, 'INSERT INTO inventory_items')).toBeUndefined();
  });

  it('never charges when the last unit is taken away by another buyer', async () => {
    const { mysql, executed } = harness({ item: avatarItem({ stock: 1 }), stockRows: 0 });
    const service = new WalletService(mysql as any);

    await expect(service.buy(USER, { itemId: 'item-1' } as any)).rejects.toThrow('This item just sold out.');
    expect(find(executed, 'UPDATE wallets SET')).toBeUndefined();
  });

  it('replays an already-processed idempotency key instead of charging twice', async () => {
    const { mysql, executed } = harness({ ledgerRows: [{ id: 'tx-1', referenceId: 'item-1' }] });
    const service = new WalletService(mysql as any);

    const result: any = await service.buy(USER, { itemId: 'item-1', idempotencyKey: 'key-1' } as any);

    expect(result).toMatchObject({ success: true, replayed: true, transactionId: 'tx-1' });
    expect(find(executed, 'UPDATE wallets SET')).toBeUndefined();
  });

  it('rejects an idempotency key that was used for another item', async () => {
    const { mysql } = harness({ ledgerRows: [{ id: 'tx-1', referenceId: 'item-9' }] });
    const service = new WalletService(mysql as any);

    await expect(service.buy(USER, { itemId: 'item-1', idempotencyKey: 'key-1' } as any)).rejects.toThrow('already used for a different item');
  });

  it('blocks items that are not inside their sale window yet', async () => {
    const { mysql, executed } = harness({ item: avatarItem({ starts_at: '2999-01-01 00:00:00.000' }) });
    const service = new WalletService(mysql as any);

    await expect(service.buy(USER, { itemId: 'item-1' } as any)).rejects.toThrow('not for sale right now');
    expect(find(executed, 'UPDATE wallets SET')).toBeUndefined();
  });

  it('grants coins and contained items when a bundle is bought', async () => {
    const { mysql, executed } = harness({ item: bundleItem(), wallet: { coins: 1000, pips: 400, version: 1 } });
    const service = new WalletService(mysql as any);

    const result: any = await service.buy(USER, { itemId: 'bundle-1' } as any);

    // The 150 pip price is charged first, then the granted 1,500 coins land.
    expect(find(executed, 'UPDATE wallets SET pips = ?')?.params).toEqual([250, USER]);
    expect(find(executed, 'UPDATE wallets SET coins = ?, version = version + 1')?.params).toEqual([2500, USER]);
    expect(result.granted).toMatchObject({ coins: 1500, pips: 0 });
    expect(result.granted.items).toEqual([{ id: 'item-1', name: 'Neon Nova', category: 'avatar', assetKey: 'avatar_neon', quantity: 1 }]);
    // One ledger row for the price, one for the coin grant.
    expect(executed.filter((entry) => entry.sql.includes('INSERT INTO wallet_transactions'))).toHaveLength(2);
  });
});

describe('inventory and equipping', () => {
  it('lists owned items with numbers and booleans already normalised', async () => {
    const { mysql } = harness({
      inventoryRows: [
        { id: 'inv-1', itemId: 'item-1', quantity: '2', equipped: 1, sku: 'avatar-neon', name: 'Neon Nova', description: '', category: 'avatar', assetKey: 'avatar_neon', isGiftable: 1, acquiredAt: '2026-09-01 10:00:00.000', expiresAt: null },
        { id: 'inv-2', itemId: 'bundle-1', quantity: 1, equipped: 0, sku: 'bundle-starter', name: 'Starter Vibe Pack', description: '', category: 'bundle', assetKey: 'bundle_starter', isGiftable: 0 },
      ],
    });
    const service = new WalletService(mysql as any);

    const inventory: any[] = await service.inventory(USER);

    expect(String(mysql.query.mock.calls[0][0])).toContain('i.quantity > 0');
    expect(inventory[0]).toMatchObject({ quantity: 2, equipped: true, isGiftable: true, equippable: true });
    expect(inventory[1]).toMatchObject({ equipped: false, isGiftable: false, equippable: false });
  });

  it('keeps exactly one item of a category equipped', async () => {
    const { mysql, executed } = harness({ ownRows: [{ category: 'avatar', quantity: 1 }] });
    const service = new WalletService(mysql as any);

    await service.equip(USER, { itemId: 'item-1' } as any);

    expect(find(executed, 'SET i.equipped = FALSE WHERE i.user_id = ? AND s.category = ?')?.params).toEqual([USER, 'avatar']);
    expect(find(executed, 'SET equipped = TRUE WHERE user_id = ? AND shop_item_id = ?')?.params).toEqual([USER, 'item-1']);
  });

  it('takes an item off with equipped:false instead of equipping it', async () => {
    const { mysql, executed } = harness({ ownRows: [{ category: 'avatar', quantity: 3 }] });
    const service = new WalletService(mysql as any);

    await service.equip(USER, { itemId: 'item-1', equipped: false } as any);

    expect(find(executed, 'SET equipped = FALSE WHERE user_id = ? AND shop_item_id = ?')?.params).toEqual([USER, 'item-1']);
    expect(find(executed, 'SET equipped = TRUE')).toBeUndefined();
  });

  it('refuses to equip a container item', async () => {
    const { mysql } = harness({ ownRows: [{ category: 'bundle', quantity: 1 }] });
    const service = new WalletService(mysql as any);

    await expect(service.equip(USER, { itemId: 'bundle-1' } as any)).rejects.toThrow('cannot be equipped');
  });

  it('refuses to equip an item the player does not own', async () => {
    const { mysql } = harness();
    const service = new WalletService(mysql as any);

    await expect(service.equip(USER, { itemId: 'item-1' } as any)).rejects.toThrow('You do not own this item.');
  });
});

describe('gifting', () => {
  it('moves the item, writes the receipt and notifies the recipient', async () => {
    const { mysql, executed } = harness({ ownRows: [{ quantity: 2 }] });
    const chat = { createPrivate: jest.fn(async () => ({ id: 'conv-1' })), send: jest.fn(async () => ({ id: 'msg-1' })) };
    const service = new WalletService(mysql as any, chat as any);

    const result: any = await service.gift(USER, { recipientId: FRIEND, itemId: 'item-1', quantity: 1, note: 'enjoy' } as any);

    expect(result).toMatchObject({ success: true, item: 'Neon Nova', quantity: 1 });
    expect(find(executed, 'UPDATE inventory_items SET quantity = quantity - ?')).toBeTruthy();
    expect(find(executed, 'INSERT INTO inventory_items')).toBeTruthy();
    expect(find(executed, 'INSERT INTO gift_transactions')).toBeTruthy();
    expect(chat.createPrivate).toHaveBeenCalledWith(USER, FRIEND);
    expect(chat.send).toHaveBeenCalledWith(USER, expect.objectContaining({ conversationId: 'conv-1', kind: 'gift', giftItemId: 'item-1' }));
  });

  it('clears the equipped flag when the last copy is gifted away', async () => {
    const { mysql, executed } = harness({ ownRows: [{ quantity: 1 }] });
    const service = new WalletService(mysql as any);

    await service.gift(USER, { recipientId: FRIEND, itemId: 'item-1' } as any);

    const update = find(executed, 'SET quantity = quantity - ?');
    expect(update?.params).toEqual([1, 0, USER, 'item-1']);
  });

  it('still delivers when the chat notification is unavailable', async () => {
    const { mysql } = harness({ ownRows: [{ quantity: 1 }] });
    const chat = { createPrivate: jest.fn(async () => { throw new Error('chat down'); }) };
    const service = new WalletService(mysql as any, chat as any);

    await expect(service.gift(USER, { recipientId: FRIEND, itemId: 'item-1' } as any)).resolves.toMatchObject({ success: true });
  });

  it('refuses self gifts and stacks the sender does not own', async () => {
    const { mysql } = harness({ ownRows: [{ quantity: 1 }] });
    const service = new WalletService(mysql as any);

    await expect(service.gift(USER, { recipientId: USER, itemId: 'item-1' } as any)).rejects.toThrow('cannot gift yourself');
    await expect(service.gift(USER, { recipientId: FRIEND, itemId: 'item-1', quantity: 2 } as any)).rejects.toThrow('do not own enough');
  });

  it('refuses items the shop marked as non-giftable', async () => {
    const { mysql } = harness({ item: avatarItem({ is_giftable: 0 }), ownRows: [{ quantity: 1 }] });
    const service = new WalletService(mysql as any);

    await expect(service.gift(USER, { recipientId: FRIEND, itemId: 'item-1' } as any)).rejects.toThrow('cannot be gifted');
  });

  it('reads gift history in both directions', async () => {
    const { mysql } = harness();
    mysql.query = jest.fn(async (_sql: string, _params: unknown[] = []) => [{ id: 'g-1', quantity: '1', direction: 'received', counterpartName: 'Mina', itemName: 'Neon Nova', category: 'avatar', assetKey: 'avatar_neon', note: null, createdAt: '2026-09-10 12:00:00.000' }]) as any;
    const service = new WalletService(mysql as any);

    const gifts: any[] = await service.gifts(USER);

    expect(gifts[0]).toMatchObject({ direction: 'received', quantity: 1, counterpartName: 'Mina' });
  });
});
