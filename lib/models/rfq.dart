import 'rfq_material.dart';

/// Model RFQ (Request for Quotation).
///
/// Map key di `toMap()`/`fromMap()` dibuat sama persis dengan nama
/// kolom tabel `rfqs` -- pola sama seperti Vendor & Material.
class Rfq {
  final int? id;
  final String? reference;
  final String? pic;
  final DateTime? dateRequest;
  final DateTime? dueDate;
  final int? customerId;
  // Hanya untuk tampilan (hasil LEFT JOIN ke tabel customers saat
  // query), TIDAK ikut dikirim balik ke database lewat toMap().
  final String? customerName;
  final String? internalNote;
  final String? status; // Clarification-Customer / Clarification-Vendor / Complete / Canceled
  final DateTime? updatedAt;

  /// Dimuat terpisah (query lain ke tabel rfq_materials, JOIN ke materials).
  final List<RfqMaterialLine> materialLines;

  Rfq({
    this.id,
    this.reference,
    this.pic,
    this.dateRequest,
    this.dueDate,
    this.customerId,
    this.customerName,
    this.internalNote,
    this.status,
    this.updatedAt,
    this.materialLines = const [],
  });

  /// RFQ Number yang ditampilkan ke user, mis. "RFQ12".
  /// Diturunkan dari `id` (sama seperti pola Customer/Vendor/Material ID).
  String get rfqCode => id != null ? 'RFQ$id' : '-';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reference': reference,
      'pic': pic,
      'date_request': dateRequest == null ? null : _dateOnly(dateRequest!),
      'due_date': dueDate == null ? null : _dateOnly(dueDate!),
      'customer_id': customerId,
      'internal_note': internalNote,
      'status': status,
    };
  }

  factory Rfq.fromMap(Map<String, dynamic> map) {
    return Rfq(
      id: map['id'] as int?,
      reference: map['reference'] as String?,
      pic: map['pic'] as String?,
      dateRequest: _readDate(map['date_request']),
      dueDate: _readDate(map['due_date']),
      customerId: map['customer_id'] as int?,
      customerName: map['customer_name'] as String?,
      internalNote: map['internal_note'] as String?,
      status: map['status'] as String?,
      updatedAt: map['updated_at'] is DateTime ? map['updated_at'] as DateTime : null,
    );
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) => identical(this, other) || (other is Rfq && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
