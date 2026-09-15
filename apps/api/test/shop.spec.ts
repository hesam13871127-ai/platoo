import { WalletService } from '../src/wallet/wallet.service';

const ITEM_AVATAR = {
  id: 'item-1',
  sku: 'avatar-neon',
  name: 'Neon Nova',
  description: 'A bright neon avatar',
  category: 'avatar',
  price_coins: 500,
  price_pips: 0,
  asset_key: 'avatar_neon',
  is_giftable: 1,
  is_active: 1,
  is_limited: 0,
  stock: null,
};

const ITEM_LIMITED_TABLE = {
  id: 'item-2',
  sku: 'table-aurora',
  name: 'Aurora Table',
  description: 'Limited Aurora table',
  category: 'table',
  price_coins: 1500,
  price_pips: 0,
  asset_key: 'table_aurora',
  is_giftable: 1,
  is_active: 1,
  is_limited: 1,
  stock: 2,
};

const ok = [{ affectedRows: 1 }, []] as any;

describe('wallet & shop operations', () => {
  const userId = 'user-1';
  const recipientId = 'user-2';

  describe('catalog and inventory queries', () => {
    it('returns formatted shop catalog with boolean flags and numeric prices', async () => {
      const mysql = {
        query: jest.fn().mockResolvedValue([
          { id: 'item-1', sku: 'avatar-1', name: 'Item', description: 'Desc', category: 'avatar', priceCoins: '500', pricePips: '0', assetKey: 'a1', isLimited: 1, isGiftable: 1, stock: '5' },
        ]),
      };
      const service = new WalletService(mysql as any);
      const catalog = await service.catalog();
      expect(catalog[0]).toEqual({
        id: 'item-1',
        sku: 'avatar-1',
        name: 'Item',
        description: 'Desc',
        category: 'avatar',
        priceCoins: 500,
        pricePips: 0,
        assetKey: 'a1',
        isLimited: true,
        isGiftable: true,
        stock: 5,
      });
    });

    it('returns filtered inventory where quantity > 0 and formatted types', async () => {
      const mysql = {
        query: jest.fn().mockResolvedValue([
          { id: 'inv-1', itemId: 'item-1', quantity: '2', equipped: 1, sku: 'avatar-1', name: 'Item', description: 'Desc', category: 'avatar', assetKey: 'a1', isGiftable: 1 },
        ]),
      };
      const service = new WalletService(mysql as any);
      const items = await service.inventory(userId);
      expect(items[0]).toEqual({
        id: 'inv-1',
        itemId: 'item-1',
        quantity: 2,
        equipped: true,
        sku: 'avatar-1',
        name: 'Item',
        description: 'Desc',
        category: 'avatar',
        assetKey: 'a1',
        isGiftable: true,
      });
    });
  });

  describe('purchases', () => {
    it('successfully purchases an item with coins, decrements wallet and inserts inventory', async () => {
      const executed: Array<{ sql: string; params?: unknown[] }> = [];
      const connection = {
        query: jest.fn(async (sql: string) => {
          if (sql.includes('FROM shop_items')) return [[ITEM_AVATAR]];
          if (sql.includes('FROM wallets')) return [[{ coins: 1000, pips: 0, version: 1 }]];
          return [[]];
        }),
        execute: jest.fn(async (sql: string, params: unknown[]) => {
          executed.push({ sql, params });
          return ok;
        }),
      };
      const mysql = {
        transaction: jest.fn(async (cb: (c: unknown) => Promise<unknown>) => cb(connection)),
      };
      const service = new WalletService(mysql as any);

      const result = await service.buy(userId, { itemId: 'item-1', quantity: 1 });
      expect(result.success).toBe(true);
      expect(result.replayed).toBe(false);
      expect(result.totalPrice).toBe(500);

      const walletUpdate = executed.find((e) => e.sql.includes('UPDATE wallets SET coins'));
      expect(walletUpdate?.params?.[0]).toBe(500);

      const inventoryInsert = executed.find((e) => e.sql.includes('INSERT INTO inventory_items'));
      expect(inventoryInsert).toBeDefined();

      const txInsert = executed.find((e) => e.sql.includes('INSERT INTO wallet_transactions'));
      expect(txInsert?.sql).toContain("'purchase'");
    });

    it('rejects purchase if balance is insufficient', async () => {
      const connection = {
        query: jest.fn(async (sql: string) => {
          if (sql.includes('FROM shop_items')) return [[ITEM_AVATAR]];
          if (sql.includes('FROM wallets')) return [[{ coins: 200, pips: 0, version: 1 }]];
          return [[]];
        }),
        execute: jest.fn().mockResolvedValue(ok),
      };
      const mysql = {
        transaction: jest.fn(async (cb: (c: unknown) => Promise<unknown>) => cb(connection)),
      };
      const service = new WalletService(mysql as any);

      await expect(service.buy(userId, { itemId: 'item-1', quantity: 1 })).rejects.toThrow('Not enough coins');
    });

    it('decrements stock for limited items and rejects if out of stock', async () => {
      const soldOutTable = { ...ITEM_LIMITED_TABLE, stock: 0 };
      const connection = {
        query: jest.fn(async (sql: string) => {
          if (sql.includes('FROM shop_items')) return [[soldOutTable]];
          if (sql.includes('FROM wallets')) return [[{ coins: 5000, pips: 0, version: 1 }]];
          return [[]];
        }),
        execute: jest.fn().mockResolvedValue(ok),
      };
      const mysql = {
        transaction: jest.fn(async (cb: (c: unknown) => Promise<unknown>) => cb(connection)),
      };
      const service = new WalletService(mysql as any);

      await expect(service.buy(userId, { itemId: 'item-2', quantity: 1 })).rejects.toThrow('sold out');
    });
  });

  describe('equipping and unequipping', () => {
    it('equips an item and unequips previous items in the same category', async () => {
      const executed: Array<{ sql: string; params?: unknown[] }> = [];
      const connection = {
        execute: jest.fn(async (sql: string, params: unknown[]) => {
          executed.push({ sql, params });
          return ok;
        }),
      };
      const mysql = {
        query: jest.fn()
          .mockResolvedValueOnce([{ equipped: 0, category: 'avatar' }]) // check owned
          .mockResolvedValueOnce([{ id: 'inv-1', itemId: 'item-1', quantity: 1, equipped: 1, category: 'avatar' }]), // refreshed inventory
        transaction: jest.fn(async (cb: (c: unknown) => Promise<unknown>) => cb(connection)),
      };
      const service = new WalletService(mysql as any);

      await service.equip(userId, { itemId: 'item-1', equipped: true });

      const unequipCategory = executed.find((e) => e.sql.includes('SET i.equipped = FALSE WHERE i.user_id = ? AND s.category = ?'));
      expect(unequipCategory?.params).toEqual([userId, 'avatar']);

      const equipItem = executed.find((e) => e.sql.includes('SET equipped = TRUE WHERE user_id = ? AND shop_item_id = ?'));
      expect(equipItem?.params).toEqual([userId, 'item-1']);
    });

    it('unequips an item when equipped=false is passed', async () => {
      const executed: Array<{ sql: string; params?: unknown[] }> = [];
      const connection = {
        execute: jest.fn(async (sql: string, params: unknown[]) => {
          executed.push({ sql, params });
          return ok;
        }),
      };
      const mysql = {
        query: jest.fn()
          .mockResolvedValueOnce([{ equipped: 1, category: 'avatar' }])
          .mockResolvedValueOnce([]),
        transaction: jest.fn(async (cb: (c: unknown) => Promise<unknown>) => cb(connection)),
      };
      const service = new WalletService(mysql as any);

      await service.equip(userId, { itemId: 'item-1', equipped: false });

      const unequipItem = executed.find((e) => e.sql.includes('SET equipped = FALSE WHERE user_id = ? AND shop_item_id = ?'));
      expect(unequipItem?.params).toEqual([userId, 'item-1']);
    });
  });

  describe('gifting', () => {
    it('gifts from inventory when sender already owns the item', async () => {
      const executed: Array<{ sql: string; params?: unknown[] }> = [];
      const connection = {
        query: jest.fn(async (sql: string) => {
          if (sql.includes('FROM users')) return [[{ id: recipientId, displayName: 'Friend' }]];
          if (sql.includes('FROM shop_items')) return [[ITEM_AVATAR]];
          if (sql.includes('FROM inventory_items')) return [[{ quantity: 2, equipped: 0 }]];
          return [[]];
        }),
        execute: jest.fn(async (sql: string, params: unknown[]) => {
          executed.push({ sql, params });
          return ok;
        }),
      };
      const mysql = {
        transaction: jest.fn(async (cb: (c: unknown) => Promise<unknown>) => cb(connection)),
      };
      const service = new WalletService(mysql as any);

      const result = await service.gift(userId, { recipientId, itemId: 'item-1', quantity: 1, note: 'Enjoy!' });
      expect(result.success).toBe(true);
      expect(result.boughtDirect).toBe(false);

      const senderDeduct = executed.find((e) => e.sql.includes('UPDATE inventory_items SET quantity = quantity - ?'));
      expect(senderDeduct?.params).toEqual([1, userId, 'item-1']);

      const giftTx = executed.find((e) => e.sql.includes('INSERT INTO gift_transactions'));
      expect(giftTx?.params).toContain('Enjoy!');
    });

    it('directly purchases and gifts when sender does not own the item', async () => {
      const executed: Array<{ sql: string; params?: unknown[] }> = [];
      const connection = {
        query: jest.fn(async (sql: string) => {
          if (sql.includes('FROM users')) return [[{ id: recipientId, displayName: 'Friend' }]];
          if (sql.includes('FROM shop_items')) return [[ITEM_AVATAR]];
          if (sql.includes('FROM inventory_items')) return [[]]; // sender owns 0
          if (sql.includes('FROM wallets')) return [[{ coins: 1000, pips: 0, version: 1 }]];
          return [[]];
        }),
        execute: jest.fn(async (sql: string, params: unknown[]) => {
          executed.push({ sql, params });
          return ok;
        }),
      };
      const mysql = {
        transaction: jest.fn(async (cb: (c: unknown) => Promise<unknown>) => cb(connection)),
      };
      const service = new WalletService(mysql as any);

      const result = await service.gift(userId, { recipientId, itemId: 'item-1', quantity: 1, note: 'Gift for you' });
      expect(result.success).toBe(true);
      expect(result.boughtDirect).toBe(true);
      expect(result.totalPrice).toBe(500);

      const walletDeduct = executed.find((e) => e.sql.includes('UPDATE wallets SET coins'));
      expect(walletDeduct?.params?.[0]).toBe(500);

      const walletTx = executed.find((e) => e.sql.includes('INSERT INTO wallet_transactions'));
      expect(walletTx?.sql).toContain("'gift_sent'");

      const recipientInventory = executed.find((e) => e.sql.includes('INSERT INTO inventory_items'));
      expect(recipientInventory?.params).toContain(recipientId);
    });

    it('rejects gifting to self', async () => {
      const service = new WalletService({} as any);
      await expect(service.gift(userId, { recipientId: userId, itemId: 'item-1' })).rejects.toThrow('cannot gift yourself');
    });
  });
});
