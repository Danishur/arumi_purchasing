import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/rfq.dart';
import '../models/rfq_material.dart';
import '../services/database_service.dart';
import 'full_export.dart';
import 'search_index.dart';

/// Hasil export: path file kalau berhasil disimpan, null kalau user
/// membatalkan dialog simpan file.
///
/// TAMBAHAN: ada 2 jenis export Excel untuk RFQ sekarang --
/// 1. [export] (dulu namanya "Export Excel", sekarang disebut "Export
///    Excel Satuan") -- 1 file per RFQ, detail lengkap tiap Material
///    (vendor, TOP, VAT, delivery, berat, dimensi, dokumen). Tombolnya
///    di RFQ Detail, paling bawah.
/// 2. [exportRecap] -- gabungan beberapa RFQ sekaligus (dipilih lewat
///    mode select di RFQ List) jadi 1 file rekap ringkas (1 baris per
///    Material per RFQ). Tombolnya muncul di AppBar RFQ List saat mode
///    select aktif & ada yang dicentang.
class RfqExcelExporter {
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  static void _setCell(Sheet sheet, int col, int row, dynamic value, {CellStyle? style}) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    if (value is num) {
      cell.value = DoubleCellValue(value.toDouble());
    } else {
      cell.value = TextCellValue(value?.toString() ?? '-');
    }
    if (style != null) cell.cellStyle = style;
  }

  static Future<String?> _saveDialog(Excel excel, String defaultFileName) async {
    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Gagal membuat file Excel.');
    }
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan Export RFQ',
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (outputPath == null) return null; // user membatalkan dialog
    final path = outputPath.toLowerCase().endsWith('.xlsx') ? outputPath : '$outputPath.xlsx';
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    return path;
  }

  /// "Export Excel Satuan" -- 1 RFQ, detail lengkap per Material
  /// (REVISI: sekarang ikut nampilin Kode Vendor, Vendor, Terms of
  /// Payment, VAT, Delivery, Berat, Dimensi, Document Requirement & Document Available -- sebelumnya cuma
  /// Material/Qty/Unit/Harga Satuan/Toko/Subtotal).
  static Future<String?> export(Rfq rfq, List<RfqMaterialLine> lines) async {
    final excel = Excel.createExcel();
    final sheetName = rfq.rfqCode;
    final sheet = excel[sheetName];
    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    final bold = CellStyle(bold: true);
    void setCell(int col, int row, dynamic value, {CellStyle? style}) =>
        _setCell(sheet, col, row, value, style: style);

    // --- Judul & Header info RFQ ---
    setCell(0, 0, 'RFQ Number', style: bold);
    setCell(1, 0, rfq.rfqCode);
    // setCell(4, 0, 'HASIL EXPORT RFQ SATUAN', style: CellStyle(bold: true, fontSize: 16));
    setCell(0, 1, 'Reference', style: bold);
    setCell(1, 1, rfq.reference ?? '-');
    setCell(0, 2, 'Customer', style: bold);
    setCell(1, 2, rfq.customerName ?? '-');
    setCell(0, 3, 'PIC', style: bold);
    setCell(1, 3, rfq.pic ?? '-');
    setCell(0, 4, 'Date Request', style: bold);
    setCell(1, 4, rfq.dateRequest == null ? '-' : _dateFmt.format(rfq.dateRequest!));
    setCell(0, 5, 'Due Date', style: bold);
    setCell(1, 5, rfq.dueDate == null ? '-' : _dateFmt.format(rfq.dueDate!));
    setCell(0, 6, 'Status', style: bold);
    setCell(1, 6, rfq.status ?? '-');
    setCell(0, 7, 'Update Data', style: bold);
    setCell(1, 7, rfq.updatedAt == null ? '-' : DateFormat('dd/MM/yyyy HH:mm').format(rfq.updatedAt!));

    // --- Tabel Material List (format baru, lebih lengkap) ---
    const tableHeaderRow = 9;
    const headers = [
      'No',
      'Kode Vendor',
      'Vendor',
      'Terms of Payment',
      'Material',
      'Qty',
      'Unit',
      'Harga Satuan',
      'Subtotal',
      'VAT',
      'Delivery',
      'Berat',
      'Satuan Berat',
      'Dimensi P',
      'Dimensi L',
      'Dimensi T',
      'Satuan Dimensi',
      'Document Requirement',
      'Document Available',
    ];
    for (var i = 0; i < headers.length; i++) {
      setCell(i, tableHeaderRow, headers[i], style: bold);
    }

    var row = tableHeaderRow + 1;
    double grandSubtotal = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      setCell(0, row, i + 1);
      setCell(1, row, line.vendorCode);
      setCell(2, row, line.vendorName ?? '-');
      setCell(3, row, line.termsOfPayment ?? '-');
      setCell(4, row, line.itemDescription ?? line.materialCode ?? 'MATL${line.materialId}');
      setCell(5, row, line.quantity);
      setCell(6, row, line.unit ?? '-');
      setCell(7, row, line.unitPrice);
      setCell(8, row, line.subtotal);
      setCell(9, row, line.vat ? 'Yes' : 'No');
      setCell(10, row, line.deliveryTerms ?? '-');
      setCell(11, row, line.weight ?? '-');
      setCell(12, row, line.weightUnit ?? '-');
      setCell(13, row, line.dimP ?? '-');
      setCell(14, row, line.dimL ?? '-');
      setCell(15, row, line.dimT ?? '-');
      setCell(16, row, line.dimUnit ?? '-');
      // REVISI: kolom "Dokumen" dipecah jadi 2 -- Document Requirement
      // (dari RFQ, sama di semua baris) & Document Available (dari
      // Material di baris itu).
      setCell(17, row, rfq.documentRequirement.isEmpty ? '-' : rfq.documentRequirement.join(', '));
      setCell(18, row, line.documents.isEmpty ? '-' : line.documents.join(', '));
      grandSubtotal += line.subtotal;
      row++;
    }

    row++; // baris kosong pemisah
    setCell(7, row, 'Total', style: bold);
    setCell(8, row, grandSubtotal, style: bold);

    // --- Internal Note (kalau ada) ---
    row += 2;
    setCell(0, row, 'Internal Note', style: bold);
    setCell(1, row, rfq.internalNote ?? '-');

    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, i == 4 ? 28 : 16);
    }

    return _saveDialog(excel, '${rfq.rfqCode}_satuan.xlsx');
  }

  /// "Export Excel Rekap" -- gabungan beberapa RFQ terpilih jadi 1
  /// file, 1 baris per Material per RFQ (RFQ tanpa Material tetap
  /// muncul 1 baris dengan kolom Material kosong).
  ///
  /// REVISI: sekarang memuat SELURUH data -- semua kolom tabel `rfqs`
  /// (customer, reference, PIC, tanggal, Document Requirement, Internal
  /// Note, Status, created_at/updated_at kalau ada) + semua kolom baris
  /// Material List (qty, unit, harga satuan, vendor, TOP, VAT, delivery,
  /// berat, dimensi, Document Available, ...) + Subtotal & baris Total.
  /// Parameter [linesByRfq] dipertahankan supaya pemanggil lama tetap
  /// jalan, tapi data diambil langsung dari database.
  static Future<String?> exportRecap(
    List<Rfq> rfqs,
    Map<int, List<RfqMaterialLine>> linesByRfq,
  ) async {
    final ids = rfqs.map((r) => r.id).whereType<int>().toSet();
    final db = DatabaseService.instance;
    final parents = (await db.getRfqs()).where((r) => ids.contains(r['id'])).toList();
    final lineGroups = SearchIndex.groupBy(await db.getAllRfqMaterialLines(), 'rfq_id');

    const headParent = ['customer_name', 'reference', 'pic', 'date_request', 'due_date'];
    const headLine = ['item_description', 'quantity', 'unit'];

    final parentKeys = FullExport.orderedKeys(parents, first: headParent);
    final allLines = <Map<String, dynamic>>[
      for (final p in parents) ...(lineGroups[p['id']] ?? const []),
    ];
    final lineKeys = FullExport.orderedKeys(
      allLines,
      first: headLine,
      skip: const {'id', 'rfq_id'},
    );

    final firstParent = parentKeys.where(headParent.contains).toList();
    final restParent = parentKeys.where((k) => !headParent.contains(k)).toList();
    final firstLine = lineKeys.where(headLine.contains).toList();
    final restLine = lineKeys.where((k) => !headLine.contains(k)).toList();

    final headers = <String>[
      'RFQ Number',
      ...firstParent.map(FullExport.headerOf),
      ...firstLine.map(FullExport.headerOf),
      'Nilai (Subtotal)',
      ...restParent.map(FullExport.headerOf),
      ...restLine.map(FullExport.headerOf),
    ];

    final rows = <List<dynamic>>[];
    double grandTotal = 0;
    for (final p in parents) {
      final id = p['id'];
      final lines = lineGroups[id] ?? const <Map<String, dynamic>>[];
      final code = id is int ? 'RFQ$id' : '-';
      final items = lines.isEmpty ? <Map<String, dynamic>?>[null] : lines;
      for (final line in items) {
        double subtotal = 0;
        if (line != null) {
          final q = line['quantity'];
          final pr = line['material_total_price'];
          final qn = q is num ? q.toDouble() : double.tryParse('$q') ?? 0;
          final pn = pr is num ? pr.toDouble() : double.tryParse('$pr') ?? 0;
          subtotal = qn * pn;
          grandTotal += subtotal;
        }
        rows.add([
          code,
          for (final k in firstParent) FullExport.cell(k, p[k]),
          for (final k in firstLine) line == null ? '-' : FullExport.cell(k, line[k]),
          line == null ? '-' : subtotal,
          for (final k in restParent) FullExport.cell(k, p[k]),
          for (final k in restLine) line == null ? '-' : FullExport.cell(k, line[k]),
        ]);
      }
    }

    // Baris Total di kolom "Nilai (Subtotal)".
    final totalRow = List<dynamic>.filled(headers.length, '');
    final nilaiIdx = headers.indexOf('Nilai (Subtotal)');
    if (nilaiIdx > 0) {
      totalRow[nilaiIdx - 1] = 'Total';
      totalRow[nilaiIdx] = grandTotal;
    }
    rows.add(totalRow);

    final fileName = rfqs.length == 1
        ? '${rfqs.first.rfqCode}_rekap.xlsx'
        : 'RFQ_Rekap_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

    return FullExport.write(
      headers: headers,
      rows: rows,
      fileName: fileName,
      sheetName: 'RFQ Rekap',
      boldLastRow: true,
    );
  }
}
