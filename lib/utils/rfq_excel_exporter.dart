import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/rfq.dart';
import '../models/rfq_material.dart';

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
  /// Payment, VAT, Delivery, Berat, Dimensi, Dokumen -- sebelumnya cuma
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

    // --- Tabel Material List (format baru, lebih lengkap) ---
    const tableHeaderRow = 8;
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
      'Dokumen',
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
      setCell(17, row, line.documents.isEmpty ? '-' : line.documents.join(', '));
      grandSubtotal += line.subtotal;
      row++;
    }

    row++; // baris kosong pemisah
    setCell(7, row, 'Total', style: bold);
    setCell(8, row, grandSubtotal, style: bold);

    // --- Internal Note & Document Requirement (kalau ada) ---
    row += 2;
    setCell(0, row, 'Internal Note', style: bold);
    setCell(1, row, rfq.internalNote ?? '-');
    row++;
    setCell(0, row, 'Document Requirement', style: bold);
    setCell(1, row, rfq.documentRequirement.isEmpty ? '-' : rfq.documentRequirement.join(', '));

    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, i == 4 ? 28 : 16);
    }

    return _saveDialog(excel, '${rfq.rfqCode}_satuan.xlsx');
  }

  /// "Export Excel Rekap" -- gabungan beberapa RFQ terpilih jadi 1
  /// file, 1 baris per Material per RFQ (RFQ tanpa Material tetap
  /// muncul 1 baris kosong di kolom Material-nya).
  static Future<String?> exportRecap(
    List<Rfq> rfqs,
    Map<int, List<RfqMaterialLine>> linesByRfq,
  ) async {
    final excel = Excel.createExcel();
    const sheetName = 'RFQ Rekap';
    final sheet = excel[sheetName];
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bold = CellStyle(bold: true);
    void setCell(int col, int row, dynamic value, {CellStyle? style}) =>
        _setCell(sheet, col, row, value, style: style);

    setCell(0, 0, 'EXPORT RFQ REKAP', style: CellStyle(bold: true, fontSize: 16));

    const headers = [
      'RFQ Number',
      'Customer',
      'Reference',
      'PIC',
      'Date Request',
      'Due Date',
      'Material',
      'Qty',
      'Unit',
      'Nilai',
      'Internal Note',
      'Update Data',
      'Status',
    ];
    const headerRow = 2;
    for (var i = 0; i < headers.length; i++) {
      setCell(i, headerRow, headers[i], style: bold);
    }

    var row = headerRow + 1;
    double grandTotal = 0;
    for (final rfq in rfqs) {
      final lines = linesByRfq[rfq.id] ?? const <RfqMaterialLine>[];
      if (lines.isEmpty) {
        setCell(0, row, rfq.rfqCode);
        setCell(1, row, rfq.customerName ?? '-');
        setCell(2, row, rfq.reference ?? '-');
        setCell(3, row, rfq.pic ?? '-');
        setCell(4, row, rfq.dateRequest == null ? '-' : _dateFmt.format(rfq.dateRequest!));
        setCell(5, row, rfq.dueDate == null ? '-' : _dateFmt.format(rfq.dueDate!));
        setCell(6, row, '-');
        setCell(7, row, '-');
        setCell(8, row, '-');
        setCell(9, row, '-');
        setCell(10, row, rfq.internalNote ?? '-');
        setCell(11, row, rfq.updatedAt == null ? '-' : DateFormat('dd/MM/yyyy HH:mm').format(rfq.updatedAt!));
        setCell(12, row, rfq.status ?? '-');
        row++;
        continue;
      }
      for (final line in lines) {
        setCell(0, row, rfq.rfqCode);
        setCell(1, row, rfq.customerName ?? '-');
        setCell(2, row, rfq.reference ?? '-');
        setCell(3, row, rfq.pic ?? '-');
        setCell(4, row, rfq.dateRequest == null ? '-' : _dateFmt.format(rfq.dateRequest!));
        setCell(5, row, rfq.dueDate == null ? '-' : _dateFmt.format(rfq.dueDate!));
        setCell(6, row, line.itemDescription ?? line.materialCode ?? 'MATL${line.materialId}');
        setCell(7, row, line.quantity);
        setCell(8, row, line.unit ?? '-');
        setCell(9, row, line.subtotal);
        setCell(10, row, rfq.internalNote ?? '-');
        setCell(11, row, rfq.updatedAt == null ? '-' : DateFormat('dd/MM/yyyy HH:mm').format(rfq.updatedAt!));
        setCell(12, row, rfq.status ?? '-');
        grandTotal += line.subtotal;
        row++;
      }
    }

    row++;
    setCell(8, row, 'Total', style: bold);
    setCell(9, row, grandTotal, style: bold);

    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, i == 6 || i == 10 ? 28 : 16);
    }

    final fileName = rfqs.length == 1
        ? '${rfqs.first.rfqCode}_rekap.xlsx'
        : 'RFQ_Rekap_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    return _saveDialog(excel, fileName);
  }
}
