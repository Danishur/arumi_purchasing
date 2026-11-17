import 'package:intl/intl.dart';
import '../models/vendor.dart';
import '../models/vendor_bank_account.dart';
import '../models/vendor_contact.dart';
import '../models/vendor_product.dart';
import 'export_helpers.dart';
import '../services/database_service.dart';
import 'full_export.dart';
import 'search_index.dart';

/// TAMBAHAN: Export Excel Rekap (dari mode select di Vendor List) &
/// Export PDF (dari Vendor Detail).
class VendorExport {
  /// REVISI: Export Excel Rekap sekarang memuat SELURUH data vendor --
  /// semua kolom tabel `vendors` (termasuk created_at/updated_at kalau
  /// ada) + semua PIC, Produk/Brand & Bank Information (1 item = 1 baris
  /// di dalam sel, urutan sama di semua kolom relasi yang sama).
  static Future<String?> exportExcelRekap(List<Vendor> vendors) async {
    final ids = vendors.map((v) => v.id).whereType<int>().toSet();
    final db = DatabaseService.instance;
    final parents = (await db.getVendors()).where((r) => ids.contains(r['id'])).toList();
    final contacts = SearchIndex.groupBy(await db.getAllChildRows('vendor_contacts'), 'vendor_id');
    final products = SearchIndex.groupBy(await db.getAllChildRows('vendor_products'), 'vendor_id');
    final banks = SearchIndex.groupBy(await db.getAllChildRows('vendor_bank_accounts'), 'vendor_id');

    final fileName = vendors.length == 1
        ? '${vendors.first.vendorCode}_rekap.xlsx'
        : 'Vendor_Rekap_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

    const skip = {'id', 'vendor_id'};
    return FullExport.saveWithChildren(
      parents: parents,
      codeHeader: 'Vendor ID',
      codeOf: (id) => 'V$id',
      children: [
        ChildSection(label: 'PIC', rowsByParent: contacts, skip: skip),
        ChildSection(label: 'Produk/Brand', rowsByParent: products, skip: skip),
        ChildSection(label: 'Bank', rowsByParent: banks, skip: skip),
      ],
      firstKeys: const [
        'vendor_name',
        'legal_standing',
        'npwp',
        'is_verified',
        'terms_of_payment',
        'scope_of_work',
        'sub_sow',
        'supply_chain_classification',
      ],
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
