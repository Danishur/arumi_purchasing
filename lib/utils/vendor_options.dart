import 'dropdown_options_cache.dart';

/// Daftar pilihan untuk field-field dropdown/multi-select di form
/// Vendor.
///
/// TAMBAHAN: isinya SEKARANG diambil dari tabel `dropdown_options`
/// (lewat [DropdownOptionsCache]), bisa diedit sendiri oleh user lewat
/// Settings > Edit Dropdown > Vendor tanpa update aplikasi. Class ini
/// sengaja dipertahankan sebagai getter statis supaya semua pemakaian
/// lama (`VendorOptions.legalStanding`, dst) tidak perlu diubah.
class VendorOptions {
  static List<String> get legalStanding => DropdownOptionsCache.get('vendor_legal_standing');

  static List<String> get termsOfPayment => DropdownOptionsCache.get('vendor_terms_of_payment');

  // SENGAJA satu kategori dengan MaterialOptions.scopeOfWork/subSow di
  // bawah -- Material Form pilih dari list yang sama (lihat catatan di
  // material_options.dart), jadi edit dari salah satu Settings > Edit
  // Dropdown (Vendor ATAU Material) otomatis berlaku untuk keduanya.
  static List<String> get scopeOfWork => DropdownOptionsCache.get('scope_of_work');

  static List<String> get subSow => DropdownOptionsCache.get('sub_sow');

  static List<String> get supplyChainClassification =>
      DropdownOptionsCache.get('vendor_supply_chain_classification');

  // SENGAJA satu kategori dengan currency di Material Form (Price Quote
  // Currency) & Settings > Update Valuta.
  static List<String> get currency => DropdownOptionsCache.get('currency');
}
