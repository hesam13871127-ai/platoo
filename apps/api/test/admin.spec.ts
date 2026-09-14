import { AdminService } from '../src/admin/admin.service';
import { BanExpiryService } from '../src/admin/ban-expiry.service';
import { RolesGuard } from '../src/common/guards/roles.guard';

const executeResult = { affectedRows: 1 } as any;

function mysqlStub(overrides: Partial<{ query: jest.Mock; execute: jest.Mock; transaction: jest.Mock }> = {}) {
  const connection = { query: jest.fn().mockResolvedValue([[]]), execute: jest.fn().mockResolvedValue([executeResult, []]) };
  const mysql = {
    query: jest.fn().mockResolvedValue([]),
    execute: jest.fn().mockResolvedValue(executeResult),
    transaction: jest.fn(async (callback: (c: unknown) => Promise<unknown>) => callback(connection)),
    ...overrides,
  };
  return { mysql, connection };
}

describe('admin access control', () => {
  const guard = new RolesGuard({ getAllAndOverride: () => ['admin'] } as any);
  const context = (role: string) => ({ switchToHttp: () => ({ getRequest: () => ({ user: { id: 'u', role } }) }), getHandler: () => null, getClass: () => null }) as any;

  it('allows an admin and rejects a moderator or player on admin-only routes', () => {
    expect(guard.canActivate(context('admin'))).toBe(true);
    expect(() => guard.canActivate(context('moderator'))).toThrow();
    expect(() => guard.canActivate(context('player'))).toThrow();
  });

  it('lets an admin through a moderator-level route', () => {
    const moderatorGuard = new RolesGuard({ getAllAndOverride: () => ['moderator'] } as any);
    expect(moderatorGuard.canActivate(context('admin'))).toBe(true);
    expect(moderatorGuard.canActivate(context('moderator'))).toBe(true);
    expect(() => moderatorGuard.canActivate(context('player'))).toThrow();
  });
});

describe('user moderation', () => {
  it('suspends the account, records the ban and revokes live sessions in one transaction', async () => {
    const { mysql, connection } = mysqlStub({ query: jest.fn().mockResolvedValue([{ id: 'user-1', role: 'player', status: 'active' }]) });
    const service = new AdminService(mysql as any, {} as any);

    const result = await service.banUser('admin-1', 'user-1', { reason: 'Cheating', durationHours: 48 });

    expect(result.status).toBe('suspended');
    const statements = connection.execute.mock.calls.map((call) => String(call[0]));
    expect(statements[0]).toContain('INSERT INTO user_bans');
    expect(statements[0]).toContain('INTERVAL ? HOUR');
    expect(statements[1]).toContain("status = 'suspended'");
    expect(statements[2]).toContain('refresh_sessions');
    expect(mysql.execute.mock.calls.some(([sql]) => String(sql).includes('admin_audit_log'))).toBe(true);
  });

  it('writes a permanent ban without an expiry when no duration is given', async () => {
    const { mysql, connection } = mysqlStub({ query: jest.fn().mockResolvedValue([{ id: 'user-1', role: 'player', status: 'active' }]) });
    await new AdminService(mysql as any, {} as any).banUser('admin-1', 'user-1', { reason: 'Fraud' });
    expect(String(connection.execute.mock.calls[0][0])).toContain('NULL)');
    expect(connection.execute.mock.calls[0][1]).toHaveLength(4);
  });

  it('refuses to ban an admin account or the acting admin', async () => {
    const { mysql } = mysqlStub({ query: jest.fn().mockResolvedValue([{ id: 'user-1', role: 'admin', status: 'active' }]) });
    const service = new AdminService(mysql as any, {} as any);
    await expect(service.banUser('admin-1', 'user-1', { reason: 'nope' })).rejects.toThrow(/Admin accounts cannot be banned/);
    await expect(service.banUser('user-1', 'user-1', { reason: 'nope' })).rejects.toThrow(/own account/);
  });

  it('reactivates the account and lifts every open ban on unban', async () => {
    const { mysql, connection } = mysqlStub({ query: jest.fn().mockResolvedValue([{ id: 'user-1', status: 'suspended' }]) });
    const result = await new AdminService(mysql as any, {} as any).unbanUser('admin-1', 'user-1', { reason: 'Appeal accepted' });
    expect(result.status).toBe('active');
    expect(String(connection.execute.mock.calls[0][0])).toContain('lifted_at = UTC_TIMESTAMP(3)');
    expect(String(connection.execute.mock.calls[1][0])).toContain("status = 'active'");
  });

  it('keeps at least one active admin when demoting a role', async () => {
    const query = jest.fn(async (sql: string) => (sql.includes('COUNT(*)') ? [{ total: 0 }] : [{ id: 'user-1', role: 'admin', status: 'active' }]));
    const { mysql } = mysqlStub({ query });
    await expect(new AdminService(mysql as any, {} as any).updateUser({ id: 'admin-2', role: 'admin' }, 'user-1', { role: 'player' })).rejects.toThrow(/at least one active admin/i);
  });

  it('rejects a wallet adjustment that would go negative and commits a valid one with a ledger row', async () => {
    const { mysql, connection } = mysqlStub();
    connection.query = jest.fn(async (sql: string) => (sql.includes('FROM users') ? [[{ id: 'user-1' }]] : [[{ coins: 100, pips: 5 }]])) as any;
    const service = new AdminService(mysql as any, {} as any);
    await expect(service.adjustWallet('admin-1', 'user-1', { currency: 'coins', amount: -500, reason: 'clawback' })).rejects.toThrow(/below zero/);

    const result = await service.adjustWallet('admin-1', 'user-1', { currency: 'coins', amount: 250, reason: 'support grant' });
    expect(result.balanceAfter).toBe(350);
    expect(connection.execute.mock.calls.some(([sql]) => String(sql).includes('wallet_transactions') && String(sql).includes('admin_adjustment'))).toBe(true);
  });
});

describe('catalogue and game management', () => {
  it('retires an owned shop item instead of deleting it', async () => {
    const query = jest.fn(async (sql: string) => (sql.includes('inventory_items') ? [{ total: 3 }] : [{ id: 'item-1', sku: 'sku', name: 'Frame' }]));
    const { mysql } = mysqlStub({ query });
    const result = await new AdminService(mysql as any, {} as any).deleteShop('admin-1', 'item-1');
    expect(result).toMatchObject({ deleted: false, retired: true });
    expect(mysql.execute.mock.calls.some(([sql]) => String(sql).includes('UPDATE shop_items SET is_active = FALSE'))).toBe(true);
    expect(mysql.execute.mock.calls.some(([sql]) => String(sql).includes('DELETE FROM shop_items'))).toBe(false);
  });

  it('hard deletes an item nobody owns', async () => {
    const query = jest.fn(async (sql: string) => (sql.includes('inventory_items') ? [{ total: 0 }] : [{ id: 'item-1', sku: 'sku', name: 'Frame' }]));
    const { mysql } = mysqlStub({ query });
    const result = await new AdminService(mysql as any, {} as any).deleteShop('admin-1', 'item-1');
    expect(result).toMatchObject({ deleted: true });
    expect(mysql.execute.mock.calls.some(([sql]) => String(sql).includes('DELETE FROM shop_items'))).toBe(true);
  });

  it('requires a price on a new shop item and rejects a duplicate SKU', async () => {
    const { mysql } = mysqlStub({ query: jest.fn().mockResolvedValue([{ id: 'existing' }]) });
    const service = new AdminService(mysql as any, {} as any);
    const base = { sku: 'a', name: 'Item', description: '', category: 'frame', assetKey: 'k', priceCoins: 0, pricePips: 0 };
    await expect(service.createShop('admin-1', base as any)).rejects.toThrow(/coin or pip price/);
    await expect(service.createShop('admin-1', { ...base, priceCoins: 10 } as any)).rejects.toThrow(/already exists/);
  });

  it('cancels queued tickets when a game is disabled but not when it is enabled', async () => {
    const { mysql } = mysqlStub();
    const service = new AdminService(mysql as any, {} as any);
    await service.toggleGame('admin-1', 'chess', { isActive: false });
    expect(mysql.execute.mock.calls.some(([sql]) => String(sql).includes('matchmaking_tickets'))).toBe(true);

    const second = mysqlStub();
    await new AdminService(second.mysql as any, {} as any).toggleGame('admin-1', 'chess', { isActive: true });
    expect(second.mysql.execute.mock.calls.some(([sql]) => String(sql).includes('matchmaking_tickets'))).toBe(false);
  });

  it('rejects a player range where the maximum is below the minimum', async () => {
    const { mysql } = mysqlStub({ query: jest.fn().mockResolvedValue([{ id: 'chess', displayName: 'Chess', minPlayers: 2, maxPlayers: 2, isActive: 1 }]) });
    await expect(new AdminService(mysql as any, {} as any).updateGame('admin-1', 'chess', { maxPlayers: 1 })).rejects.toThrow(/at least the minimum/);
  });
});

describe('reports and seasons', () => {
  it('applies the attached moderation action when a report is resolved', async () => {
    const query = jest.fn(async (sql: string) => {
      if (sql.includes('FROM reports')) return [{ id: 'report-1', status: 'open', reportedUserId: 'user-9' }];
      return [{ id: 'user-9', role: 'player', status: 'active' }];
    });
    const { mysql } = mysqlStub({ query });
    const result = await new AdminService(mysql as any, {} as any).resolveReport('admin-1', 'report-1', { status: 'resolved', action: 'suspend', banDurationHours: 12 });
    expect(result.status).toBe('resolved');
    expect(result.moderation).toMatchObject({ status: 'suspended' });
  });

  it('closes a report without touching the account when no action is attached', async () => {
    const { mysql } = mysqlStub({ query: jest.fn().mockResolvedValue([{ id: 'report-1', status: 'open', reportedUserId: 'user-9' }]) });
    const result = await new AdminService(mysql as any, {} as any).resolveReport('admin-1', 'report-1', { status: 'dismissed' });
    expect(result.moderation).toBeNull();
    expect(mysql.execute.mock.calls.some(([sql]) => String(sql).includes('user_bans'))).toBe(false);
  });

  it('refuses overlapping season reward tiers', async () => {
    const query = jest.fn(async (sql: string) => (sql.includes('FROM season_rewards') ? [{ id: 'reward-1' }] : [{ id: 'season-1' }]));
    const { mysql } = mysqlStub({ query });
    await expect(new AdminService(mysql as any, {} as any).createReward('admin-1', 'season-1', { minRank: 1, maxRank: 10, coins: 100, pips: 0 })).rejects.toThrow(/already covers/);
  });

  it('only finishes an active season and delegates payout to the ranking service', async () => {
    const ranking = { finishSeason: jest.fn().mockResolvedValue(undefined) };
    const scheduled = mysqlStub({ query: jest.fn().mockResolvedValue([{ id: 'season-1', status: 'scheduled' }]) });
    await expect(new AdminService(scheduled.mysql as any, ranking as any).finishSeason('admin-1', 'season-1')).rejects.toThrow(/active season/);
    expect(ranking.finishSeason).not.toHaveBeenCalled();

    const active = mysqlStub({ query: jest.fn().mockResolvedValue([{ id: 'season-1', status: 'active' }]) });
    await new AdminService(active.mysql as any, ranking as any).finishSeason('admin-1', 'season-1');
    expect(ranking.finishSeason).toHaveBeenCalledWith('season-1');
  });

  it('activates one season at a time', async () => {
    const { mysql, connection } = mysqlStub();
    connection.execute = jest.fn().mockResolvedValue([{ affectedRows: 1 }, []]) as any;
    await new AdminService(mysql as any, {} as any).activateSeason('admin-1', 'season-2');
    expect(String(connection.execute.mock.calls[0][0])).toContain("SET status = 'finished' WHERE status = 'active'");
    expect(String(connection.execute.mock.calls[1][0])).toContain("SET status = 'active'");
  });
});

describe('ban expiry sweep', () => {
  it('reinstates an account once its last ban has elapsed', async () => {
    const query = jest.fn(async (sql: string) => (sql.includes('DISTINCT user_id') ? [{ userId: 'user-1' }] : []));
    const { mysql } = mysqlStub({ query });
    await new BanExpiryService(mysql as any).sweep();
    expect(mysql.execute.mock.calls.some(([sql]) => String(sql).includes("SET status = 'active'"))).toBe(true);
  });

  it('leaves an account suspended while another ban is still open', async () => {
    const query = jest.fn(async (sql: string) => (sql.includes('DISTINCT user_id') ? [{ userId: 'user-1' }] : [{ id: 'ban-2' }]));
    const { mysql } = mysqlStub({ query });
    await new BanExpiryService(mysql as any).sweep();
    expect(mysql.execute.mock.calls.some(([sql]) => String(sql).includes("SET status = 'active'"))).toBe(false);
  });
});
