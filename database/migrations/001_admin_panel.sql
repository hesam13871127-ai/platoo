-- 001_admin_panel.sql
-- Adds the moderation history and admin note tables the admin panel relies on.
-- Idempotent so it can be replayed by `npm run db:migrate` or applied by hand.
SET NAMES utf8mb4;
SET time_zone = '+00:00';
USE vibetable;

CREATE TABLE IF NOT EXISTS user_bans (
  id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  issued_by CHAR(36) NOT NULL,
  reason VARCHAR(500) NOT NULL,
  expires_at DATETIME(3) NULL,
  lifted_by CHAR(36) NULL,
  lifted_at DATETIME(3) NULL,
  lift_reason VARCHAR(500) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_user_bans_active (user_id, lifted_at, expires_at),
  CONSTRAINT fk_user_ban_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_user_ban_issuer FOREIGN KEY (issued_by) REFERENCES users(id) ON DELETE RESTRICT,
  CONSTRAINT fk_user_ban_lifter FOREIGN KEY (lifted_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS report_notes (
  id CHAR(36) NOT NULL,
  report_id CHAR(36) NOT NULL,
  author_id CHAR(36) NOT NULL,
  body VARCHAR(2000) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_report_notes_report (report_id, created_at),
  CONSTRAINT fk_report_note_report FOREIGN KEY (report_id) REFERENCES reports(id) ON DELETE CASCADE,
  CONSTRAINT fk_report_note_author FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
