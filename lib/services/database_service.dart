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

  /// REVISI: Bank Information sekarang bisa lebih dari 1 per vendor,
  /// disimpan di tabel `vendor_bank_accounts` terpisah (pola sama
  /// dengan PIC/Produk).
  Future<List<Map<String, dynamic>>> getBankAccountsByVendorId(int vendorId) async {
    final conn = await _conn;
    final results = await conn.query(
      'SELECT * FROM vendor_bank_accounts WHERE vendor_id = ? ORDER BY id ASC',
      [vendorId],
    );
    return results.map((row) => _convertRow(row.fields)).toList();
  }

  /// Insert vendor baru + semua PIC, Produk/Brand, dan Bank Information
  /// (bisa lebih dari 1) sekaligus. Mengembalikan id vendor yang baru
  /// dibuat.
  Future<int> insertVendor(
    Map<String, dynamic> vendorRow,
    List<Map<String, dynamic>> contacts,
    List<Map<String, dynamic>> products,
    List<Map<String, dynamic>> bankAccounts,
  ) async {
    final conn = await _conn;
    final result = await conn.query(
      '''INSERT INTO vendors
         (vendor_name, legal_standing, npwp, is_verified, terms_of_payment,
          scope_of_work, sub_sow, supply_chain_classification, internal_note,
          vendor_address, pic_website, status)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
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

    for (final b in bankAccounts) {
      await conn.query(
        '''INSERT INTO vendor_bank_accounts
           (vendor_id, bank_name, account_number, account_holder, currency, swift_code)
           VALUES (?, ?, ?, ?, ?, ?)''',
        [
          vendorId,
          b['bank_name'],
          b['account_number'],
          b['account_holder'],
          b['currency'],
          b['swift_code'],
        ],
      );
    }

    return vendorId;
  }

  /// Update data vendor + ganti seluruh daftar PIC, Produk/Brand, dan
  /// Bank Information-nya (hapus yang lama, masukkan ulang yang baru)
  /// -- pola sama dengan updateCustomer.
  Future<void> updateVendor(
    Map<String, dynamic> vendorRow,
    List<Map<String, dynamic>> contacts,
    List<Map<String, dynamic>> products,
    List<Map<String, dynamic>> bankAccounts,
  ) async {
    final conn = await _conn;
    final id = vendorRow['id'];

    await conn.query(
      '''UPDATE vendors
         SET vendor_name = ?, legal_standing = ?, npwp = ?, is_verified = ?,
             terms_of_payment = ?, scope_of_work = ?, sub_sow = ?,
             supply_chain_classification = ?, internal_note = ?,
             vendor_address = ?, pic_website = ?, status = ?
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

    await conn.query('DELETE FROM vendor_bank_accounts WHERE vendor_id = ?', [id]);
    for (final b in bankAccounts) {
      await conn.query(
        '''INSERT INTO vendor_bank_accounts
           (vendor_id, bank_name, account_number, account_holder, currency, swift_code)
           VALUES (?, ?, ?, ?, ?, ?)''',
        [
          id,
          b['bank_name'],
          b['account_number'],
          b['account_holder'],
          b['currency'],
          b['swift_code'],
        ],
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

  // ==================== MATERIAL ====================

  /// LEFT JOIN ke `vendors` supaya `vendor_name` ikut kebawa buat
  /// ditampilkan di list/detail, tanpa perlu query terpisah lagi ke
  /// tabel vendors untuk tiap baris material.
  Future<List<Map<String, dynamic>>> getMaterials() async {
    final conn = await _conn;
    final results = await conn.query('''
      SELECT m.*, v.vendor_name AS vendor_name
      FROM materials m
      LEFT JOIN vendors v ON v.id = m.vendor_id
      ORDER BY m.id DESC
    ''');
    return results.map((row) => _convertRow(row.fields)).toList();
  }

  Future<List<Map<String, dynamic>>> getDiscountsByMaterialId(int materialId) async {
    final conn = await _conn;
    final results = await conn.query(
      'SELECT * FROM material_discounts WHERE material_id = ? ORDER BY id ASC',
      [materialId],
    );
    return results.map((row) => _convertRow(row.fields)).toList();
  }

  /// Insert material baru + semua baris diskonnya sekaligus.
  /// Mengembalikan id material yang baru dibuat.
  Future<int> insertMaterial(
    Map<String, dynamic> materialRow,
    List<Map<String, dynamic>> discounts,
  ) async {
    final conn = await _conn;
    final result = await conn.query(
      '''INSERT INTO materials
         (vendor_id, scope_of_work, sub_sow, brand_unit_installed_on,
          type_unit_installed_on, item_description, category, item_manufacturer,
          origin_country, item_type, item_part_number, size, photo_path,
          reference_genuine_part_number, existing_item_description,
          price_quote, price_quote_currency, price_quote_foreign_amount,
          price_quote_date, total_discount, price_discount, total_price,
          vat, dpp, vat_value, lead_time_days, delivery_terms, delivery_address,
          dim_p, dim_l, dim_t, dim_unit, weight, weight_unit, documents,
          is_transaction, status)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                 ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        materialRow['vendor_id'],
        materialRow['scope_of_work'],
        materialRow['sub_sow'],
        materialRow['brand_unit_installed_on'],
        materialRow['type_unit_installed_on'],
        materialRow['item_description'],
        materialRow['category'],
        materialRow['item_manufacturer'],
        materialRow['origin_country'],
        materialRow['item_type'],
        materialRow['item_part_number'],
        materialRow['size'],
        materialRow['photo_path'],
        materialRow['reference_genuine_part_number'],
        materialRow['existing_item_description'],
        materialRow['price_quote'],
        materialRow['price_quote_currency'],
        materialRow['price_quote_foreign_amount'],
        materialRow['price_quote_date'],
        materialRow['total_discount'],
        materialRow['price_discount'],
        materialRow['total_price'],
        materialRow['vat'],
        materialRow['dpp'],
        materialRow['vat_value'],
        materialRow['lead_time_days'],
        materialRow['delivery_terms'],
        materialRow['delivery_address'],
        materialRow['dim_p'],
        materialRow['dim_l'],
        materialRow['dim_t'],
        materialRow['dim_unit'],
        materialRow['weight'],
        materialRow['weight_unit'],
        materialRow['documents'],
        materialRow['is_transaction'],
        materialRow['status'],
      ],
    );
    final materialId = result.insertId!;

    for (final d in discounts) {
      await conn.query(
        'INSERT INTO material_discounts (material_id, discount_amount, discount_date) VALUES (?, ?, ?)',
        [materialId, d['discount_amount'], d['discount_date']],
      );
    }

    return materialId;
  }

  /// Update data material + ganti seluruh daftar diskonnya (hapus yang
  /// lama, masukkan ulang yang baru) -- pola sama dengan updateVendor.
  Future<void> updateMaterial(
    Map<String, dynamic> materialRow,
    List<Map<String, dynamic>> discounts,
  ) async {
    final conn = await _conn;
    final id = materialRow['id'];

    await conn.query(
      '''UPDATE materials
         SET vendor_id = ?, scope_of_work = ?, sub_sow = ?, brand_unit_installed_on = ?,
             type_unit_installed_on = ?, item_description = ?, category = ?,
             item_manufacturer = ?, origin_country = ?, item_type = ?, item_part_number = ?,
             size = ?, photo_path = ?, reference_genuine_part_number = ?,
             existing_item_description = ?, price_quote = ?, price_quote_currency = ?,
             price_quote_foreign_amount = ?,
             price_quote_date = ?, total_discount = ?, price_discount = ?, total_price = ?,
             vat = ?, dpp = ?, vat_value = ?, lead_time_days = ?, delivery_terms = ?,
             delivery_address = ?, dim_p = ?, dim_l = ?, dim_t = ?, dim_unit = ?,
             weight = ?, weight_unit = ?, documents = ?, is_transaction = ?, status = ?
         WHERE id = ?''',
      [
        materialRow['vendor_id'],
        materialRow['scope_of_work'],
        materialRow['sub_sow'],
        materialRow['brand_unit_installed_on'],
        materialRow['type_unit_installed_on'],
        materialRow['item_description'],
        materialRow['category'],
        materialRow['item_manufacturer'],
        materialRow['origin_country'],
        materialRow['item_type'],
        materialRow['item_part_number'],
        materialRow['size'],
        materialRow['photo_path'],
        materialRow['reference_genuine_part_number'],
        materialRow['existing_item_description'],
        materialRow['price_quote'],
        materialRow['price_quote_currency'],
        materialRow['price_quote_foreign_amount'],
        materialRow['price_quote_date'],
        materialRow['total_discount'],
        materialRow['price_discount'],
        materialRow['total_price'],
        materialRow['vat'],
        materialRow['dpp'],
        materialRow['vat_value'],
        materialRow['lead_time_days'],
        materialRow['delivery_terms'],
        materialRow['delivery_address'],
        materialRow['dim_p'],
        materialRow['dim_l'],
        materialRow['dim_t'],
        materialRow['dim_unit'],
        materialRow['weight'],
        materialRow['weight_unit'],
        materialRow['documents'],
        materialRow['is_transaction'],
        materialRow['status'],
        id,
      ],
    );

    await conn.query('DELETE FROM material_discounts WHERE material_id = ?', [id]);
    for (final d in discounts) {
      await conn.query(
        'INSERT INTO material_discounts (material_id, discount_amount, discount_date) VALUES (?, ?, ?)',
        [id, d['discount_amount'], d['discount_date']],
      );
    }
  }

  Future<void> deleteMaterial(int id) async {
    final conn = await _conn;
    await conn.query('DELETE FROM materials WHERE id = ?', [id]);
  }

  /// Hapus banyak material sekaligus (fitur select multi di layar list).
  /// `material_discounts` ikut kehapus otomatis lewat FK `ON DELETE
  /// CASCADE` (lihat sql/04_create_material_tables.sql).
  Future<void> deleteMaterials(List<int> ids) async {
    if (ids.isEmpty) return;
    final conn = await _conn;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await conn.query('DELETE FROM materials WHERE id IN ($placeholders)', ids);
  }

  // ==================== RFQ ====================

  /// LEFT JOIN ke `customers` supaya `customer_name` ikut kebawa buat
  /// ditampilkan di list/detail, tanpa perlu query terpisah lagi.
  Future<List<Map<String, dynamic>>> getRfqs() async {
    final conn = await _conn;
    final results = await conn.query('''
      SELECT r.*, c.customer_name AS customer_name
      FROM rfqs r
      LEFT JOIN customers c ON c.id = r.customer_id
      ORDER BY r.id DESC
    ''');
    return results.map((row) => _convertRow(row.fields)).toList();
  }

  /// JOIN ke `materials` (buat `item_description` & harga) dan ke
  /// `vendors` (buat nama supplier) sekaligus -- dipakai buat tampilan
  /// Material List DAN buat Export Excel (kolom Harga Satuan, Toko/
  /// Supplier, Subtotal).
  Future<List<Map<String, dynamic>>> getRfqMaterialsByRfqId(int rfqId) async {
    final conn = await _conn;
    final results = await conn.query('''
      SELECT rm.*,
             m.item_description AS item_description,
             m.total_price AS material_total_price,
             v.vendor_name AS vendor_name
      FROM rfq_materials rm
      LEFT JOIN materials m ON m.id = rm.material_id
      LEFT JOIN vendors v ON v.id = m.vendor_id
      WHERE rm.rfq_id = ?
      ORDER BY rm.id ASC
    ''', [rfqId]);
    return results.map((row) => _convertRow(row.fields)).toList();
  }

  /// Insert RFQ baru + semua baris Material List-nya (dengan Quantity &
  /// Unit masing-masing) sekaligus. Mengembalikan id RFQ yang baru dibuat.
  Future<int> insertRfq(
    Map<String, dynamic> rfqRow,
    List<Map<String, dynamic>> materialLines,
  ) async {
    final conn = await _conn;
    final result = await conn.query(
      '''INSERT INTO rfqs
         (reference, pic, date_request, due_date, customer_id, internal_note,
          document_requirement, status)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        rfqRow['reference'],
        rfqRow['pic'],
        rfqRow['date_request'],
        rfqRow['due_date'],
        rfqRow['customer_id'],
        rfqRow['internal_note'],
        rfqRow['document_requirement'],
        rfqRow['status'],
      ],
    );
    final rfqId = result.insertId!;

    for (final line in materialLines) {
      await conn.query(
        'INSERT INTO rfq_materials (rfq_id, material_id, quantity, unit) VALUES (?, ?, ?, ?)',
        [rfqId, line['material_id'], line['quantity'], line['unit']],
      );
    }

    return rfqId;
  }

  /// Update data RFQ + ganti seluruh Material List-nya (hapus yang
  /// lama, masukkan ulang yang baru) -- pola sama dengan updateMaterial.
  Future<void> updateRfq(
    Map<String, dynamic> rfqRow,
    List<Map<String, dynamic>> materialLines,
  ) async {
    final conn = await _conn;
    final id = rfqRow['id'];

    await conn.query(
      '''UPDATE rfqs
         SET reference = ?, pic = ?, date_request = ?, due_date = ?,
             customer_id = ?, internal_note = ?, document_requirement = ?, status = ?
         WHERE id = ?''',
      [
        rfqRow['reference'],
        rfqRow['pic'],
        rfqRow['date_request'],
        rfqRow['due_date'],
        rfqRow['customer_id'],
        rfqRow['internal_note'],
        rfqRow['document_requirement'],
        rfqRow['status'],
        id,
      ],
    );

    await conn.query('DELETE FROM rfq_materials WHERE rfq_id = ?', [id]);
    for (final line in materialLines) {
      await conn.query(
        'INSERT INTO rfq_materials (rfq_id, material_id, quantity, unit) VALUES (?, ?, ?, ?)',
        [id, line['material_id'], line['quantity'], line['unit']],
      );
    }
  }

  Future<void> deleteRfq(int id) async {
    final conn = await _conn;
    await conn.query('DELETE FROM rfqs WHERE id = ?', [id]);
  }

  /// Hapus banyak RFQ sekaligus (fitur select multi di layar list).
  /// `rfq_materials` ikut kehapus otomatis lewat FK `ON DELETE CASCADE`
  /// (lihat sql/05_alter_materials_and_create_rfq_tables.sql).
  Future<void> deleteRfqs(List<int> ids) async {
    if (ids.isEmpty) return;
    final conn = await _conn;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await conn.query('DELETE FROM rfqs WHERE id IN ($placeholders)', ids);
  }

  // ==================== CURRENCY (Settings > Update Valuta) ====================

  Future<List<Map<String, dynamic>>> getCurrencyRates() async {
    final conn = await _conn;
    final results = await conn.query('SELECT * FROM currency_rates ORDER BY currency_code ASC');
    return results.map((row) => _convertRow(row.fields)).toList();
  }

  Future<int> insertCurrencyRate(String currencyCode, double rateToIdr) async {
    final conn = await _conn;
    final result = await conn.query(
      'INSERT INTO currency_rates (currency_code, rate_to_idr) VALUES (?, ?)',
      [currencyCode, rateToIdr],
    );
    return result.insertId!;
  }

  Future<void> updateCurrencyRate(int id, double rateToIdr) async {
    final conn = await _conn;
    await conn.query('UPDATE currency_rates SET rate_to_idr = ? WHERE id = ?', [rateToIdr, id]);
  }

  Future<void> deleteCurrencyRate(int id) async {
    final conn = await _conn;
    await conn.query('DELETE FROM currency_rates WHERE id = ?', [id]);
  }
}