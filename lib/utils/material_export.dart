import 'package:intl/intl.dart';
import '../models/material_discount.dart';
import '../models/material_item.dart';
import 'export_helpers.dart';
import '../services/database_service.dart';
import 'full_export.dart';
import 'search_index.dart';

final _rupiahFmt = NumberFormat.decimalPattern('id_ID');
String _rupiah(double v) => 'Rp ${_rupiahFmt.format(v)}';

/// TAMBAHAN: Export Excel Rekap (dari mode select di Material List) &
/// Export PDF (dari Material Detail).
class MaterialExport {
  /// REVISI: Export Excel Rekap sekarang memuat SELURUH data material --
  /// semua kolom tabel `materials` (termasuk vendor, dimensi, berat,
  /// Document Available, created_at/updated_at kalau ada) + semua baris
  /// Discount (1 diskon = 1 baris di dalam sel). Kolom awal tetap
  /// berurutan: Material Code, Item Description, Category, Vendor,
  /// Price, Currency, Price IDR, VAT, DPP, VAT Value.
  static Future<String?> exportExcelRekap(List<MaterialItem> materials) async {
    final ids = materials.map((m) => m.id).whereType<int>().toSet();
    final db = DatabaseService.instance;
    final parents = (await db.getMaterials()).where((r) => ids.contains(r['id'])).toList();
    final discounts = SearchIndex.groupBy(await db.getAllChildRows('material_discounts'), 'material_id');

    final fileName = materials.length == 1
        ? '${materials.first.materialCode}_rekap.xlsx'
        : 'Material_Rekap_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

    return FullExport.saveWithChildren(
      parents: parents,
      codeHeader: 'Material Code',
      codeOf: (id) => 'MATL$id',
      children: [
        ChildSection(
          label: 'Discount',
          rowsByParent: discounts,
          skip: const {'id', 'material_id'},
        ),
      ],
      firstKeys: const [
        'item_description',
        'category',
        'vendor_name',
        'price_quote_foreign_amount',
        'price_quote_currency',
        'total_price',
        'vat',
        'dpp',
        'vat_value',
      ],
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
        MapEntry('Document Available', material.documents.isEmpty ? '-' : material.documents.join(', ')),
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
