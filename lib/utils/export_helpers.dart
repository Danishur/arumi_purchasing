import 'dart:io';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Helper umum dipakai bareng oleh semua exporter (Customer/Vendor/
/// Material/RFQ) supaya tidak nulis ulang logic "bikin sheet Excel lalu
/// munculkan dialog Save File" / "bikin tabel PDF" di tiap modul.
class ExportHelpers {
  /// Bikin 1 file Excel (.xlsx) rekap sederhana: 1 judul, 1 baris
  /// header kolom, lalu baris data. Dipakai untuk fitur "Export Excel
  /// Rekap" di Customer/Vendor/Material/RFQ List (mode select).
  static Future<String?> saveExcelRekap({
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String fileName,
    String sheetName = 'Rekap',
  }) async {
    final excel = xl.Excel.createExcel();
    final sheet = excel[sheetName];
    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    final bold = xl.CellStyle(bold: true);
    void setCell(int col, int row, dynamic value, {xl.CellStyle? style}) {
      final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      if (value is num) {
        cell.value = xl.DoubleCellValue(value.toDouble());
      } else {
        cell.value = xl.TextCellValue(value?.toString() ?? '-');
      }
      if (style != null) cell.cellStyle = style;
    }

    setCell(0, 0, title, style: xl.CellStyle(bold: true, fontSize: 16));

    const headerRow = 2;
    for (var i = 0; i < headers.length; i++) {
      setCell(i, headerRow, headers[i], style: bold);
    }

    for (var r = 0; r < rows.length; r++) {
      final rowData = rows[r];
      for (var c = 0; c < rowData.length; c++) {
        setCell(c, headerRow + 1 + r, rowData[c]);
      }
    }

    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 20);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Gagal membuat file Excel.');

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan Export Excel Rekap',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (outputPath == null) return null;
    final path = outputPath.toLowerCase().endsWith('.xlsx') ? outputPath : '$outputPath.xlsx';
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    return path;
  }

  /// Bikin 1 file PDF detail sederhana: judul dokumen, daftar field
  /// (label-value), lalu 0 atau lebih tabel tambahan (mis. PIC, Bank
  /// Information, Rincian Diskon). Dipakai untuk fitur "Export PDF" di
  /// Customer/Vendor/Material Detail.
  static Future<String?> savePdfDetail({
    required String docTitle,
    required String subtitle,
    required List<MapEntry<String, String>> fields,
    List<PdfTableSection> tables = const [],
    required String fileName,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(docTitle, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text(subtitle, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            pw.SizedBox(height: 8),
            pw.Divider(),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Table(
            columnWidths: const {0: pw.FlexColumnWidth(1.4), 1: pw.FlexColumnWidth(2.6)},
            children: [
              for (final f in fields)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                      child: pw.Text(f.key, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                      child: pw.Text(f.value.isEmpty ? '-' : f.value, style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
            ],
          ),
          for (final t in tables) ...[
            pw.SizedBox(height: 14),
            pw.Text(t.title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    for (final h in t.headers)
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(h, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                      ),
                  ],
                ),
                if (t.rows.isEmpty)
                  pw.TableRow(
                    children: [
                      for (var i = 0; i < t.headers.length; i++)
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(i == 0 ? 'Belum ada data.' : '', style: const pw.TextStyle(fontSize: 9)),
                        ),
                    ],
                  )
                else
                  for (final row in t.rows)
                    pw.TableRow(
                      children: [
                        for (final cell in row)
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(cell, style: const pw.TextStyle(fontSize: 9)),
                          ),
                      ],
                    ),
              ],
            ),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan Export PDF',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (outputPath == null) return null;
    final path = outputPath.toLowerCase().endsWith('.pdf') ? outputPath : '$outputPath.pdf';
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    return path;
  }
}

/// Satu tabel tambahan di PDF detail (mis. daftar PIC, Bank Information).
class PdfTableSection {
  final String title;
  final List<String> headers;
  final List<List<String>> rows;

  PdfTableSection({required this.title, required this.headers, required this.rows});
}
