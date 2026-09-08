-- ============================================================
-- FIX: tabel customer_contacts yang strukturnya tidak sesuai
-- ============================================================
-- Jalankan file ini KALAU kamu sempat bikin tabel `customer_contacts`
-- secara manual lewat phpMyAdmin (bukan menjalankan 01_create_database.sql
-- persis apa adanya), sehingga nama kolomnya jadi `customers_id`
-- (pakai "s") alih-alih `customer_id` -- menyebabkan error:
--   "Error 1048 (23000): Column 'customers_id' cannot be null"
--
-- Script ini AMAN dijalankan berkali-kali. Yang di-DROP cuma tabel
-- `customer_contacts` (data PIC), BUKAN tabel `customers` (data utama
-- customer) -- jadi data customer yang sudah sempat tersimpan TIDAK
-- ikut hilang.
-- ============================================================

USE purchasing_intermediary;

-- Matikan sementara pengecekan foreign key selama proses DROP+CREATE
-- ulang, supaya tidak terganggu relasi yang mungkin sudah kepasang aneh
-- sebelumnya.
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS customer_contacts;

CREATE TABLE customer_contacts (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  customer_id   INT           NOT NULL,
  pic_name      VARCHAR(255)  NOT NULL,
  contact       VARCHAR(255)  NOT NULL,
  created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_customer_contacts_customer
    FOREIGN KEY (customer_id) REFERENCES customers (id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_customer_contacts_customer_id
  ON customer_contacts (customer_id);

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- Cek juga: kemungkinan ada 1 (atau lebih) baris di tabel `customers`
-- yang "yatim" (tersimpan tanpa PIC), sisa dari percobaan Save yang
-- gagal di tengah jalan tadi. Jalankan query ini untuk melihatnya:
-- ============================================================
SELECT c.id, c.name, c.customer_type, c.address, c.created_at,
       (SELECT COUNT(*) FROM customer_contacts cc WHERE cc.customer_id = c.id) AS jumlah_pic
FROM customers c
ORDER BY c.id DESC
LIMIT 10;

-- Kalau ada baris dengan jumlah_pic = 0 yang memang cuma sisa percobaan
-- gagal tadi (bukan data yang mau dipakai), boleh dihapus manual lewat
-- phpMyAdmin (tab Browse pada tabel `customers`, klik ikon tempat sampah
-- di baris tersebut) -- atau biarkan saja, tidak masalah secara teknis,
-- cuma numpuk 1 baris testing yang kosong PIC-nya.
