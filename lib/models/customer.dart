import 'customer_contact.dart';

/// Model Customer (data master pembeli/klien PT).
class Customer {
  final int? id;
  final String name;
  final String? npwpNumber;
  final String? termsOfPayment;
  final String? customerType;
  final String? address;
  final bool isActive;

  /// Daftar PIC & kontak milik customer ini. Dimuat terpisah (query
  /// kedua ke tabel customer_contacts), bukan bagian dari tabel
  /// `customers` itu sendiri.
  final List<CustomerContact> contacts;

  Customer({
    this.id,
    required this.name,
    this.npwpNumber,
    this.termsOfPayment,
    this.customerType,
    this.address,
    this.isActive = true,
    this.contacts = const [],
  });

  /// Customer ID yang ditampilkan ke user, mis. "C17". Diturunkan dari
  /// `id` di database (bukan kolom tersendiri) supaya selalu unik
  /// otomatis tanpa perlu penomoran manual terpisah.
  String get customerCode => id != null ? 'C$id' : '-';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'npwp_number': npwpNumber,
      'terms_of_payment': termsOfPayment,
      'customer_type': customerType,
      'address': address,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map, {List<CustomerContact> contacts = const []}) {
    return Customer(
      id: map['id'] as int?,
      // BUG FIX: tabel MySQL `customers` pakai nama kolom `customer_name`,
      // `npwp`, dan `status` -- bukan `name`, `npwp_number`, `is_active`.
      // Sebelumnya baris ini baca key yang salah sehingga SELALU balik
      // null/kosong tiap kali data dimuat ulang dari database (makanya
      // Customer Name & NPWP hilang ketika buka lagi data yang sudah
      // disimpan). Dukung kedua nama key (kolom DB & key toMap() lokal)
      // supaya tetap aman dipakai untuk sumber data mana pun.
      name: ((map['customer_name'] ?? map['name']) as String?) ?? '',
      npwpNumber: (map['npwp'] ?? map['npwp_number']) as String?,
      termsOfPayment: map['terms_of_payment'] as String?,
      customerType: map['customer_type'] as String?,
      address: map['address'] as String?,
      // BUG FIX (defensif): kolom TINYINT(1) dari MySQL kadang kebaca
      // sebagai int (0/1), kadang sebagai bool tergantung driver --
      // ditangani dua-duanya di sini supaya tidak crash gara-gara type
      // cast yang keliru.
      isActive: _readBool(map['status'] ?? map['is_active']),
      contacts: contacts,
    );
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return true; // default aman: dianggap aktif kalau tidak jelas
  }

  Customer copyWith({
    String? name,
    String? npwpNumber,
    String? termsOfPayment,
    String? customerType,
    String? address,
    bool? isActive,
    List<CustomerContact>? contacts,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      npwpNumber: npwpNumber ?? this.npwpNumber,
      termsOfPayment: termsOfPayment ?? this.termsOfPayment,
      customerType: customerType ?? this.customerType,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      contacts: contacts ?? this.contacts,
    );
  }

  // Dibutuhkan supaya DropdownButton<Customer> (kalau dipakai di modul
  // lain nanti, mis. RFQ) tetap bisa mencocokkan value-nya dengan benar
  // walau provider reload data dan membuat instance Customer baru.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Customer && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
