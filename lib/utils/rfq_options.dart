import 'dropdown_options_cache.dart';

/// Daftar pilihan untuk field "Status" di form RFQ.
///
/// TAMBAHAN: isinya SEKARANG diambil dari tabel `dropdown_options`
/// (lewat [DropdownOptionsCache]), bisa diedit sendiri oleh user lewat
/// Settings > Edit Dropdown > RFQ tanpa update aplikasi.
///
/// CATATAN: "Document Requirement" di form RFQ SENGAJA pakai daftar
/// yang SAMA dengan MaterialOptions.documents (kategori
/// `material_documents`) -- jadi tidak ada getter terpisah di sini,
/// lihat pemakaiannya di rfq_form_screen.dart. "Unit" di form RFQ
/// (dipilih per baris Material List) juga masih SAMA dengan
/// MaterialOptions.unit -- tidak diduplikasi di sini.
class RfqOptions {
  static List<String> get status => DropdownOptionsCache.get('rfq_status');
}
