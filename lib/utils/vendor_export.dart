import 'package:intl/intl.dart';
import '../models/vendor.dart';
import '../models/vendor_bank_account.dart';
import '../models/vendor_contact.dart';
import '../models/vendor_product.dart';
import 'export_helpers.dart';

/// TAMBAHAN: Export Excel Rekap (dari mode select di Vendor List) &
/// Export PDF (dari Vendor Detail).
class VendorExport {
  static Future<String?> exportExcelRekap(List<Vendor> vendors) async {
    final rows = vendors
        .map((v) => [
              v.vendorCode,
              v.vendorName,
              v.legalStanding ?? '-',
              v.npwp ?? '-',
              v.isVerified ? 'Verified' : 'Unverified',
              v.termsOfPayment ?? '-',
              v.supplyChainClassification ?? '-',
              v.isActive ? 'Aktif' : 'Nonaktif',
            ])
        .toList();

    final fileName = vendors.length == 1
        ? '${vendors.first.vendorCode}_rekap.xlsx'
        : 'Vendor_Rekap_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

    return ExportHelpers.saveExcelRekap(
      title: '',
      headers: [
        'Vendor ID',
        'Nama',
        'Legal Standing',
        'NPWP',
        'Verified',
        'Terms of Payment',
        'Supply Chain Classification',
        'Status',
      ],
      rows: rows,
      fileName: fileName,
      sheetName: 'Vendor Rekap',
    );
  }

  static Future<String?> exportPdfDetail(
    Vendor vendor,
    List<VendorContact> contacts,
    List<VendorProduct> products,
    List<VendorBankAccount> bankAccounts,
  ) async {
    return ExportHelpers.savePdfDetail(
      docTitle: 'VENDOR DETAIL',
      subtitle: '${vendor.vendorCode} • ${vendor.vendorName}',
      fields: [
        MapEntry('Vendor Name', vendor.vendorName),
        MapEntry('Vendor ID', vendor.vendorCode),
        MapEntry('Legal Standing', vendor.legalStanding ?? '-'),
        MapEntry('NPWP', vendor.npwp ?? '-'),
        MapEntry('Verified', vendor.isVerified ? 'Verified' : 'Unverified'),
        MapEntry('Terms of Payment', vendor.termsOfPayment ?? '-'),
        MapEntry('Produk / Brand', products.isEmpty ? '-' : products.map((p) => p.productName).join(', ')),
        MapEntry('Scope of Work', vendor.scopeOfWork.isEmpty ? '-' : vendor.scopeOfWork.join(', ')),
        MapEntry('Sub-SoW', vendor.subSow.isEmpty ? '-' : vendor.subSow.join(', ')),
        MapEntry('Supply Chain Classification', vendor.supplyChainClassification ?? '-'),
        MapEntry('Vendor Address', vendor.vendorAddress ?? '-'),
        MapEntry('PIC-Website', vendor.picWebsite ?? '-'),
        MapEntry('Status', vendor.isActive ? 'Aktif' : 'Nonaktif'),
      ],
      tables: [
        PdfTableSection(
          title: 'PIC & Contact PIC',
          headers: ['Nama', 'Posisi', 'No. HP', 'Email'],
          rows: contacts
              .map((c) => [
                    c.picName.isEmpty ? '-' : c.picName,
                    c.position.isEmpty ? '-' : c.position,
                    c.contact.isEmpty ? '-' : c.contact,
                    c.email.isEmpty ? '-' : c.email,
                  ])
              .toList(),
        ),
        PdfTableSection(
          title: 'Bank Information',
          headers: ['Bank', 'Account Number', 'Account Holder', 'Currency', 'SWIFT Code'],
          rows: bankAccounts
              .map((b) => [
                    b.bankName.isEmpty ? '-' : b.bankName,
                    b.accountNumber.isEmpty ? '-' : b.accountNumber,
                    b.accountHolder.isEmpty ? '-' : b.accountHolder,
                    b.currency ?? '-',
                    b.swiftCode.isEmpty ? '-' : b.swiftCode,
                  ])
              .toList(),
        ),
      ],
      fileName: '${vendor.vendorCode}.pdf',
    );
  }
}
