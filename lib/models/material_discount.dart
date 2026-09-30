/// Satu baris diskon di form Material ("+ Add Discount"). 1 material
/// boleh punya lebih dari 1 diskon (Diskon 1, Diskon 2, Diskon 3, dst),
/// masing-masing dengan nominal & tanggal update sendiri.
class MaterialDiscount {
  final int? id;
  final int? materialId;
  final double amount;
  final DateTime? date;

  MaterialDiscount({
    this.id,
    this.materialId,
    this.amount = 0,
    this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'material_id': materialId,
      'discount_amount': amount,
      'discount_date': date == null
          ? null
          : '${date!.year.toString().padLeft(4, '0')}-'
              '${date!.month.toString().padLeft(2, '0')}-'
              '${date!.day.toString().padLeft(2, '0')}',
    };
  }

  factory MaterialDiscount.fromMap(Map<String, dynamic> map) {
    return MaterialDiscount(
      id: map['id'] as int?,
      materialId: map['material_id'] as int?,
      amount: _readDouble(map['discount_amount']),
      date: _readDate(map['discount_date']),
    );
  }

  static double _readDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
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
}
