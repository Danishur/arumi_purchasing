/// Model 1 baris data pada tabel `dropdown_options` -- satu nilai
/// pilihan di salah satu dropdown aplikasi (mis. 1 baris "Toko" untuk
/// kategori `vendor_legal_standing`).
///
/// TAMBAHAN: dipakai oleh fitur Settings > Edit Dropdown supaya isi
/// semua dropdown di form Customer/Vendor/Material/RFQ/Update Valuta
/// bisa diedit sendiri oleh user tanpa update aplikasi.
class DropdownOption {
  final int? id;
  final String category;
  final String value;

  DropdownOption({this.id, required this.category, required this.value});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'value': value,
    };
  }

  factory DropdownOption.fromMap(Map<String, dynamic> map) {
    return DropdownOption(
      id: map['id'] as int?,
      category: (map['category'] as String?) ?? '',
      value: (map['value'] as String?) ?? '',
    );
  }
}
