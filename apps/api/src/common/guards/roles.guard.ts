import { CanActivate, ExecutionContext, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from '../decorators/roles.decorator';
import { AuthenticatedUser } from '../decorators/current-user.decorator';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<AuthenticatedUser['role'][]>(ROLES_KEY, [context.getHandler(), context.getClass()]);
    if (!required?.length) return true;
    const user = context.switchToHttp().getRequest<{ user?: AuthenticatedUser }>().user;
    if (!user) throw new UnauthorizedException('A valid access token is required.');
    // Admins inherit moderator privileges; anything requiring only 'admin' stays admin-only.
    if (required.includes(user.role) || (user.role === 'admin' && required.includes('moderator'))) return true;
    const adminOnly = required.includes('admin') && !required.includes('moderator');
    throw new ForbiddenException(adminOnly ? 'This action requires admin privileges.' : 'This action requires moderator privileges.');
  }
}
