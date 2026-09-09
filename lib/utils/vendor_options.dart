/// Daftar pilihan tetap untuk field-field dropdown/multi-select di form
/// Vendor, sesuai data yang dikirim (screenshot referensi desain).
///
/// CATATAN: sama seperti CustomerOptions, di-hardcode dulu di sini
/// (bukan tabel database terpisah) supaya modul Vendor bisa selesai
/// lebih cepat. Gampang dipindah ke tabel MySQL nanti kalau perlu bisa
/// diedit sendiri oleh user tanpa update aplikasi.
class VendorOptions {
  static const List<String> legalStanding = [
    'Toko',
    'PT',
    'CV',
    'Perorangan',
    'UD',
    'Ltd',
    'Koperasi',
  ];

  static const List<String> termsOfPayment = [
    'Cash',
    'TOP 7 Days',
    'TOP 14 Days',
    'TOP 21 Days',
    'TOP 30 Days',
    'TOP 60 Days',
    'TOP 45 Days',
    '20-80',
    '25-75',
    '30-70',
    '40-60',
    '50-50',
    '60-40',
    '30-Balance TOP 30 Days',
    '50-Balance TOP 30 Days',
    '50-Balance TOP 60 Days',
    '50-Balance TOP 90 Days',
  ];

  static const List<String> scopeOfWork = [
    'Warehouse',
    'Trucking',
    'Shipping',
    'Industrial',
  ];

  static const List<String> subSow = [
    'Sparepart',
    'Undercarriage',
    'Tools',
    'Consumable',
    'Electrical',
    'Mechanical',
    'Civil',
    'Safety',
    'Tire',
    'Raw material',
    'Service / Jasa',
    'Fire suppression',
    'Engine (Set)',
    // CATATAN: di foto referensi item terakhir tertulis "spae" (tulisan
    // tangan/terpotong) -- kemungkinan besar maksudnya "Spare". Kalau
    // salah, tinggal ganti teksnya di sini, tidak perlu ubah kode lain.
    'Spare',
  ];

  static const List<String> supplyChainClassification = [
    'Principle',
    'Distributor',
    'Agen',
    'Reseller',
    'Packager / Fabricator',
    'Rental',
    'Installer / Service',
    'Unclassified',
  ];

  static const List<String> currency = [
    'IDR',
    'USD',
    'SGD',
    'GPB',
    'EUR',
    'AUD',
    'HKD',
    'JPY',
    'MYR',
    // CATATAN: daftar di foto referensi terpotong (ada scroll ke bawah
    // setelah MYR) -- tambahkan currency lain di sini kalau ada yang
    // kurang, formatnya sama (kode 3 huruf).
  ];
}
