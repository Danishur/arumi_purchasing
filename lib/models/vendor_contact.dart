/// PIC (Person In Charge) milik satu Vendor. Satu vendor boleh punya
/// lebih dari 1 PIC -- pola persis sama seperti CustomerContact.
class VendorContact {
  final int? id;
  final int? vendorId;
  final String picName;
  final String position; // Posisi / Jabatan -- isian bebas, bukan dropdown
  final String contact; // No. HP
  final String email;

  VendorContact({
    this.id,
    this.vendorId,
    required this.picName,
    this.position = '',
    this.contact = '',
    this.email = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'pic_name': picName,
      'pic_position': position,
      'pic_contact': contact,
      'pic_email': email,
    };
  }

  factory VendorContact.fromMap(Map<String, dynamic> map) {
    return VendorContact(
      id: map['id'] as int?,
      vendorId: map['vendor_id'] as int?,
      picName: (map['pic_name'] as String?) ?? '',
      position: (map['pic_position'] as String?) ?? '',
      contact: (map['pic_contact'] as String?) ?? '',
      email: (map['pic_email'] as String?) ?? '',
    );
  }
}
