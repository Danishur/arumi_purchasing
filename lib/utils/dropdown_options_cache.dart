import '../services/database_service.dart';

/// Cache in-memory untuk isi semua dropdown yang sekarang disimpan di
/// tabel `dropdown_options` (lihat Settings > Edit Dropdown) dan bisa
/// diedit sendiri oleh user tanpa update aplikasi.
///
/// SENGAJA dibuat static (bukan Provider/ChangeNotifier biasa) supaya
/// CustomerOptions/VendorOptions/MaterialOptions/RfqOptions bisa tetap
/// dipakai persis seperti sebelumnya (`VendorOptions.legalStanding` dkk)
/// di SEMUA form yang sudah ada -- tidak satupun form screen perlu
/// diubah untuk fitur ini.
///
/// `defaultValues` di bawah ini SEKALIGUS jadi: (1) nilai seed pertama
/// kali tabel `dropdown_options` kosong/baru dibuat, dan (2) fallback
/// kalau koneksi database lagi tidak tersedia saat app dibuka, supaya
/// app tetap bisa jalan normal seperti sebelum fitur ini ada.
class DropdownOptionsCache {
  DropdownOptionsCache._();

  static final Map<String, List<String>> _cache = {};
  static bool _loaded = false;

  // CATATAN kategori yang dipakai BERSAMA oleh lebih dari 1 modul
  // (sesuai desain form yang sudah ada sebelumnya):
  // - `scope_of_work` & `sub_sow`   -> dipakai Vendor Form & Material Form
  // - `material_documents`         -> dipakai Material Form (field
  //   "Documents") & RFQ Form (field "Document Requirement")
  // - `currency`                   -> dipakai Vendor Form (Bank Account
  //   Currency), Material Form (Price Quote Currency), & Update Valuta
  // Mengedit salah satu field itu dari Settings > Edit Dropdown otomatis
  // berlaku juga untuk field lain yang satu kategori -- sama seperti
  // perilaku app sebelum fitur ini ada (dulu sama-sama baca 1 const
  // list yang sama).
  static const Map<String, List<String>> defaultValues = {
    'customer_terms_of_payment': [
      '15 Days after invoice',
      '30 Days after invoice received',
      '45 Days after invoice received',
      '60 Days after invoice received',
      '90 Days after invoice received',
      'Cash before delivery',
      'DP 50; Balance before delivery',
      'DP 30; Balance before delivery',
      'SCF 30 Days after invoice received',
    ],
    'customer_customer_type': ['BUMN', 'Swasta', 'Kawasan Berikat'],
    'vendor_legal_standing': ['Toko', 'PT', 'CV', 'Perorangan', 'UD', 'Ltd', 'Koperasi'],
    'vendor_terms_of_payment': [
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
    ],
    'scope_of_work': ['Warehouse', 'Trucking', 'Shipping', 'Industrial'],
    'sub_sow': [
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
      'Spare',
    ],
    'vendor_supply_chain_classification': [
      'Principle',
      'Distributor',
      'Agen',
      'Reseller',
      'Packager / Fabricator',
      'Rental',
      'Installer / Service',
      'Unclassified',
    ],
    'currency': ['IDR', 'USD', 'SGD', 'GPB', 'EUR', 'AUD', 'HKD', 'JPY', 'MYR'],
    'material_category': ['Genuine', 'OEM', 'Private Label', 'Non-Brand'],
    'material_documents': [
      'Certificate of Manufacture',
      'Certificate of Origin (by Chamber)',
      'Certificate of Compliance',
      'Certificate of Conformity',
      'MSDS',
      'Mill Test Certificate',
      'Guarantee Letter',
    ],
    'rfq_status': ['Clarification-Customer', 'Clarification-Vendor', 'Complete', 'Canceled'],
  };

  /// Dipanggil sekali waktu app baru dibuka (lihat main.dart). Memuat
  /// semua kategori dari tabel `dropdown_options`; kalau tabel masih
  /// kosong (pertama kali fitur ini jalan), otomatis di-seed dulu dari
  /// [defaultValues] supaya isi dropdown tetap sama seperti sebelumnya.
  static Future<void> loadAll() async {
    try {
      var rows = await DatabaseService.instance.getAllDropdownOptions();
      if (rows.isEmpty) {
        for (final entry in defaultValues.entries) {
          for (final value in entry.value) {
            await DatabaseService.instance.insertDropdownOption(entry.key, value);
          }
        }
        rows = await DatabaseService.instance.getAllDropdownOptions();
      }
      _cache.clear();
      for (final row in rows) {
        final category = row['category'] as String;
        _cache.putIfAbsent(category, () => []).add(row['value'] as String);
      }
      _loaded = true;
    } catch (_) {
      // Database belum bisa diakses saat app dibuka (mis. masih
      // konek) -- biarkan cache kosong, getter di bawah otomatis balik
      // ke defaultValues supaya form tetap bisa dipakai normal.
    }
  }

  /// Dipanggil layar Edit Dropdown tiap habis tambah/edit/hapus data,
  /// supaya form lain yang dibuka SETELAHNYA langsung lihat perubahan
  /// tanpa perlu restart app.
  static Future<void> refreshCategory(String category) async {
    final rows = await DatabaseService.instance.getDropdownOptionsByCategory(category);
    _cache[category] = rows.map((r) => r['value'] as String).toList();
  }

  static bool get isLoaded => _loaded;

  static List<String> get(String category) {
    final cached = _cache[category];
    if (cached == null || cached.isEmpty) {
      return List<String>.from(defaultValues[category] ?? const []);
    }
    return cached;
  }
}
