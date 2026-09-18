import { CORE_GAME_IDS, GameRegistry } from '../src/games/game.registry';
import { GameService } from '../src/games/game.service';
import { MatchmakingService } from '../src/matchmaking/matchmaking.service';
import { AdminController } from '../src/admin/admin.controller';
import { AdminService } from '../src/admin/admin.service';
import { AuthService } from '../src/auth/auth.service';
import { RolesGuard } from '../src/common/guards/roles.guard';

const coreRows = (futureEnabled = false) => [
  ...CORE_GAME_IDS.map((id) => ({ id, isActive: 1 })),
  { id: 'bingo', isActive: futureEnabled ? 1 : 0 },
  { id: 'mini_golf', isActive: 0 },
];

const executionContext = (user: unknown) => ({
  getHandler: () => function handler() {},
  getClass: () => class Controller {},
  switchToHttp: () => ({ getRequest: () => ({ user }) }),
});

describe('focused core-game release gate', () => {
  it('keeps the default server catalog to the ten active core games', async () => {
    const mysql = { query: jest.fn(async () => coreRows()) };
    const service = new GameService(mysql as any, new GameRegistry(), {} as any);

    const games = await service.listGames();

    expect(games).toHaveLength(CORE_GAME_IDS.length);
    expect(games.map((game) => game.id).sort()).toEqual([...CORE_GAME_IDS].sort());
    expect(games).not.toContainEqual(expect.objectContaining({ id: 'bingo' }));
  });

  it('lets a re-enabled retained game flow through the player catalog', async () => {
    const mysql = { query: jest.fn(async () => coreRows(true)) };
    const games = new GameService(mysql as any, new GameRegistry(), {} as any);

    const listed = await games.listGames();

    expect(listed).toContainEqual(expect.objectContaining({ id: 'bingo' }));
  });

  it('rejects disabled games before any match can be created or queued', async () => {
    const mysql = {
      query: jest.fn(async (sql: string) => sql.includes('is_active') ? [{ isActive: 0 }] : []),
      execute: jest.fn(),
      transaction: jest.fn(),
    };
    const games = new GameService(mysql as any, new GameRegistry(), {} as any);
    const matchmaking = new MatchmakingService(mysql as any, games, new GameRegistry());

    await expect(games.createMatch('bingo', 'casual', ['player-1'])).rejects.toThrow('currently unavailable');
    await expect(matchmaking.join('player-1', { gameId: 'bingo', mode: 'casual', playerCount: 2 } as any)).rejects.toThrow('currently unavailable');
  });

  it('reports future games as disabled by default and permits reversible admin reactivation', async () => {
    const mysql = {
      query: jest.fn(async (sql: string) => {
        if (sql.includes('ORDER BY displayName')) return [{ id: 'bingo', displayName: 'Bingo', isActive: 0 }];
        if (sql.includes('FROM games WHERE id')) return [{ id: 'bingo', is_active: 0, min_players: 2, max_players: 8, config: '{}' }];
        return [];
      }),
      execute: jest.fn(async () => ({ affectedRows: 1 })),
    };
    const service = new AdminService(mysql as any, { finishSeason: jest.fn() } as any);

    const listed = await service.games();
    expect(listed[0]).toMatchObject({ isCore: false, isActive: false, releaseState: 'disabled_future' });
    await expect(service.updateGame('admin-1', 'bingo', { isActive: true })).resolves.toMatchObject({ id: 'bingo' });
    expect(mysql.execute).toHaveBeenCalledWith(expect.stringContaining('is_active = ?'), [true, 'bingo']);

    const controller = new AdminController(service);
    await expect(controller.updateGame({ id: 'mod-1', role: 'moderator' }, 'bingo', { isActive: true })).resolves.toMatchObject({ id: 'bingo' });
    await expect(Promise.resolve().then(() => controller.updateGame({ id: 'mod-1', role: 'moderator' }, 'bingo', { displayName: 'Hidden' }))).rejects.toThrow('only change game availability');
  });
});

describe('development admin access and role authority', () => {
  const config = (values: Record<string, unknown>) => ({ get: jest.fn((key: string, fallback?: unknown) => key in values ? values[key] : fallback), getOrThrow: jest.fn((key: string) => values[key] ?? `${key}-secret`) });

  it('rejects the development shortcut when disabled or when a player owns the username', async () => {
    const disabled = new AuthService({} as any, {} as any, config({ 'devAdmin.enabled': false }) as any);
    await expect(disabled.devAdminLogin({ username: 'admin', password: 'vibetable-admin' })).rejects.toThrow('disabled');

    const mysql = { query: jest.fn(async () => [{ id: 'player-1', role: 'player', status: 'active' }]) };
    const service = new AuthService(mysql as any, {} as any, config({ 'devAdmin.enabled': true, 'devAdmin.username': 'admin', 'devAdmin.password': 'secret' }) as any);
    await expect(service.devAdminLogin({ username: 'admin', password: 'secret' })).rejects.toThrow('not authorized');
  });

  it('issues a normal session only for an existing staff account', async () => {
    const mysql = { query: jest.fn(async () => [{ id: 'admin-1', role: 'moderator', status: 'active' }]), execute: jest.fn() };
    const jwt = { signAsync: jest.fn().mockResolvedValueOnce('access').mockResolvedValueOnce('refresh') };
    const service = new AuthService(mysql as any, jwt as any, config({ 'devAdmin.enabled': true, 'devAdmin.username': 'admin', 'devAdmin.password': 'secret', 'jwt.accessSecret': 'access-secret', 'jwt.refreshSecret': 'refresh-secret' }) as any);
    jest.spyOn(service, 'getMe').mockResolvedValue({ id: 'admin-1', role: 'moderator' } as any);

    const session = await service.devAdminLogin({ username: 'admin', password: 'secret' }, 'test-agent', '127.0.0.1');

    expect(session).toMatchObject({ accessToken: 'access', refreshToken: 'refresh', user: { id: 'admin-1', role: 'moderator' } });
    expect(mysql.execute).toHaveBeenCalledWith(expect.stringContaining('refresh_sessions'), expect.any(Array));
  });

  it('allows staff roles and rejects player roles at the server guard', () => {
    const reflector = { getAllAndOverride: jest.fn().mockReturnValue(['moderator', 'admin']) };
    const guard = new RolesGuard(reflector as any);

    expect(guard.canActivate(executionContext({ id: 'admin-1', role: 'admin' }) as any)).toBe(true);
    expect(guard.canActivate(executionContext({ id: 'mod-1', role: 'moderator' }) as any)).toBe(true);
    expect(() => guard.canActivate(executionContext({ id: 'player-1', role: 'player' }) as any)).toThrow('moderator privileges');
  });
});
