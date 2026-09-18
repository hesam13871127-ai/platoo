import 'reflect-metadata';
import { RequestMethod } from '@nestjs/common';
import { METHOD_METADATA, MODULE_METADATA, PATH_METADATA } from '@nestjs/common/constants';
import { AdminController } from '../src/admin/admin.controller';
import { AdminModule } from '../src/admin/admin.module';
import { AuthController } from '../src/auth/auth.controller';
import { AuthModule } from '../src/auth/auth.module';
import { AppModule } from '../src/app.module';
import { ChatController } from '../src/chat/chat.controller';
import { ChatModule } from '../src/chat/chat.module';
import { GameController } from '../src/games/game.controller';
import { GameModule } from '../src/games/game.module';
import { IapController } from '../src/iap/iap.controller';
import { IapModule } from '../src/iap/iap.module';
import { MatchmakingController } from '../src/matchmaking/matchmaking.controller';
import { MatchmakingModule } from '../src/matchmaking/matchmaking.module';
import { RankingController } from '../src/ranking/ranking.controller';
import { RankingModule } from '../src/ranking/ranking.module';
import { UsersController } from '../src/users/users.controller';
import { UsersModule } from '../src/users/users.module';
import { VoiceController } from '../src/voice/voice.controller';
import { VoiceModule } from '../src/voice/voice.module';
import { WalletController } from '../src/wallet/wallet.controller';
import { WalletModule } from '../src/wallet/wallet.module';

const methodNames = new Map<number, string>([
  [RequestMethod.GET, 'GET'],
  [RequestMethod.POST, 'POST'],
  [RequestMethod.PUT, 'PUT'],
  [RequestMethod.DELETE, 'DELETE'],
  [RequestMethod.PATCH, 'PATCH'],
]);

type ControllerClass = { new (...args: any[]): any; prototype: Record<string, any> };

type ModuleClass = { new (...args: any[]): any };

function controllerRoutes(controller: ControllerClass): string[] {
  const controllerPath = String(Reflect.getMetadata(PATH_METADATA, controller) ?? '').replace(/^\/+|\/+$/g, '');
  return Object.getOwnPropertyNames(controller.prototype)
    .filter((name) => name !== 'constructor')
    .flatMap((name) => {
      const handler = controller.prototype[name];
      const path = Reflect.getMetadata(PATH_METADATA, handler);
      const method = methodNames.get(Reflect.getMetadata(METHOD_METADATA, handler));
      if (path === undefined || !method) return [];
      const paths = Array.isArray(path) ? path : [path];
      return paths.map((item) => {
        const suffix = String(item).replace(/^\/+|\/+$/g, '');
        return `${method} /api/v1/${[controllerPath, suffix].filter(Boolean).join('/')}`;
      });
    });
}

function moduleControllers(moduleClass: ModuleClass): unknown[] {
  return Reflect.getMetadata(MODULE_METADATA.CONTROLLERS, moduleClass) ?? [];
}

describe('REST route contracts', () => {
  it('keeps every mobile-facing controller registered in its feature module and AppModule', () => {
    const featureModules: Array<[ModuleClass, ControllerClass]> = [
      [AuthModule, AuthController],
      [UsersModule, UsersController],
      [WalletModule, WalletController],
      [ChatModule, ChatController],
      [VoiceModule, VoiceController],
      [GameModule, GameController],
      [MatchmakingModule, MatchmakingController],
      [RankingModule, RankingController],
      [AdminModule, AdminController],
      [IapModule, IapController],
    ];
    const appImports = (Reflect.getMetadata(MODULE_METADATA.IMPORTS, AppModule) ?? []) as unknown[];

    for (const [featureModule, controller] of featureModules) {
      expect(moduleControllers(featureModule)).toContain(controller);
      expect(appImports).toContain(featureModule);
    }
  });

  it('publishes auth, staff, shop, game, matchmaking and social paths beneath the global API prefix', () => {
    const routes = [
      ...controllerRoutes(AuthController),
      ...controllerRoutes(AdminController),
      ...controllerRoutes(GameController),
      ...controllerRoutes(MatchmakingController),
      ...controllerRoutes(WalletController),
      ...controllerRoutes(IapController),
      ...controllerRoutes(UsersController),
      ...controllerRoutes(ChatController),
      ...controllerRoutes(VoiceController),
      ...controllerRoutes(RankingController),
    ];

    expect(routes).toEqual(expect.arrayContaining([
      'POST /api/v1/auth/otp/request',
      'POST /api/v1/auth/otp/verify',
      'POST /api/v1/auth/dev-admin',
      'POST /api/v1/auth/refresh',
      'GET /api/v1/admin/overview',
      'GET /api/v1/admin/analytics',
      'GET /api/v1/admin/matches/recent',
      'GET /api/v1/admin/users',
      'GET /api/v1/admin/users/:id',
      'GET /api/v1/admin/shop',
      'GET /api/v1/admin/games',
      'GET /api/v1/admin/reports',
      'GET /api/v1/admin/reports/:id',
      'GET /api/v1/admin/seasons',
      'GET /api/v1/admin/seasons/:id',
      'GET /api/v1/admin/audit-log',
      'POST /api/v1/matches',
      'GET /api/v1/matches/:id',
      'POST /api/v1/matches/:id/actions',
      'POST /api/v1/matches/:id/resign',
      'GET /api/v1/games',
      'POST /api/v1/matchmaking/join',
      'GET /api/v1/matchmaking/:id',
      'GET /api/v1/shop/items',
      'POST /api/v1/shop/purchase',
      'GET /api/v1/iap/products',
      'GET /api/v1/users/me',
      'GET /api/v1/users/search',
      'GET /api/v1/chat/conversations',
      'POST /api/v1/chat/messages',
      'POST /api/v1/voice/token',
      'GET /api/v1/ranking/:gameId/leaderboard',
    ]));
  });
});
