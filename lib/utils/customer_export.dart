import 'package:intl/intl.dart';
import '../models/customer.dart';
import '../models/customer_contact.dart';
import 'export_helpers.dart';

/// TAMBAHAN: Export Excel Rekap (dari mode select di Customer List) &
/// Export PDF (dari Customer Detail).
class CustomerExport {
  static Future<String?> exportExcelRekap(List<Customer> customers) async {
    final rows = customers
        .map((c) => [
              c.customerCode,
              c.name,
              c.npwpNumber ?? '-',
              c.termsOfPayment ?? '-',
              c.customerType ?? '-',
              c.address ?? '-',
              c.isActive ? 'Aktif' : 'Nonaktif',
            ])
        .toList();

    final fileName = customers.length == 1
        ? '${customers.first.customerCode}_rekap.xlsx'
        : 'Customer_Rekap_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

    return ExportHelpers.saveExcelRekap(
      title: '',
      headers: ['Customer ID', 'Nama', 'NPWP', 'Terms of Payment', 'Tipe', 'Alamat', 'Status'],
      rows: rows,
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
