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

  // ==================== VENDOR ====================

  Future<List<Map<String, dynamic>>> getVendors() async {
    final conn = await _conn;
    final results = await conn.query('SELECT * FROM vendors ORDER BY id DESC');
    return results.map((row) => _convertRow(row.fields)).toList();
  }

  Future<List<Map<String, dynamic>>> getContactsByVendorId(int vendorId) async {
    final conn = await _conn;
    final results = await conn.query(
      'SELECT * FROM vendor_contacts WHERE vendor_id = ? ORDER BY id ASC',
      [vendorId],
    );
    return results.map((row) => _convertRow(row.fields)).toList();
  }

  Future<List<Map<String, dynamic>>> getProductsByVendorId(int vendorId) async {
    final conn = await _conn;
    final results = await conn.query(
      'SELECT * FROM vendor_products WHERE vendor_id = ? ORDER BY id ASC',
      [vendorId],
    );
    return results.map((row) => _convertRow(row.fields)).toList();
  }

  /// Insert vendor baru + semua PIC dan Produk/Brand-nya sekaligus.
  /// Mengembalikan id vendor yang baru dibuat.
  Future<int> insertVendor(
    Map<String, dynamic> vendorRow,
    List<Map<String, dynamic>> contacts,
    List<Map<String, dynamic>> products,
  ) async {
    final conn = await _conn;
    final result = await conn.query(
      '''INSERT INTO vendors
         (vendor_name, legal_standing, npwp, is_verified, terms_of_payment,
          scope_of_work, sub_sow, supply_chain_classification, internal_note,
          vendor_address, pic_website, bank_name, bank_account_number,
          bank_account_holder, bank_currency, bank_swift_code, status)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        vendorRow['vendor_name'],
        vendorRow['legal_standing'],
        vendorRow['npwp'],
        vendorRow['is_verified'],
        vendorRow['terms_of_payment'],
        vendorRow['scope_of_work'],
        vendorRow['sub_sow'],
        vendorRow['supply_chain_classification'],
        vendorRow['internal_note'],
        vendorRow['vendor_address'],
        vendorRow['pic_website'],
        vendorRow['bank_name'],
        vendorRow['bank_account_number'],
        vendorRow['bank_account_holder'],
        vendorRow['bank_currency'],
        vendorRow['bank_swift_code'],
        vendorRow['status'],
      ],
    );
    final vendorId = result.insertId!;

    for (final c in contacts) {
      await conn.query(
        '''INSERT INTO vendor_contacts (vendor_id, pic_name, pic_position, pic_contact, pic_email)
           VALUES (?, ?, ?, ?, ?)''',
        [vendorId, c['pic_name'], c['pic_position'], c['pic_contact'], c['pic_email']],
      );
    }

    for (final p in products) {
      await conn.query(
        'INSERT INTO vendor_products (vendor_id, product_name) VALUES (?, ?)',
        [vendorId, p['product_name']],
      );
    }

    return vendorId;
  }

  /// Update data vendor + ganti seluruh daftar PIC & Produk/Brand-nya
  /// (hapus yang lama, masukkan ulang yang baru) -- pola sama dengan
  /// updateCustomer.
  Future<void> updateVendor(
    Map<String, dynamic> vendorRow,
    List<Map<String, dynamic>> contacts,
    List<Map<String, dynamic>> products,
  ) async {
    final conn = await _conn;
    final id = vendorRow['id'];

    await conn.query(
      '''UPDATE vendors
         SET vendor_name = ?, legal_standing = ?, npwp = ?, is_verified = ?,
             terms_of_payment = ?, scope_of_work = ?, sub_sow = ?,
             supply_chain_classification = ?, internal_note = ?,
             vendor_address = ?, pic_website = ?, bank_name = ?,
             bank_account_number = ?, bank_account_holder = ?,
             bank_currency = ?, bank_swift_code = ?, status = ?
         WHERE id = ?''',
      [
        vendorRow['vendor_name'],
        vendorRow['legal_standing'],
        vendorRow['npwp'],
        vendorRow['is_verified'],
        vendorRow['terms_of_payment'],
        vendorRow['scope_of_work'],
        vendorRow['sub_sow'],
        vendorRow['supply_chain_classification'],
        vendorRow['internal_note'],
        vendorRow['vendor_address'],
        vendorRow['pic_website'],
        vendorRow['bank_name'],
        vendorRow['bank_account_number'],
        vendorRow['bank_account_holder'],
        vendorRow['bank_currency'],
        vendorRow['bank_swift_code'],
        vendorRow['status'],
        id,
      ],
    );

    await conn.query('DELETE FROM vendor_contacts WHERE vendor_id = ?', [id]);
    for (final c in contacts) {
      await conn.query(
        '''INSERT INTO vendor_contacts (vendor_id, pic_name, pic_position, pic_contact, pic_email)
           VALUES (?, ?, ?, ?, ?)''',
        [id, c['pic_name'], c['pic_position'], c['pic_contact'], c['pic_email']],
      );
    }

    await conn.query('DELETE FROM vendor_products WHERE vendor_id = ?', [id]);
    for (final p in products) {
      await conn.query(
        'INSERT INTO vendor_products (vendor_id, product_name) VALUES (?, ?)',
        [id, p['product_name']],
      );
    }
  }

  Future<void> deleteVendor(int id) async {
    final conn = await _conn;
    await conn.query('DELETE FROM vendors WHERE id = ?', [id]);
  }

  /// Hapus banyak vendor sekaligus (fitur select multi di layar list).
  /// `vendor_contacts` & `vendor_products` ikut kehapus otomatis lewat
  /// FK `ON DELETE CASCADE` (lihat sql/03_create_vendor_tables.sql).
  Future<void> deleteVendors(List<int> ids) async {
    if (ids.isEmpty) return;
    final conn = await _conn;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await conn.query('DELETE FROM vendors WHERE id IN ($placeholders)', ids);
  }
}