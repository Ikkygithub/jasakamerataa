-- Jasakamerata — skema MySQL 8 / MariaDB 10.6+ (Hostinger phpMyAdmin)
-- Impor: phpMyAdmin → pilih database Anda → tab Import → pilih file ini → Go.
-- Hanya membuat tabel (CREATE TABLE IF NOT EXISTS). Tidak menghapus tabel/data apa pun.
-- ID memakai string (VARCHAR) yang sama dengan sistem saat ini agar migrasi data 1:1.
-- Kolom *_encrypted berisi token Fernet (kunci = ENCRYPTION_KEY, jangan hilang).

SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE TABLE IF NOT EXISTS users (
  user_id VARCHAR(40) PRIMARY KEY,
  email VARCHAR(190) NOT NULL UNIQUE,
  name VARCHAR(120) NOT NULL,
  picture VARCHAR(500) NULL,
  role ENUM('customer','photographer','admin') NOT NULL DEFAULT 'customer',
  photographer_id VARCHAR(40) NULL UNIQUE,
  bank_name VARCHAR(60) NULL,
  bank_holder_name VARCHAR(80) NULL,
  bank_number_encrypted TEXT NULL,
  bank_masked VARCHAR(20) NULL,
  bank_updated_at DATETIME NULL,
  photographer_policy_agreed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS user_sessions (
  session_token VARCHAR(255) PRIMARY KEY,
  user_id VARCHAR(40) NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_sessions_user (user_id),
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS photographers (
  photographer_id VARCHAR(40) PRIMARY KEY,
  user_id VARCHAR(40) NULL UNIQUE,
  slug VARCHAR(140) NOT NULL UNIQUE,
  name VARCHAR(120) NOT NULL,
  username VARCHAR(140) NULL,
  category ENUM('Wedding','Commercial','Event','Graduation') NOT NULL,
  location VARCHAR(120) NOT NULL DEFAULT 'Makassar, Sulawesi Selatan',
  bio TEXT NULL,
  profile_image VARCHAR(500) NULL,
  service_area VARCHAR(200) NULL,
  availability_note VARCHAR(120) NULL,
  min_duration TINYINT UNSIGNED NOT NULL DEFAULT 2,
  starting_price INT UNSIGNED NOT NULL DEFAULT 0,
  listing_status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  listing_note VARCHAR(500) NULL,
  verified TINYINT(1) NOT NULL DEFAULT 0,
  verification_status ENUM('not_submitted','pending','needs_fix','approved','rejected') NOT NULL DEFAULT 'not_submitted',
  verification_note VARCHAR(500) NULL,
  rating DECIMAL(3,2) NULL,
  reviews INT UNSIGNED NOT NULL DEFAULT 0,
  rating_source ENUM('demo','verified') NULL,
  is_demo TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_ph_listing (listing_status, category),
  CONSTRAINT fk_ph_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS services (
  service_id VARCHAR(40) PRIMARY KEY,
  photographer_id VARCHAR(40) NOT NULL,
  title VARCHAR(100) NOT NULL,
  category ENUM('Wedding','Commercial','Event','Graduation') NOT NULL,
  price INT UNSIGNED NOT NULL,
  pricing_type VARCHAR(30) NOT NULL DEFAULT 'per paket',
  duration VARCHAR(50) NOT NULL,
  deliverables VARCHAR(200) NOT NULL,
  turnaround VARCHAR(50) NOT NULL DEFAULT '7 hari kerja',
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  KEY idx_services_ph (photographer_id),
  CONSTRAINT fk_services_ph FOREIGN KEY (photographer_id) REFERENCES photographers(photographer_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS photographer_gallery (
  photographer_id VARCHAR(40) NOT NULL,
  position SMALLINT UNSIGNED NOT NULL,
  url VARCHAR(500) NOT NULL,
  PRIMARY KEY (photographer_id, position),
  CONSTRAINT fk_gal_ph FOREIGN KEY (photographer_id) REFERENCES photographers(photographer_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS portfolio_items (
  item_id VARCHAR(40) PRIMARY KEY,
  photographer_id VARCHAR(40) NOT NULL,
  url VARCHAR(500) NOT NULL,
  storage_path VARCHAR(300) NULL,
  content_type VARCHAR(60) NULL,
  size_bytes INT UNSIGNED NULL,
  title VARCHAR(100) NOT NULL DEFAULT '',
  description VARCHAR(500) NOT NULL DEFAULT '',
  sort_order INT NOT NULL DEFAULT 0,
  is_cover TINYINT(1) NOT NULL DEFAULT 0,
  is_deleted TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  KEY idx_pf_ph (photographer_id, is_deleted, sort_order),
  CONSTRAINT fk_pf_ph FOREIGN KEY (photographer_id) REFERENCES photographers(photographer_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS availability_blocks (
  block_id VARCHAR(40) PRIMARY KEY,
  photographer_id VARCHAR(40) NOT NULL,
  block_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  reason VARCHAR(200) NOT NULL DEFAULT '',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_blocks_ph_date (photographer_id, block_date),
  CONSTRAINT fk_blocks_ph FOREIGN KEY (photographer_id) REFERENCES photographers(photographer_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS bookings (
  booking_id VARCHAR(40) PRIMARY KEY,
  customer_id VARCHAR(40) NOT NULL,
  customer_name VARCHAR(120) NOT NULL,
  photographer_id VARCHAR(40) NOT NULL,
  photographer_name VARCHAR(120) NOT NULL,
  photographer_slug VARCHAR(140) NOT NULL,
  service_id VARCHAR(40) NOT NULL,
  service_title VARCHAR(100) NOT NULL,
  category VARCHAR(20) NOT NULL,
  session_date DATE NOT NULL,
  start_time TIME NOT NULL,
  duration_hours TINYINT UNSIGNED NOT NULL,
  location VARCHAR(200) NOT NULL,
  notes TEXT NULL,
  total INT UNSIGNED NOT NULL,
  commission_rate DECIMAL(4,3) NOT NULL DEFAULT 0.050,
  commission INT UNSIGNED NOT NULL,
  photographer_earning INT UNSIGNED NOT NULL,
  status ENUM('pending','accepted','delivered','revision_requested','disputed','completed','declined','cancelled') NOT NULL DEFAULT 'pending',
  payment_status ENUM('demo_deferred','unpaid','pending','paid','failed','expired','refund_pending','reversed') NOT NULL DEFAULT 'unpaid',
  payment_due_at DATETIME NULL,
  payment_order_id VARCHAR(60) NULL,
  paid_at DATETIME NULL,
  policy_version VARCHAR(20) NULL,
  policy_agreed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NULL,
  KEY idx_bk_ph_date (photographer_id, session_date, status),
  KEY idx_bk_customer (customer_id, created_at),
  KEY idx_bk_payment_due (status, payment_status, payment_due_at),
  CONSTRAINT fk_bk_customer FOREIGN KEY (customer_id) REFERENCES users(user_id),
  CONSTRAINT fk_bk_ph FOREIGN KEY (photographer_id) REFERENCES photographers(photographer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS booking_history (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  booking_id VARCHAR(40) NOT NULL,
  status VARCHAR(30) NOT NULL,
  actor VARCHAR(30) NOT NULL,
  note VARCHAR(500) NOT NULL DEFAULT '',
  created_at DATETIME NOT NULL,
  KEY idx_bh_booking (booking_id, created_at),
  CONSTRAINT fk_bh_booking FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS deliveries (
  delivery_id VARCHAR(40) PRIMARY KEY,
  booking_id VARCHAR(40) NOT NULL,
  note TEXT NULL,
  link VARCHAR(500) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_dl_booking (booking_id),
  CONSTRAINT fk_dl_booking FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS delivery_files (
  file_id VARCHAR(40) PRIMARY KEY,
  delivery_id VARCHAR(40) NOT NULL,
  storage_path VARCHAR(300) NOT NULL,
  content_type VARCHAR(60) NOT NULL,
  size_bytes INT UNSIGNED NOT NULL,
  original_filename VARCHAR(120) NOT NULL DEFAULT '',
  CONSTRAINT fk_df_delivery FOREIGN KEY (delivery_id) REFERENCES deliveries(delivery_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS reviews (
  review_id VARCHAR(40) PRIMARY KEY,
  booking_id VARCHAR(40) NOT NULL UNIQUE,
  photographer_id VARCHAR(40) NOT NULL,
  customer_name VARCHAR(120) NOT NULL,
  service_title VARCHAR(100) NOT NULL,
  rating TINYINT UNSIGNED NOT NULL,
  comment TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_rev_ph (photographer_id),
  CONSTRAINT chk_rating CHECK (rating BETWEEN 1 AND 5),
  CONSTRAINT fk_rev_booking FOREIGN KEY (booking_id) REFERENCES bookings(booking_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS favorites (
  user_id VARCHAR(40) NOT NULL,
  photographer_id VARCHAR(40) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, photographer_id),
  CONSTRAINT fk_fav_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_fav_ph FOREIGN KEY (photographer_id) REFERENCES photographers(photographer_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS conversations (
  conversation_id VARCHAR(40) PRIMARY KEY,
  customer_id VARCHAR(40) NOT NULL,
  photographer_id VARCHAR(40) NOT NULL,
  last_message VARCHAR(120) NOT NULL DEFAULT '',
  last_at DATETIME NOT NULL,
  unread_customer INT UNSIGNED NOT NULL DEFAULT 0,
  unread_photographer INT UNSIGNED NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_conv (customer_id, photographer_id),
  CONSTRAINT fk_conv_customer FOREIGN KEY (customer_id) REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_conv_ph FOREIGN KEY (photographer_id) REFERENCES photographers(photographer_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS messages (
  message_id VARCHAR(40) PRIMARY KEY,
  conversation_id VARCHAR(40) NOT NULL,
  sender_id VARCHAR(40) NOT NULL,
  sender_role ENUM('customer','photographer') NOT NULL,
  body TEXT NOT NULL,
  created_at DATETIME(3) NOT NULL,
  KEY idx_msg_conv (conversation_id, created_at),
  CONSTRAINT fk_msg_conv FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS payments (
  order_id VARCHAR(60) PRIMARY KEY,
  booking_id VARCHAR(40) NOT NULL,
  customer_id VARCHAR(40) NOT NULL,
  gross_amount INT UNSIGNED NOT NULL,
  snap_token VARCHAR(100) NULL,
  transaction_status VARCHAR(20) NOT NULL DEFAULT 'created',
  status_code VARCHAR(5) NULL,
  fraud_status VARCHAR(20) NULL,
  transaction_id VARCHAR(80) NULL,
  is_production TINYINT(1) NOT NULL DEFAULT 0,
  expires_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NULL,
  KEY idx_pay_booking (booking_id),
  CONSTRAINT fk_pay_booking FOREIGN KEY (booking_id) REFERENCES bookings(booking_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS payment_events (
  event_key CHAR(64) PRIMARY KEY,
  order_id VARCHAR(60) NOT NULL,
  status VARCHAR(20) NOT NULL,
  source VARCHAR(20) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_pe_order (order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Ledger: setiap mutasi saldo; idem_key UNIQUE mencegah kredit/komisi ganda.
CREATE TABLE IF NOT EXISTS ledger (
  entry_id VARCHAR(40) PRIMARY KEY,
  idem_key VARCHAR(80) NOT NULL UNIQUE,
  photographer_id VARCHAR(40) NULL,
  type ENUM('earning','platform_commission','payout_reserve','payout_release','correction') NOT NULL,
  amount BIGINT NOT NULL,
  ref VARCHAR(60) NOT NULL,
  note VARCHAR(300) NOT NULL DEFAULT '',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_ledger_ph (photographer_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS wallets (
  photographer_id VARCHAR(40) PRIMARY KEY,
  available BIGINT NOT NULL DEFAULT 0,
  CONSTRAINT chk_wallet_nonneg CHECK (available >= 0),
  CONSTRAINT fk_wallet_ph FOREIGN KEY (photographer_id) REFERENCES photographers(photographer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS payouts (
  payout_id VARCHAR(40) PRIMARY KEY,
  photographer_id VARCHAR(40) NOT NULL,
  photographer_name VARCHAR(120) NOT NULL,
  amount INT UNSIGNED NOT NULL,
  bank_name VARCHAR(60) NULL,
  holder_name VARCHAR(80) NULL,
  bank_account_masked VARCHAR(20) NULL,
  bank_snapshot_encrypted TEXT NOT NULL,
  status ENUM('requested','approved','processing','success','failed','rejected') NOT NULL DEFAULT 'requested',
  transfer_reference VARCHAR(120) NULL,
  note VARCHAR(500) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NULL,
  KEY idx_po_ph (photographer_id, status),
  CONSTRAINT chk_payout_amount CHECK (amount BETWEEN 100000 AND 10000000),
  CONSTRAINT fk_po_ph FOREIGN KEY (photographer_id) REFERENCES photographers(photographer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS payout_history (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  payout_id VARCHAR(40) NOT NULL,
  status VARCHAR(20) NOT NULL,
  actor VARCHAR(120) NOT NULL,
  note VARCHAR(500) NOT NULL DEFAULT '',
  reference VARCHAR(120) NOT NULL DEFAULT '',
  created_at DATETIME NOT NULL,
  CONSTRAINT fk_ph_payout FOREIGN KEY (payout_id) REFERENCES payouts(payout_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS verifications (
  submission_id VARCHAR(40) PRIMARY KEY,
  photographer_id VARCHAR(40) NOT NULL,
  photographer_name VARCHAR(120) NOT NULL,
  experience TEXT NOT NULL,
  links VARCHAR(500) NOT NULL DEFAULT '',
  status ENUM('pending','needs_fix','approved','rejected') NOT NULL DEFAULT 'pending',
  note VARCHAR(500) NULL,
  decided_by VARCHAR(40) NULL,
  decided_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_ver_status (status),
  CONSTRAINT fk_ver_ph FOREIGN KEY (photographer_id) REFERENCES photographers(photographer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS verification_documents (
  doc_id VARCHAR(40) PRIMARY KEY,
  submission_id VARCHAR(40) NOT NULL,
  kind ENUM('id_document','supporting') NOT NULL,
  storage_path VARCHAR(300) NOT NULL,
  content_type VARCHAR(60) NOT NULL,
  size_bytes INT UNSIGNED NOT NULL,
  original_filename VARCHAR(120) NOT NULL DEFAULT '',
  CONSTRAINT fk_vd_sub FOREIGN KEY (submission_id) REFERENCES verifications(submission_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS audit_logs (
  log_id VARCHAR(40) PRIMARY KEY,
  actor_id VARCHAR(40) NOT NULL,
  actor_name VARCHAR(120) NOT NULL DEFAULT '',
  actor_role VARCHAR(20) NOT NULL DEFAULT '',
  action VARCHAR(60) NOT NULL,
  target VARCHAR(80) NOT NULL DEFAULT '',
  detail VARCHAR(500) NOT NULL DEFAULT '',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_audit_time (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS email_logs (
  log_id VARCHAR(40) PRIMARY KEY,
  kind VARCHAR(40) NOT NULL,
  ref VARCHAR(60) NOT NULL,
  recipient VARCHAR(190) NOT NULL,
  subject VARCHAR(200) NOT NULL,
  status ENUM('sent','disabled','failed','paused','blocked') NOT NULL,
  detail VARCHAR(300) NOT NULL DEFAULT '',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_email_time (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS schema_migrations (
  version VARCHAR(20) PRIMARY KEY,
  applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO schema_migrations (version) VALUES ('2026-10-v1');
