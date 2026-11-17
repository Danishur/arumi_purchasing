import 'dart:io';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

/// 1 kelompok data relasi (mis. PIC, Produk/Brand, Bank Information,
/// Diskon) yang ikut di-export bersama data utamanya.
class ChildSection {
  /// Awalan header kolom, mis. "PIC" -> "PIC - Pic Name".
  final String label;

  /// Baris mentah tabel relasi, sudah dikelompokkan per id parent.
  final Map<int, List<Map<String, dynamic>>> rowsByParent;

  /// Kolom yang tidak ditampilkan (id & foreign key ke parent).
  final Set<String> skip;

  ChildSection({
    required this.label,
    required this.rowsByParent,
    this.skip = const {'id'},
  });
}

/// Export Excel PENUH: semua kolom yang ada di database ikut masuk
/// (dibangun dari baris mentah `SELECT *`, bukan daftar kolom yang
/// ditulis tangan) -- kolom apa pun yang ada di tabel, termasuk
/// created_at / updated_at / created_by & kolom yang baru ditambah
/// nanti, otomatis ikut ter-export.
class FullExport {
  static final _dateFmt = DateFormat('dd/MM/yyyy');
  static final _dateTimeFmt = DateFormat('dd/MM/yyyy HH:mm');

  static const _acronyms = {
    'id': 'ID',
    'npwp': 'NPWP',
    'sow': 'SOW',
    'vat': 'VAT',
    'dpp': 'DPP',
    'pic': 'PIC',
    'idr': 'IDR',
    'rfq': 'RFQ',
    'url': 'URL',
    'rm': 'RM',
    'top': 'TOP',
  };

  /// Override header untuk kolom tertentu (selain hasil title-case otomatis).
  static const labelOverrides = {
    'customer_name': 'Customer Name',
    'status': 'Status',
    'documents': 'Document Available',
    'document_requirement': 'Document Requirement',
    'is_verified': 'Verified',
    'is_transaction': 'Transaction',
    'price_quote_foreign_amount': 'Price',
    'price_quote_currency': 'Currency',
    'price_quote': 'Price Quote (IDR)',
    'total_price': 'Price IDR',
    'quantity': 'Qty',
    'material_total_price': 'Harga Satuan',
    'material_vat': 'VAT',
    'dim_p': 'Dimensi P',
    'dim_l': 'Dimensi L',
    'dim_t': 'Dimensi T',
    'dim_unit': 'Satuan Dimensi',
    'weight_unit': 'Satuan Berat',
    'date_request': 'Date Request',
    'pic_contact': 'Contact',
  };

  // Kolom TINYINT(1) yang ditampilkan sebagai Yes/No (status -> Aktif/Nonaktif).
  static const _yesNoKeys = {
    'is_verified',
    'is_transaction',
    'vat',
    'material_vat',
  };
  static const _activeKeys = {'status', 'is_active'};

  static String headerOf(String key) {
    final o = labelOverrides[key];
    if (o != null) return o;
    return key
        .split('_')
        .where((p) => p.isNotEmpty)
        .map((p) => _acronyms[p] ?? (p[0].toUpperCase() + p.substring(1)))
        .join(' ');
  }

  /// Urutan kolom: yang ada di [first] duluan (kalau ada di data), lalu
  /// sisanya sesuai urutan di database. Kolom di [skip] dibuang.
  static List<String> orderedKeys(
    Iterable<Map<String, dynamic>> rows, {
    List<String> first = const [],
    Set<String> skip = const {'id'},
  }) {
    final seen = <String>[];
    for (final r in rows) {
      for (final k in r.keys) {
        if (!seen.contains(k)) seen.add(k);
      }
    }
    final head = first.where((k) => seen.contains(k) && !skip.contains(k)).toList();
    final rest = seen.where((k) => !head.contains(k) && !skip.contains(k));
    return [...head, ...rest];
  }

  static bool _isOne(dynamic v) => v == true || v == 1 || v == '1';
  static bool _isZero(dynamic v) => v == false || v == 0 || v == '0';

  static String _numText(num v) {
    if (v is int) return v.toString();
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toString();
  }

  static String _dateText(DateTime d) {
    final hasTime = d.hour != 0 || d.minute != 0 || d.second != 0;
    return hasTime ? _dateTimeFmt.format(d) : _dateFmt.format(d);
  }

  /// Nilai untuk 1 sel di kolom data utama: angka tetap angka, sisanya teks.
  static dynamic cell(String key, dynamic v) {
    if (v == null) return '-';
    if (_activeKeys.contains(key) && (_isOne(v) || _isZero(v))) {
      return _isOne(v) ? 'Aktif' : 'Nonaktif';
    }
    if (_yesNoKeys.contains(key) && (_isOne(v) || _isZero(v))) {
      return _isOne(v) ? 'Yes' : 'No';
    }
    if (v is DateTime) return _dateText(v);
    if (v is num) return v;
    if (v is bool) return v ? 'Yes' : 'No';
    final s = v.toString().trim();
    if (s.isEmpty) return '-';
    // Kolom multi-select disimpan dipisah koma -> rapikan jadi ", ".
    if (key == 'documents' ||
        key == 'document_requirement' ||
        key == 'scope_of_work' ||
        key == 'sub_sow') {
      return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).join(', ');
    }
    return s;
  }

  static String cellText(String key, dynamic v) {
    final c = cell(key, v);
    if (c is num) return _numText(c);
    return c.toString();
  }

  /// Gabungkan semua item relasi per kolom: 1 item = 1 baris di dalam sel
  /// (urutan item sama di semua kolom relasi, jadi mudah dicocokkan).
  static Map<String, String> flattenChildren(
    ChildSection section,
    int parentId,
    List<String> keys,
  ) {
    final items = section.rowsByParent[parentId] ?? const [];
    final out = <String, String>{};
    for (final k in keys) {
      if (items.isEmpty) {
        out[k] = '-';
        continue;
      }
      final parts = <String>[];
      for (var i = 0; i < items.length; i++) {
        final t = cellText(k, items[i][k]);
        parts.add(items.length == 1 ? t : '${i + 1}. $t');
      }
      out[k] = parts.join('\n');
    }
    return out;
  }

  /// 1 baris per parent (Customer/Vendor/Material): semua kolom parent +
  /// semua kolom tiap [ChildSection] (item relasi digabung per sel).
  static Future<String?> saveWithChildren({
    required List<Map<String, dynamic>> parents,
    required String codeHeader,
    required String Function(int id) codeOf,
    required List<ChildSection> children,
    required String fileName,
    required String sheetName,
    List<String> firstKeys = const [],
  }) async {
    final parentKeys = orderedKeys(parents, first: firstKeys);
    final childKeys = <ChildSection, List<String>>{};
    for (final s in children) {
      final all = <Map<String, dynamic>>[];
      for (final p in parents) {
        final id = p['id'];
        if (id is int) all.addAll(s.rowsByParent[id] ?? const []);
      }
      childKeys[s] = orderedKeys(all, skip: s.skip);
    }

    final headers = <String>[
      codeHeader,
      ...parentKeys.map(headerOf),
      for (final s in children)
        ...childKeys[s]!.map((k) => '${s.label} - ${headerOf(k)}'),
    ];

    final rows = <List<dynamic>>[];
    for (final p in parents) {
      final id = p['id'];
      final row = <dynamic>[id is int ? codeOf(id) : '-'];
      for (final k in parentKeys) {
        row.add(cell(k, p[k]));
      }
      for (final s in children) {
        final flat = id is int
            ? flattenChildren(s, id, childKeys[s]!)
            : <String, String>{};
        for (final k in childKeys[s]!) {
          row.add(flat[k] ?? '-');
        }
      }
      rows.add(row);
    }

    return write(headers: headers, rows: rows, fileName: fileName, sheetName: sheetName);
  }

  /// Tulis [headers] + [rows] ke file .xlsx lalu munculkan dialog Save.
  /// [boldLastRow]: tebalkan baris terakhir (mis. baris Total).
  static Future<String?> write({
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String fileName,
    required String sheetName,
    bool boldLastRow = false,
  }) async {
    final excel = xl.Excel.createExcel();
    final sheet = excel[sheetName];
    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    final bold = xl.CellStyle(bold: true);
    final wrap = xl.CellStyle(
      textWrapping: xl.TextWrapping.WrapText,
      verticalAlign: xl.VerticalAlign.Top,
    );

    void setCell(int col, int row, dynamic value, {xl.CellStyle? style}) {
      final c = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      if (value is num) {
        c.value = xl.DoubleCellValue(value.toDouble());
      } else {
        c.value = xl.TextCellValue(value?.toString() ?? '-');
      }
      if (style != null) c.cellStyle = style;
    }

    for (var i = 0; i < headers.length; i++) {
      setCell(i, 0, headers[i], style: bold);
    }
    for (var r = 0; r < rows.length; r++) {
      final isLast = boldLastRow && r == rows.length - 1;
      for (var c = 0; c < rows[r].length; c++) {
        final v = rows[r][c];
        final hasNewline = v is String && v.contains('\n');
        setCell(c, r + 1, v, style: isLast ? bold : (hasNewline ? wrap : null));
      }
    }

    // Lebar kolom menyesuaikan isi (maks 50) supaya tidak terlalu sempit.
    for (var c = 0; c < headers.length; c++) {
      var w = headers[c].length;
      for (final row in rows) {
        if (c >= row.length) continue;
        final v = row[c];
        final text = v is num ? _numText(v) : (v?.toString() ?? '');
        for (final line in text.split('\n')) {
          if (line.length > w) w = line.length;
        }
      }
      sheet.setColumnWidth(c, (w + 3).clamp(12, 50).toDouble());
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Gagal membuat file Excel.');

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan Export Excel Rekap',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (outputPath == null) return null;
    final path = outputPath.toLowerCase().endsWith('.xlsx') ? outputPath : '$outputPath.xlsx';
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    return path;
  }
}
