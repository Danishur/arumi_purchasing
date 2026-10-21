import 'package:intl/intl.dart';
import '../models/material_discount.dart';
import '../models/material_item.dart';
import 'export_helpers.dart';

final _rupiahFmt = NumberFormat.decimalPattern('id_ID');
String _rupiah(double v) => 'Rp ${_rupiahFmt.format(v)}';

/// TAMBAHAN: Export Excel Rekap (dari mode select di Material List) &
/// Export PDF (dari Material Detail).
class MaterialExport {
  static Future<String?> exportExcelRekap(List<MaterialItem> materials) async {
    final rows = materials
        .map((m) => [
              m.materialCode,
              m.itemDescription ?? '-',
              m.category ?? '-',
              m.vendorName ?? '-',
              m.totalPrice,
              m.vat ? 'Yes' : 'No',
              m.dpp,
              m.vatValue,
              m.leadTimeDays,
              m.isActive ? 'Aktif' : 'Nonaktif',
            ])
        .toList();

    final fileName = materials.length == 1
        ? '${materials.first.materialCode}_rekap.xlsx'
        : 'Material_Rekap_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

    return ExportHelpers.saveExcelRekap(
      title: '',
      headers: [
        'Material Code',
        'Item Description',
        'Category',
        'Vendor',
        'Total Price',
        'VAT',
        'DPP',
        'VAT Value',
        'Lead Time (Hari)',
        'Status',
      ],
      rows: rows,
      fileName: fileName,
      sheetName: 'Material Rekap',
    );
  }

  static Future<String?> exportPdfDetail(MaterialItem material, List<MaterialDiscount> discounts) async {
    return ExportHelpers.savePdfDetail(
      docTitle: 'MATERIAL DETAIL',
      subtitle: '${material.materialCode} • ${material.itemDescription ?? '-'}',
      fields: [
        MapEntry('Registered Item', material.materialCode),
        MapEntry('Vendor', material.vendorName ?? '-'),
        MapEntry('Item Description', material.itemDescription ?? '-'),
        MapEntry('Category', material.category ?? '-'),
        MapEntry('Item Manufacturer', material.itemManufacturer ?? '-'),
        MapEntry('Origin Country', material.originCountry ?? '-'),
        MapEntry('Item Part Number', material.itemPartNumber ?? '-'),
        MapEntry('Total Price', _rupiah(material.totalPrice)),
        MapEntry('VAT', material.vat ? 'Yes' : 'No'),
        MapEntry('DPP', _rupiah(material.dpp)),
        MapEntry('VAT Value', _rupiah(material.vatValue)),
        MapEntry('Lead Time (Hari)', '${material.leadTimeDays}'),
        MapEntry('Delivery Terms', material.deliveryTerms ?? '-'),
        MapEntry('Delivery Address', material.deliveryAddress ?? '-'),
        MapEntry('Documents', material.documents.isEmpty ? '-' : material.documents.join(', ')),
        MapEntry('Status', material.isActive ? 'Aktif' : 'Nonaktif'),
      ],
      tables: [
        PdfTableSection(
          title: 'Rincian Diskon',
          headers: ['No', 'Jumlah', 'Tanggal'],
          rows: discounts
              .asMap()
              .entries
              .map((e) => [
                    '${e.key + 1}',
                    _rupiah(e.value.amount),
                    e.value.date == null ? '-' : DateFormat('dd/MM/yyyy').format(e.value.date!),
                  ])
              .toList(),
        ),
      ],
      fileName: '${material.materialCode}.pdf',
    );
  }
}
