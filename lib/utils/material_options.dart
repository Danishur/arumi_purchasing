/// Daftar pilihan tetap untuk field-field dropdown/multi-select di form
/// Material, sesuai screenshot referensi desain yang dikirim.
class MaterialOptions {
  static const List<String> category = [
    'Genuine',
    'OEM',
    'Private Label',
    'Non-Brand',
  ];

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

  static const List<String> documents = [
    'Certificate of Manufacture',
    'Certificate of Origin (by Chamber)',
    'Certificate of Compliance',
    'Certificate of Conformity',
    'MSDS',
    'Mill Test Certificate',
    'Guarantee Letter',
  ];

  // Scope of Work & Sub-SoW di Material SENGAJA pakai daftar yang SAMA
  // dengan VendorOptions.scopeOfWork / VendorOptions.subSow (sumbernya
  // sama, cuma di Material dipilih single/satu saja, bukan multi) --
  // lihat pemakaiannya di material_form_screen.dart.
}
