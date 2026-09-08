-- ============================================================
-- Aplikasi Purchasing Intermediary - PT Arumi Money Pocket
-- Script pembuatan database & tabel untuk MODUL CUSTOMER
-- (Minggu 1 - modul lain seperti Vendor/Material/RFQ menyusul
--  di minggu-minggu berikutnya sesuai timeline)
-- ============================================================

CREATE DATABASE IF NOT EXISTS purchasing_intermediary
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE purchasing_intermediary;

-- ------------------------------------------------------------
-- Tabel customers: data master customer.
-- Customer ID yang tampil di aplikasi (mis. "C17") DITURUNKAN
-- dari kolom `id` (AUTO_INCREMENT) saat ditampilkan di Flutter,
-- BUKAN kolom tersendiri -- supaya selalu unik otomatis tanpa
-- perlu logika penomoran manual terpisah yang rawan bug/tabrakan
-- kalau ada beberapa user input bersamaan.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  name              VARCHAR(255)  NOT NULL,
  npwp_number       VARCHAR(30)   NULL,
  terms_of_payment  VARCHAR(100)  NULL,
  customer_type     VARCHAR(50)   NULL,
  address           TEXT          NULL,
  is_active         TINYINT(1)    NOT NULL DEFAULT 1,
  created_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                   ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Tabel customer_contacts: PIC & kontak milik 1 customer.
-- Relasi 1 customer -> banyak PIC (one-to-many), sesuai
-- permintaan owner: "PT Merdeka Copper (C7) punya 3 kontak,
-- jadi C7.1, C7.2, C7.3 -- semua data customer-nya SAMA,
-- cuma PIC & kontaknya beda-beda".
-- ON DELETE CASCADE: kalau customer induknya dihapus, semua PIC
-- ikut terhapus otomatis (tidak ada PIC "yatim" tanpa customer).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customer_contacts (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  customer_id   INT           NOT NULL,
  pic_name      VARCHAR(255)  NOT NULL,
  contact       VARCHAR(255)  NOT NULL,
  created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_customer_contacts_customer
    FOREIGN KEY (customer_id) REFERENCES customers (id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Index tambahan supaya query "ambil semua kontak milik 1 customer"
-- (dipanggil tiap kali buka form edit customer) tetap cepat walau
-- datanya sudah banyak nanti.
CREATE INDEX idx_customer_contacts_customer_id
  ON customer_contacts (customer_id);
