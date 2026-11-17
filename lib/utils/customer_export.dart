import 'package:intl/intl.dart';
import '../models/customer.dart';
import '../models/customer_contact.dart';
import 'export_helpers.dart';
import '../services/database_service.dart';
import 'full_export.dart';
import 'search_index.dart';

/// TAMBAHAN: Export Excel Rekap (dari mode select di Customer List) &
/// Export PDF (dari Customer Detail).
class CustomerExport {
  /// REVISI: Export Excel Rekap sekarang memuat SELURUH data customer --
  /// semua kolom tabel `customers` (termasuk created_at/updated_at kalau
  /// ada) + semua PIC/kontak (1 PIC = 1 baris di dalam sel, urutan sama
  /// di semua kolom PIC).
  static Future<String?> exportExcelRekap(List<Customer> customers) async {
    final ids = customers.map((c) => c.id).whereType<int>().toSet();
    final db = DatabaseService.instance;
    final parents = (await db.getCustomers()).where((r) => ids.contains(r['id'])).toList();
    final contacts = SearchIndex.groupBy(await db.getAllChildRows('customer_contacts'), 'customer_id');

    final fileName = customers.length == 1
        ? '${customers.first.customerCode}_rekap.xlsx'
        : 'Customer_Rekap_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

    return FullExport.saveWithChildren(
      parents: parents,
      codeHeader: 'Customer ID',
      codeOf: (id) => 'C$id',
      children: [
        ChildSection(
          label: 'PIC',
          rowsByParent: contacts,
          skip: const {'id', 'customer_id'},
        ),
      ],
      firstKeys: const [
        'customer_name',
        'npwp',
        'terms_of_payment',
        'customer_type',
        'address',
        'status',
      ],
      fileName: fileName,
      sheetName: 'Customer Rekap',
    );
  }

  static Future<String?> exportPdfDetail(Customer customer, List<CustomerContact> contacts) async {
    return ExportHelpers.savePdfDetail(
      docTitle: 'CUSTOMER DETAIL',
      subtitle: '${customer.customerCode} • ${customer.name}',
      fields: [
        MapEntry('Customer Name', customer.name),
        MapEntry('Customer ID', customer.customerCode),
        MapEntry('NPWP Number', customer.npwpNumber ?? '-'),
        MapEntry('Terms of Payment', customer.termsOfPayment ?? '-'),
        MapEntry('Customer Type', customer.customerType ?? '-'),
        MapEntry('Address', customer.address ?? '-'),
        MapEntry('Status', customer.isActive ? 'Aktif' : 'Nonaktif'),
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
      ],
      fileName: '${customer.customerCode}.pdf',
    );
  }
}
