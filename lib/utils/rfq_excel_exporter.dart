import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/rfq.dart';
import '../models/rfq_material.dart';

/// Hasil export: path file kalau berhasil disimpan, null kalau user
/// membatalkan dialog simpan file.
class RfqExcelExporter {
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  /// Generate file Excel (.xlsx) dari 1 RFQ + Material List-nya, lalu
  /// minta user pilih lokasi simpan lewat dialog Save File bawaan
  /// Windows. Dipakai di tombol "Export Excel" -- baik yang di layar
  /// Data RFQ (list) maupun di RFQ Detail.
  static Future<String?> export(Rfq rfq, List<RfqMaterialLine> lines) async {
    final excel = Excel.createExcel();
    final sheetName = rfq.rfqCode;
    final sheet = excel[sheetName];
    // Sheet default bawaan package ("Sheet1") dibuang supaya yang
    // kebuka pas file di-double click langsung sheet data RFQ-nya.
    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    final bold = CellStyle(bold: true);

    void setCell(int col, int row, dynamic value, {CellStyle? style}) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      if (value is num) {
        cell.value = DoubleCellValue(value.toDouble());
      } else {
        cell.value = TextCellValue(value?.toString() ?? '-');
      }
      if (style != null) cell.cellStyle = style;
    }

    // --- Header info RFQ ---
    setCell(0, 0, 'RFQ Number', style: bold);
    setCell(1, 0, rfq.rfqCode);
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

    // --- Tabel Material List ---
    const tableHeaderRow = 8;
    const headers = ['No', 'Material', 'Qty', 'Unit', 'Harga Satuan', 'Toko / Supplier', 'Subtotal'];
    for (var i = 0; i < headers.length; i++) {
      setCell(i, tableHeaderRow, headers[i], style: bold);
    }

    var row = tableHeaderRow + 1;
    double grandTotal = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      setCell(0, row, i + 1);
      setCell(1, row, line.itemDescription ?? line.materialCode ?? 'MATL${line.materialId}');
      setCell(2, row, line.quantity);
      setCell(3, row, line.unit ?? '-');
      setCell(4, row, line.unitPrice);
      setCell(5, row, line.vendorName ?? '-');
      setCell(6, row, line.subtotal);
      grandTotal += line.subtotal;
      row++;
    }

    row++; // baris kosong pemisah
    setCell(5, row, 'Total', style: bold);
    setCell(6, row, grandTotal, style: bold);

    // --- Internal Note (kalau ada) ---
    row += 2;
    setCell(0, row, 'Internal Note', style: bold);
    setCell(1, row, rfq.internalNote ?? '-');

    // Lebar kolom supaya rapi & tidak terpotong.
    sheet.setColumnWidth(0, 14);
    sheet.setColumnWidth(1, 32);
    sheet.setColumnWidth(2, 10);
    sheet.setColumnWidth(3, 10);
    sheet.setColumnWidth(4, 16);
    sheet.setColumnWidth(5, 22);
    sheet.setColumnWidth(6, 16);

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Gagal membuat file Excel.');
    }

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan Export RFQ',
      fileName: '${rfq.rfqCode}.xlsx',
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
}
