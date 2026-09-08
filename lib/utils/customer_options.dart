/// Daftar pilihan tetap untuk field "Terms of Payment" dan
/// "Customer Type" di form Customer, sesuai referensi desain yang
/// diberikan.
///
/// CATATAN: untuk sekarang daftar ini di-hardcode di sini (bukan tabel
/// database terpisah), karena isinya relatif tetap/standar dan supaya
/// modul Customer minggu ini bisa selesai lebih cepat. Kalau ke depannya
/// daftar ini perlu bisa diedit sendiri oleh user tanpa update aplikasi,
/// gampang diubah jadi tabel MySQL (`terms_of_payment`, `customer_types`)
/// -- tinggal ganti isi 2 list ini jadi hasil query, kode form-nya tidak
/// perlu diubah sama sekali.
class CustomerOptions {
  static const List<String> termsOfPayment = [
    '15 Days after invoice',
    '30 Days after invoice received',
    '45 Days after invoice received',
    '60 Days after invoice received',
    '90 Days after invoice received',
    'Cash before delivery',
    'DP 50; Balance before delivery',
    'DP 30; Balance before delivery',
    'SCF 30 Days after invoice received',
  ];

  static const List<String> customerType = [
    'BUMN',
    'Swasta',
    'Kawasan Berikat',
  ];
}
