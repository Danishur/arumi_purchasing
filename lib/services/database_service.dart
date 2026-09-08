import 'package:mysql1/mysql1.dart';
import 'dart:convert';
import '../config/db_config.dart';

/// Singleton untuk mengelola koneksi & query MySQL.
///
/// Pola singleton + memoized Future ini sengaja disamakan dengan
/// DatabaseHelper di project POC sebelumnya (yang sempat kena bug race
/// condition saat banyak layar minta akses database bersamaan di awal
/// buka app) -- di sini dari awal sudah aman dari bug yang sama.
class DatabaseService {
  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();

  MySqlConnection? _connection;
  Future<MySqlConnection>? _connectingFuture;

  Future<MySqlConnection> get _conn async {
    if (_connection != null) return _connection!;
    _connectingFuture ??= _connect();
    try {
      _connection = await _connectingFuture;
      return _connection!;
    } catch (e) {
      _connectingFuture = null;
      rethrow;
    }
  }

  Future<MySqlConnection> _connect() async {
    // ignore: avoid_print
    print('=== DB CONFIG YANG DIPAKAI SAAT INI ===');
    // ignore: avoid_print
    print('host      : ${DbConfig.host}');
    // ignore: avoid_print
    print('port      : ${DbConfig.port}');
    // ignore: avoid_print
    print('user      : ${DbConfig.user}');
    // ignore: avoid_print
    print(
        'password  : ${DbConfig.password.isEmpty ? "(KOSONG)" : "(BERISI ${DbConfig.password.length} karakter)"}');
    // ignore: avoid_print
    print('database  : ${DbConfig.databaseName}');
    // ignore: avoid_print
    print('========================================');

    return MySqlConnection.connect(
      ConnectionSettings(
        host: DbConfig.host,
        port: DbConfig.port,
        user: DbConfig.user,
        password: DbConfig.password,
        db: DbConfig.databaseName,
      ),
    );
  }

  Future<void> testConnection() async {
    final conn = await _conn;
    await conn.query('SELECT 1');
  }

  /// Konversi hasil query mentah jadi Map yang aman dipakai UI.
  /// Kolom bertipe TEXT/BLOB kadang dikembalikan package mysql1
  /// sebagai objek Blob, bukan String -- ini bikin error type cast
  /// kalau langsung dipakai. Di sini di-convert dulu jadi String biasa.
  Map<String, dynamic> _convertRow(Map<String, dynamic> fields) {
    final map = <String, dynamic>{};
    fields.forEach((key, value) {
      if (value is Blob) {
        map[key] = utf8.decode(value.toBytes());
      } else {
        map[key] = value;
      }
    });
    return map;
  }

  // ==================== CUSTOMER ====================

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final conn = await _conn;
    final results =
        await conn.query('SELECT * FROM customers ORDER BY id DESC');
    return results.map((row) => _convertRow(row.fields)).toList();
  }

  Future<List<Map<String, dynamic>>> getContactsByCustomerId(
      int customerId) async {
    final conn = await _conn;
    final results = await conn.query(
      'SELECT * FROM customer_contacts WHERE customer_id = ? ORDER BY id ASC',
      [customerId],
    );
    return results.map((row) => _convertRow(row.fields)).toList();
  }

  /// Insert customer baru + semua PIC/kontaknya sekaligus.
  /// Mengembalikan id customer yang baru dibuat.
  Future<int> insertCustomer(
    Map<String, dynamic> customerRow,
    List<Map<String, dynamic>> contacts,
  ) async {
    final conn = await _conn;
    final result = await conn.query(
      '''INSERT INTO customers
         (customer_name, npwp, terms_of_payment, customer_type, address, status)
         VALUES (?, ?, ?, ?, ?, ?)''',
      [
        customerRow['name'],
        customerRow['npwp_number'],
        customerRow['terms_of_payment'],
        customerRow['customer_type'],
        customerRow['address'],
        customerRow['is_active'],
      ],
    );
    final customerId = result.insertId!;

    for (final c in contacts) {
      await conn.query(
        '''INSERT INTO customer_contacts
           (customer_id, pic_name, pic_position, pic_contact, pic_email)
           VALUES (?, ?, ?, ?, ?)''',
        [customerId, c['pic_name'], c['pic_position'], c['contact'], c['pic_email']],
      );
    }

    return customerId;
  }

  /// Update data customer + ganti seluruh daftar PIC/kontaknya (hapus
  /// yang lama, masukkan ulang yang baru).
  Future<void> updateCustomer(
    Map<String, dynamic> customerRow,
    List<Map<String, dynamic>> contacts,
  ) async {
    final conn = await _conn;
    final id = customerRow['id'];

    await conn.query(
      '''UPDATE customers
         SET customer_name = ?, npwp = ?, terms_of_payment = ?,
             customer_type = ?, address = ?, status = ?
         WHERE id = ?''',
      [
        customerRow['name'],
        customerRow['npwp_number'],
        customerRow['terms_of_payment'],
        customerRow['customer_type'],
        customerRow['address'],
        customerRow['is_active'],
        id,
      ],
    );

    await conn
        .query('DELETE FROM customer_contacts WHERE customer_id = ?', [id]);
    for (final c in contacts) {
      await conn.query(
        '''INSERT INTO customer_contacts
           (customer_id, pic_name, pic_position, pic_contact, pic_email)
           VALUES (?, ?, ?, ?, ?)''',
        [id, c['pic_name'], c['pic_position'], c['contact'], c['pic_email']],
      );
    }
  }

  Future<void> deleteCustomer(int id) async {
    final conn = await _conn;
    await conn.query('DELETE FROM customers WHERE id = ?', [id]);
  }

  /// Hapus banyak customer sekaligus (dipakai fitur select multi di
  /// layar list). `customer_contacts` ikut kehapus otomatis lewat FK
  /// `ON DELETE CASCADE` (lihat sql/01_create_database.sql).
  Future<void> deleteCustomers(List<int> ids) async {
    if (ids.isEmpty) return;
    final conn = await _conn;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await conn.query('DELETE FROM customers WHERE id IN ($placeholders)', ids);
  }
}