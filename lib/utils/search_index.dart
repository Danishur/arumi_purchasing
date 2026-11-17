import 'package:intl/intl.dart';

/// Global Search: bikin 1 teks "index" per record dari SEMUA kolom di
/// database (bukan cuma beberapa field pilihan), termasuk data relasi
/// (PIC, produk, bank, diskon, baris material RFQ, dst).
///
/// Karena dibangun dari baris mentah database (`SELECT *`), kolom apa pun
/// yang ada di tabel -- termasuk kolom yang baru ditambahkan nanti --
/// otomatis ikut bisa dicari tanpa perlu ubah kode search lagi.
class SearchIndex {
  static final _num = NumberFormat.decimalPattern('id_ID');

  static void _addValue(StringBuffer buf, dynamic v) {
    if (v == null) return;
    if (v is DateTime) {
      buf
        ..write(DateFormat('yyyy-MM-dd').format(v))
        ..write(' ')
        ..write(DateFormat('dd/MM/yyyy').format(v))
        ..write(' ')
        ..write(DateFormat('dd-MM-yyyy HH:mm').format(v))
        ..write(' | ');
      return;
    }
    if (v is num) {
      buf.write(v.toString());
      // Versi berformat (50.000) & tanpa ".0" supaya angka diskon/harga
      // bisa ditemukan baik diketik "50000" maupun "50.000".
      if (v is double && v == v.truncateToDouble()) {
        buf.write(' ${v.toInt()}');
      }
      buf.write(' ${_num.format(v)} | ');
      return;
    }
    final s = v.toString().trim();
    if (s.isEmpty) return;
    buf.write('$s | ');
  }

  static void addRow(StringBuffer buf, Map<String, dynamic> row) {
    for (final v in row.values) {
      _addValue(buf, v);
    }
  }

  /// [parent] = baris utama, [children] = baris dari tabel relasi,
  /// [extra] = teks tambahan (mis. kode "C5", "aktif").
  static String build(
    Map<String, dynamic> parent, {
    Iterable<Map<String, dynamic>> children = const [],
    Iterable<String> extra = const [],
  }) {
    final buf = StringBuffer();
    for (final e in extra) {
      if (e.isNotEmpty) buf.write('$e | ');
    }
    addRow(buf, parent);
    for (final c in children) {
      addRow(buf, c);
    }
    return buf.toString().toLowerCase();
  }

  /// Cocokkan [rawQuery] dengan [indexText]. Kalau query berisi beberapa
  /// kata, SEMUA kata harus ada (di field mana pun). Awalan berlabel
  /// seperti "PIC: Budi" juga diterima -- label sebelum ":" diabaikan.
  static bool matches(String indexText, String rawQuery) {
    var q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    final colon = q.lastIndexOf(':');
    if (colon >= 0 && colon < q.length - 1) {
      q = q.substring(colon + 1).trim();
    }
    if (q.isEmpty) return true;
    if (indexText.contains(q)) return true;
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    return tokens.every(indexText.contains);
  }

  /// Kelompokkan baris relasi berdasarkan kolom foreign key.
  static Map<int, List<Map<String, dynamic>>> groupBy(
    List<Map<String, dynamic>> rows,
    String fkColumn,
  ) {
    final out = <int, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      final k = r[fkColumn];
      final id = k is int ? k : int.tryParse('$k');
      if (id == null) continue;
      out.putIfAbsent(id, () => []).add(r);
    }
    return out;
  }
}
