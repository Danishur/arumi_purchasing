import 'package:mysql1/mysql1.dart';
import 'dart:convert';
import 'dart:math';
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

    await _log('create', 'Customer', _s(customerRow['name']));
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
    await _log('update', 'Customer', _s(customerRow['name']));

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
    final labels = await _labelsOf('customers', "customer_name", [id]);
    await conn.query('DELETE FROM customers WHERE id = ?', [id]);
    await _logDeletes('Customer', labels);
  }

  /// Hapus banyak customer sekaligus (dipakai fitur select multi di
  /// layar list). `customer_contacts` ikut kehapus otomatis lewat FK
  /// `ON DELETE CASCADE` (lihat sql/01_create_database.sql).
  Future<void> deleteCustomers(List<int> ids) async {
    if (ids.isEmpty) return;
    final conn = await _conn;
    final placeholders = List.filled(ids.length, '?').join(', ');
    final labels = await _labelsOf('customers', "customer_name", ids);
    await conn.query('DELETE FROM customers WHERE id IN ($placeholders)', ids);
    await _logDeletes('Customer', labels);
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

    await _log('create', 'Vendor', _s(vendorRow['vendor_name']));
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
    await _log('update', 'Vendor', _s(vendorRow['vendor_name']));

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
    final labels = await _labelsOf('vendors', "vendor_name", [id]);
    await conn.query('DELETE FROM vendors WHERE id = ?', [id]);
    await _logDeletes('Vendor', labels);
  }

  /// Hapus banyak vendor sekaligus (fitur select multi di layar list).
  /// `vendor_contacts` & `vendor_products` ikut kehapus otomatis lewat
  /// FK `ON DELETE CASCADE` (lihat sql/03_create_vendor_tables.sql).
  Future<void> deleteVendors(List<int> ids) async {
    if (ids.isEmpty) return;
    final conn = await _conn;
    final placeholders = List.filled(ids.length, '?').join(', ');
    final labels = await _labelsOf('vendors', "vendor_name", ids);
    await conn.query('DELETE FROM vendors WHERE id IN ($placeholders)', ids);
    await _logDeletes('Vendor', labels);
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

    await _log('create', 'Material', _s(materialRow['item_description']));
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
    await _log('update', 'Material', _s(materialRow['item_description']));

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
    final labels = await _labelsOf('materials', "item_description", [id]);
    await conn.query('DELETE FROM materials WHERE id = ?', [id]);
    await _logDeletes('Material', labels);
  }

  /// Hapus banyak material sekaligus (fitur select multi di layar list).
  /// `material_discounts` ikut kehapus otomatis lewat FK `ON DELETE
  /// CASCADE` (lihat sql/04_create_material_tables.sql).
  Future<void> deleteMaterials(List<int> ids) async {
    if (ids.isEmpty) return;
    final conn = await _conn;
    final placeholders = List.filled(ids.length, '?').join(', ');
    final labels = await _labelsOf('materials', "item_description", ids);
    await conn.query('DELETE FROM materials WHERE id IN ($placeholders)', ids);
    await _logDeletes('Material', labels);
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
  /// TAMBAHAN: ikut ambil field tambahan dari `materials`/`vendors`
  /// (terms_of_payment, vat, delivery_terms, weight, dimensi, documents)
  /// buat format baru "Export Excel Satuan" di rfq_excel_exporter.dart.
  Future<List<Map<String, dynamic>>> getRfqMaterialsByRfqId(int rfqId) async {
    final conn = await _conn;
    final results = await conn.query('''
      SELECT rm.*,
             m.item_description AS item_description,
             m.total_price AS material_total_price,
             m.vat AS material_vat,
             m.delivery_terms AS delivery_terms,
             m.weight AS weight,
             m.weight_unit AS weight_unit,
             m.dim_p AS dim_p,
             m.dim_l AS dim_l,
             m.dim_t AS dim_t,
             m.dim_unit AS dim_unit,
             m.documents AS documents,
             v.id AS vendor_id,
             v.vendor_name AS vendor_name,
             v.terms_of_payment AS terms_of_payment
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

    await _log('create', 'RFQ', _s(rfqRow['reference']).isEmpty ? 'RFQ #$rfqId' : _s(rfqRow['reference']));
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
    await _log('update', 'RFQ', _s(rfqRow['reference']).isEmpty ? 'RFQ #$id' : _s(rfqRow['reference']));

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
    final labels = await _labelsOf('rfqs', "COALESCE(NULLIF(reference, ''), CONCAT('RFQ #', id))", [id]);
    await conn.query('DELETE FROM rfqs WHERE id = ?', [id]);
    await _logDeletes('RFQ', labels);
  }

  /// Hapus banyak RFQ sekaligus (fitur select multi di layar list).
  /// `rfq_materials` ikut kehapus otomatis lewat FK `ON DELETE CASCADE`
  /// (lihat sql/05_alter_materials_and_create_rfq_tables.sql).
  Future<void> deleteRfqs(List<int> ids) async {
    if (ids.isEmpty) return;
    final conn = await _conn;
    final placeholders = List.filled(ids.length, '?').join(', ');
    final labels = await _labelsOf('rfqs', "COALESCE(NULLIF(reference, ''), CONCAT('RFQ #', id))", ids);
    await conn.query('DELETE FROM rfqs WHERE id IN ($placeholders)', ids);
    await _logDeletes('RFQ', labels);
  }

  // ==================== CURRENCY (Settings > Update Valuta) ====================

  Future<List<Map<String, dynamic>>> getCurrencyRates() async {
    final conn = await _conn;
    final results = await conn.query('SELECT * FROM currency_rates ORDER BY currency_code ASC');
    return results.map((row) => _convertRow(row.fields)).toList();
  }

  Future<int> insertCurrencyRate(String currencyCode, double rateToIdr) async {
    final conn = await _conn;
    // TAMBAHAN: isi `updated_at` eksplisit dengan NOW() tiap kali
    // tambah/edit currency, supaya "tanggal update kurs" selalu akurat
    // walau kolomnya tidak di-set ON UPDATE CURRENT_TIMESTAMP di DB.
    final result = await conn.query(
      'INSERT INTO currency_rates (currency_code, rate_to_idr, updated_at) VALUES (?, ?, NOW())',
      [currencyCode, rateToIdr],
    );
    await _log('create', 'Valuta', '$currencyCode = $rateToIdr');
    return result.insertId!;
  }

  Future<void> updateCurrencyRate(int id, double rateToIdr) async {
    final conn = await _conn;
    await conn.query(
      'UPDATE currency_rates SET rate_to_idr = ?, updated_at = NOW() WHERE id = ?',
      [rateToIdr, id],
    );
    final l = await _labelsOf('currency_rates', 'currency_code', [id]);
    await _log('update', 'Valuta', '${l.isEmpty ? id : l.first} = $rateToIdr');
  }

  Future<void> deleteCurrencyRate(int id) async {
    final conn = await _conn;
    final labels = await _labelsOf('currency_rates', 'currency_code', [id]);
    await conn.query('DELETE FROM currency_rates WHERE id = ?', [id]);
    await _logDeletes('Valuta', labels);
  }

  // ==================== BULK (Global Search & Export Excel Penuh) ====================
  //
  // Ambil SEMUA baris dari tabel relasi sekaligus (1 query per tabel,
  // bukan 1 query per record) supaya Global Search & Export Excel bisa
  // mencakup seluruh data PIC/Produk/Bank/Diskon/Material RFQ tanpa
  // bikin layar list lambat. `SELECT *` -> kolom apa pun yang ada di
  // tabel ikut terbawa.

  static const _bulkChildTables = {
    'customer_contacts',
    'vendor_contacts',
    'vendor_products',
    'vendor_bank_accounts',
    'material_discounts',
  };

  Future<List<Map<String, dynamic>>> getAllChildRows(String table) async {
    if (!_bulkChildTables.contains(table)) {
      throw ArgumentError('Tabel tidak diizinkan: $table');
    }
    final conn = await _conn;
    final results = await conn.query('SELECT * FROM $table ORDER BY id ASC');
    return results.map((row) => _convertRow(row.fields)).toList();
  }

  /// Semua baris rfq_materials (semua RFQ) lengkap dengan JOIN yang sama
  /// seperti [getRfqMaterialsByRfqId].
  Future<List<Map<String, dynamic>>> getAllRfqMaterialLines() async {
    final conn = await _conn;
    final results = await conn.query('''
      SELECT rm.*,
             m.item_description AS item_description,
             m.total_price AS material_total_price,
             m.vat AS material_vat,
             m.delivery_terms AS delivery_terms,
             m.weight AS weight,
             m.weight_unit AS weight_unit,
             m.dim_p AS dim_p,
             m.dim_l AS dim_l,
             m.dim_t AS dim_t,
             m.dim_unit AS dim_unit,
             m.documents AS documents,
             v.id AS vendor_id,
             v.vendor_name AS vendor_name,
             v.terms_of_payment AS terms_of_payment
      FROM rfq_materials rm
      LEFT JOIN materials m ON m.id = rm.material_id
      LEFT JOIN vendors v ON v.id = m.vendor_id
      ORDER BY rm.id ASC
    ''');
    return results.map((row) => _convertRow(row.fields)).toList();
  }

  // ==================== DROPDOWN OPTIONS (Settings > Edit Dropdown) ====================
  //
  // TAMBAHAN: dulu isi semua dropdown (Terms of Payment, Legal Standing,
  // Scope of Work, dst) di-hardcode di CustomerOptions/VendorOptions/
  // MaterialOptions/RfqOptions (lihat folder lib/utils/). Sekarang
  // dipindah ke tabel `dropdown_options` supaya bisa diedit sendiri oleh
  // user lewat Settings > Edit Dropdown tanpa update aplikasi. Table
  // belum otomatis dibuat migration-nya di sini (project ini tidak
  // pakai migration runner) -- SQL CREATE TABLE-nya ada di catatan yang
  // dikirim terpisah, harus dijalankan sekali manual lewat phpMyAdmin.
  //
  // `category` = kunci dropdown mana (mis. `vendor_legal_standing`),
  // `value` = 1 baris pilihan dalam kategori itu.

  Future<List<Map<String, dynamic>>> getAllDropdownOptions() async {
    final conn = await _conn;
    final results = await conn.query(
      'SELECT * FROM dropdown_options ORDER BY category ASC, id ASC',
    );
    return results.map((row) => _convertRow(row.fields)).toList();
  }

  Future<List<Map<String, dynamic>>> getDropdownOptionsByCategory(String category) async {
    final conn = await _conn;
    final results = await conn.query(
      'SELECT * FROM dropdown_options WHERE category = ? ORDER BY id ASC',
      [category],
    );
    return results.map((row) => _convertRow(row.fields)).toList();
  }

  Future<int> insertDropdownOption(String category, String value) async {
    final conn = await _conn;
    final result = await conn.query(
      'INSERT INTO dropdown_options (category, value) VALUES (?, ?)',
      [category, value],
    );
    await _log('create', 'Dropdown', '$category: $value');
    return result.insertId!;
  }

  Future<void> updateDropdownOption(int id, String value) async {
    final conn = await _conn;
    await conn.query('UPDATE dropdown_options SET value = ? WHERE id = ?', [value, id]);
    await _log('update', 'Dropdown', value);
  }

  Future<void> deleteDropdownOption(int id) async {
    final conn = await _conn;
    final labels = await _labelsOf('dropdown_options', "CONCAT(category, ': ', value)", [id]);
    await conn.query('DELETE FROM dropdown_options WHERE id = ?', [id]);
    await _logDeletes('Dropdown', labels);
  }

  // ==================== USER LOGIN & APPROVAL + RIWAYAT AKTIVITAS ====================
  //
  // Dibuat otomatis oleh [ensureAuthTables] waktu app dibuka (tidak perlu
  // menjalankan SQL manual; file sql/06_create_auth_tables.sql hanya
  // cadangan kalau user MySQL tidak punya izin CREATE TABLE).

  /// User yang sedang login -- diisi AuthProvider. Dipakai [_log] untuk
  /// mencatat SIAPA yang menambah / mengubah / menghapus data.
  static int? actorId;
  static String actorName = '';

  /// Akun owner bawaan (dibuat sekali kalau belum ada owner di tabel).
  /// SEGERA diganti lewat Settings > Management User > Change Password.
  static const String defaultOwnerEmail = 'owner@arumi.co.id';
  static const String defaultOwnerPassword = 'Owner123!';

  /// Riwayat aktivitas otomatis dihapus kalau umurnya lebih dari ini.
  static const int historyRetentionMonths = 5;

  static String _newSalt() {
    final rnd = Random.secure();
    return List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static String _s(dynamic v) => (v ?? '').toString();

  Future<void> ensureAuthTables() async {
    final conn = await _conn;
    await conn.query('''
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
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ''');
    await conn.query('''
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
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ''');

    final owners = await conn.query("SELECT id FROM app_users WHERE role = 'owner' LIMIT 1");
    if (owners.isEmpty) {
      final salt = _newSalt();
      await conn.query(
        '''INSERT INTO app_users
           (name, position, id_number, email, password_salt, password_hash, role, status, approved_at)
           VALUES (?, ?, ?, ?, ?, SHA2(CONCAT(?, ?), 256), 'owner', 'active', NOW())''',
        ['Owner', 'Owner', '-', defaultOwnerEmail, salt, salt, defaultOwnerPassword],
      );
    }
    await purgeOldLogs();
  }

  /// Hapus riwayat yang sudah lewat [historyRetentionMonths] bulan.
  Future<void> purgeOldLogs() async {
    final conn = await _conn;
    await conn.query(
      'DELETE FROM activity_logs WHERE created_at < DATE_SUB(NOW(), INTERVAL ? MONTH)',
      [historyRetentionMonths],
    );
  }

  /// Catat 1 aktivitas. Tidak pernah melempar error (pencatatan gagal
  /// tidak boleh menggagalkan simpan data) dan dilewati kalau belum ada
  /// user yang login.
  Future<void> _log(String action, String module, String label, {String? detail}) async {
    if (actorId == null) return;
    try {
      final conn = await _conn;
      await conn.query(
        '''INSERT INTO activity_logs (user_id, user_name, action, module, record_label, detail)
           VALUES (?, ?, ?, ?, ?, ?)''',
        [actorId, actorName, action, module, label, detail],
      );
    } catch (_) {}
  }

  Future<List<String>> _labelsOf(String table, String expr, List<int> ids) async {
    if (ids.isEmpty) return [];
    final conn = await _conn;
    final ph = List.filled(ids.length, '?').join(', ');
    final r = await conn.query('SELECT $expr AS label FROM $table WHERE id IN ($ph)', ids);
    return r.map((row) => _s(_convertRow(row.fields)['label'])).toList();
  }

  Future<void> _logDeletes(String module, List<String> labels) async {
    for (final l in labels) {
      await _log('delete', module, l);
    }
  }

  /// Daftar akun baru (status pending).
  Future<void> registerUser({
    required String name,
    required String position,
    required String idNumber,
    required String email,
    required String password,
  }) async {
    final conn = await _conn;
    final salt = _newSalt();
    final existing = await conn.query('SELECT id, status FROM app_users WHERE LOWER(email) = LOWER(?)', [email]);
    if (existing.isNotEmpty) {
      final row = _convertRow(existing.first.fields);
      if (_s(row['status']) != 'rejected') {
        throw AuthException('Email ini sudah terdaftar.');
      }
      await conn.query(
        '''UPDATE app_users SET name = ?, position = ?, id_number = ?, password_salt = ?,
           password_hash = SHA2(CONCAT(?, ?), 256), status = 'pending', created_at = NOW()
           WHERE id = ?''',
        [name, position, idNumber, salt, salt, password, row['id']],
      );
      return;
    }
    await conn.query(
      '''INSERT INTO app_users (name, position, id_number, email, password_salt, password_hash, role, status)
         VALUES (?, ?, ?, ?, ?, SHA2(CONCAT(?, ?), 256), 'user', 'pending')''',
      [name, position, idNumber, email, salt, salt, password],
    );
  }

  /// Cek login. Mengembalikan data user, atau melempar [AuthException]
  /// dengan pesan yang siap ditampilkan.
  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    final conn = await _conn;
    final found = await conn.query(
      '''SELECT id, name, position, id_number, email, role, status,
                (password_hash = SHA2(CONCAT(password_salt, ?), 256)) AS ok
         FROM app_users WHERE LOWER(email) = LOWER(?) LIMIT 1''',
      [password, email],
    );
    if (found.isEmpty) throw AuthException('User / email atau password salah.');
    final row = _convertRow(found.first.fields);
    final ok = row['ok'];
    if (!(ok == 1 || ok == true)) throw AuthException('User / email atau password salah.');
    final status = _s(row['status']);
    if (status == 'pending') {
      throw AuthException('Akun kamu masih menunggu persetujuan owner.');
    }
    if (status == 'rejected') {
      throw AuthException('Pendaftaran akun kamu ditolak owner.');
    }
    row.remove('ok');
    return row;
  }

  Future<List<Map<String, dynamic>>> getActiveUsers() async {
    final conn = await _conn;
    final r = await conn.query(
      "SELECT id, name, position, email, role, status FROM app_users WHERE status = 'active' ORDER BY id ASC",
    );
    return r.map((row) => _convertRow(row.fields)).toList();
  }

  /// Akun baru yang belum disetujui + permintaan reset password.
  /// Kolom `request_type`: 'register' atau 'reset'.
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final conn = await _conn;
    final r = await conn.query('''
      SELECT id, name, position, email,
             IF(status = 'pending', 'register', 'reset') AS request_type
      FROM app_users
      WHERE status = 'pending' OR pending_hash IS NOT NULL
      ORDER BY id ASC
    ''');
    return r.map((row) => _convertRow(row.fields)).toList();
  }

  Future<void> approveUser(int id) async {
    final conn = await _conn;
    final label = await _labelsOf('app_users', 'email', [id]);
    await conn.query("UPDATE app_users SET status = 'active', approved_at = NOW() WHERE id = ?", [id]);
    await _log('update', 'User', label.isEmpty ? '#$id' : label.first, detail: 'Akun disetujui');
  }

  Future<void> rejectUser(int id) async {
    final conn = await _conn;
    final label = await _labelsOf('app_users', 'email', [id]);
    await conn.query("UPDATE app_users SET status = 'rejected' WHERE id = ?", [id]);
    await _log('update', 'User', label.isEmpty ? '#$id' : label.first, detail: 'Akun ditolak');
  }

  /// Permintaan ganti password dari layar "Lupa password" -- baru
  /// berlaku setelah owner menyetujui (lihat [approveReset]).
  Future<void> requestPasswordReset(String email, String newPassword) async {
    final conn = await _conn;
    final r = await conn.query(
      "SELECT id FROM app_users WHERE LOWER(email) = LOWER(?) AND status = 'active'",
      [email],
    );
    if (r.isEmpty) throw AuthException('Email tidak ditemukan atau akun belum aktif.');
    final salt = _newSalt();
    await conn.query(
      'UPDATE app_users SET pending_salt = ?, pending_hash = SHA2(CONCAT(?, ?), 256) WHERE LOWER(email) = LOWER(?)',
      [salt, salt, newPassword, email],
    );
  }

  Future<void> approveReset(int id) async {
    final conn = await _conn;
    final label = await _labelsOf('app_users', 'email', [id]);
    await conn.query(
      '''UPDATE app_users SET password_salt = pending_salt, password_hash = pending_hash,
         pending_salt = NULL, pending_hash = NULL WHERE id = ? AND pending_hash IS NOT NULL''',
      [id],
    );
    await _log('update', 'User', label.isEmpty ? '#$id' : label.first, detail: 'Reset password disetujui');
  }

  Future<void> rejectReset(int id) async {
    final conn = await _conn;
    final label = await _labelsOf('app_users', 'email', [id]);
    await conn.query('UPDATE app_users SET pending_salt = NULL, pending_hash = NULL WHERE id = ?', [id]);
    await _log('update', 'User', label.isEmpty ? '#$id' : label.first, detail: 'Reset password ditolak');
  }

  /// Owner mengganti password user langsung (Management User > Change
  /// Password).
  Future<void> setUserPassword(String email, String newPassword) async {
    final conn = await _conn;
    final r = await conn.query('SELECT id FROM app_users WHERE LOWER(email) = LOWER(?)', [email]);
    if (r.isEmpty) throw AuthException('User / email tidak ditemukan.');
    final salt = _newSalt();
    await conn.query(
      '''UPDATE app_users SET password_salt = ?, password_hash = SHA2(CONCAT(?, ?), 256),
         pending_salt = NULL, pending_hash = NULL WHERE LOWER(email) = LOWER(?)''',
      [salt, salt, newPassword, email],
    );
    await _log('update', 'User', email, detail: 'Password diganti owner');
  }

  /// Riwayat aktivitas terbaru. [module] null = semua modul.
  Future<List<Map<String, dynamic>>> getActivityLogs({String? module, String? search, int limit = 500}) async {
    final conn = await _conn;
    final where = <String>[];
    final params = <Object?>[];
    if (module != null && module.isNotEmpty) {
      where.add('module = ?');
      params.add(module);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add('(user_name LIKE ? OR record_label LIKE ? OR detail LIKE ?)');
      final like = '%${search.trim()}%';
      params.addAll([like, like, like]);
    }
    final sql = 'SELECT * FROM activity_logs ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
        'ORDER BY id DESC LIMIT $limit';
    final r = await conn.query(sql, params);
    return r.map((row) => _convertRow(row.fields)).toList();
  }
}

/// Error login / register / approval dengan pesan siap tampil ke user.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
