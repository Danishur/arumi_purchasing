import 'material_discount.dart';

/// Model Material (data master barang/item).
///
/// CATATAN PENTING: class ini SENGAJA dinamai `MaterialItem`, BUKAN
/// `Material` -- karena `Material` sudah dipakai Flutter sendiri
/// sebagai nama widget (`Material(child: ...)` dari
/// `package:flutter/material.dart`, yang diimport di HAMPIR SEMUA
/// file). Kalau class ini dinamai `Material`, akan selalu bentrok
/// setiap kali file yang sama juga butuh widget Material bawaan
/// Flutter -- jadi nama `MaterialItem` di sini murni buat menghindari
/// tabrakan nama, isinya tetap data master Material.
///
/// Sama seperti Vendor, map key di `toMap()`/`fromMap()` dibuat SAMA
/// PERSIS dengan nama kolom tabel `materials` supaya tidak ada celah
/// salah mapping seperti yang sempat kejadian di modul Customer.
class MaterialItem {
  final int? id;
  final int? vendorId;
  // Hanya untuk tampilan (hasil LEFT JOIN ke tabel vendors saat query),
  // TIDAK ikut dikirim balik ke database lewat toMap().
  final String? vendorName;

  final String? scopeOfWork;
  final String? subSow;
  final String? brandUnitInstalledOn;
  final String? typeUnitInstalledOn;

  final String? itemDescription;
  final String? category; // Genuine / OEM / Private Label / Non-Brand
  final String? itemManufacturer;
  final String? originCountry;
  final String? itemType;
  final String? itemPartNumber;
  final String? size;
  final String? photoPath;
  final String? referenceGenuinePartNumber;
  final String? existingItemDescription;

  // CATATAN REVISI (dari owner): Quantity & Unit DIHAPUS dari Material,
  // dipindah ke RFQ -- karena quantity semestinya ditentukan per
  // permintaan (RFQ), bukan melekat ke data master Material. Kalau
  // quantity ditentukan di Material, repot saat repeat order dengan
  // quantity yang beda-beda. Lihat RfqMaterialLine di rfq_material.dart.

  final double priceQuote; // selalu dalam IDR (hasil konversi final)
  // REVISI: Price - Quote sekarang bisa diisi manual dalam mata uang
  // asing (ambil daftar dari Settings > Update Valuta / sama dengan
  // VendorOptions.currency) -- priceQuoteCurrency & priceQuoteForeign
  // Amount simpan apa yang diketik user (buat ditampilkan balik saat
  // edit), sedangkan priceQuote di atas tetap hasil konversi ke IDR
  // yang dipakai di semua kalkulasi lain (discount, total, DPP, VAT,
  // Excel export) supaya tidak perlu ubah logic di tempat lain.
  final String priceQuoteCurrency; // IDR, USD, dst
  final double priceQuoteForeignAmount; // nilai yang diketik manual, dalam priceQuoteCurrency
  final DateTime? priceQuoteDate;
  final double totalDiscount;
  final double priceDiscount; // harga akhir setelah diskon
  final double totalPrice; // ikut quote, atau ikut priceDiscount kalau ada diskon
  final bool vat;
  final double dpp;
  final double vatValue;

  final int leadTimeDays;
  final String? deliveryTerms; // Franco / Loco
  final String? deliveryAddress;

  final double? dimP;
  final double? dimL;
  final double? dimT;
  final String? dimUnit; // mm / cm / M
  final double? weight;
  final String? weightUnit; // kg / Ton / lbs

  final List<String> documents;
  final bool isTransaction; // N / Y
  final bool isActive;
  final DateTime? updatedAt;

  /// Dimuat terpisah (query lain ke tabel material_discounts).
  final List<MaterialDiscount> discounts;

  MaterialItem({
    this.id,
    this.vendorId,
    this.vendorName,
    this.scopeOfWork,
    this.subSow,
    this.brandUnitInstalledOn,
    this.typeUnitInstalledOn,
    this.itemDescription,
    this.category,
    this.itemManufacturer,
    this.originCountry,
    this.itemType,
    this.itemPartNumber,
    this.size,
    this.photoPath,
    this.referenceGenuinePartNumber,
    this.existingItemDescription,
    this.priceQuote = 0,
    this.priceQuoteCurrency = 'IDR',
    this.priceQuoteForeignAmount = 0,
    this.priceQuoteDate,
    this.totalDiscount = 0,
    this.priceDiscount = 0,
    this.totalPrice = 0,
    this.vat = false,
    this.dpp = 0,
    this.vatValue = 0,
    this.leadTimeDays = 0,
    this.deliveryTerms,
    this.deliveryAddress,
    this.dimP,
    this.dimL,
    this.dimT,
    this.dimUnit,
    this.weight,
    this.weightUnit,
    this.documents = const [],
    this.isTransaction = false,
    this.isActive = true,
    this.updatedAt,
    this.discounts = const [],
  });

  /// Registered Item / kode yang ditampilkan ke user, mis. "MATL43".
  /// Diturunkan dari `id` (sama seperti pola Customer ID/Vendor ID).
  String get materialCode => id != null ? 'MATL$id' : '-';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'scope_of_work': scopeOfWork,
      'sub_sow': subSow,
      'brand_unit_installed_on': brandUnitInstalledOn,
      'type_unit_installed_on': typeUnitInstalledOn,
      'item_description': itemDescription,
      'category': category,
      'item_manufacturer': itemManufacturer,
      'origin_country': originCountry,
      'item_type': itemType,
      'item_part_number': itemPartNumber,
      'size': size,
      'photo_path': photoPath,
      'reference_genuine_part_number': referenceGenuinePartNumber,
      'existing_item_description': existingItemDescription,
      'price_quote': priceQuote,
      'price_quote_currency': priceQuoteCurrency,
      'price_quote_foreign_amount': priceQuoteForeignAmount,
      'price_quote_date': priceQuoteDate == null ? null : _dateOnly(priceQuoteDate!),
      'total_discount': totalDiscount,
      'price_discount': priceDiscount,
      'total_price': totalPrice,
      'vat': vat ? 1 : 0,
      'dpp': dpp,
      'vat_value': vatValue,
      'lead_time_days': leadTimeDays,
      'delivery_terms': deliveryTerms,
      'delivery_address': deliveryAddress,
      'dim_p': dimP,
      'dim_l': dimL,
      'dim_t': dimT,
      'dim_unit': dimUnit,
      'weight': weight,
      'weight_unit': weightUnit,
      'documents': documents.join(','),
      'is_transaction': isTransaction ? 1 : 0,
      'status': isActive ? 1 : 0,
    };
  }

  factory MaterialItem.fromMap(
    Map<String, dynamic> map, {
    List<MaterialDiscount> discounts = const [],
  }) {
    return MaterialItem(
      id: map['id'] as int?,
      vendorId: map['vendor_id'] as int?,
      vendorName: map['vendor_name'] as String?,
      scopeOfWork: map['scope_of_work'] as String?,
      subSow: map['sub_sow'] as String?,
      brandUnitInstalledOn: map['brand_unit_installed_on'] as String?,
      typeUnitInstalledOn: map['type_unit_installed_on'] as String?,
      itemDescription: map['item_description'] as String?,
      category: map['category'] as String?,
      itemManufacturer: map['item_manufacturer'] as String?,
      originCountry: map['origin_country'] as String?,
      itemType: map['item_type'] as String?,
      itemPartNumber: map['item_part_number'] as String?,
      size: map['size'] as String?,
      photoPath: map['photo_path'] as String?,
      referenceGenuinePartNumber: map['reference_genuine_part_number'] as String?,
      existingItemDescription: map['existing_item_description'] as String?,
      priceQuote: _readDouble(map['price_quote']),
      priceQuoteCurrency: (map['price_quote_currency'] as String?) ?? 'IDR',
      priceQuoteForeignAmount: _readDouble(map['price_quote_foreign_amount']),
      priceQuoteDate: _readDate(map['price_quote_date']),
      totalDiscount: _readDouble(map['total_discount']),
      priceDiscount: _readDouble(map['price_discount']),
      totalPrice: _readDouble(map['total_price']),
      vat: _readBool(map['vat']),
      dpp: _readDouble(map['dpp']),
      vatValue: _readDouble(map['vat_value']),
      leadTimeDays: _readInt(map['lead_time_days']),
      deliveryTerms: map['delivery_terms'] as String?,
      deliveryAddress: map['delivery_address'] as String?,
      dimP: _readDoubleOrNull(map['dim_p']),
      dimL: _readDoubleOrNull(map['dim_l']),
      dimT: _readDoubleOrNull(map['dim_t']),
      dimUnit: map['dim_unit'] as String?,
      weight: _readDoubleOrNull(map['weight']),
      weightUnit: map['weight_unit'] as String?,
      documents: _splitCsv(map['documents']),
      isTransaction: _readBool(map['is_transaction']),
      isActive: _readBool(map['status']),
      updatedAt: map['updated_at'] is DateTime ? map['updated_at'] as DateTime : null,
      discounts: discounts,
    );
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  static int _readInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _readDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static double? _readDoubleOrNull(dynamic value) {
    if (value == null) return null;
    return _readDouble(value);
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  static List<String> _splitCsv(dynamic value) {
    if (value == null) return [];
    final text = value.toString().trim();
    if (text.isEmpty) return [];
    return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MaterialItem && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
