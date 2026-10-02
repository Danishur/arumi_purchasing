/// Satu baris Material yang dipilih di dalam 1 RFQ, lengkap dengan
/// Quantity & Unit -- sesuai revisi owner: Quantity & Unit dipindah
/// dari Material ke RFQ, karena jumlahnya ditentukan per permintaan
/// (RFQ), bukan melekat ke data master Material. 1 RFQ boleh punya
/// lebih dari 1 Material (multi-select "Material List").
class RfqMaterialLine {
  final int? id;
  final int? rfqId;
  final int materialId;
  final int quantity;
  final String? unit;

  // Hanya untuk tampilan & Export Excel (hasil JOIN ke tabel
  // materials/vendors saat query), TIDAK ikut dikirim balik ke
  // database lewat toMap().
  final String? materialCode;
  final String? itemDescription;
  final double unitPrice; // dari materials.total_price
  final String? vendorName;

  RfqMaterialLine({
    this.id,
    this.rfqId,
    required this.materialId,
    this.quantity = 0,
    this.unit,
    this.materialCode,
    this.itemDescription,
    this.unitPrice = 0,
    this.vendorName,
  });

  /// Label ringkas buat ditampilkan di list/picker, mis. "Besi Hollow (MATL1)".
  String get displayLabel {
    final desc = (itemDescription ?? '').trim();
    final code = materialCode ?? 'MATL$materialId';
    return desc.isEmpty ? code : '$desc ($code)';
  }

  /// Subtotal = Qty x Harga Satuan -- dipakai di Export Excel.
  double get subtotal => quantity * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rfq_id': rfqId,
      'material_id': materialId,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory RfqMaterialLine.fromMap(Map<String, dynamic> map) {
    return RfqMaterialLine(
      id: map['id'] as int?,
      rfqId: map['rfq_id'] as int?,
      materialId: map['material_id'] as int,
      quantity: _readInt(map['quantity']),
      unit: map['unit'] as String?,
      materialCode: map['material_id'] == null ? null : 'MATL${map['material_id']}',
      itemDescription: map['item_description'] as String?,
      unitPrice: _readDouble(map['material_total_price']),
      vendorName: map['vendor_name'] as String?,
    );
  }

  static int _readInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _readDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
