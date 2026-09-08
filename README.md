# Aplikasi Purchasing Intermediary — PT Arumi Money Pocket

Aplikasi "asli" (bukan lagi POC/demo) untuk alur Purchasing: Customer,
Vendor, Material, RFQ, sampai Export. Dibangun bertahap sesuai timeline
4 bulan (lihat gambar timeline yang diberikan ke tim dev).

**Status saat ini: Minggu 1 — Modul Customer.** Modul Vendor, Material, RFQ,
dan Process/Export menyusul di minggu-minggu berikutnya.

## Perbedaan dari POC Sebelumnya

| | POC (`toko_buah_poc`) | Aplikasi Asli (project ini) |
|---|---|---|
| Database | SQLite (file lokal, 1 device) | **MySQL** (server terpusat, bisa dipakai banyak user) |
| Istilah | Analogi Toko Buah | Istilah bisnis asli (Customer, Vendor, Material, RFQ) |
| Cakupan | Semua modul sekaligus (demo) | Dibangun bertahap per-modul sesuai timeline |

## Setup Database (WAJIB dibaca dulu sebelum menjalankan app)

Lihat **[TUTORIAL_MYSQL.md](./TUTORIAL_MYSQL.md)** — panduan step-by-step
install MySQL (via XAMPP), bikin database & tabel, sampai konfigurasi
koneksi di aplikasi. Aplikasi ini **tidak akan bisa jalan** sebelum MySQL
sudah disiapkan sesuai tutorial itu.

> ⚠️ **Penting**: pastikan tabelnya dibuat dengan **menjalankan file
> `sql/01_create_database.sql` apa adanya** (copy-paste ke tab SQL
> phpMyAdmin, atau `source ...` di command line — lihat Langkah 4 di
> tutorial). Kalau tabelnya dibuat manual lewat form/wizard "Create table"
> phpMyAdmin sendiri, ada risiko nama kolom jadi tidak persis sama
> (mis. `customers_id` vs `customer_id` yang seharusnya) — bisa
> menyebabkan error `Column 'xxx' cannot be null` saat Save. Kalau sudah
> terlanjur begini, jalankan `sql/03_fix_customer_contacts_column.sql`
> untuk memperbaikinya (aman, tidak menghapus data customer yang sudah
> tersimpan).

## Modul Customer (Minggu 1)

Fitur yang sudah ada:

- **List Customer** — daftar semua customer, badge status Aktif/Nonaktif,
  pull-to-refresh, tombol hapus (dengan konfirmasi).
- **Form Tambah/Edit Customer**, sesuai referensi desain yang diberikan:
  - **Customer ID** — otomatis (`C{id}`), read-only, tidak bisa diisi manual.
  - **Customer Name** — wajib diisi.
  - **PIC & Contact PIC** — **1 customer boleh punya lebih dari 1 PIC**
    (sesuai permintaan owner: PT Merdeka Copper dengan flag C7 punya 3
    kontak → C7.1, C7.2, C7.3, semua data customer sama, cuma PIC-nya
    beda). Bisa tambah/hapus baris PIC bebas lewat tombol "+ Tambah PIC".
  - **NPWP Number** — opsional.
  - **Terms of Payment** — dropdown dengan **kolom search**, daftar sesuai
    referensi (15/30/45/60/90 Days, Cash before delivery, DP 50/30%, SCF).
  - **Customer Type** — dropdown pilihan (BUMN / Swasta / Kawasan Berikat).
  - **Address** — opsional, multi-baris.
  - **Status Aktif/Nonaktif** — toggle switch (konsisten dengan flag yang
    diminta di modul-modul POC sebelumnya).

## Struktur Proyek

```
lib/
  config/
    db_config.dart          # setting koneksi MySQL (host/user/password/db)
  models/
    customer.dart           # data master customer
    customer_contact.dart   # PIC & kontak (1 customer -> banyak kontak)
  services/
    database_service.dart   # semua query MySQL untuk modul Customer
  providers/
    customer_provider.dart  # state management (Provider/ChangeNotifier)
  screens/
    customer_list_screen.dart
    customer_form_screen.dart
  widgets/
    option_picker_dialog.dart  # dialog pilihan reusable (dengan/tanpa search)
  utils/
    app_theme.dart          # palet warna
    customer_options.dart   # daftar tetap Terms of Payment & Customer Type
  main.dart
sql/
  01_create_database.sql    # WAJIB dijalankan sebelum app pertama kali dipakai
  02_seed_sample_data.sql   # opsional, data contoh untuk testing
TUTORIAL_MYSQL.md           # panduan setup database step-by-step
```

## Cara Menjalankan

1. **Ikuti [TUTORIAL_MYSQL.md](./TUTORIAL_MYSQL.md) dari awal sampai selesai**
   (install MySQL, bikin database, sesuaikan `lib/config/db_config.dart`).
2. Generate folder platform (belum ada di project ini, cuma `lib/` +
   `pubspec.yaml`):
   ```bash
   cd purchasing_intermediary
   flutter create .
   ```
3. Install dependency:
   ```bash
   flutter pub get
   ```
4. Jalankan:
   ```bash
   flutter run -d windows
   ```

## Keputusan Desain Penting

- **Koneksi Flutter → MySQL langsung** (bukan lewat backend API terpisah),
  dipilih supaya development lebih cepat — cukup untuk aplikasi internal
  PT dengan jumlah user terbatas. Kalau nanti butuh lebih aman/scalable
  (banyak user, akses dari luar jaringan kantor), bisa dievaluasi ulang
  di fase deployment.
- **Customer ID diturunkan dari `id` database** (`C{id}`), bukan kolom
  tersendiri — supaya selalu unik otomatis walau banyak user input
  bersamaan, tanpa perlu logika penomoran manual yang rawan bug/tabrakan.
- **PIC & Contact disimpan di tabel terpisah** (`customer_contacts`,
  relasi one-to-many ke `customers`) — bukan digabung jadi 1 baris di
  tabel customer, supaya jumlah PIC per customer tidak dibatasi dan
  gampang ditambah/dikurangi.
- **Terms of Payment & Customer Type di-hardcode** di
  `utils/customer_options.dart` untuk sekarang (bukan tabel MySQL
  terpisah), karena daftarnya relatif tetap dan supaya modul ini selesai
  lebih cepat di minggu 1. Gampang diubah jadi tabel database nanti kalau
  perlu bisa diedit sendiri oleh user tanpa update aplikasi.
- **Tidak pakai `conn.transaction()`** dari package `mysql1` untuk insert
  customer + PIC — sengaja pakai insert berurutan biasa, karena API
  transaction package tersebut ingin dipastikan dulu cocok persis dengan
  versi yang ke-install sebelum dipakai (menghindari risiko error build
  yang pernah terjadi sebelumnya karena masalah versi package).
