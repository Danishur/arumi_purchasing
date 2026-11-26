-- ============================================================
-- Tabel user (login + approval owner) dan riwayat aktivitas
-- ============================================================
-- Tabel ini DIBUAT OTOMATIS saat aplikasi dibuka. File ini hanya
-- cadangan: jalankan di phpMyAdmin (database arumi_purchasing) kalau
-- app menampilkan error "CREATE command denied" saat dibuka.

CREATE TABLE IF NOT EXISTS app_users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  position VARCHAR(100) NULL,
  id_number VARCHAR(100) NULL,
  email VARCHAR(150) NOT NULL UNIQUE,
  password_salt VARCHAR(64) NOT NULL,
  password_hash VARCHAR(64) NOT NULL,
  pending_salt VARCHAR(64) NULL,
  pending_hash VARCHAR(64) NULL,
  role VARCHAR(20) NOT NULL DEFAULT 'user',
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  approved_at DATETIME NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS activity_logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NULL,
  user_name VARCHAR(150) NULL,
  action VARCHAR(20) NOT NULL,
  module VARCHAR(40) NOT NULL,
  record_label VARCHAR(255) NULL,
  detail TEXT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_activity_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Akun owner bawaan dibuat otomatis oleh aplikasi:
--   user/email : owner@arumi.co.id
--   password   : Owner123!
-- SEGERA ganti lewat Settings > Management User > Change Password.
