import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'import_specs.dart';
import 'import_types.dart';

/// Baca/tulis file Excel untuk fitur Update DB: simpan template, pilih
/// file .xlsx, baca isi sheet jadi [ParsedSheet], dan simpan laporan
/// baris gagal.
class ImportExcelIo {
  // ───────────────────────── Template ─────────────────────────

  /// Buat template .xlsx (sheet Data, Contoh, Petunjuk) lalu munculkan
  /// dialog Save. Mengembalikan path file, atau null kalau dibatalkan.
  static Future<String?> saveTemplate(ImportModule module) async {
    final cols = ImportSpecs.columns(module);
    final excel = xl.Excel.createExcel();
    final data = excel['Data'];
    final example = excel['Contoh'];
    final guide = excel['Petunjuk'];
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

    final bold = xl.CellStyle(bold: true);

    xl.Data cell(xl.Sheet s, int col, int row) =>
        s.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));

    for (var c = 0; c < cols.length; c++) {
      final header = cols[c].required ? '${cols[c].header} *' : cols[c].header;
      final h = cell(data, c, 0);
      h.value = xl.TextCellValue(header);
      h.cellStyle = bold;
      final h2 = cell(example, c, 0);
      h2.value = xl.TextCellValue(header);
      h2.cellStyle = bold;
      final e = cell(example, c, 1);
      e.value = xl.TextCellValue(cols[c].example);
      final w = (cols[c].header.length + 6).clamp(14, 40).toDouble();
      data.setColumnWidth(c, w);
      example.setColumnWidth(c, w);
    }

    var r = 0;
    final t = cell(guide, 0, r++);
    t.value = xl.TextCellValue('Petunjuk import ${ImportSpecs.title(module)}');
    t.cellStyle = bold;
    r++;
    final a = cell(guide, 0, r++);
    a.value = xl.TextCellValue('Isi data di sheet "Data" mulai baris ke-2. Judul kolom jangan diubah. Kolom bertanda * wajib diisi.');
    for (final n in ImportSpecs.notes(module)) {
      cell(guide, 0, r++).value = xl.TextCellValue('- $n');
    }
    guide.setColumnWidth(0, 120);

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Gagal membuat file template.');

    final out = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan Template ${ImportSpecs.title(module)}',
      fileName: 'template_import_${ImportSpecs.title(module).toLowerCase()}.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (out == null) return null;
    final path = out.toLowerCase().endsWith('.xlsx') ? out : '$out.xlsx';
    final f = File(path);
    await f.create(recursive: true);
    await f.writeAsBytes(bytes);
    return path;
  }

  // ───────────────────────── Baca file ─────────────────────────

  /// Dialog pilih file. Mengembalikan (path, bytes) atau null.
  static Future<({String path, List<int> bytes})?> pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      dialogTitle: 'Pilih file Excel',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final pf = res.files.first;
    List<int>? bytes = pf.bytes;
    if (bytes == null && pf.path != null) {
      bytes = await File(pf.path!).readAsBytes();
    }
    if (bytes == null) throw Exception('File tidak bisa dibaca.');
    return (path: pf.path ?? pf.name, bytes: bytes);
  }

  /// Baca sheet pertama yang cocok (prioritas sheet "Data", kalau tidak
  /// ada pakai sheet pertama) menjadi [ParsedSheet] untuk [module].
  static ParsedSheet parse(List<int> bytes, ImportModule module) {
    final excel = xl.Excel.decodeBytes(_fixStyles(bytes));
    if (excel.tables.isEmpty) throw Exception('File Excel kosong.');

    String sheetName = excel.tables.keys.first;
    for (final k in excel.tables.keys) {
      if (k.trim().toLowerCase() == 'data') {
        sheetName = k;
        break;
      }
    }
    final sheet = excel.tables[sheetName]!;
    final specs = ImportSpecs.columns(module);
    final byNorm = {for (final s in specs) ColumnSpec.normalize(s.header): s.key};

    // Baris judul = 10 baris pertama yang paling banyak cocok.
    var headerRow = -1;
    var best = 0;
    final scan = sheet.rows.length < 10 ? sheet.rows.length : 10;
    for (var i = 0; i < scan; i++) {
      var hits = 0;
      for (final c in sheet.rows[i]) {
        final n = ColumnSpec.normalize(cellText(c?.value));
        if (n.isNotEmpty && byNorm.containsKey(n)) hits++;
      }
      if (hits > best) {
        best = hits;
        headerRow = i;
      }
    }
    if (headerRow < 0) {
      return ParsedSheet(
        rows: [],
        rowNumbers: [],
        missingRequiredColumns: specs.where((s) => s.required).map((s) => s.header).toList(),
        sheetName: sheetName,
      );
    }

    final colKeys = <int, String>{};
    final headerCells = sheet.rows[headerRow];
    for (var c = 0; c < headerCells.length; c++) {
      final n = ColumnSpec.normalize(cellText(headerCells[c]?.value));
      final key = byNorm[n];
      if (key != null && !colKeys.containsValue(key)) colKeys[c] = key;
    }

    final missing = specs
        .where((s) => s.required && !colKeys.containsValue(s.key))
        .map((s) => s.header)
        .toList();

    final rows = <Map<String, String>>[];
    final nums = <int>[];
    for (var i = headerRow + 1; i < sheet.rows.length; i++) {
      final raw = sheet.rows[i];
      final m = <String, String>{};
      var any = false;
      colKeys.forEach((c, key) {
        final text = c < raw.length ? cellText(raw[c]?.value) : '';
        m[key] = text;
        if (text.isNotEmpty) any = true;
      });
      if (!any) continue;
      rows.add(m);
      nums.add(i + 1);
    }
    return ParsedSheet(rows: rows, rowNumbers: nums, missingRequiredColumns: missing, sheetName: sheetName);
  }


  /// Perbaikan untuk file hasil simpan Excel/WPS: package `excel` gagal
  /// membaca file yang mendeklarasikan format angka bawaan (id < 164,
  /// mis. 42 / 44 format akuntansi) di styles.xml dengan error "custom
  /// numFmtId starts at 164". Format angka tidak berpengaruh ke isi
  /// data, jadi deklarasi itu dibuang sebelum dibaca.
  static List<int> _fixStyles(List<int> bytes) {
    try {
      final zip = ZipDecoder().decodeBytes(bytes);
      final out = Archive();
      var changed = false;
      for (final f in zip.files) {
        if (f.isFile && f.name == 'xl/styles.xml') {
          final text = utf8.decode(f.content as List<int>);
          var fixed = text.replaceAllMapped(
            RegExp(r'<numFmt\s+numFmtId="(\d+)"[^>]*/>'),
            (m) => int.parse(m.group(1)!) < 164 ? '' : m.group(0)!,
          );
          fixed = fixed.replaceAll(RegExp(r'numFmtId="4[1-4]"'), 'numFmtId="0"');
          if (fixed != text) {
            changed = true;
            final data = utf8.encode(fixed);
            out.addFile(ArchiveFile(f.name, data.length, data));
            continue;
          }
        }
        out.addFile(f);
      }
      if (!changed) return bytes;
      return ZipEncoder().encode(out) ?? bytes;
    } catch (_) {
      return bytes;
    }
  }

  /// Nilai sel jadi teks bersih. Tanggal -> yyyy-MM-dd, angka bulat tanpa
  /// ".0", rumus / error (#NAME?, #N/A, ...) -> kosong.
  static String cellText(xl.CellValue? v) {
    if (v == null) return '';
    String s;
    if (v is xl.TextCellValue) {
      s = v.value.toString();
    } else if (v is xl.IntCellValue) {
      s = v.value.toString();
    } else if (v is xl.DoubleCellValue) {
      final d = v.value;
      s = d == d.truncateToDouble() ? d.toInt().toString() : d.toString();
    } else if (v is xl.DateCellValue) {
      s = '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
    } else if (v is xl.DateTimeCellValue) {
      s = '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
    } else if (v is xl.BoolCellValue) {
      s = v.value ? 'Yes' : 'No';
    } else {
      return ''; // FormulaCellValue, TimeCellValue, dst
    }
    s = s.trim();
    if (s.startsWith('#') && (s.endsWith('?') || s.endsWith('!') || s == '#N/A')) return '';
    return s;
  }

  // ───────────────────────── Laporan gagal ─────────────────────────

  /// Simpan laporan baris yang gagal / bermasalah ke .xlsx.
  static Future<String?> saveFailureReport(ImportModule module, List<PreparedItem> failed) async {
    final excel = xl.Excel.createExcel();
    final sheet = excel['Laporan'];
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
    final bold = xl.CellStyle(bold: true);
    final heads = ['Baris Excel', 'Data', 'Status', 'Masalah'];
    for (var i = 0; i < heads.length; i++) {
      final c = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      c.value = xl.TextCellValue(heads[i]);
      c.cellStyle = bold;
    }
    for (var r = 0; r < failed.length; r++) {
      final it = failed[r];
      final vals = [
        it.excelRows.join(', '),
        it.label,
        it.status == ImportStatus.skipped ? 'Dilewati' : 'Gagal',
        it.message ?? '',
      ];
      for (var c = 0; c < vals.length; c++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1)).value =
            xl.TextCellValue(vals[c]);
      }
    }
    sheet.setColumnWidth(0, 14);
    sheet.setColumnWidth(1, 40);
    sheet.setColumnWidth(2, 12);
    sheet.setColumnWidth(3, 80);

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Gagal membuat laporan.');
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final out = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan Laporan Baris Gagal',
      fileName: 'laporan_gagal_${ImportSpecs.title(module).toLowerCase()}_$stamp.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (out == null) return null;
    final path = out.toLowerCase().endsWith('.xlsx') ? out : '$out.xlsx';
    final f = File(path);
    await f.create(recursive: true);
    await f.writeAsBytes(bytes);
    return path;
  }
}
