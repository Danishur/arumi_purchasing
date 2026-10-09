/// Satu rekening bank milik Vendor. Sebelumnya cuma 1 set field di
/// tabel `vendors` langsung -- sekarang dipisah jadi tabel sendiri
/// (pola sama seperti VendorContact/VendorProduct) supaya 1 vendor
/// bisa punya lebih dari 1 rekening ("Add Bank Information").
class VendorBankAccount {
  final int? id;
  final int? vendorId;
  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final String? currency;
  final String swiftCode;

  VendorBankAccount({
    this.id,
    this.vendorId,
    this.bankName = '',
    this.accountNumber = '',
    this.accountHolder = '',
    this.currency,
    this.swiftCode = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_holder': accountHolder,
      'currency': currency,
      'swift_code': swiftCode,
    };
  }

  factory VendorBankAccount.fromMap(Map<String, dynamic> map) {
    return VendorBankAccount(
      id: map['id'] as int?,
      vendorId: map['vendor_id'] as int?,
      bankName: (map['bank_name'] as String?) ?? '',
      accountNumber: (map['account_number'] as String?) ?? '',
      accountHolder: (map['account_holder'] as String?) ?? '',
      currency: map['currency'] as String?,
      swiftCode: (map['swift_code'] as String?) ?? '',
    );
  }
}
