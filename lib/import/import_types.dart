/// Tipe-tipe dasar fitur Settings > Update DB (import data lama dari
/// Excel).

/// 1 kolom di template Excel.
class ColumnSpec {
  final String key; // kunci internal, dipakai importer
  final String header; // judul kolom di template Excel
  final bool required;
  final String hint; // petunjuk isian (tampil di sheet "Petunjuk")
  final String example; // contoh isian (tampil di sheet "Contoh")

  const ColumnSpec(
    this.key,
    this.header, {
    this.required = false,
    this.hint = '',
    this.example = '',
  });

  /// Judul dinormalisasi (huruf kecil, tanpa spasi/tanda baca) supaya
  /// "Brand / Produk" dan "brand/produk" dianggap sama.
  static String normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

enum ImportModule { customer, vendor, material, rfq }

enum ImportStatus { ready, skipped, error }

/// Isi sheet Excel yang sudah dibaca: tiap baris = peta kunci kolom ->
/// teks sel. [rowNumbers] = nomor baris asli di Excel (baris 1 = judul).
class ParsedSheet {
  final List<Map<String, String>> rows;
  final List<int> rowNumbers;
  final List<String> missingRequiredColumns;
  final String sheetName;

  ParsedSheet({
    required this.rows,
    required this.rowNumbers,
    required this.missingRequiredColumns,
    required this.sheetName,
  });
}

/// 1 data hasil analisis (1 customer / 1 vendor / 1 material / 1 RFQ).
/// Beberapa baris Excel bisa jadi 1 data (mis. 1 customer dengan
/// banyak PIC).
class PreparedItem {
  final String label;
  final List<int> excelRows;
  ImportStatus status;
  String? message;

  /// Baris utama (kunci = nama kolom database, sesuai method insertXxx
  /// di DatabaseService).
  final Map<String, dynamic> data;

  /// Baris relasi: PIC / produk / bank / diskon / material RFQ.
  final Map<String, List<Map<String, dynamic>>> children;

  PreparedItem({
    required this.label,
    required this.excelRows,
    this.status = ImportStatus.ready,
    this.message,
    Map<String, dynamic>? data,
    Map<String, List<Map<String, dynamic>>>? children,
  })  : data = data ?? {},
        children = children ?? {};
}

class ImportPreview {
  final ImportModule module;
  final List<PreparedItem> items;
  final List<String> fileProblems; // masalah level file (kolom wajib hilang, dst)

  /// Nilai dropdown baru yang akan ditambahkan kalau opsi "tambah
  /// otomatis" aktif: kategori -> daftar nilai.
  final Map<String, List<String>> pendingDropdown;

  ImportPreview({
    required this.module,
    required this.items,
    this.fileProblems = const [],
    Map<String, List<String>>? pendingDropdown,
  }) : pendingDropdown = pendingDropdown ?? {};

  int get readyCount => items.where((i) => i.status == ImportStatus.ready).length;
  int get skippedCount => items.where((i) => i.status == ImportStatus.skipped).length;
  int get errorCount => items.where((i) => i.status == ImportStatus.error).length;
}

class ImportReport {
  final int success;
  final int skipped;
  final List<PreparedItem> failed; // gagal validasi + gagal saat simpan

  ImportReport({required this.success, required this.skipped, required this.failed});
}
