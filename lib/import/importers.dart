import '../services/database_service.dart';
import '../utils/dropdown_options_cache.dart';
import '../utils/material_options.dart';
import '../utils/rfq_options.dart';
import 'import_types.dart';

/// Analisis (validasi + pengelompokan baris) dan simpan data import.
/// Semua simpan lewat method insertXxx yang sama dengan form manual,
/// jadi hasilnya identik dengan input lewat aplikasi.
class Importers {
  // ───────────────────────── Helper umum ─────────────────────────

  static String _s(Map<String, String> r, String k) => (r[k] ?? '').trim();

  static String _low(String s) => s.trim().toLowerCase();

  /// Ambil nilai pertama yang terisi dari sekelompok baris.
  static String _first(List<Map<String, String>> rows, String k) {
    for (final r in rows) {
      final v = _s(r, k);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  /// true/false dari teks. Kosong -> [def]. Tidak dikenali -> null.
  static bool? _bool(String s, bool def) {
    final v = _low(s);
    if (v.isEmpty) return def;
    if (['yes', 'y', 'ya', 'true', '1', 'aktif', 'active', 'verified'].contains(v)) return true;
    if (['no', 'n', 'tidak', 'false', '0', 'nonaktif', 'non aktif', 'inactive', 'tidak aktif'].contains(v)) {
      return false;
    }
    return null;
  }

  static double? _num(String s) {
    var t = s.trim().replaceAll(RegExp(r'[^0-9.,\-]'), '');
    if (t.isEmpty) return null;
    if (t.contains(',') && t.contains('.')) {
      t = t.replaceAll(',', '');
    } else if (t.contains(',')) {
      t = RegExp(r'^-?\d{1,3}(,\d{3})+$').hasMatch(t) ? t.replaceAll(',', '') : t.replaceAll(',', '.');
    }
    return double.tryParse(t);
  }

  /// Tanggal -> 'yyyy-MM-dd'. Mendukung yyyy-MM-dd, dd/MM/yyyy, dd-MM-yyyy.
  static String? _date(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    int? y, m, d;
    var mt = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(t);
    if (mt != null) {
      y = int.parse(mt.group(1)!);
      m = int.parse(mt.group(2)!);
      d = int.parse(mt.group(3)!);
    } else {
      mt = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})').firstMatch(t);
      if (mt == null) return null;
      d = int.parse(mt.group(1)!);
      m = int.parse(mt.group(2)!);
      y = int.parse(mt.group(3)!);
    }
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return '${y.toString().padLeft(4, '0')}-${two(m)}-${two(d)}';
  }

  static List<String> _split(String s) =>
      s.split(RegExp(r'[,;\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  /// Pencocokan nilai ke daftar dropdown (tidak peka huruf besar/kecil).
  /// Tidak ketemu: kalau [auto] aktif nilai dicatat ke [pending] dan
  /// dianggap valid, kalau tidak, catat error ke [errors].
  static String? _pick(
    String value,
    List<String> options,
    String category,
    String label,
    bool auto,
    Map<String, Set<String>> pending,
    List<String> errors,
  ) {
    final v = value.trim();
    if (v.isEmpty) return null;
    for (final o in options) {
      if (_low(o) == _low(v)) return o;
    }
    if (auto) {
      pending.putIfAbsent(category, () => <String>{}).add(v);
      return v;
    }
    errors.add('$label "$v" tidak ada di daftar dropdown');
    return null;
  }

  static List<String> _pickMulti(
    String value,
    List<String> options,
    String category,
    String label,
    bool auto,
    Map<String, Set<String>> pending,
    List<String> errors,
  ) {
    final out = <String>[];
    for (final part in _split(value)) {
      final p = _pick(part, options, category, label, auto, pending, errors);
      if (p != null && !out.contains(p)) out.add(p);
    }
    return out;
  }

  static String? _pickFixed(String value, List<String> options, String label, List<String> errors) {
    final v = value.trim();
    if (v.isEmpty) return null;
    for (final o in options) {
      if (_low(o) == _low(v)) return o;
    }
    errors.add('$label "$v" tidak valid (pilihan: ${options.join(', ')})');
    return null;
  }

  static ImportStatus _statusOf(List<String> errors) =>
      errors.isEmpty ? ImportStatus.ready : ImportStatus.error;

  static ImportPreview _finish(
    ImportModule m,
    ParsedSheet sheet,
    List<PreparedItem> items,
    Map<String, Set<String>> pending,
  ) {
    final problems = <String>[];
    if (sheet.missingRequiredColumns.isNotEmpty) {
      problems.add('Kolom wajib tidak ditemukan: ${sheet.missingRequiredColumns.join(', ')}');
    }
    if (sheet.rows.isEmpty && problems.isEmpty) {
      problems.add('Tidak ada baris data di sheet "${sheet.sheetName}".');
    }
    return ImportPreview(
      module: m,
      items: items,
      fileProblems: problems,
      pendingDropdown: {for (final e in pending.entries) e.key: e.value.toList()},
    );
  }

  /// Kelompokkan baris berdasarkan kunci; baris tanpa kunci ikut
  /// kelompok sebelumnya. Mengembalikan kelompok berurutan.
  static List<_Group> _group(ParsedSheet sheet, String keyField) {
    final groups = <_Group>[];
    final byKey = <String, _Group>{};
    for (var i = 0; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final key = _low(_s(row, keyField));
      if (key.isEmpty) {
        if (groups.isEmpty) {
          groups.add(_Group('', [row], [sheet.rowNumbers[i]]));
        } else {
          groups.last.rows.add(row);
          groups.last.nums.add(sheet.rowNumbers[i]);
        }
        continue;
      }
      final g = byKey[key];
      if (g == null) {
        final ng = _Group(key, [row], [sheet.rowNumbers[i]]);
        byKey[key] = ng;
        groups.add(ng);
      } else {
        g.rows.add(row);
        g.nums.add(sheet.rowNumbers[i]);
      }
    }
    return groups;
  }

  // ───────────────────────── Analisis ─────────────────────────

  static Future<ImportPreview> analyze(ImportModule m, ParsedSheet sheet, {required bool autoAddDropdown}) {
    switch (m) {
      case ImportModule.customer:
        return _customers(sheet, autoAddDropdown);
      case ImportModule.vendor:
        return _vendors(sheet, autoAddDropdown);
      case ImportModule.material:
        return _materials(sheet, autoAddDropdown);
      case ImportModule.rfq:
        return _rfqs(sheet, autoAddDropdown);
    }
  }

  // ── Customer ──

  static Future<ImportPreview> _customers(ParsedSheet sheet, bool auto) async {
    final existing = (await DatabaseService.instance.getCustomers())
        .map((c) => _low((c['customer_name'] ?? '').toString()))
        .toSet();
    final pending = <String, Set<String>>{};
    final items = <PreparedItem>[];

    for (final g in _group(sheet, 'name')) {
      final name = _first(g.rows, 'name');
      final errors = <String>[];
      if (name.isEmpty) errors.add('Customer Name kosong');

      final top = _pick(_first(g.rows, 'top'), CustomerOptionsRef.top, 'customer_terms_of_payment',
          'Terms of Payment', auto, pending, errors);
      final type = _pick(_first(g.rows, 'type'), CustomerOptionsRef.type, 'customer_customer_type',
          'Customer Type', auto, pending, errors);
      final active = _bool(_first(g.rows, 'status'), true);
      if (active == null) errors.add('Status harus Aktif / Nonaktif');

      final contacts = <Map<String, dynamic>>[];
      for (final r in g.rows) {
        final pn = _s(r, 'picName'), pp = _s(r, 'picPosition'), pc = _s(r, 'picContact'), pe = _s(r, 'picEmail');
        if ([pn, pp, pc, pe].every((e) => e.isEmpty)) continue;
        contacts.add({'pic_name': pn, 'pic_position': pp, 'contact': pc, 'pic_email': pe});
      }

      final item = PreparedItem(
        label: name.isEmpty ? '(tanpa nama)' : name,
        excelRows: g.nums,
        data: {
          'name': name,
          'npwp_number': _first(g.rows, 'npwp'),
          'terms_of_payment': top,
          'customer_type': type,
          'address': _first(g.rows, 'address'),
          'is_active': (active ?? true) ? 1 : 0,
        },
        children: {'contacts': contacts},
      );
      if (errors.isNotEmpty) {
        item.status = ImportStatus.error;
        item.message = errors.join('; ');
      } else if (existing.contains(_low(name))) {
        item.status = ImportStatus.skipped;
        item.message = 'Customer sudah ada di aplikasi';
      }
      items.add(item);
    }
    return _finish(ImportModule.customer, sheet, items, pending);
  }

  // ── Vendor ──

  static Future<ImportPreview> _vendors(ParsedSheet sheet, bool auto) async {
    final existing = (await DatabaseService.instance.getVendors())
        .map((v) => _low((v['vendor_name'] ?? '').toString()))
        .toSet();
    final pending = <String, Set<String>>{};
    final items = <PreparedItem>[];

    for (final g in _group(sheet, 'name')) {
      final name = _first(g.rows, 'name');
      final errors = <String>[];
      if (name.isEmpty) errors.add('Vendor Name kosong');

      final legal = _pick(_first(g.rows, 'legal'), VendorOptionsRef.legal, 'vendor_legal_standing',
          'Legal Standing', auto, pending, errors);
      final top = _pick(_first(g.rows, 'top'), VendorOptionsRef.top, 'vendor_terms_of_payment',
          'Terms of Payment', auto, pending, errors);
      final scope = _pickMulti(_first(g.rows, 'scope'), VendorOptionsRef.scope, 'scope_of_work',
          'Scope of Work', auto, pending, errors);
      final sub = _pickMulti(_first(g.rows, 'sub'), VendorOptionsRef.sub, 'sub_sow', 'Sub SOW', auto, pending, errors);
      final scc = _pick(_first(g.rows, 'scc'), VendorOptionsRef.scc, 'vendor_supply_chain_classification',
          'Supply Chain Classification', auto, pending, errors);
      final verified = _bool(_first(g.rows, 'verified'), false);
      if (verified == null) errors.add('Verified harus Yes / No');
      final active = _bool(_first(g.rows, 'status'), true);
      if (active == null) errors.add('Status harus Aktif / Nonaktif');

      final contacts = <Map<String, dynamic>>[];
      final products = <Map<String, dynamic>>[];
      final banks = <Map<String, dynamic>>[];
      final seenProducts = <String>{};
      for (final r in g.rows) {
        final pn = _s(r, 'picName'), pp = _s(r, 'picPosition'), pc = _s(r, 'picContact'), pe = _s(r, 'picEmail');
        if (![pn, pp, pc, pe].every((e) => e.isEmpty)) {
          contacts.add({'pic_name': pn, 'pic_position': pp, 'pic_contact': pc, 'pic_email': pe});
        }
        final prod = _s(r, 'product');
        if (prod.isNotEmpty && seenProducts.add(_low(prod))) products.add({'product_name': prod});

        final bn = _s(r, 'bankName'), bno = _s(r, 'bankNumber'), bh = _s(r, 'bankHolder'), sw = _s(r, 'bankSwift');
        final bc = _pick(_s(r, 'bankCurrency'), VendorOptionsRef.currency, 'currency', 'Bank Currency', auto, pending,
            errors);
        if (![bn, bno, bh, sw].every((e) => e.isEmpty)) {
          banks.add({
            'bank_name': bn,
            'account_number': bno,
            'account_holder': bh,
            'currency': bc ?? 'IDR',
            'swift_code': sw,
          });
        }
      }

      var note = _first(g.rows, 'note');
      final oldCode = _first(g.rows, 'oldCode');
      if (oldCode.isNotEmpty) note = note.isEmpty ? 'Kode lama: $oldCode' : '$note\nKode lama: $oldCode';

      final item = PreparedItem(
        label: name.isEmpty ? '(tanpa nama)' : name,
        excelRows: g.nums,
        data: {
          'vendor_name': name,
          'legal_standing': legal,
          'npwp': _first(g.rows, 'npwp'),
          'is_verified': (verified ?? false) ? 1 : 0,
          'terms_of_payment': top,
          'scope_of_work': scope.join(','),
          'sub_sow': sub.join(','),
          'supply_chain_classification': scc,
          'internal_note': note,
          'vendor_address': _first(g.rows, 'address'),
          'pic_website': _first(g.rows, 'website'),
          'status': (active ?? true) ? 1 : 0,
        },
        children: {'contacts': contacts, 'products': products, 'banks': banks},
      );
      if (errors.isNotEmpty) {
        item.status = ImportStatus.error;
        item.message = errors.toSet().join('; ');
      } else if (existing.contains(_low(name))) {
        item.status = ImportStatus.skipped;
        item.message = 'Vendor sudah ada di aplikasi';
      }
      items.add(item);
    }
    return _finish(ImportModule.vendor, sheet, items, pending);
  }

  // ── Material ──

  static Future<ImportPreview> _materials(ParsedSheet sheet, bool auto) async {
    final db = DatabaseService.instance;
    final vendors = await db.getVendors();
    final vendorIds = <String, int>{
      for (final v in vendors) _low((v['vendor_name'] ?? '').toString()): (v['id'] as num).toInt(),
    };
    final rates = <String, double>{'IDR': 1};
    for (final r in await db.getCurrencyRates()) {
      final code = (r['currency_code'] ?? '').toString().toUpperCase();
      final rate = r['rate_to_idr'];
      if (code.isNotEmpty && rate != null) rates[code] = double.tryParse(rate.toString()) ?? 0;
    }
    final existingKeys = <String>{};
    for (final m in await db.getMaterials()) {
      existingKeys.add(_matKey(m['vendor_id'], (m['item_description'] ?? '').toString(),
          (m['item_part_number'] ?? '').toString()));
    }

    final pending = <String, Set<String>>{};
    final items = <PreparedItem>[];
    final seenInFile = <String>{};

    for (var i = 0; i < sheet.rows.length; i++) {
      final r = sheet.rows[i];
      final errors = <String>[];
      final vendorName = _s(r, 'vendor');
      final desc = _s(r, 'desc');
      final vendorId = vendorIds[_low(vendorName)];
      if (vendorName.isEmpty) {
        errors.add('Vendor Name kosong');
      } else if (vendorId == null) {
        errors.add('Vendor "$vendorName" belum ada (import Vendor dulu)');
      }
      if (desc.isEmpty) errors.add('Item Description kosong');

      final scope = _pick(_s(r, 'scope'), VendorOptionsRef.scope, 'scope_of_work', 'Scope of Work', auto, pending, errors);
      final sub = _pick(_s(r, 'sub'), VendorOptionsRef.sub, 'sub_sow', 'Sub SOW', auto, pending, errors);
      final category = _pick(_s(r, 'category'), MaterialOptions.category, 'material_category', 'Category', auto,
          pending, errors);
      final docs = _pickMulti(_s(r, 'docs'), MaterialOptions.documents, 'material_documents', 'Document Available',
          auto, pending, errors);
      final dimUnit = _pickFixed(_s(r, 'dimUnit'), MaterialOptions.dimensionUnit, 'Dimensi Unit', errors);
      final weightUnit = _pickFixed(_s(r, 'weightUnit'), MaterialOptions.weightUnit, 'Weight Unit', errors);
      final termsRaw = _s(r, 'delivTerms');
      String? deliv;
      if (termsRaw.isNotEmpty) deliv = _pickFixed(termsRaw, const ['Franco', 'Loco'], 'Delivery Terms', errors);

      // Mata uang & harga
      var currency = _s(r, 'currency').toUpperCase();
      if (currency.isEmpty) currency = 'IDR';
      if (!rates.containsKey(currency)) {
        errors.add('Mata uang $currency belum ada di Update Valuta');
      }
      final foreignText = _s(r, 'foreign');
      final quoteText = _s(r, 'quoteIdr');
      final foreign = _num(foreignText);
      final quoteIn = _num(quoteText);
      if (foreignText.isNotEmpty && foreign == null) errors.add('Price bukan angka');
      if (quoteText.isNotEmpty && quoteIn == null) errors.add('Price Quote (IDR) bukan angka');
      final rate = rates[currency] ?? 1;
      double quote;
      if (currency == 'IDR') {
        quote = quoteIn ?? foreign ?? 0;
      } else {
        quote = quoteIn ?? ((foreign ?? 0) * rate);
      }
      final foreignAmount = foreign ?? (currency == 'IDR' ? quote : 0);

      final dateText = _s(r, 'priceDate');
      final priceDate = _date(dateText);
      if (dateText.isNotEmpty && priceDate == null) errors.add('Price Date tidak valid');

      final vat = _bool(_s(r, 'vat'), false);
      if (vat == null) errors.add('VAT harus Yes / No');
      final trans = _bool(_s(r, 'transaction'), false);
      if (trans == null) errors.add('Transaction harus Yes / No');
      final active = _bool(_s(r, 'status'), true);
      if (active == null) errors.add('Status harus Aktif / Nonaktif');

      final leadText = _s(r, 'lead');
      final lead = _num(leadText);
      if (leadText.isNotEmpty && lead == null) errors.add('Lead Time bukan angka');

      double? opt(String key, String label) {
        final t = _s(r, key);
        if (t.isEmpty) return null;
        final v = _num(t);
        if (v == null) errors.add('$label bukan angka');
        return v;
      }

      final dimP = opt('dimP', 'Dimensi P');
      final dimL = opt('dimL', 'Dimensi L');
      final dimT = opt('dimT', 'Dimensi T');
      final weight = opt('weight', 'Weight');

      final discounts = <Map<String, dynamic>>[];
      final discText = _s(r, 'discount');
      if (discText.isNotEmpty) {
        final dv = _num(discText);
        final dd = _s(r, 'discountDate');
        final ddv = _date(dd);
        if (dv == null) {
          errors.add('Discount Amount bukan angka');
        } else {
          if (dd.isNotEmpty && ddv == null) errors.add('Discount Date tidak valid');
          discounts.add({'discount_amount': dv, 'discount_date': ddv});
        }
      }
      final totalDiscount = discounts.fold<double>(0, (s, d) => s + (d['discount_amount'] as double));
      final priceDiscount = (quote - totalDiscount) < 0 ? 0.0 : (quote - totalDiscount);
      final totalPrice = discounts.isEmpty ? quote : priceDiscount;
      final dpp = totalPrice * 11 / 12;
      final vatValue = (vat ?? false) ? dpp * 0.12 : 0.0;

      final item = PreparedItem(
        label: desc.isEmpty ? '(tanpa deskripsi)' : desc,
        excelRows: [sheet.rowNumbers[i]],
        data: {
          'vendor_id': vendorId,
          'scope_of_work': scope,
          'sub_sow': sub,
          'brand_unit_installed_on': _s(r, 'brand'),
          'type_unit_installed_on': _s(r, 'unitType'),
          'item_description': desc,
          'category': category,
          'item_manufacturer': _s(r, 'manufacturer'),
          'origin_country': _s(r, 'origin'),
          'item_type': _s(r, 'itemType'),
          'item_part_number': _s(r, 'part'),
          'size': _s(r, 'size'),
          'photo_path': null,
          'reference_genuine_part_number': _s(r, 'refPart'),
          'existing_item_description': _s(r, 'existing'),
          'price_quote': quote,
          'price_quote_currency': currency,
          'price_quote_foreign_amount': foreignAmount,
          'price_quote_date': priceDate,
          'total_discount': totalDiscount,
          'price_discount': priceDiscount,
          'total_price': totalPrice,
          'vat': (vat ?? false) ? 1 : 0,
          'dpp': dpp,
          'vat_value': vatValue,
          'lead_time_days': (lead ?? 0).round(),
          'delivery_terms': deliv,
          'delivery_address': _s(r, 'delivAddress'),
          'dim_p': dimP,
          'dim_l': dimL,
          'dim_t': dimT,
          'dim_unit': dimUnit,
          'weight': weight,
          'weight_unit': weightUnit,
          'documents': docs.join(','),
          'is_transaction': (trans ?? false) ? 1 : 0,
          'status': (active ?? true) ? 1 : 0,
        },
        children: {'discounts': discounts},
      );

      if (errors.isNotEmpty) {
        item.status = ImportStatus.error;
        item.message = errors.toSet().join('; ');
      } else {
        final key = _matKey(vendorId, desc, _s(r, 'part'));
        if (existingKeys.contains(key)) {
          item.status = ImportStatus.skipped;
          item.message = 'Material sudah ada di aplikasi';
        } else if (!seenInFile.add(key)) {
          item.status = ImportStatus.skipped;
          item.message = 'Duplikat di dalam file';
        }
      }
      items.add(item);
    }
    return _finish(ImportModule.material, sheet, items, pending);
  }

  static String _matKey(dynamic vendorId, String desc, String part) =>
      '${vendorId ?? ''}|${_low(desc)}|${_low(part)}';

  // ── RFQ ──

  static const String _noteMarker = 'No. RFQ Lama:';

  static Future<ImportPreview> _rfqs(ParsedSheet sheet, bool auto) async {
    final db = DatabaseService.instance;
    final customerIds = <String, int>{
      for (final c in await db.getCustomers()) _low((c['customer_name'] ?? '').toString()): (c['id'] as num).toInt(),
    };

    final vendorNameById = <int, String>{
      for (final v in await db.getVendors()) (v['id'] as num).toInt(): _low((v['vendor_name'] ?? '').toString()),
    };
    final byDesc = <String, List<_Mat>>{};
    final idSet = <int>{};
    for (final m in await db.getMaterials()) {
      final id = (m['id'] as num).toInt();
      idSet.add(id);
      final vid = m['vendor_id'] == null ? null : (m['vendor_id'] as num).toInt();
      byDesc
          .putIfAbsent(_low((m['item_description'] ?? '').toString()), () => [])
          .add(_Mat(id, vid == null ? '' : (vendorNameById[vid] ?? '')));
    }

    final existingOld = <String>{};
    for (final r in await db.getRfqs()) {
      final note = (r['internal_note'] ?? '').toString();
      for (final line in note.split('\n')) {
        final t = line.trim();
        if (t.startsWith(_noteMarker)) existingOld.add(_low(t.substring(_noteMarker.length)));
      }
    }

    final pending = <String, Set<String>>{};
    final items = <PreparedItem>[];

    for (final g in _group(sheet, 'oldNo')) {
      final oldNo = _first(g.rows, 'oldNo');
      final errors = <String>[];
      if (oldNo.isEmpty) errors.add('No. RFQ Lama kosong');

      final custName = _first(g.rows, 'customer');
      final customerId = customerIds[_low(custName)];
      if (custName.isEmpty) {
        errors.add('Customer Name kosong');
      } else if (customerId == null) {
        errors.add('Customer "$custName" belum ada (import Customer dulu)');
      }

      final dr = _first(g.rows, 'dateRequest');
      final dd = _first(g.rows, 'dueDate');
      final dateRequest = _date(dr);
      final dueDate = _date(dd);
      if (dr.isNotEmpty && dateRequest == null) errors.add('Date Request tidak valid');
      if (dd.isNotEmpty && dueDate == null) errors.add('Due Date tidak valid');

      final docReq = _pickMulti(_first(g.rows, 'docReq'), MaterialOptions.documents, 'material_documents',
          'Document Requirement', auto, pending, errors);
      final statusRaw = _first(g.rows, 'status');
      String? status = statusRaw.isEmpty
          ? (RfqOptions.status.isEmpty ? null : RfqOptions.status.first)
          : _pick(statusRaw, RfqOptions.status, 'rfq_status', 'Status', auto, pending, errors);

      final lines = <Map<String, dynamic>>[];
      for (var i = 0; i < g.rows.length; i++) {
        final r = g.rows[i];
        final rowNo = g.nums[i];
        final matText = _s(r, 'material');
        if (matText.isEmpty) {
          errors.add('Baris $rowNo: Material kosong');
          continue;
        }
        int? matId;
        final code = RegExp(r'^MATL(\d+)$', caseSensitive: false).firstMatch(matText);
        if (code != null) {
          final id = int.parse(code.group(1)!);
          if (idSet.contains(id)) {
            matId = id;
          } else {
            errors.add('Baris $rowNo: material $matText tidak ditemukan');
          }
        } else {
          var cands = byDesc[_low(matText)] ?? const <_Mat>[];
          final vn = _low(_s(r, 'materialVendor'));
          if (vn.isNotEmpty) cands = cands.where((c) => c.vendor == vn).toList();
          if (cands.isEmpty) {
            errors.add('Baris $rowNo: material "$matText" belum ada (import Material dulu)');
          } else if (cands.length > 1) {
            errors.add('Baris $rowNo: material "$matText" ada di beberapa vendor, isi kolom Vendor (Material)');
          } else {
            matId = cands.first.id;
          }
        }

        final qtyText = _s(r, 'qty');
        final qty = _num(qtyText);
        if (qty == null || qty <= 0 || qty != qty.truncateToDouble()) {
          errors.add('Baris $rowNo: Qty harus bilangan bulat > 0');
        }
        final unitRaw = _s(r, 'unit');
        final unit = unitRaw.isEmpty ? 'Ea' : (_pickFixed(unitRaw, MaterialOptions.unit, 'Baris $rowNo: Unit', errors));
        if (matId != null && qty != null && unit != null) {
          lines.add({'material_id': matId, 'quantity': qty.toInt(), 'unit': unit});
        }
      }

      var note = _first(g.rows, 'note');
      if (oldNo.isNotEmpty) {
        note = note.isEmpty ? '$_noteMarker $oldNo' : '$note\n$_noteMarker $oldNo';
      }

      final item = PreparedItem(
        label: oldNo.isEmpty ? '(tanpa nomor)' : oldNo,
        excelRows: g.nums,
        data: {
          'reference': _first(g.rows, 'reference'),
          'pic': _first(g.rows, 'pic'),
          'date_request': dateRequest,
          'due_date': dueDate,
          'customer_id': customerId,
          'internal_note': note,
          'document_requirement': docReq.join(','),
          'status': status,
        },
        children: {'lines': lines},
      );
      if (errors.isNotEmpty) {
        item.status = ImportStatus.error;
        item.message = errors.toSet().join('; ');
      } else if (existingOld.contains(_low(oldNo))) {
        item.status = ImportStatus.skipped;
        item.message = 'RFQ dengan No. RFQ Lama ini sudah pernah di-import';
      }
      items.add(item);
    }
    return _finish(ImportModule.rfq, sheet, items, pending);
  }

  // ───────────────────────── Simpan ─────────────────────────

  /// Simpan semua item berstatus ready. Tiap item dibungkus try/catch
  /// sendiri, jadi 1 item gagal tidak membatalkan yang lain.
  static Future<ImportReport> commit(
    ImportPreview preview, {
    required bool autoAddDropdown,
    void Function(int done, int total)? onProgress,
  }) async {
    final db = DatabaseService.instance;
    final failed = <PreparedItem>[];
    var success = 0;

    // Nilai dropdown baru (hanya kalau opsi tambah otomatis aktif).
    if (autoAddDropdown) {
      for (final e in preview.pendingDropdown.entries) {
        try {
          final current = DropdownOptionsCache.get(e.key).map(_low).toSet();
          for (final v in e.value) {
            if (current.contains(_low(v))) continue;
            await db.insertDropdownOption(e.key, v);
            current.add(_low(v));
          }
          await DropdownOptionsCache.refreshCategory(e.key);
        } catch (_) {
          // gagal tambah dropdown tidak menggagalkan import datanya
        }
      }
    }

    final ready = preview.items.where((i) => i.status == ImportStatus.ready).toList();
    var done = 0;
    for (final it in ready) {
      try {
        switch (preview.module) {
          case ImportModule.customer:
            await db.insertCustomer(it.data, it.children['contacts'] ?? const []);
            break;
          case ImportModule.vendor:
            await db.insertVendor(it.data, it.children['contacts'] ?? const [],
                it.children['products'] ?? const [], it.children['banks'] ?? const []);
            break;
          case ImportModule.material:
            await db.insertMaterial(it.data, it.children['discounts'] ?? const []);
            break;
          case ImportModule.rfq:
            await db.insertRfq(it.data, it.children['lines'] ?? const []);
            break;
        }
        success++;
      } catch (e) {
        it.status = ImportStatus.error;
        it.message = 'Gagal disimpan: $e';
        failed.add(it);
      }
      done++;
      onProgress?.call(done, ready.length);
    }

    final bad = preview.items.where((i) => i.status == ImportStatus.error && !failed.contains(i)).toList();
    return ImportReport(
      success: success,
      skipped: preview.skippedCount,
      failed: [...bad, ...failed],
    );
  }
}

class _Group {
  final String key;
  final List<Map<String, String>> rows;
  final List<int> nums;
  _Group(this.key, this.rows, this.nums);
}

class _Mat {
  final int id;
  final String vendor;
  _Mat(this.id, this.vendor);
}

/// Pintasan ke daftar dropdown yang dipakai importer.
class CustomerOptionsRef {
  static List<String> get top => DropdownOptionsCache.get('customer_terms_of_payment');
  static List<String> get type => DropdownOptionsCache.get('customer_customer_type');
}

class VendorOptionsRef {
  static List<String> get legal => DropdownOptionsCache.get('vendor_legal_standing');
  static List<String> get top => DropdownOptionsCache.get('vendor_terms_of_payment');
  static List<String> get scope => DropdownOptionsCache.get('scope_of_work');
  static List<String> get sub => DropdownOptionsCache.get('sub_sow');
  static List<String> get scc => DropdownOptionsCache.get('vendor_supply_chain_classification');
  static List<String> get currency => DropdownOptionsCache.get('currency');
}
