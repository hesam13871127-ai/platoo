import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { RowDataPacket } from 'mysql2/promise';
import { MysqlService } from '../database/mysql.service';
import { conflict, forbidden, invalid, notFound } from '../common/errors';
import { SendMessageDto } from './chat.dto';

@Injectable()
export class ChatService {
  constructor(private readonly mysql: MysqlService) {}

  async conversations(userId: string) {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT c.id, c.type, COALESCE(c.title, (SELECT other_user.display_name FROM conversation_members other_member JOIN users other_user ON other_user.id = other_member.user_id WHERE other_member.conversation_id = c.id AND other_member.user_id <> ? LIMIT 1)) AS title, c.group_id AS groupId, c.match_id AS matchId, c.created_at AS createdAt, cm.last_read_message_id AS lastReadMessageId, (SELECT body FROM messages m WHERE m.conversation_id = c.id AND m.deleted_at IS NULL ORDER BY m.created_at DESC LIMIT 1) AS lastMessage, (SELECT created_at FROM messages m WHERE m.conversation_id = c.id AND m.deleted_at IS NULL ORDER BY m.created_at DESC LIMIT 1) AS lastMessageAt, (SELECT COUNT(*) FROM conversation_members unread_cm JOIN messages unread_m ON unread_m.conversation_id = unread_cm.conversation_id AND unread_m.created_at > COALESCE((SELECT created_at FROM messages read_m WHERE read_m.id = unread_cm.last_read_message_id), '1970-01-01') WHERE unread_cm.conversation_id = c.id AND unread_cm.user_id = ? AND unread_m.sender_id <> ?) AS unreadCount FROM conversations c JOIN conversation_members cm ON cm.conversation_id = c.id AND cm.user_id = ? ORDER BY COALESCE(lastMessageAt, c.created_at) DESC`, [userId, userId, userId, userId]);
    return rows.map((row) => ({ ...row, unreadCount: Number(row.unreadCount ?? 0) }));
  }

  async history(userId: string, conversationId: string, before?: string, limit = 50) {
    await this.assertMember(userId, conversationId);
    const safeLimit = Math.min(Math.max(limit, 1), 100);
    const params: unknown[] = [conversationId];
    const where = before ? 'AND m.created_at < ?' : '';
    if (before) params.push(new Date(before));
    params.push(safeLimit);
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT m.id, m.conversation_id AS conversationId, m.sender_id AS senderId, u.display_name AS senderName, u.avatar_url AS senderAvatarUrl, m.kind, m.body, m.gift_item_id AS giftItemId, m.reply_to_id AS replyToId, m.created_at AS createdAt FROM messages m JOIN users u ON u.id = m.sender_id WHERE m.conversation_id = ? AND m.deleted_at IS NULL ${where} ORDER BY m.created_at DESC LIMIT ?`, params);
    return rows.reverse();
  }

  async createPrivate(userId: string, otherUserId: string) {
    if (userId === otherUserId) throw invalid('You cannot start a conversation with yourself.');
    const users = await this.mysql.query<RowDataPacket[]>(`SELECT id FROM users WHERE id IN (?, ?) AND status = 'active'`, [userId, otherUserId]);
    if (users.length !== 2) throw notFound('User not found.');
    const existing = await this.mysql.query<RowDataPacket[]>(`SELECT c.id FROM conversations c JOIN conversation_members a ON a.conversation_id = c.id AND a.user_id = ? JOIN conversation_members b ON b.conversation_id = c.id AND b.user_id = ? WHERE c.type = 'private' LIMIT 1`, [userId, otherUserId]);
    if (existing[0]) return { id: existing[0].id, type: 'private' };
    const id = randomUUID();
    await this.mysql.transaction(async (connection) => {
      await connection.execute(`INSERT INTO conversations (id, type) VALUES (?, 'private')`, [id]);
      await connection.execute(`INSERT INTO conversation_members (conversation_id, user_id) VALUES (?, ?), (?, ?)`, [id, userId, id, otherUserId]);
    });
    return { id, type: 'private' };
  }

  async send(userId: string, dto: SendMessageDto) {
    await this.assertMember(userId, dto.conversationId);
    const body = dto.body.trim();
    if (!body) throw invalid('Message cannot be empty.');
    const id = randomUUID();
    await this.mysql.execute(`INSERT INTO messages (id, conversation_id, sender_id, kind, body, gift_item_id) VALUES (?, ?, ?, ?, ?, ?)`, [id, dto.conversationId, userId, dto.kind ?? 'text', body, dto.giftItemId ?? null]);
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT m.id, m.conversation_id AS conversationId, m.sender_id AS senderId, u.display_name AS senderName, u.avatar_url AS senderAvatarUrl, m.kind, m.body, m.gift_item_id AS giftItemId, m.created_at AS createdAt FROM messages m JOIN users u ON u.id = m.sender_id WHERE m.id = ?`, [id]);
    return rows[0];
  }

  async markRead(userId: string, conversationId: string, messageId: string) {
    await this.assertMember(userId, conversationId);
    const message = await this.mysql.query<RowDataPacket[]>(`SELECT id FROM messages WHERE id = ? AND conversation_id = ?`, [messageId, conversationId]);
    if (!message[0]) throw notFound('Message not found.');
    await this.mysql.execute(`UPDATE conversation_members SET last_read_message_id = ? WHERE conversation_id = ? AND user_id = ?`, [messageId, conversationId, userId]);
    return { success: true };
  }

  async assertMember(userId: string, conversationId: string): Promise<void> {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT 1 FROM conversation_members WHERE conversation_id = ? AND user_id = ?`, [conversationId, userId]);
    if (!rows[0]) throw forbidden('You are not a member of this conversation.');
  }
}
