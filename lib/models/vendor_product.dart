/// Satu baris Produk / Brand milik Vendor. Sesuai catatan di sketsa
/// form: "bisa ditambah / dikurangi, bisa lebih dari 1" -- makanya
/// disimpan sebagai daftar (tabel terpisah), bukan 1 kolom teks.
class VendorProduct {
  final int? id;
  final int? vendorId;
  final String productName;

  VendorProduct({this.id, this.vendorId, required this.productName});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'product_name': productName,
    };
  }

  factory VendorProduct.fromMap(Map<String, dynamic> map) {
    return VendorProduct(
      id: map['id'] as int?,
      vendorId: map['vendor_id'] as int?,
      productName: (map['product_name'] as String?) ?? '',
    );
  }
}
