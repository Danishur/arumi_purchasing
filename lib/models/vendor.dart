import 'vendor_contact.dart';
import 'vendor_product.dart';

/// Model Vendor (data master supplier/vendor).
///
/// CATATAN: berbeda dengan modul Customer (yang sempat kena bug nama
/// kolom tidak cocok karena tabelnya sudah ada duluan sebelum model
/// dibuat), di sini map key di `toMap()`/`fromMap()` SENGAJA dibuat
/// SAMA PERSIS dengan nama kolom tabel `vendors` di database supaya
/// tidak ada celah salah mapping seperti sebelumnya.
class Vendor {
  final int? id;
  final String vendorName;
  final String? legalStanding;
  final String? npwp;
  final bool isVerified;
  final String? termsOfPayment;
  final List<String> scopeOfWork;
  final List<String> subSow;
  final String? supplyChainClassification;
  final String? internalNote;
  final String? vendorAddress;
  final String? picWebsite;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountHolder;
  final String? bankCurrency;
  final String? bankSwiftCode;
  final bool isActive;
  final DateTime? updatedAt;

  /// Dimuat terpisah (query lain), bukan bagian dari tabel `vendors`.
  final List<VendorContact> contacts;
  final List<VendorProduct> products;

  Vendor({
    this.id,
    required this.vendorName,
    this.legalStanding,
    this.npwp,
    this.isVerified = false,
    this.termsOfPayment,
    this.scopeOfWork = const [],
    this.subSow = const [],
    this.supplyChainClassification,
    this.internalNote,
    this.vendorAddress,
    this.picWebsite,
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountHolder,
    this.bankCurrency,
    this.bankSwiftCode,
    this.isActive = true,
    this.updatedAt,
    this.contacts = const [],
    this.products = const [],
  });

  /// Vendor ID yang ditampilkan ke user, mis. "V5". Diturunkan dari
  /// `id` di database (sama seperti pola Customer ID "C1").
  String get vendorCode => id != null ? 'V$id' : '-';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_name': vendorName,
      'legal_standing': legalStanding,
      'npwp': npwp,
      'is_verified': isVerified ? 1 : 0,
      'terms_of_payment': termsOfPayment,
      'scope_of_work': scopeOfWork.join(','),
      'sub_sow': subSow.join(','),
      'supply_chain_classification': supplyChainClassification,
      'internal_note': internalNote,
      'vendor_address': vendorAddress,
      'pic_website': picWebsite,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_account_holder': bankAccountHolder,
      'bank_currency': bankCurrency,
      'bank_swift_code': bankSwiftCode,
      'status': isActive ? 1 : 0,
    };
  }

  factory Vendor.fromMap(
    Map<String, dynamic> map, {
    List<VendorContact> contacts = const [],
    List<VendorProduct> products = const [],
  }) {
    return Vendor(
      id: map['id'] as int?,
      vendorName: (map['vendor_name'] as String?) ?? '',
      legalStanding: map['legal_standing'] as String?,
      npwp: map['npwp'] as String?,
      isVerified: _readBool(map['is_verified']),
      termsOfPayment: map['terms_of_payment'] as String?,
      scopeOfWork: _splitCsv(map['scope_of_work']),
      subSow: _splitCsv(map['sub_sow']),
      supplyChainClassification: map['supply_chain_classification'] as String?,
      internalNote: map['internal_note'] as String?,
      vendorAddress: map['vendor_address'] as String?,
      picWebsite: map['pic_website'] as String?,
      bankName: map['bank_name'] as String?,
      bankAccountNumber: map['bank_account_number'] as String?,
      bankAccountHolder: map['bank_account_holder'] as String?,
      bankCurrency: map['bank_currency'] as String?,
      bankSwiftCode: map['bank_swift_code'] as String?,
      // Dukung dua-duanya (defensif, sama seperti pola Customer): driver
      // MySQL kadang balikin TINYINT(1) sebagai int, kadang sebagai bool.
      isActive: _readBool(map['status']),
      updatedAt: map['updated_at'] is DateTime ? map['updated_at'] as DateTime : null,
      contacts: contacts,
      products: products,
    );
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  static List<String> _splitCsv(dynamic value) {
    if (value == null) return [];
    final text = value.toString().trim();
    if (text.isEmpty) return [];
    return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Vendor && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
