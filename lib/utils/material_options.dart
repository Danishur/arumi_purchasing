import 'dropdown_options_cache.dart';

/// Daftar pilihan untuk field-field dropdown/multi-select di form
/// Material.
///
/// TAMBAHAN: `category` & `documents` SEKARANG diambil dari tabel
/// `dropdown_options` (lewat [DropdownOptionsCache]), bisa diedit
/// sendiri oleh user lewat Settings > Edit Dropdown > Material tanpa
/// update aplikasi. `unit`, `dimensionUnit`, & `weightUnit` masih tetap
/// hardcode seperti sebelumnya (belum termasuk daftar yang diminta
/// untuk bisa diedit).
class MaterialOptions {
  static List<String> get category => DropdownOptionsCache.get('material_category');

  static const List<String> unit = [
    'Ea',
    'Lot',
    'Set',
    'Length-M',
    'Length-MM',
    'Length-CM',
    'Unit',
    'Can',
  ];

  static const List<String> dimensionUnit = ['MM', 'CM', 'M'];

  static const List<String> weightUnit = ['KG', 'TON', 'LBS'];

  // SENGAJA satu kategori dengan RfqOptions "Document Requirement" --
  // lihat catatan di rfq_options.dart.
  static List<String> get documents => DropdownOptionsCache.get('material_documents');

  // Scope of Work & Sub-SoW di Material SENGAJA pakai daftar yang SAMA
  // dengan VendorOptions.scopeOfWork / VendorOptions.subSow (sumbernya
  // sama, cuma di Material dipilih single/satu saja, bukan multi) --
  // lihat pemakaiannya di material_form_screen.dart.
}
