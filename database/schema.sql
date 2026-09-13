-- VibeTable MySQL 8 schema
-- The API treats UUIDs as application-generated identifiers so a database can be
-- restored or replicated without coupling identity to a single server.
SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE DATABASE IF NOT EXISTS vibetable CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE vibetable;

CREATE TABLE IF NOT EXISTS users (
  id CHAR(36) NOT NULL,
  username VARCHAR(32) NOT NULL,
  display_name VARCHAR(80) NOT NULL,
  phone_e164 VARCHAR(20) NULL,
  email VARCHAR(254) NULL,
  avatar_url VARCHAR(500) NULL,
  locale ENUM('en','fa') NOT NULL DEFAULT 'en',
  theme ENUM('light','dark','system') NOT NULL DEFAULT 'system',
  role ENUM('player','moderator','admin') NOT NULL DEFAULT 'player',
  status ENUM('active','suspended','deleted') NOT NULL DEFAULT 'active',
  level SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  experience INT UNSIGNED NOT NULL DEFAULT 0,
  last_seen_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_username (username),
  UNIQUE KEY uq_users_phone (phone_e164),
  UNIQUE KEY uq_users_email (email),
  KEY idx_users_status_seen (status, last_seen_at),
  CONSTRAINT chk_users_username CHECK (CHAR_LENGTH(username) BETWEEN 3 AND 32),
  CONSTRAINT chk_users_level CHECK (level BETWEEN 1 AND 100)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS auth_identities (
  id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  provider ENUM('phone','google','apple') NOT NULL,
  provider_subject VARCHAR(255) NOT NULL,
  provider_email VARCHAR(254) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  last_used_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_identity_provider_subject (provider, provider_subject),
  KEY idx_identity_user (user_id),
  CONSTRAINT fk_identity_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS otp_challenges (
  id CHAR(36) NOT NULL,
  phone_e164 VARCHAR(20) NOT NULL,
  code_hash CHAR(64) NOT NULL,
  purpose ENUM('login','link_phone','change_phone') NOT NULL DEFAULT 'login',
  attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  expires_at DATETIME(3) NOT NULL,
  consumed_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_otp_lookup (phone_e164, purpose, created_at),
  KEY idx_otp_expiry (expires_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS refresh_sessions (
  id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  token_hash CHAR(64) NOT NULL,
  user_agent VARCHAR(500) NULL,
  ip_address VARCHAR(45) NULL,
  expires_at DATETIME(3) NOT NULL,
  revoked_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  last_used_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_refresh_token_hash (token_hash),
  KEY idx_refresh_user_active (user_id, revoked_at, expires_at),
  CONSTRAINT fk_refresh_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS wallets (
  user_id CHAR(36) NOT NULL,
  coins BIGINT UNSIGNED NOT NULL DEFAULT 1000,
  pips BIGINT UNSIGNED NOT NULL DEFAULT 0,
  version BIGINT UNSIGNED NOT NULL DEFAULT 0,
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (user_id),
  CONSTRAINT fk_wallet_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS wallet_transactions (
  id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  currency ENUM('coins','pips') NOT NULL,
  amount BIGINT NOT NULL,
  balance_after BIGINT UNSIGNED NOT NULL,
  type ENUM('signup','purchase','match_entry','match_reward','gift_sent','gift_received','admin_adjustment','refund','season_reward') NOT NULL,
  reference_type VARCHAR(40) NULL,
  reference_id CHAR(36) NULL,
  idempotency_key VARCHAR(100) NULL,
  metadata JSON NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_wallet_idempotency (user_id, idempotency_key),
  KEY idx_wallet_ledger (user_id, created_at),
  CONSTRAINT fk_wallet_tx_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT chk_wallet_amount CHECK (amount <> 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS shop_items (
  id CHAR(36) NOT NULL,
  sku VARCHAR(80) NOT NULL,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(500) NOT NULL,
  category ENUM('avatar','frame','emote','table','dice','bundle') NOT NULL,
  price_coins BIGINT UNSIGNED NOT NULL DEFAULT 0,
  price_pips BIGINT UNSIGNED NOT NULL DEFAULT 0,
  asset_key VARCHAR(160) NOT NULL,
  metadata JSON NULL,
  stock INT NULL,
  is_limited BOOLEAN NOT NULL DEFAULT FALSE,
  is_giftable BOOLEAN NOT NULL DEFAULT TRUE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  starts_at DATETIME(3) NULL,
  ends_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_shop_sku (sku),
  KEY idx_shop_catalog (is_active, category, starts_at, ends_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS inventory_items (
  id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  shop_item_id CHAR(36) NOT NULL,
  quantity INT UNSIGNED NOT NULL DEFAULT 1,
  equipped BOOLEAN NOT NULL DEFAULT FALSE,
  acquired_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  expires_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_inventory_user_item (user_id, shop_item_id),
  KEY idx_inventory_user (user_id, equipped),
  CONSTRAINT fk_inventory_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_inventory_item FOREIGN KEY (shop_item_id) REFERENCES shop_items(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS purchases (
  id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  provider ENUM('manual','stripe','apple','google') NOT NULL,
  provider_reference VARCHAR(255) NULL,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  amount_minor INT UNSIGNED NOT NULL,
  coins BIGINT UNSIGNED NOT NULL DEFAULT 0,
  pips BIGINT UNSIGNED NOT NULL DEFAULT 0,
  status ENUM('pending','paid','refunded','failed') NOT NULL DEFAULT 'pending',
  metadata JSON NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  completed_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_purchase_provider_ref (provider, provider_reference),
  KEY idx_purchase_user_status (user_id, status, created_at),
  CONSTRAINT fk_purchase_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS gift_transactions (
  id CHAR(36) NOT NULL,
  sender_id CHAR(36) NOT NULL,
  recipient_id CHAR(36) NOT NULL,
  shop_item_id CHAR(36) NOT NULL,
  quantity INT UNSIGNED NOT NULL DEFAULT 1,
  note VARCHAR(240) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_gift_recipient (recipient_id, created_at),
  CONSTRAINT fk_gift_sender FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE RESTRICT,
  CONSTRAINT fk_gift_recipient FOREIGN KEY (recipient_id) REFERENCES users(id) ON DELETE RESTRICT,
  CONSTRAINT fk_gift_item FOREIGN KEY (shop_item_id) REFERENCES shop_items(id) ON DELETE RESTRICT,
  CONSTRAINT chk_gift_users CHECK (sender_id <> recipient_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS friendships (
  id CHAR(36) NOT NULL,
  requester_id CHAR(36) NOT NULL,
  addressee_id CHAR(36) NOT NULL,
  status ENUM('pending','accepted','blocked') NOT NULL DEFAULT 'pending',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_friendship_pair (requester_id, addressee_id),
  KEY idx_friendship_addressee (addressee_id, status),
  CONSTRAINT fk_friendship_requester FOREIGN KEY (requester_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_friendship_addressee FOREIGN KEY (addressee_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT chk_friendship_users CHECK (requester_id <> addressee_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_groups (
  id CHAR(36) NOT NULL,
  owner_id CHAR(36) NOT NULL,
  name VARCHAR(80) NOT NULL,
  description VARCHAR(280) NOT NULL DEFAULT '',
  avatar_url VARCHAR(500) NULL,
  is_private BOOLEAN NOT NULL DEFAULT TRUE,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_groups_owner (owner_id),
  CONSTRAINT fk_group_owner FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS group_members (
  group_id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  role ENUM('owner','admin','member') NOT NULL DEFAULT 'member',
  joined_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (group_id, user_id),
  KEY idx_group_members_user (user_id),
  CONSTRAINT fk_group_member_group FOREIGN KEY (group_id) REFERENCES user_groups(id) ON DELETE CASCADE,
  CONSTRAINT fk_group_member_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS conversations (
  id CHAR(36) NOT NULL,
  type ENUM('private','group','match') NOT NULL,
  group_id CHAR(36) NULL,
  match_id CHAR(36) NULL,
  title VARCHAR(120) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_conversation_group (group_id),
  UNIQUE KEY uq_conversation_match (match_id),
  CONSTRAINT fk_conversation_group FOREIGN KEY (group_id) REFERENCES user_groups(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS conversation_members (
  conversation_id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  last_read_message_id CHAR(36) NULL,
  joined_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  muted_until DATETIME(3) NULL,
  PRIMARY KEY (conversation_id, user_id),
  KEY idx_conversation_members_user (user_id),
  CONSTRAINT fk_conversation_member_conversation FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
  CONSTRAINT fk_conversation_member_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS messages (
  id CHAR(36) NOT NULL,
  conversation_id CHAR(36) NOT NULL,
  sender_id CHAR(36) NOT NULL,
  kind ENUM('text','system','gift','image') NOT NULL DEFAULT 'text',
  body VARCHAR(4000) NOT NULL,
  gift_item_id CHAR(36) NULL,
  reply_to_id CHAR(36) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  KEY idx_messages_conversation (conversation_id, created_at),
  KEY idx_messages_sender (sender_id, created_at),
  CONSTRAINT fk_message_conversation FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
  CONSTRAINT fk_message_sender FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE RESTRICT,
  CONSTRAINT fk_message_gift FOREIGN KEY (gift_item_id) REFERENCES shop_items(id) ON DELETE SET NULL,
  CONSTRAINT fk_message_reply FOREIGN KEY (reply_to_id) REFERENCES messages(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS games (
  id VARCHAR(40) NOT NULL,
  display_name VARCHAR(80) NOT NULL,
  category ENUM('board','cards','arcade','party','sports') NOT NULL,
  min_players TINYINT UNSIGNED NOT NULL,
  max_players TINYINT UNSIGNED NOT NULL,
  supports_teams BOOLEAN NOT NULL DEFAULT FALSE,
  accent_color CHAR(7) NOT NULL,
  icon_key VARCHAR(40) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  config JSON NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT chk_game_player_count CHECK (min_players > 0 AND max_players >= min_players)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS seasons (
  id CHAR(36) NOT NULL,
  name VARCHAR(80) NOT NULL,
  starts_at DATETIME(3) NOT NULL,
  ends_at DATETIME(3) NOT NULL,
  status ENUM('scheduled','active','finished') NOT NULL DEFAULT 'scheduled',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_seasons_status_dates (status, starts_at, ends_at),
  CONSTRAINT chk_season_dates CHECK (ends_at > starts_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS season_rewards (
  id CHAR(36) NOT NULL,
  season_id CHAR(36) NOT NULL,
  min_rank INT UNSIGNED NOT NULL,
  max_rank INT UNSIGNED NOT NULL,
  coins BIGINT UNSIGNED NOT NULL DEFAULT 0,
  pips BIGINT UNSIGNED NOT NULL DEFAULT 0,
  shop_item_id CHAR(36) NULL,
  PRIMARY KEY (id),
  KEY idx_season_rewards_season (season_id, min_rank),
  CONSTRAINT fk_season_reward_season FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE CASCADE,
  CONSTRAINT fk_season_reward_item FOREIGN KEY (shop_item_id) REFERENCES shop_items(id) ON DELETE SET NULL,
  CONSTRAINT chk_season_reward_rank CHECK (max_rank >= min_rank)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS player_ratings (
  user_id CHAR(36) NOT NULL,
  game_id VARCHAR(40) NOT NULL,
  season_id CHAR(36) NOT NULL,
  rating INT NOT NULL DEFAULT 1000,
  wins INT UNSIGNED NOT NULL DEFAULT 0,
  losses INT UNSIGNED NOT NULL DEFAULT 0,
  draws INT UNSIGNED NOT NULL DEFAULT 0,
  games_played INT UNSIGNED NOT NULL DEFAULT 0,
  peak_rating INT NOT NULL DEFAULT 1000,
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (user_id, game_id, season_id),
  KEY idx_rating_leaderboard (game_id, season_id, rating),
  CONSTRAINT fk_rating_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_rating_game FOREIGN KEY (game_id) REFERENCES games(id) ON DELETE RESTRICT,
  CONSTRAINT fk_rating_season FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS matches (
  id CHAR(36) NOT NULL,
  game_id VARCHAR(40) NOT NULL,
  mode ENUM('casual','ranked','private') NOT NULL,
  status ENUM('waiting','active','finished','cancelled') NOT NULL DEFAULT 'waiting',
  max_players TINYINT UNSIGNED NOT NULL,
  state JSON NOT NULL,
  revision INT UNSIGNED NOT NULL DEFAULT 0,
  winner_ids JSON NULL,
  loser_ids JSON NULL,
  draw BOOLEAN NOT NULL DEFAULT FALSE,
  bot_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  started_at DATETIME(3) NULL,
  finished_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_matches_game_status (game_id, status, created_at),
  CONSTRAINT fk_match_game FOREIGN KEY (game_id) REFERENCES games(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS match_players (
  match_id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  seat TINYINT UNSIGNED NOT NULL,
  team TINYINT UNSIGNED NULL,
  is_bot BOOLEAN NOT NULL DEFAULT FALSE,
  rating_before INT NULL,
  rating_after INT NULL,
  result ENUM('pending','win','loss','draw') NOT NULL DEFAULT 'pending',
  joined_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  left_at DATETIME(3) NULL,
  PRIMARY KEY (match_id, user_id),
  UNIQUE KEY uq_match_seat (match_id, seat),
  KEY idx_match_players_user (user_id, joined_at),
  CONSTRAINT fk_match_player_match FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE,
  CONSTRAINT fk_match_player_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS match_moves (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  match_id CHAR(36) NOT NULL,
  revision INT UNSIGNED NOT NULL,
  user_id CHAR(36) NOT NULL,
  action VARCHAR(80) NOT NULL,
  payload JSON NOT NULL,
  state_after JSON NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_match_revision (match_id, revision),
  KEY idx_match_moves_match (match_id, created_at),
  CONSTRAINT fk_move_match FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE,
  CONSTRAINT fk_move_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS match_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  match_id CHAR(36) NOT NULL,
  event_type VARCHAR(60) NOT NULL,
  actor_id CHAR(36) NULL,
  payload JSON NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_match_events_match (match_id, created_at),
  CONSTRAINT fk_event_match FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE,
  CONSTRAINT fk_event_actor FOREIGN KEY (actor_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS matchmaking_tickets (
  id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  game_id VARCHAR(40) NOT NULL,
  mode ENUM('casual','ranked','private') NOT NULL,
  desired_players TINYINT UNSIGNED NOT NULL,
  rating INT NOT NULL DEFAULT 1000,
  status ENUM('queued','matched','cancelled','expired') NOT NULL DEFAULT 'queued',
  queued_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  matched_at DATETIME(3) NULL,
  match_id CHAR(36) NULL,
  PRIMARY KEY (id),
  KEY idx_matchmaking_queue (game_id, mode, desired_players, status, queued_at),
  KEY idx_matchmaking_user (user_id, status),
  CONSTRAINT fk_ticket_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_ticket_game FOREIGN KEY (game_id) REFERENCES games(id) ON DELETE RESTRICT,
  CONSTRAINT fk_ticket_match FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS game_stats (
  user_id CHAR(36) NOT NULL,
  game_id VARCHAR(40) NOT NULL,
  games_played INT UNSIGNED NOT NULL DEFAULT 0,
  wins INT UNSIGNED NOT NULL DEFAULT 0,
  losses INT UNSIGNED NOT NULL DEFAULT 0,
  draws INT UNSIGNED NOT NULL DEFAULT 0,
  total_score BIGINT NOT NULL DEFAULT 0,
  best_score INT NOT NULL DEFAULT 0,
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (user_id, game_id),
  CONSTRAINT fk_stat_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_stat_game FOREIGN KEY (game_id) REFERENCES games(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS reports (
  id CHAR(36) NOT NULL,
  reporter_id CHAR(36) NOT NULL,
  reported_user_id CHAR(36) NULL,
  match_id CHAR(36) NULL,
  category ENUM('abuse','cheating','spam','safety','other') NOT NULL,
  description VARCHAR(2000) NOT NULL,
  status ENUM('open','investigating','resolved','dismissed') NOT NULL DEFAULT 'open',
  resolution_note VARCHAR(2000) NULL,
  resolved_by CHAR(36) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  resolved_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  KEY idx_reports_status (status, created_at),
  CONSTRAINT fk_report_reporter FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE RESTRICT,
  CONSTRAINT fk_report_reported FOREIGN KEY (reported_user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_report_match FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE SET NULL,
  CONSTRAINT fk_report_resolver FOREIGN KEY (resolved_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS notifications (
  id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  type VARCHAR(60) NOT NULL,
  title VARCHAR(160) NOT NULL,
  body VARCHAR(500) NOT NULL,
  payload JSON NULL,
  read_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_notifications_user (user_id, read_at, created_at),
  CONSTRAINT fk_notification_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS voice_rooms (
  id CHAR(36) NOT NULL,
  match_id CHAR(36) NULL,
  conversation_id CHAR(36) NULL,
  provider ENUM('livekit','agora') NOT NULL,
  room_name VARCHAR(120) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  ended_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_voice_room_name (room_name),
  CONSTRAINT fk_voice_match FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE,
  CONSTRAINT fk_voice_conversation FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS voice_participants (
  room_id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  joined_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  left_at DATETIME(3) NULL,
  PRIMARY KEY (room_id, user_id),
  CONSTRAINT fk_voice_participant_room FOREIGN KEY (room_id) REFERENCES voice_rooms(id) ON DELETE CASCADE,
  CONSTRAINT fk_voice_participant_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS admin_audit_log (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  admin_id CHAR(36) NOT NULL,
  action VARCHAR(100) NOT NULL,
  entity_type VARCHAR(60) NOT NULL,
  entity_id VARCHAR(80) NULL,
  before_json JSON NULL,
  after_json JSON NULL,
  ip_address VARCHAR(45) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_admin_audit_date (created_at, admin_id),
  CONSTRAINT fk_admin_audit_user FOREIGN KEY (admin_id) REFERENCES users(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE OR REPLACE VIEW active_leaderboard AS
SELECT
  pr.game_id,
  pr.season_id,
  pr.user_id,
  u.display_name,
  u.avatar_url,
  pr.rating,
  pr.wins,
  pr.losses,
  pr.draws,
  pr.games_played,
  DENSE_RANK() OVER (PARTITION BY pr.game_id, pr.season_id ORDER BY pr.rating DESC, pr.wins DESC) AS rank_position
FROM player_ratings pr
JOIN users u ON u.id = pr.user_id
JOIN seasons s ON s.id = pr.season_id AND s.status = 'active'
WHERE u.status = 'active';
