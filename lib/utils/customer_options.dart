import 'dropdown_options_cache.dart';

/// Daftar pilihan untuk field "Terms of Payment" dan "Customer Type" di
/// form Customer.
///
/// TAMBAHAN: isinya SEKARANG diambil dari tabel `dropdown_options`
/// (lewat [DropdownOptionsCache]), bisa diedit sendiri oleh user lewat
/// Settings > Edit Dropdown > Customer tanpa update aplikasi. Class ini
/// sengaja dipertahankan sebagai getter statis supaya semua pemakaian
/// lama (`CustomerOptions.termsOfPayment`, dst) tidak perlu diubah.
class CustomerOptions {
  static List<String> get termsOfPayment => DropdownOptionsCache.get('customer_terms_of_payment');

  static List<String> get customerType => DropdownOptionsCache.get('customer_customer_type');
}
