import { AdminService } from '../src/admin/admin.service';

const ok = { affectedRows: 1 } as any;

interface MysqlStub {
  query: jest.Mock;
  execute: jest.Mock;
  transaction: jest.Mock;
}

function stubMysql(routes: Record<string, unknown[] | unknown>, executeImpl?: (sql: string) => unknown): MysqlStub {
  const pick = (sql: string): unknown[] => {
    for (const [fragment, rows] of Object.entries(routes)) {
      if (sql.includes(fragment)) return rows as unknown[];
    }
    return [];
  };
  const connection = {
    query: jest.fn(async (sql: string) => [pick(sql)]),
    execute: jest.fn(async (sql: string) => (executeImpl ? executeImpl(sql) : ok)),
  };
  return {
    query: jest.fn(async (sql: string) => pick(sql)),
    execute: jest.fn(async (sql: string) => (executeImpl ? executeImpl(sql) : ok)),
    transaction: jest.fn(async (callback: (connection: unknown) => Promise<unknown>) => callback(connection)),
  };
}

const ranking = { finishSeason: jest.fn().mockResolvedValue(undefined) };

describe('admin safety rules', () => {
  beforeEach(() => jest.clearAllMocks());

  it('refuses to ban the acting admin account', async () => {
    const mysql = stubMysql({ 'FROM users WHERE id': [{ id: 'admin-1', username: 'root', role: 'admin', status: 'active' }] });
    const service = new AdminService(mysql as any, ranking as any);
    await expect(service.banUser('admin-1', 'admin-1', {})).rejects.toThrow('You cannot ban your own account.');
  });

  it('refuses to ban other admin accounts', async () => {
    const mysql = stubMysql({ 'FROM users WHERE id': [{ id: 'admin-2', username: 'root2', role: 'admin', status: 'active' }] });
    const service = new AdminService(mysql as any, ranking as any);
    await expect(service.banUser('admin-1', 'admin-2', {})).rejects.toThrow('Admin accounts cannot be banned');
  });

  it('bans a player, revokes sessions, and audits the action', async () => {
    const mysql = stubMysql({});
    // First call returns the active user, second call (after update) returns suspended.
    mysql.query
      .mockResolvedValueOnce([{ id: 'user-1', username: 'trouble', role: 'player', status: 'active' }])
      .mockResolvedValueOnce([{ id: 'user-1', username: 'trouble', role: 'player', status: 'suspended' }]);
    const service = new AdminService(mysql as any, ranking as any);
    const result = await service.banUser('admin-1', 'user-1', { reason: 'spam' });
    expect(result).toMatchObject({ id: 'user-1', status: 'suspended' });
    expect(mysql.transaction).toHaveBeenCalledTimes(1);
    expect(mysql.execute).toHaveBeenCalledWith(expect.stringContaining('admin_audit_log'), expect.arrayContaining(['admin-1', 'user.ban']));
  });

  it('refuses to demote the last active admin', async () => {
    const mysql = stubMysql({
      'SELECT id, username, role, status FROM users': [{ id: 'admin-1', username: 'root', role: 'admin', status: 'active' }],
      "role = 'admin'": [{ total: 0 }],
    });
    const service = new AdminService(mysql as any, ranking as any);
    await expect(service.updateUser('admin-2', 'admin-1', { role: 'player' })).rejects.toThrow('last active admin');
  });

  it('refuses moderator suspension from a report', async () => {
    const mysql = stubMysql({
      'FROM reports r LEFT JOIN users reported': [{ id: 'report-1', status: 'open', reportedUserId: 'user-9', reportedRole: 'player', reportedStatus: 'active' }],
    });
    const service = new AdminService(mysql as any, ranking as any);
    await expect(service.resolveReport('mod-1', 'moderator', 'report-1', { status: 'resolved', moderationAction: 'suspend_reported' })).rejects.toThrow(
      'Only admins can suspend accounts',
    );
  });

  it('refuses to hard-delete a shop item owned by players', async () => {
    const mysql = stubMysql({
      'FROM shop_items WHERE id': [{ id: 'item-1', sku: 'avatar-x', name: 'Avatar X' }],
      'FROM inventory_items': [{ refs: 3 }],
    });
    const service = new AdminService(mysql as any, ranking as any);
    await expect(service.deleteShop('admin-1', 'item-1', true)).rejects.toThrow('only be deactivated');
  });

  it('maps duplicate SKUs to a conflict error', async () => {
    const mysql = stubMysql({}, (sql: string) => {
      if (sql.includes('INSERT INTO shop_items')) throw Object.assign(new Error('Duplicate entry'), { code: 'ER_DUP_ENTRY' });
      return ok;
    });
    const service = new AdminService(mysql as any, ranking as any);
    await expect(
      service.createShop('admin-1', { sku: 'dup', name: 'Dup', description: 'd', category: 'emote', priceCoins: 10, pricePips: 0, assetKey: 'e' } as any),
    ).rejects.toThrow('already exists');
  });

  it('returns paginated user search results', async () => {
    const mysql = stubMysql({
      'SELECT COUNT(*)': [{ total: 45 }],
      'FROM users u LEFT JOIN wallets': [{ id: 'user-1', level: 3, experience: 100, coins: 50, pips: 0 }],
    });
    const service = new AdminService(mysql as any, ranking as any);
    const page = await service.users('tro', 'active', undefined, 1, 20);
    expect(page.total).toBe(45);
    expect(page.page).toBe(1);
    expect(page.totalPages).toBe(3);
    expect(page.items).toHaveLength(1);
  });

  it('rejects invalid game player ranges', async () => {
    const mysql = stubMysql({ 'FROM games WHERE id': [{ id: 'chess', min_players: 2, max_players: 2, is_active: 1 }] });
    const service = new AdminService(mysql as any, ranking as any);
    await expect(service.updateGame('admin-1', 'chess', { minPlayers: 4, maxPlayers: 2 })).rejects.toThrow('player range is invalid');
  });

  it('locks finished seasons against edits and finishes only active ones', async () => {
    const finished = stubMysql({ 'FROM seasons WHERE id': [{ id: 'season-1', name: 'S1', status: 'finished' }] });
    const service = new AdminService(finished as any, ranking as any);
    await expect(service.updateSeason('admin-1', 'season-1', { name: 'Rename' })).rejects.toThrow('Finished seasons cannot be edited');
    await expect(service.finishSeason('admin-1', 'season-1')).rejects.toThrow('Only the active season can be finished');
  });

  it('finishes the active season through the ranking service', async () => {
    const mysql = stubMysql({ 'FROM seasons WHERE id': [{ id: 'season-2', status: 'active' }] });
    const service = new AdminService(mysql as any, ranking as any);
    await expect(service.finishSeason('admin-1', 'season-2')).resolves.toEqual({ success: true });
    expect(ranking.finishSeason).toHaveBeenCalledWith('season-2');
  });
});
