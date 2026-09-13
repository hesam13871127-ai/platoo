import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { createHash, randomInt, randomUUID } from 'node:crypto';
import { jwtVerify, createRemoteJWKSet, JWTPayload } from 'jose';
import { PoolConnection, RowDataPacket } from 'mysql2/promise';
import { MysqlService } from '../database/mysql.service';
import { conflict, invalid, notFound, unauthenticated } from '../common/errors';
import { RequestOtpDto, SocialLoginDto, UpdatePreferencesDto } from './auth.dto';
import { AuthenticatedUser } from '../common/decorators/current-user.decorator';

interface UserRow extends RowDataPacket {
  id: string; username: string; display_name: string; phone_e164: string | null; email: string | null;
  avatar_url: string | null; locale: 'en' | 'fa'; theme: 'light' | 'dark' | 'system'; role: AuthenticatedUser['role'];
  level: number; experience: number; coins: number; pips: number;
}

interface IdentityClaims extends JWTPayload { sub: string; email?: string; name?: string; email_verified?: boolean; }

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private readonly appleKeys = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));
  private readonly googleKeys = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));

  constructor(
    private readonly mysql: MysqlService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async requestOtp(dto: RequestOtpDto): Promise<{ challengeId: string; expiresAt: string; devCode?: string }> {
    const phone = dto.phone.trim();
    const recent = await this.mysql.query<RowDataPacket[]>(
      `SELECT COUNT(*) AS count FROM otp_challenges WHERE phone_e164 = ? AND created_at > UTC_TIMESTAMP(3) - INTERVAL 60 SECOND`, [phone],
    );
    if (Number(recent[0]?.count ?? 0) >= 3) throw invalid('Too many code requests. Please wait one minute.');

    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    const challengeId = randomUUID();
    const ttlSeconds = this.config.get<number>('otp.ttlSeconds', 300);
    const expiresAt = new Date(Date.now() + ttlSeconds * 1000);
    const hash = this.hashCode(challengeId, code);
    await this.mysql.execute(
      `INSERT INTO otp_challenges (id, phone_e164, code_hash, purpose, expires_at) VALUES (?, ?, ?, 'login', ?)`,
      [challengeId, phone, hash, expiresAt],
    );
    await this.deliverOtp(phone, code);
    const response: { challengeId: string; expiresAt: string; devCode?: string } = { challengeId, expiresAt: expiresAt.toISOString() };
    if (this.config.get<boolean>('otp.devEnabled', false)) response.devCode = code;
    return response;
  }

  async verifyOtp(challengeId: string, code: string, userAgent?: string, ipAddress?: string) {
    const userId = await this.mysql.transaction(async (connection) => {
      const [rows] = await connection.query<RowDataPacket[]>(
        `SELECT * FROM otp_challenges WHERE id = ? LIMIT 1 FOR UPDATE`, [challengeId],
      );
      const challenge = rows[0] as (RowDataPacket & { phone_e164: string; code_hash: string; attempts: number; expires_at: string; consumed_at: string | null }) | undefined;
      if (!challenge || challenge.consumed_at || new Date(challenge.expires_at).getTime() < Date.now()) throw unauthenticated('This verification code has expired.');
      const maxAttempts = this.config.get<number>('otp.maxAttempts', 5);
      if (challenge.attempts >= maxAttempts) throw unauthenticated('Too many incorrect verification attempts.');
      if (this.hashCode(challengeId, code) !== challenge.code_hash) {
        await connection.execute(`UPDATE otp_challenges SET attempts = attempts + 1 WHERE id = ?`, [challengeId]);
        throw unauthenticated('The verification code is incorrect.');
      }
      await connection.execute(`UPDATE otp_challenges SET consumed_at = UTC_TIMESTAMP(3) WHERE id = ?`, [challengeId]);
      return this.upsertPhoneUser(connection, challenge.phone_e164);
    });
    return this.issueSession(userId, userAgent, ipAddress);
  }

  async socialLogin(dto: SocialLoginDto, userAgent?: string, ipAddress?: string) {
    const claims = await this.verifySocialToken(dto.provider, dto.token);
    const providerSubject = claims.sub;
    if (!providerSubject) throw unauthenticated('The identity provider did not return a subject.');
    const userId = await this.mysql.transaction(async (connection) => {
      const [existing] = await connection.query<RowDataPacket[]>(`SELECT user_id FROM auth_identities WHERE provider = ? AND provider_subject = ? LIMIT 1`, [dto.provider, providerSubject]);
      if (existing[0]?.user_id) {
        await connection.execute(`UPDATE auth_identities SET last_used_at = UTC_TIMESTAMP(3), provider_email = ? WHERE provider = ? AND provider_subject = ?`, [claims.email ?? null, dto.provider, providerSubject]);
        return existing[0].user_id as string;
      }
      const userId = randomUUID();
      const name = this.safeDisplayName(dto.displayName ?? claims.name ?? claims.email?.split('@')[0] ?? 'Vibe Player');
      const username = await this.uniqueUsername(connection, name);
      await connection.execute(`INSERT INTO users (id, username, display_name, email) VALUES (?, ?, ?, ?)`, [userId, username, name, claims.email ?? null]);
      await connection.execute(`INSERT INTO auth_identities (id, user_id, provider, provider_subject, provider_email, last_used_at) VALUES (?, ?, ?, ?, ?, UTC_TIMESTAMP(3))`, [randomUUID(), userId, dto.provider, providerSubject, claims.email ?? null]);
      await connection.execute(`INSERT INTO wallets (user_id, coins) VALUES (?, 1000)`, [userId]);
      await connection.execute(`INSERT INTO wallet_transactions (id, user_id, currency, amount, balance_after, type, reference_id) VALUES (?, ?, 'coins', 1000, 1000, 'signup', ?)`, [randomUUID(), userId, userId]);
      return userId;
    });
    return this.issueSession(userId, userAgent, ipAddress);
  }

  async refresh(refreshToken: string, userAgent?: string, ipAddress?: string) {
    let payload: { sub: string; sid: string };
    try {
      payload = await this.jwt.verifyAsync<{ sub: string; sid: string }>(refreshToken, { secret: this.config.getOrThrow<string>('jwt.refreshSecret') });
    } catch {
      throw unauthenticated('The refresh token is invalid or expired.');
    }
    const tokenHash = this.hash(refreshToken);
    const userId = await this.mysql.transaction(async (connection) => {
      const [rows] = await connection.query<RowDataPacket[]>(`SELECT user_id FROM refresh_sessions WHERE id = ? AND token_hash = ? AND revoked_at IS NULL AND expires_at > UTC_TIMESTAMP(3) LIMIT 1 FOR UPDATE`, [payload.sid, tokenHash]);
      if (!rows[0]) throw unauthenticated('The refresh session is no longer active.');
      await connection.execute(`UPDATE refresh_sessions SET revoked_at = UTC_TIMESTAMP(3), last_used_at = UTC_TIMESTAMP(3) WHERE id = ?`, [payload.sid]);
      return rows[0].user_id as string;
    });
    return this.issueSession(userId, userAgent, ipAddress);
  }

  async logout(user: AuthenticatedUser): Promise<void> {
    if (user.sessionId) await this.mysql.execute(`UPDATE refresh_sessions SET revoked_at = UTC_TIMESTAMP(3) WHERE id = ? AND user_id = ? AND revoked_at IS NULL`, [user.sessionId, user.id]);
  }

  async getMe(userId: string) {
    const rows = await this.mysql.query<UserRow[]>(
      `SELECT u.*, COALESCE(w.coins, 0) AS coins, COALESCE(w.pips, 0) AS pips FROM users u LEFT JOIN wallets w ON w.user_id = u.id WHERE u.id = ? AND u.status = 'active' LIMIT 1`, [userId],
    );
    if (!rows[0]) throw notFound('User not found.');
    return this.publicUser(rows[0]);
  }

  async updatePreferences(userId: string, dto: UpdatePreferencesDto) {
    const fields: string[] = [];
    const values: unknown[] = [];
    if (dto.locale) { fields.push('locale = ?'); values.push(dto.locale); }
    if (dto.theme) { fields.push('theme = ?'); values.push(dto.theme); }
    if (fields.length) await this.mysql.execute(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`, [...values, userId]);
    return this.getMe(userId);
  }

  private async issueSession(userId: string, userAgent?: string, ipAddress?: string) {
    const user = await this.getMe(userId);
    const sessionId = randomUUID();
    const accessToken = await this.jwt.signAsync({ sub: user.id, role: user.role, sid: sessionId }, { secret: this.config.getOrThrow<string>('jwt.accessSecret'), expiresIn: this.config.get<string>('jwt.accessTtl', '15m') });
    const refreshToken = await this.jwt.signAsync({ sub: user.id, role: user.role, sid: sessionId }, { secret: this.config.getOrThrow<string>('jwt.refreshSecret'), expiresIn: this.config.get<string>('jwt.refreshTtl', '30d') });
    const expiresAt = new Date(Date.now() + this.parseTtl(this.config.get<string>('jwt.refreshTtl', '30d')));
    await this.mysql.execute(`INSERT INTO refresh_sessions (id, user_id, token_hash, user_agent, ip_address, expires_at) VALUES (?, ?, ?, ?, ?, ?)`, [sessionId, user.id, this.hash(refreshToken), userAgent?.slice(0, 500) ?? null, ipAddress ?? null, expiresAt]);
    return { accessToken, refreshToken, expiresAt: expiresAt.toISOString(), user };
  }

  private async upsertPhoneUser(connection: PoolConnection, phone: string): Promise<string> {
    const [identity] = await connection.query<RowDataPacket[]>(`SELECT user_id FROM auth_identities WHERE provider = 'phone' AND provider_subject = ? LIMIT 1`, [phone]);
    if (identity[0]?.user_id) {
      await connection.execute(`UPDATE auth_identities SET last_used_at = UTC_TIMESTAMP(3) WHERE id = (SELECT id FROM (SELECT id FROM auth_identities WHERE provider = 'phone' AND provider_subject = ? LIMIT 1) AS identity_lookup)`, [phone]);
      return identity[0].user_id as string;
    }
    const userId = randomUUID();
    const username = await this.uniqueUsername(connection, `player${phone.slice(-6)}`);
    await connection.execute(`INSERT INTO users (id, username, display_name, phone_e164) VALUES (?, ?, ?, ?)`, [userId, username, `Player ${phone.slice(-4)}`, phone]);
    await connection.execute(`INSERT INTO auth_identities (id, user_id, provider, provider_subject, last_used_at) VALUES (?, ?, 'phone', ?, UTC_TIMESTAMP(3))`, [randomUUID(), userId, phone]);
    await connection.execute(`INSERT INTO wallets (user_id, coins) VALUES (?, 1000)`, [userId]);
    await connection.execute(`INSERT INTO wallet_transactions (id, user_id, currency, amount, balance_after, type, reference_id) VALUES (?, ?, 'coins', 1000, 1000, 'signup', ?)`, [randomUUID(), userId, userId]);
    return userId;
  }

  private async uniqueUsername(connection: PoolConnection, source: string): Promise<string> {
    const base = source.toLowerCase().replace(/[^a-z0-9_]/g, '').slice(0, 24) || 'player';
    let username = base;
    for (let attempt = 0; attempt < 100; attempt += 1) {
      const [rows] = await connection.query<RowDataPacket[]>(`SELECT id FROM users WHERE username = ? LIMIT 1`, [username]);
      if (!rows[0]) return username;
      username = `${base.slice(0, 18)}${randomInt(1000, 9999)}`;
    }
    throw conflict('Unable to create a unique username.');
  }

  private async verifySocialToken(provider: 'google' | 'apple', token: string): Promise<IdentityClaims> {
    try {
      const issuer = provider === 'google' ? 'https://accounts.google.com' : 'https://appleid.apple.com';
      const audience = provider === 'google' ? this.config.get<string>('googleClientId') : this.config.get<string>('appleBundleId', 'com.vibetable.app');
      if (provider === 'google' && !audience) throw invalid('Google sign-in is not configured.');
      const result = await jwtVerify(token, provider === 'google' ? this.googleKeys : this.appleKeys, { issuer, ...(audience ? { audience } : {}) });
      return result.payload as IdentityClaims;
    } catch {
      throw unauthenticated(`The ${provider} identity token is invalid.`);
    }
  }

  private async deliverOtp(phone: string, code: string): Promise<void> {
    const webhook = this.config.get<string>('otp.webhookUrl');
    if (webhook) {
      const response = await fetch(webhook, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ phone, code }) });
      if (!response.ok) throw invalid('The verification message could not be sent.');
      return;
    }
    if (this.config.get<boolean>('otp.devEnabled', false)) {
      this.logger.warn(`Development OTP for ${phone}: ${code}`);
      return;
    }
    throw invalid('Phone verification is not configured.');
  }

  private hashCode(challengeId: string, code: string): string { return this.hash(`${challengeId}:${code}`); }
  private hash(value: string): string { return createHash('sha256').update(value).digest('hex'); }
  private safeDisplayName(value: string): string { return value.trim().replace(/[<>]/g, '').slice(0, 80) || 'Vibe Player'; }
  private parseTtl(value: string): number {
    const match = /^(\d+)([smhd])$/.exec(value.trim());
    if (!match) return 30 * 24 * 60 * 60 * 1000;
    const unit = { s: 1000, m: 60_000, h: 3_600_000, d: 86_400_000 }[match[2] as 's' | 'm' | 'h' | 'd'];
    return Number(match[1]) * unit;
  }
  private publicUser(user: UserRow) {
    return { id: user.id, username: user.username, displayName: user.display_name, phone: user.phone_e164, email: user.email, avatarUrl: user.avatar_url, locale: user.locale, theme: user.theme, role: user.role, level: user.level, experience: user.experience, coins: Number(user.coins), pips: Number(user.pips) };
  }
}
