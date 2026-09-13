import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { RowDataPacket } from 'mysql2/promise';
import { AuthenticatedUser } from '../decorators/current-user.decorator';
import { MysqlService } from '../../database/mysql.service';

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly jwt: JwtService, private readonly config: ConfigService, private readonly mysql: MysqlService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<{ headers: Record<string, string | undefined>; user?: AuthenticatedUser }>();
    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) throw new UnauthorizedException('A valid access token is required.');
    try {
      const payload = await this.jwt.verifyAsync<{ sub: string; sid?: string }>(header.slice(7), { secret: this.config.getOrThrow<string>('jwt.accessSecret') });
      const rows = await this.mysql.query<RowDataPacket[]>(`SELECT role, status FROM users WHERE id = ? LIMIT 1`, [payload.sub]);
      if (!rows[0] || rows[0].status !== 'active') throw new UnauthorizedException('This account is not active.');
      request.user = { id: payload.sub, role: rows[0].role as AuthenticatedUser['role'], sessionId: payload.sid };
      return true;
    } catch (error) {
      if (error instanceof UnauthorizedException) throw error;
      throw new UnauthorizedException('The access token is invalid or expired.');
    }
  }
}
