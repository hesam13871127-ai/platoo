import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { RowDataPacket } from 'mysql2/promise';
import { MysqlService } from '../database/mysql.service';
import { conflict, forbidden, invalid, notFound } from '../common/errors';
import { CreateGroupDto, FriendshipDto, ReportUserDto, UpdateProfileDto } from './users.dto';

@Injectable()
export class UsersService {
  constructor(private readonly mysql: MysqlService) {}

  async profile(userId: string) {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT u.id, u.username, u.display_name AS displayName, u.avatar_url AS avatarUrl, u.locale, u.theme, u.level, u.experience, u.last_seen_at AS lastSeenAt, COALESCE(w.coins, 0) AS coins, COALESCE(w.pips, 0) AS pips FROM users u LEFT JOIN wallets w ON w.user_id = u.id WHERE u.id = ? AND u.status = 'active'`, [userId]);
    if (!rows[0]) throw notFound('User not found.');
    return { ...rows[0], coins: Number(rows[0].coins), pips: Number(rows[0].pips), isOnline: this.isOnline(rows[0].lastSeenAt as string | null) };
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const fields: string[] = [];
    const values: unknown[] = [];
    if (dto.displayName !== undefined) { fields.push('display_name = ?'); values.push(dto.displayName.trim()); }
    if (dto.avatarUrl !== undefined) { fields.push('avatar_url = ?'); values.push(dto.avatarUrl || null); }
    if (fields.length) await this.mysql.execute(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`, [...values, userId]);
    return this.profile(userId);
  }

  async search(userId: string, query: string) {
    const term = query.trim();
    if (term.length < 2) throw invalid('Search must contain at least two characters.');
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT id, username, display_name AS displayName, avatar_url AS avatarUrl, level, last_seen_at AS lastSeenAt FROM users WHERE id <> ? AND status = 'active' AND (username LIKE ? OR display_name LIKE ?) ORDER BY display_name ASC LIMIT 30`, [userId, `%${term}%`, `%${term}%`]);
    return rows.map((row) => ({ ...row, isOnline: this.isOnline(row.lastSeenAt as string | null) }));
  }

  async touchPresence(userId: string): Promise<void> { await this.mysql.execute(`UPDATE users SET last_seen_at = UTC_TIMESTAMP(3) WHERE id = ?`, [userId]); }

  async friends(userId: string) {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT f.id AS friendshipId, f.status, f.requester_id AS requesterId, f.addressee_id AS addresseeId, u.id AS userId, u.username, u.display_name AS displayName, u.avatar_url AS avatarUrl, u.level, u.last_seen_at AS lastSeenAt FROM friendships f JOIN users u ON u.id = CASE WHEN f.requester_id = ? THEN f.addressee_id ELSE f.requester_id END WHERE (f.requester_id = ? OR f.addressee_id = ?) AND u.status = 'active' ORDER BY f.updated_at DESC`, [userId, userId, userId]);
    return rows.map((row) => ({ ...row, isOnline: this.isOnline(row.lastSeenAt as string | null), isRequester: row.requesterId === userId }));
  }

  async requestFriend(userId: string, recipientId: string) {
    if (userId === recipientId) throw invalid('You cannot add yourself.');
    const target = await this.mysql.query<RowDataPacket[]>(`SELECT id FROM users WHERE id = ? AND status = 'active'`, [recipientId]);
    if (!target[0]) throw notFound('User not found.');
    const existing = await this.mysql.query<RowDataPacket[]>(`SELECT id, requester_id AS requesterId, addressee_id AS addresseeId, status FROM friendships WHERE (requester_id = ? AND addressee_id = ?) OR (requester_id = ? AND addressee_id = ?) LIMIT 1`, [userId, recipientId, recipientId, userId]);
    if (existing[0]) {
      if (existing[0].status === 'accepted') throw conflict('You are already friends.');
      throw conflict('A friendship request already exists.');
    }
    const id = randomUUID();
    await this.mysql.execute(`INSERT INTO friendships (id, requester_id, addressee_id) VALUES (?, ?, ?)`, [id, userId, recipientId]);
    return { id, status: 'pending' };
  }

  async handleFriend(userId: string, friendshipId: string, dto: FriendshipDto) {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT * FROM friendships WHERE id = ? AND (requester_id = ? OR addressee_id = ?) LIMIT 1`, [friendshipId, userId, userId]);
    const friendship = rows[0];
    if (!friendship) throw notFound('Friendship request not found.');
    if (dto.action === 'accept' && friendship.addressee_id !== userId) throw forbidden('Only the recipient can accept a request.');
    if (dto.action === 'reject') {
      await this.mysql.execute(`DELETE FROM friendships WHERE id = ?`, [friendshipId]);
      return { success: true, status: 'removed' };
    }
    const status = dto.action === 'block' ? 'blocked' : 'accepted';
    await this.mysql.execute(`UPDATE friendships SET status = ? WHERE id = ?`, [status, friendshipId]);
    return { success: true, status };
  }

  async createGroup(userId: string, dto: CreateGroupDto) {
    const groupId = randomUUID();
    await this.mysql.transaction(async (connection) => {
      await connection.execute(`INSERT INTO user_groups (id, owner_id, name, description, avatar_url, is_private) VALUES (?, ?, ?, ?, ?, ?)`, [groupId, userId, dto.name.trim(), dto.description?.trim() ?? '', dto.avatarUrl ?? null, dto.isPrivate ?? true]);
      await connection.execute(`INSERT INTO group_members (group_id, user_id, role) VALUES (?, ?, 'owner')`, [groupId, userId]);
      const conversationId = randomUUID();
      await connection.execute(`INSERT INTO conversations (id, type, group_id, title) VALUES (?, 'group', ?, ?)`, [conversationId, groupId, dto.name.trim()]);
      await connection.execute(`INSERT INTO conversation_members (conversation_id, user_id) VALUES (?, ?)`, [conversationId, userId]);
    });
    return this.group(userId, groupId);
  }

  async groups(userId: string) {
    return this.mysql.query<RowDataPacket[]>(`SELECT g.id, g.name, g.description, g.avatar_url AS avatarUrl, g.owner_id AS ownerId, g.is_private AS isPrivate, gm.role, COUNT(all_members.user_id) AS memberCount, g.created_at AS createdAt FROM group_members gm JOIN user_groups g ON g.id = gm.group_id LEFT JOIN group_members all_members ON all_members.group_id = g.id WHERE gm.user_id = ? GROUP BY g.id, gm.role ORDER BY g.updated_at DESC`, [userId]);
  }

  async addGroupMember(userId: string, groupId: string, memberId: string) {
    const owner = await this.mysql.query<RowDataPacket[]>(`SELECT role FROM group_members WHERE group_id = ? AND user_id = ? AND role IN ('owner','admin')`, [groupId, userId]);
    if (!owner[0]) throw forbidden('Only group admins can add members.');
    const member = await this.mysql.query<RowDataPacket[]>(`SELECT id FROM users WHERE id = ? AND status = 'active'`, [memberId]);
    if (!member[0]) throw notFound('User not found.');
    const conversation = await this.mysql.query<RowDataPacket[]>(`SELECT id FROM conversations WHERE group_id = ?`, [groupId]);
    await this.mysql.execute(`INSERT IGNORE INTO group_members (group_id, user_id) VALUES (?, ?)`, [groupId, memberId]);
    if (conversation[0]) await this.mysql.execute(`INSERT IGNORE INTO conversation_members (conversation_id, user_id) VALUES (?, ?)`, [conversation[0].id, memberId]);
    return { success: true };
  }

  async group(userId: string, groupId: string) {
    const groups = await this.mysql.query<RowDataPacket[]>(`SELECT g.id, g.name, g.description, g.avatar_url AS avatarUrl, g.owner_id AS ownerId, g.is_private AS isPrivate, gm.role FROM user_groups g JOIN group_members gm ON gm.group_id = g.id WHERE g.id = ? AND gm.user_id = ?`, [groupId, userId]);
    if (!groups[0]) throw notFound('Group not found.');
    const members = await this.mysql.query<RowDataPacket[]>(`SELECT u.id, u.username, u.display_name AS displayName, u.avatar_url AS avatarUrl, gm.role, u.last_seen_at AS lastSeenAt FROM group_members gm JOIN users u ON u.id = gm.user_id WHERE gm.group_id = ? ORDER BY FIELD(gm.role, 'owner','admin','member'), u.display_name`, [groupId]);
    return { ...groups[0], members: members.map((member) => ({ ...member, isOnline: this.isOnline(member.lastSeenAt as string | null) })) };
  }

  async report(userId: string, dto: ReportUserDto) {
    if (userId === dto.reportedUserId) throw invalid('You cannot report yourself.');
    const target = await this.mysql.query<RowDataPacket[]>(`SELECT id FROM users WHERE id = ?`, [dto.reportedUserId]);
    if (!target[0]) throw notFound('User not found.');
    const id = randomUUID();
    await this.mysql.execute(`INSERT INTO reports (id, reporter_id, reported_user_id, category, description) VALUES (?, ?, ?, ?, ?)`, [id, userId, dto.reportedUserId, dto.category, dto.description.trim()]);
    return { id, status: 'open' };
  }

  private isOnline(lastSeen: string | null): boolean { return !!lastSeen && Date.now() - new Date(lastSeen).getTime() < 90_000; }
}
