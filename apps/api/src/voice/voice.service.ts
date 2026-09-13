import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AccessToken } from 'livekit-server-sdk';
import { randomUUID } from 'node:crypto';
import { RowDataPacket } from 'mysql2/promise';
import { MysqlService } from '../database/mysql.service';
import { forbidden, invalid } from '../common/errors';

@Injectable()
export class VoiceService {
  constructor(private readonly mysql: MysqlService, private readonly config: ConfigService) {}

  async token(userId: string, matchId?: string, conversationId?: string) {
    if ((!matchId && !conversationId) || (matchId && conversationId)) throw invalid('Provide exactly one matchId or conversationId.');
    let roomName: string;
    if (matchId) {
      const rows = await this.mysql.query<RowDataPacket[]>(`SELECT id FROM match_players WHERE match_id = ? AND user_id = ?`, [matchId, userId]);
      if (!rows[0]) throw forbidden('You are not a player in this match.');
      roomName = `match-${matchId}`;
    } else {
      const rows = await this.mysql.query<RowDataPacket[]>(`SELECT id FROM conversation_members WHERE conversation_id = ? AND user_id = ?`, [conversationId, userId]);
      if (!rows[0]) throw forbidden('You are not a member of this conversation.');
      roomName = `conversation-${conversationId}`;
    }
    const apiKey = this.config.get<string>('livekit.apiKey');
    const apiSecret = this.config.get<string>('livekit.apiSecret');
    const serverUrl = this.config.get<string>('livekit.url');
    if (!apiKey || !apiSecret || !serverUrl) throw invalid('Voice chat is not configured.');
    const existing = await this.mysql.query<RowDataPacket[]>(`SELECT id FROM voice_rooms WHERE room_name = ? LIMIT 1`, [roomName]);
    const roomId = existing[0]?.id as string | undefined ?? randomUUID();
    if (existing[0]) await this.mysql.execute(`UPDATE voice_rooms SET ended_at = NULL WHERE id = ?`, [roomId]);
    else await this.mysql.execute(`INSERT INTO voice_rooms (id, match_id, conversation_id, provider, room_name) VALUES (?, ?, ?, 'livekit', ?)`, [roomId, matchId ?? null, conversationId ?? null, roomName]);
    await this.mysql.execute(`INSERT INTO voice_participants (room_id, user_id) VALUES (?, ?) ON DUPLICATE KEY UPDATE left_at = NULL`, [roomId, userId]);
    const token = new AccessToken(apiKey, apiSecret, { identity: userId, ttl: '1h' });
    token.addGrant({ roomJoin: true, room: roomName, canPublish: true, canSubscribe: true });
    return { token: await token.toJwt(), url: serverUrl, roomName };
  }
}
