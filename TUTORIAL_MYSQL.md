# Tutorial Lengkap: Setup & Pakai MySQL untuk Aplikasi Purchasing Intermediary

Panduan ini ditulis untuk yang **belum pernah setup database MySQL sama
sekali**. Ikuti dari atas ke bawah secara berurutan, jangan ada langkah yang
dilewat — tiap langkah dibangun di atas langkah sebelumnya.

**Perkiraan waktu total: 30–45 menit** (tergantung kecepatan internet buat
download XAMPP).

---

## Daftar Isi

1. [Sebelum Mulai](#1-sebelum-mulai)
2. [Konsep Dasar: Apa Itu Database, Table, Column, Row?](#2-konsep-dasar-apa-itu-database-table-column-row)
3. [Kenapa Pindah dari SQLite ke MySQL?](#3-kenapa-pindah-dari-sqlite-ke-mysql)
4. [Langkah 1: Install XAMPP](#langkah-1-install-xampp)
5. [Langkah 2: Nyalakan MySQL & Apache](#langkah-2-nyalakan-mysql--apache)
6. [Langkah 3: Kenalan dengan phpMyAdmin](#langkah-3-kenalan-dengan-phpmyadmin)
7. [Langkah 4: Membuat Database & Tabel](#langkah-4-membuat-database--tabel)
8. [Langkah 5: Verifikasi Hasilnya](#langkah-5-verifikasi-hasilnya)
9. [Langkah 6: Isi Data Contoh (Opsional)](#langkah-6-isi-data-contoh-opsional)
10. [Langkah 7: Sambungkan Aplikasi Flutter ke MySQL](#langkah-7-sambungkan-aplikasi-flutter-ke-mysql)
11. [Langkah 8: Jalankan Aplikasinya](#langkah-8-jalankan-aplikasinya)
12. [Bonus: Kelola Data Manual Lewat phpMyAdmin](#bonus-kelola-data-manual-lewat-phpmyadmin)
13. [Troubleshooting](#troubleshooting)
14. [FAQ (Pertanyaan yang Sering Muncul)](#faq-pertanyaan-yang-sering-muncul)
15. [Langkah Selanjutnya (Untuk Nanti, Bukan Sekarang)](#langkah-selanjutnya-untuk-nanti-bukan-sekarang)

---

## 1. Sebelum Mulai

Pastikan dulu:

- [ ] Laptop/PC pakai **Windows** (tutorial ini fokus ke Windows, sesuai
      environment development kita).
- [ ] Ada akses **internet** buat download XAMPP (sekitar 150-180 MB).
- [ ] Ada **ruang disk kosong** minimal 1 GB.
- [ ] Punya akses **Administrator** di laptop tersebut (buat install
      software). Kalau laptop kantor dan kamu bukan admin, minta tolong IT
      dulu buat install-kan atau kasih akses admin sementara.
- [ ] **Flutter SDK sudah terpasang** (`flutter doctor` di terminal harus
      hijau semua) — ini prasyarat dari project sebelumnya, bukan bagian
      dari tutorial MySQL ini.
- [ ] Folder project `purchasing_intermediary` sudah di-download & di-extract
      di komputer kamu.

Kalau semua di atas sudah oke, lanjut ke bagian berikutnya.

---

## 2. Konsep Dasar: Apa Itu Database, Table, Column, Row?

Kalau kamu sudah paham konsep ini, boleh skip ke [bagian 3](#3-kenapa-pindah-dari-sqlite-ke-mysql).
Kalau belum pernah pegang database sama sekali, baca dulu — ini bakal
memudahkan langkah-langkah setelahnya.

Bayangkan database itu seperti **1 folder besar berisi banyak file Excel**:

```
DATABASE "purchasing_intermediary"   <-- ini foldernya
  |
  +-- TABLE "customers"              <-- ini 1 file Excel-nya
  |     (data master tiap customer)
  |
  +-- TABLE "customer_contacts"      <-- ini file Excel lainnya
        (data PIC & kontak tiap customer)
```

Di dalam 1 **table** (mis. `customers`), strukturnya persis kayak sheet
Excel:

| id (COLUMN) | name (COLUMN) | npwp_number (COLUMN) | is_active (COLUMN) |
|---|---|---|---|
| 1 | PT. Nusantara Perdagangan | 01.234.567.8-901.000 | 1 |  <- ini 1 ROW
| 2 | PT Merdeka Copper | 02.345.678.9-012.000 | 1 |  <- ini 1 ROW

Istilahnya:
- **Database** = wadah besar yang menampung semua table (di project kita:
  `purchasing_intermediary`).
- **Table** = "sheet Excel"-nya, tempat 1 jenis data disimpan (di project
  kita minggu ini: `customers` dan `customer_contacts`).
- **Column** = "header kolom" di Excel, mendefinisikan JENIS data apa yang
  disimpan (nama, alamat, dst) beserta tipe datanya (teks, angka, dst).
- **Row** = "1 baris data", 1 record/entry yang lengkap (mis. 1 customer).

Aplikasi Flutter yang kita buat nanti akan **membaca dan menulis** ke
table-table ini lewat internet/jaringan lokal (bukan buka file secara
langsung kayak Excel) — makanya kita perlu jalankan **MySQL Server**
(program yang "menjaga" database ini dan melayani permintaan baca/tulis
dari aplikasi).

---

## 3. Kenapa Pindah dari SQLite ke MySQL?

Di POC sebelumnya kita pakai **SQLite** — databasenya cuma 1 file lokal di
1 laptop, cuma bisa dipakai 1 orang di 1 device itu saja. Sekarang aplikasi
"asli" ini akan dipakai **TIM PURCHASING** (banyak orang, dari device
masing-masing), jadi butuh **1 database terpusat** yang semua orang bisa
akses & lihat data yang SAMA secara real-time — itulah **MySQL**.

**Alur besarnya:**
```
Laptop kamu (development sekarang) --> MySQL LOCAL di laptop sendiri
                                          |
                                          v (nanti kalau sudah mau dipakai tim)
                                     MySQL di SERVER PUSAT
                                          |
                    +---------------------+---------------------+
                    |                     |                     |
              Laptop User A         Laptop User B         Laptop User C
             (Flutter app)         (Flutter app)         (Flutter app)
```

Untuk **sekarang** (development, minggu 1), kita install MySQL di laptop
kamu sendiri dulu. Nanti pas mau serah terima ke tim purchasing, tinggal
pindahkan MySQL-nya ke server kantor / cloud, dan cuma perlu ubah 1 baris
setting di aplikasi (`lib/config/db_config.dart`) — kode aplikasinya
TIDAK perlu diubah sama sekali. Detail soal ini ada di [bagian terakhir](#langkah-selanjutnya-untuk-nanti-bukan-sekarang).

---

## Langkah 1: Install XAMPP

**XAMPP** dipilih karena paling gampang untuk pemula — sekali install,
sudah dapat paket lengkap: **MySQL** (database engine-nya) + **phpMyAdmin**
(aplikasi web buat lihat/edit database pakai klik-klik & antarmuka visual,
tanpa perlu ketik perintah SQL manual kalau tidak mau) + Apache (web server
yang dibutuhkan supaya phpMyAdmin bisa dibuka lewat browser).

### 1.1. Download

1. Buka browser (Chrome/Edge/dll), pergi ke **<https://www.apachefriends.org/>**
2. Cari tombol download besar, biasanya tulisannya **"Download"** dengan
   logo Windows di sampingnya. Klik itu.
3. Kamu akan diarahkan ke pilihan versi. Pilih yang **versi terbaru untuk
   Windows** (nama file-nya biasanya seperti `xampp-windows-x64-8.x.x-x-installer.exe`).
   Versi PHP-nya (8.0, 8.1, 8.2, dst) tidak terlalu penting untuk kita
   karena yang kita pakai cuma bagian MySQL & phpMyAdmin-nya.
4. Tunggu download selesai (file-nya sekitar 150-180 MB, tergantung
   kecepatan internet).

### 1.2. Install

1. Buka file installer yang baru di-download (biasanya ada di folder
   **Downloads**), nama filenya diawali `xampp-windows-...`.
2. Kalau muncul **peringatan Windows/antivirus** ("Windows protected your
   PC" atau serupa) — ini NORMAL untuk installer XAMPP karena belum
   punya sertifikat digital tertentu. Klik **"More info"** lalu **"Run
   anyway"**.
3. Kalau muncul **User Account Control (UAC)** minta izin admin — klik
   **"Yes"**.
4. Muncul jendela **Setup Wizard XAMPP**, klik **Next**.
5. Muncul halaman **"Select Components"** — pastikan minimal komponen
   berikut TERCENTANG (biasanya sudah default tercentang semua, jangan
   di-uncheck):
   - ✅ **Apache**
   - ✅ **MySQL**
   - ✅ **phpMyAdmin**

   Komponen lain (FileZilla, Mercury, Tomcat, Webalizer) boleh di-uncheck
   kalau mau instalasi lebih ringkas — tidak kita pakai. Klik **Next**.
6. Halaman **"Installation folder"** — biarkan default (`C:\xampp`). Ini
   penting supaya path-path di tutorial ini nanti cocok. Klik **Next**.
7. Kalau ada halaman tentang **"Bitnami for XAMPP"** — klik **Next**/skip
   saja (tidak relevan buat kita).
8. Halaman **"Ready to Install"** — klik **Next**, tunggu proses instalasi
   selesai (beberapa menit).
9. Setelah selesai, akan ada checkbox **"Do you want to start the Control
   Panel now?"** — biarkan tercentang, klik **Finish**.

Kalau semua langkah di atas berhasil, **XAMPP Control Panel** akan
otomatis terbuka (jendela kecil dengan daftar service: Apache, MySQL,
FileZilla, dst — masing-masing punya tombol Start/Stop).

---

## Langkah 2: Nyalakan MySQL & Apache

1. Di **XAMPP Control Panel**, cari baris **MySQL**, klik tombol **Start**
   di sebelah kanannya.
2. Tunggu beberapa detik. Kalau berhasil, baris MySQL akan berubah warna
   jadi **hijau**, dan di kolom sebelahnya muncul nomor **PID** & **Port(s)**
   (biasanya `3306`).
3. Lakukan hal yang sama untuk baris **Apache** — klik **Start**, tunggu
   sampai hijau. Apache dibutuhkan supaya phpMyAdmin (yang jalan lewat
   browser) bisa diakses.

> **Penting**: biarkan **XAMPP Control Panel tetap terbuka** selama kamu
> develop/pakai aplikasi Flutter-nya. Kalau MySQL di-Stop atau laptop
> kamu restart (servicenya tidak otomatis nyala lagi kecuali kamu setting
> khusus), aplikasi Flutter TIDAK akan bisa connect ke database sampai
> kamu buka lagi XAMPP Control Panel dan Start MySQL-nya manual.

**Kalau tombol Start MySQL gagal / warnanya jadi merah / muncul error
"port 3306 sudah dipakai"**: lihat bagian [Troubleshooting](#troubleshooting)
di bawah, ada solusinya.

---

## Langkah 3: Kenalan dengan phpMyAdmin

Sebelum bikin database, kenalan dulu sama alat yang akan sering kamu pakai:

1. Buka browser, ketik alamat: **`http://localhost/phpmyadmin`**, Enter.
2. Kalau MySQL & Apache sudah Running (langkah 2), halaman **phpMyAdmin**
   akan terbuka. Tampilannya kira-kira:
   - **Sidebar kiri**: daftar database yang ada (awalnya cuma database
     bawaan MySQL seperti `information_schema`, `mysql`, `performance_schema`
     — database project kita BELUM ada di sini, itu wajar, kita akan
     buat di langkah berikutnya).
   - **Area utama/tengah**: berubah-ubah tergantung apa yang kamu klik di
     sidebar. Kalau belum klik apa-apa, biasanya nampilin info umum server
     MySQL-nya.
   - **Menu tab di atas** (SQL, Status, User accounts, dst): muncul kalau
     kamu sudah klik salah satu database/tabel di sidebar.

Kalau halaman ini berhasil terbuka, artinya MySQL & Apache kamu sudah
jalan dengan benar — lanjut ke langkah berikutnya.

**Kalau halaman ini TIDAK bisa dibuka** (error "This site can't be reached"
atau serupa): balik ke Langkah 2, pastikan Apache & MySQL statusnya hijau
di XAMPP Control Panel.

---

## Langkah 4: Membuat Database & Tabel

Sekarang bagian intinya — bikin database `purchasing_intermediary` beserta
2 tabel yang dibutuhkan modul Customer minggu ini (`customers` dan
`customer_contacts`). Ada 2 cara, **pilih SALAH SATU saja** (hasil akhirnya
sama persis):

### Cara A — Pakai phpMyAdmin (disarankan untuk pemula, klik-klik saja)

1. Dari halaman phpMyAdmin (`http://localhost/phpmyadmin`), klik tab
   **SQL** di bagian **atas halaman** (bukan di sidebar kiri — tab di
   atas, sejajar dengan tab "Databases", "User accounts", "Status", dst).

   > Kalau tab "SQL" tidak kelihatan di halaman utama: klik dulu
   > **"Databases"** di menu atas, itu tidak masalah — tab "SQL" tetap ada
   > di halaman manapun selama kamu belum masuk ke dalam 1 tabel spesifik.

2. Buka file `sql/01_create_database.sql` yang ada di dalam folder project
   `purchasing_intermediary` (klik kanan file itu di Windows Explorer >
   **Open with** > **Notepad**, atau text editor apapun yang kamu punya).

3. **Select semua isi file itu** (Ctrl+A), **copy** (Ctrl+C).

4. Balik ke tab browser phpMyAdmin tadi, **klik di kotak kosong besar**
   di bawah tab SQL, **paste** (Ctrl+V) isi file SQL-nya ke situ.

5. Klik tombol **Go** di pojok kanan bawah kotak tersebut.

6. Kalau berhasil, akan muncul beberapa pesan hijau seperti
   **"Query executed successfully"** (satu per satu perintah di dalam
   file SQL-nya — file itu berisi beberapa perintah `CREATE TABLE`
   sekaligus, jadi wajar kalau muncul beberapa pesan sukses).

7. Cek sidebar kiri — sekarang harus muncul database baru bernama
   **`purchasing_intermediary`**. Kalau belum kelihatan, klik ikon
   **refresh** kecil di atas sidebar (atau reload halaman browser-nya,
   F5).

### Cara B — Pakai Command Line (untuk yang lebih terbiasa terminal)

1. Buka **Command Prompt** atau **PowerShell**.

2. Masuk ke folder MySQL bin milik XAMPP:
   ```powershell
   cd C:\xampp\mysql\bin
   ```

3. Login ke MySQL. Default XAMPP: user `root`, password **KOSONG** (pas
   diminta password, tinggal tekan **Enter** tanpa ketik apa-apa):
   ```powershell
   .\mysql.exe -u root -p
   ```

4. Setelah berhasil login, prompt-nya berubah jadi `mysql>`. Jalankan
   file SQL-nya pakai perintah `source`, dengan path LENGKAP ke file
   tersebut (ganti sesuai lokasi folder project kamu, dan **pakai garis
   miring `/`, bukan `\`**):
   ```sql
   source C:/Users/NamaKamu/Downloads/purchasing_intermediary/sql/01_create_database.sql;
   ```

5. Kalau berhasil, akan muncul beberapa baris `Query OK` untuk tiap
   perintah di dalam file tersebut.

6. Cek hasilnya:
   ```sql
   USE purchasing_intermediary;
   SHOW TABLES;
   ```
   Harus muncul 2 baris: `customers` dan `customer_contacts`.

7. Ketik `exit;` untuk keluar dari MySQL command line.

### Penjelasan Isi File `01_create_database.sql`

Biar tidak asal copy-paste, ini penjelasan tiap bagian file SQL-nya:

```sql
CREATE DATABASE IF NOT EXISTS purchasing_intermediary ...
```
→ Bikin "folder besar" (database) bernama `purchasing_intermediary`, kalau
belum ada. `CHARACTER SET utf8mb4` supaya bisa menyimpan segala jenis
karakter dengan aman (termasuk emoji, karakter aksen, dll — praktik
standar untuk aplikasi modern).

```sql
CREATE TABLE IF NOT EXISTS customers (
  id  INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  ...
)
```
→ Bikin tabel `customers` dengan kolom-kolom sesuai kebutuhan form
Customer. `id INT AUTO_INCREMENT PRIMARY KEY` artinya kolom `id` otomatis
diisi angka urut (1, 2, 3, ...) oleh MySQL sendiri setiap ada data baru —
kita tidak perlu isi manual. `NOT NULL` artinya kolom itu WAJIB diisi
(tidak boleh kosong), sesuai field yang bertanda bintang merah (*) di form
(Customer Name). Kolom lain seperti `npwp_number`, `terms_of_payment`
dibuat `NULL` (boleh kosong) karena di form juga tidak wajib.

```sql
CREATE TABLE IF NOT EXISTS customer_contacts (
  id  INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NOT NULL,
  pic_name VARCHAR(255) NOT NULL,
  contact VARCHAR(255) NOT NULL,
  ...
  FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
)
```
→ Tabel terpisah untuk PIC & kontak, supaya **1 customer bisa punya lebih
dari 1 PIC** (sesuai permintaan owner). Kolom `customer_id` menyimpan "link"
ke customer pemiliknya. `FOREIGN KEY ... ON DELETE CASCADE` artinya: kalau
1 customer dihapus, SEMUA PIC-nya otomatis ikut terhapus juga — supaya
tidak ada data PIC "yatim" yang nyangkut tanpa customer.

---

## Langkah 5: Verifikasi Hasilnya

Balik ke phpMyAdmin (`http://localhost/phpmyadmin`):

1. Klik database **`purchasing_intermediary`** di sidebar kiri.
2. Akan terbuka daftar tabel di dalamnya — harus ada **2 tabel**:
   `customers` dan `customer_contacts`.
3. Klik tabel **`customers`**, lalu klik tab **Structure** — kamu akan
   lihat daftar kolomnya: `id`, `name`, `npwp_number`, `terms_of_payment`,
   `customer_type`, `address`, `is_active`, `created_at`, `updated_at`.
   Kalau semua kolom ini muncul, berarti tabelnya sudah benar.
4. Klik tabel **`customer_contacts`**, cek juga tab **Structure** — harus
   ada kolom: `id`, `customer_id`, `pic_name`, `contact`, `created_at`.

Kalau semua sesuai di atas — **selamat, database kamu sudah siap!**
Lanjut ke langkah berikutnya.

---

## Langkah 6: Isi Data Contoh (Opsional)

Kalau mau langsung ada data testing tanpa input manual satu-satu dari
aplikasi, jalankan file `sql/02_seed_sample_data.sql` dengan cara **yang
sama** seperti Langkah 4 (copy-paste ke tab SQL phpMyAdmin, atau `source
...` di command line).

Ini akan mengisi 2 contoh customer:
- **PT. Nusantara Perdagangan** dengan 1 PIC (Budi Santoso).
- **PT Merdeka Copper** dengan 3 PIC (Andi Wijaya, Siti Rahma, Hendra
  Gunawan) — persis skenario "C7.1, C7.2, C7.3" yang dicontohkan owner di
  chat WA.

Ini **boleh dilewati** kalau kamu mau mulai dari database kosong dan input
manual semua data lewat aplikasi.

---

## Langkah 7: Sambungkan Aplikasi Flutter ke MySQL

Buka file `lib/config/db_config.dart` di text editor / code editor kamu
(VS Code, dsb). Isinya seperti ini:

```dart
class DbConfig {
  static const String host = 'localhost';
  static const int port = 3306;
  static const String user = 'root';
  static const String password = '';
  static const String databaseName = 'purchasing_intermediary';
}
```

Kalau kamu ikutin tutorial ini **persis** (install XAMPP default, tidak
ubah-ubah setting apapun), **nilai di atas sudah pas dan TIDAK perlu
diubah apapun** — langsung lanjut ke Langkah 8.

Cuma perlu diubah kalau:
- Kamu set password sendiri untuk user `root` MySQL → isi di `password`.
- MySQL kamu jalan di port lain (bukan `3306`) → sesuaikan `port`.
- Kamu pakai MySQL Installer resmi (bukan XAMPP) dan bikin user MySQL
  baru (bukan `root`) → sesuaikan `user` & `password`.

---

## Langkah 8: Jalankan Aplikasinya

Buka terminal (Command Prompt/PowerShell/terminal VS Code), masuk ke
folder project:

```bash
cd purchasing_intermediary
flutter create .
flutter pub get
flutter run -d windows
```

Kalau semua langkah di atas benar, aplikasi akan terbuka langsung ke
layar **"Data Customer"** (kosong kalau belum isi seed data, atau ada 2
baris kalau tadi kamu jalankan Langkah 6).

**Tes cepat**: tekan tombol **+** di pojok kanan bawah, isi form Customer
baru, tekan **Save**. Kalau berhasil, kamu akan balik ke halaman list dan
customer barunya muncul di situ. Buka lagi phpMyAdmin, klik tabel
`customers` > tab **Browse** — data yang baru kamu input dari aplikasi
harus **langsung muncul** di situ juga. Kalau ini berhasil, artinya
koneksi Flutter ↔ MySQL kamu sudah benar-benar jalan end-to-end.

---

## Bonus: Kelola Data Manual Lewat phpMyAdmin

Kadang kamu perlu lihat/ubah/hapus data langsung dari database (tanpa
lewat aplikasi Flutter) — misalnya buat debug atau bersih-bersih data
testing. Caranya:

- **Lihat semua data**: klik database `purchasing_intermediary` > klik
  tabel (mis. `customers`) > tab **Browse**.
- **Edit 1 baris data**: di tab Browse, cari baris yang mau diedit, klik
  ikon **pensil** di ujung kiri baris itu, ubah nilainya di form yang
  muncul, klik **Go**.
- **Hapus 1 baris data**: di tab Browse, klik ikon **tempat sampah** di
  ujung kiri baris tersebut, konfirmasi penghapusan.
- **Kosongkan SEMUA data di 1 tabel** (tanpa menghapus tabelnya): klik
  tabel tersebut > tab **Operations** > cari tombol **"Empty the table
  (TRUNCATE)"**.
- **Jalankan query SQL manual apapun**: tab **SQL** di halaman database
  atau tabel manapun, ketik perintahnya, klik **Go**.

> ⚠️ Hati-hati: aksi hapus/edit lewat phpMyAdmin **langsung permanen**,
> tidak ada tombol "Undo". Kalau ragu, backup dulu (klik database >
> tab **Export** > **Go**, akan ke-download file `.sql` berisi salinan
> semua data saat ini).

---

## Troubleshooting

| Gejala | Kemungkinan Penyebab | Solusi |
|---|---|---|
| Saat Save Customer muncul error **`Column 'customers_id' cannot be null`** (atau nama kolom lain yang mirip tapi tidak persis) | Tabel `customer_contacts` dibuat manual lewat wizard "Create table" phpMyAdmin (bukan menjalankan file `01_create_database.sql` apa adanya), sehingga nama kolomnya tidak persis sama dengan yang diharapkan kode aplikasi | Jalankan file **`sql/03_fix_customer_contacts_column.sql`** (caranya sama seperti Langkah 4: copy-paste ke tab SQL phpMyAdmin, klik Go). Ini aman — cuma membuat ulang tabel `customer_contacts` dengan struktur yang benar, data di tabel `customers` tidak ikut terhapus. Setelah itu, cek juga apakah ada baris customer "yatim" (tersimpan tanpa PIC) sisa percobaan yang gagal tadi — query untuk cek ini sudah ada di bagian bawah file fix tersebut. |
| Tombol Start MySQL di XAMPP gagal / jadi merah, ada tulisan "port 3306 sudah dipakai" | Ada aplikasi lain yang sudah pakai port 3306 (biasanya instalasi MySQL Installer resmi yang jalan otomatis sebagai Windows Service) | Buka **Task Manager** > tab **Services** (atau ketik "Services" di Start Menu) > cari service bernama **MySQL** atau **MySQL80** > klik kanan > **Stop**. Baru coba Start lagi dari XAMPP Control Panel. |
| Halaman `localhost/phpmyadmin` tidak bisa dibuka | Apache belum Start, atau port 80 dipakai aplikasi lain (mis. Skype lama, IIS) | Pastikan Apache statusnya hijau di XAMPP. Kalau tetap gagal, di XAMPP Control Panel klik **Config** di baris Apache > **Apache (httpd.conf)** > cari `Listen 80`, ganti ke port lain mis. `Listen 8080`, lalu akses `localhost:8080/phpmyadmin` |
| Layar app Flutter: "Gagal terhubung ke database MySQL" | MySQL belum jalan, atau setting di `db_config.dart` salah | Buka XAMPP Control Panel, pastikan MySQL "Running". Cek ulang `host`/`port`/`user`/`password` di `db_config.dart` |
| Error spesifik `Access denied for user 'root'@'localhost' (using password: YES)` saat Save/load data | Password di `lib/config/db_config.dart` tidak cocok dengan password root MySQL yang sebenarnya (paling sering: `db_config.dart` ke-isi sesuatu padahal root MySQL-nya sebenarnya TIDAK punya password) | **Diagnosis dulu**: buka `http://localhost/phpmyadmin` — kalau langsung masuk tanpa diminta login, root TIDAK punya password (pastikan `db_config.dart` persis `static const String password = '';` — kosong). Kalau phpMyAdmin minta login, pakai password yang berhasil login di situ ke `db_config.dart`. **Kalau lupa passwordnya dan mau di-reset ke kosong**: lihat langkah reset di bawah tabel ini. |
| `(using password: NO)` di pesan error (bukan YES) | `db_config.dart` sudah kosong (benar), tapi root MySQL-nya JUSTRU **butuh** password | Set ulang password root ke kosong (ikuti langkah reset di bawah), ATAU cari tahu password yang benar dan isi ke `db_config.dart` |
| Error `Connection refused` / timeout lama lalu gagal | Port 3306 diblokir firewall Windows, atau MySQL jalan di port lain | Cek nomor port yang tertera di XAMPP Control Panel (kolom "Port(s)" baris MySQL), sesuaikan `port` di `db_config.dart`. Kalau soal firewall, biasanya tidak masalah untuk koneksi ke `localhost` (komputer sendiri) |
| Data yang disimpan dari app tidak muncul di phpMyAdmin (atau sebaliknya) | ada 2 MySQL server nyala bersamaan (mis. XAMPP + MySQL Installer resmi keduanya aktif), jadi app & phpMyAdmin connect ke server yang beda | Pastikan cuma **SATU** MySQL server yang jalan. Matikan salah satu (lihat solusi baris pertama tabel ini untuk cara stop MySQL Installer resmi) |
| Setelah restart laptop, app Flutter langsung error tidak bisa connect | XAMPP tidak otomatis nyala saat laptop dinyalakan (defaultnya memang begitu) | Buka XAMPP Control Panel secara manual, Start MySQL & Apache lagi setiap kali habis restart laptop |
| Muncul error mengandung tulisan "Too many connections" | Banyak koneksi ke MySQL dibuka tapi tidak pernah ditutup (jarang terjadi di app ini karena sudah pakai pola singleton connection, tapi bisa muncul kalau app di-restart berkali-kali lewat hot-restart tanpa menutup koneksi lama) | Restart MySQL dari XAMPP Control Panel (Stop lalu Start lagi) untuk reset semua koneksi yang menggantung |

### Cara Reset Password Root MySQL ke Kosong (Kalau Lupa / Mau Disamakan dengan Default XAMPP)

Ikuti ini kalau kamu dapat error `Access denied` dan mau memastikan root MySQL-nya balik ke kondisi default XAMPP (tanpa password), supaya cocok dengan `db_config.dart` yang defaultnya juga kosong.

1. Buka **Command Prompt**, masuk ke folder MySQL bin milik XAMPP:
   ```powershell
   cd C:\xampp\mysql\bin
   ```
2. Coba login TANPA flag `-p` dulu (kalau memang passwordnya kosong, ini
   langsung berhasil masuk tanpa ditanya apa-apa):
   ```powershell
   .\mysql.exe -u root
   ```
   Kalau berhasil masuk (muncul prompt `mysql>`), lanjut ke langkah 4.

3. Kalau langkah 2 gagal (diminta password dan kamu tidak tahu), coba
   dengan flag `-p` dan masukkan password yang mungkin pernah kamu set:
   ```powershell
   .\mysql.exe -u root -p
   ```
   Kalau tetap tidak ada password yang berhasil dan benar-benar buntu,
   opsi terakhir: **install ulang XAMPP** (uninstall dulu, hapus folder
   `C:\xampp` kalau masih ada sisa, install ulang dari awal seperti
   Langkah 1 tutorial ini) — instalasi baru selalu mulai dengan root
   tanpa password.

4. Setelah berhasil masuk (prompt `mysql>`), jalankan:
   ```sql
   ALTER USER 'root'@'localhost' IDENTIFIED BY '';
   FLUSH PRIVILEGES;
   EXIT;
   ```
5. Pastikan `lib/config/db_config.dart` juga `password = '';` (kosong),
   lalu jalankan ulang aplikasi Flutter-nya (stop total, bukan hot-reload).

---

## FAQ (Pertanyaan yang Sering Muncul)

**Q: Apakah saya perlu paham SQL untuk pakai aplikasi ini sehari-hari?**
A: Tidak. Perintah SQL cuma dipakai SEKALI di awal (Langkah 4) untuk
bikin struktur tabel. Setelah itu, semua tambah/lihat/edit/hapus data
dilakukan lewat aplikasi Flutter-nya, bukan lewat SQL manual.

**Q: Kenapa password default root MySQL kosong? Apa itu aman?**
A: Untuk development LOCAL di laptop sendiri, itu aman-aman saja karena
MySQL-nya cuma bisa diakses dari komputer itu sendiri (`localhost`) —
tidak ada orang luar yang bisa akses lewat internet. Nanti kalau sudah ke
tahap MySQL di server terpusat (dipakai bareng tim), WAJIB pakai password
yang kuat — ini dibahas di bagian [Langkah Selanjutnya](#langkah-selanjutnya-untuk-nanti-bukan-sekarang).

**Q: Apa bedanya Apache dan MySQL di XAMPP? Saya cuma butuh database, kok
harus nyalain Apache juga?**
A: MySQL = database engine-nya (yang benar-benar dipakai aplikasi
Flutter). Apache = web server yang dibutuhkan supaya **phpMyAdmin** (alat
bantu visual berbasis web) bisa dibuka lewat browser. Aplikasi Flutter
sendiri TIDAK butuh Apache — tapi kalau kamu mau pakai phpMyAdmin buat
lihat/edit data manual, Apache harus nyala.

**Q: Data yang saya input hilang setelah restart laptop, kenapa?**
A: Seharusnya TIDAK hilang — data MySQL tersimpan permanen di disk
(`C:\xampp\mysql\data`), bukan cuma di memory. Kalau kelihatan hilang,
kemungkinan besar MySQL belum di-Start lagi setelah restart (lihat baris
terkait di tabel Troubleshooting), jadi aplikasi gagal connect dan
kelihatan seperti kosong, padahal datanya masih ada begitu MySQL
dinyalakan lagi.

**Q: Boleh install ulang / uninstall XAMPP kalau ada masalah?**
A: Boleh, tapi **backup dulu** database kamu (lihat cara Export di bagian
[Bonus](#bonus-kelola-data-manual-lewat-phpmyadmin) di atas) sebelum
uninstall, supaya data yang sudah diinput tidak hilang.

---

## Langkah Selanjutnya (Untuk Nanti, Bukan Sekarang)

Kalau nanti aplikasi sudah mau dipakai betulan oleh tim purchasing (bukan
cuma development sendiri), MySQL-nya perlu dipindah dari laptop kamu ke
lokasi yang bisa diakses semua orang, misalnya:

- **Server kantor** yang selalu nyala & terhubung ke jaringan kantor (LAN),
- atau **cloud database** (mis. layanan managed MySQL dari penyedia cloud).

Yang perlu diubah nanti **CUMA** `lib/config/db_config.dart` (ganti `host`
ke alamat server barunya, `user`/`password` sesuai kredensial di server
itu) — kode aplikasi lainnya tidak perlu disentuh sama sekali.

Hal-hal yang perlu dipikirkan di fase itu nanti (didiskusikan lagi waktunya,
tidak perlu dipikirkan sekarang):
- MySQL server-nya perlu di-setting supaya bisa menerima koneksi dari luar
  `localhost` (`bind-address` di file konfigurasi MySQL).
- Firewall server perlu dibuka untuk port 3306 (atau port lain yang dipakai).
- User MySQL khusus aplikasi (bukan `root`) dengan password kuat, dan hak
  akses yang dibatasi cuma ke database `purchasing_intermediary` saja.
- Backup database berkala (supaya data tim tidak hilang kalau server
  bermasalah).
