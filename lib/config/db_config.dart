/// Konfigurasi koneksi MySQL.
///
/// SEMUA setting koneksi database ada di SATU tempat ini, supaya kalau
/// nanti pindah dari "MySQL local di laptop sendiri" ke "MySQL di
/// server/cloud kantor", cukup ubah 4 baris di file ini saja -- tidak
/// perlu cari-cari di banyak file lain.
///
/// NILAI DEFAULT DI BAWAH INI SESUAI SETTING XAMPP / MySQL Installer
/// standar untuk development LOCAL. Sesuaikan kalau environment kamu beda
/// (lihat TUTORIAL_MYSQL.md untuk cara setting-nya step-by-step).
class DbConfig {
  static const String host = 'localhost';
  static const int port = 3306;
  static const String user = 'flutter_user';
  static const String password = 'Flutter123!';
  static const String databaseName = 'arumi_purchasing';
}
