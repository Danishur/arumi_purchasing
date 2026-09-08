-- ============================================================
-- Data contoh (OPSIONAL) -- jalankan ini kalau mau ada data
-- testing langsung tanpa input manual dari aplikasi.
-- Boleh dilewati kalau mau mulai dari database kosong.
-- ============================================================

USE purchasing_intermediary;

INSERT INTO customers (name, npwp_number, terms_of_payment, customer_type, address, is_active)
VALUES
  ('PT. Nusantara Perdagangan', '01.234.567.8-901.000', '30 Days after invoice received', 'Swasta',
   'Jl. Merdeka No. 12, Jakarta Pusat, DKI Jakarta', 1),
  ('PT Merdeka Copper', '02.345.678.9-012.000', '45 Days after invoice received', 'BUMN',
   'Jl. Industri Raya No. 7, Gresik, Jawa Timur', 1);

-- PT. Nusantara Perdagangan (customer pertama, id = 1) -> 1 PIC
INSERT INTO customer_contacts (customer_id, pic_name, contact)
VALUES
  (1, 'Budi Santoso', '0812-1111-2222');

-- PT Merdeka Copper (customer kedua, id = 2) -> 3 PIC, sesuai
-- contoh dari owner (C7.1, C7.2, C7.3)
INSERT INTO customer_contacts (customer_id, pic_name, contact)
VALUES
  (2, 'Andi Wijaya', 'andi.wijaya@merdekacopper.co.id'),
  (2, 'Siti Rahma', '0813-3333-4444'),
  (2, 'Hendra Gunawan', '0814-5555-6666');
