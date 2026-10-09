/// Nilai tukar 1 mata uang ke IDR, diisi manual lewat Settings ->
/// Update Valuta. Dipakai buat mengkonversi "Price - Quote" di
/// Material Form yang diisi dalam mata uang asing menjadi IDR
/// otomatis.
class CurrencyRate {
  final int? id;
  final String currencyCode; // IDR, USD, EUR, dst -- sama dengan VendorOptions.currency
  final double rateToIdr; // nilai 1 unit currency ini dalam Rupiah
  final DateTime? updatedAt;

  CurrencyRate({
    this.id,
    required this.currencyCode,
    required this.rateToIdr,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'currency_code': currencyCode,
      'rate_to_idr': rateToIdr,
    };
  }

  factory CurrencyRate.fromMap(Map<String, dynamic> map) {
    return CurrencyRate(
      id: map['id'] as int?,
      currencyCode: (map['currency_code'] as String?) ?? '',
      rateToIdr: _readDouble(map['rate_to_idr']),
      updatedAt: map['updated_at'] is DateTime ? map['updated_at'] as DateTime : null,
    );
  }

  static double _readDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
