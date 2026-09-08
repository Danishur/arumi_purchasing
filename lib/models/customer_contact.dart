/// Model PIC & Kontak milik 1 Customer.
///
/// Satu Customer boleh punya BANYAK CustomerContact (relasi
/// one-to-many), sesuai permintaan owner: 1 customer bisa ada beberapa
/// PIC, masing-masing dengan kontaknya sendiri, tapi data customer
/// induknya (nama, NPWP, alamat, dst) tetap sama.
class CustomerContact {
  final int? id;
  final int? customerId;
  final String picName;
  // BARU: Posisi / Jabatan -- diketik bebas oleh user, bukan pilihan
  // dari dropdown/list.
  final String position;
  final String contact; // No. HP PIC
  final String email; // BARU: Email PIC

  CustomerContact({
    this.id,
    this.customerId,
    required this.picName,
    this.position = '',
    required this.contact,
    this.email = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'pic_name': picName,
      'pic_position': position,
      'contact': contact,
      'pic_email': email,
    };
  }

  factory CustomerContact.fromMap(Map<String, dynamic> map) {
    return CustomerContact(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int?,
      picName: (map['pic_name'] as String?) ?? '',
      position: (map['pic_position'] as String?) ?? '',
      // BUG FIX: kolom di tabel `customer_contacts` namanya `pic_contact`,
      // bukan `contact` -- sebelumnya ini bikin nomor HP/email PIC selalu
      // hilang begitu data dimuat ulang dari database.
      contact: ((map['pic_contact'] ?? map['contact']) as String?) ?? '',
      email: (map['pic_email'] as String?) ?? '',
    );
  }

  CustomerContact copyWith({
    String? picName,
    String? position,
    String? contact,
    String? email,
  }) {
    return CustomerContact(
      id: id,
      customerId: customerId,
      picName: picName ?? this.picName,
      position: position ?? this.position,
      contact: contact ?? this.contact,
      email: email ?? this.email,
    );
  }
}
