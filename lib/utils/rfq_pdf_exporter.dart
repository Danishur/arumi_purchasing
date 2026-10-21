import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/rfq.dart';
import '../models/rfq_material.dart';

/// TAMBAHAN: Export PDF untuk RFQ -- format mengikuti contoh dokumen
/// "REQUEST FOR QUOTATION" yang dikirim user (judul di tengah, RFQ
/// Number di kiri atas, Date/Closing Date/Mail to di kanan atas, lalu
/// tabel No / Item Description / Qty / Unit). Tombolnya di RFQ Detail,
/// di bawah tombol "Export Excel Satuan".
class RfqPdfExporter {
  static final _dateFmt = DateFormat('MMM dd, yyyy');

  static Future<String?> export(Rfq rfq, List<RfqMaterialLine> lines) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(
                'REQUEST FOR QUOTATION',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(rfq.rfqCode, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Date: ${rfq.dateRequest == null ? '-' : _dateFmt.format(rfq.dateRequest!)}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Closing Date: ${rfq.dueDate == null ? '-' : _dateFmt.format(rfq.dueDate!)}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Mail to: purchasing@arumi-sn.com',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
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
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.6),
              1: pw.FlexColumnWidth(4),
              2: pw.FlexColumnWidth(0.8),
              3: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _th('No'),
                  _th('Item Description'),
                  _th('Qty'),
                  _th('Unit'),
                ],
              ),
              for (var i = 0; i < lines.length; i++)
                pw.TableRow(
                  children: [
                    _td('${i + 1}', align: pw.TextAlign.center),
                    _td(lines[i].itemDescription ?? lines[i].materialCode ?? 'MATL${lines[i].materialId}'),
                    _td('${lines[i].quantity}', align: pw.TextAlign.center),
                    _td(lines[i].unit ?? '-', align: pw.TextAlign.center),
                  ],
                ),
              if (lines.isEmpty)
                pw.TableRow(
                  children: [
                    _td(''),
                    _td('Belum ada Material dipilih.'),
                    _td(''),
                    _td(''),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 16),
          if (rfq.documentRequirement.isNotEmpty) ...[
            pw.Text('Document Requirement', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.SizedBox(height: 4),
            pw.Text(rfq.documentRequirement.join(', '), style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 12),
          ],
          if ((rfq.internalNote ?? '').isNotEmpty) ...[
            pw.Text('Note', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.SizedBox(height: 4),
            pw.Text(rfq.internalNote!, style: const pw.TextStyle(fontSize: 10)),
          ],
        ],
      ),
    );

    final bytes = await doc.save();

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan Export PDF RFQ',
      fileName: '${rfq.rfqCode}.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (outputPath == null) return null; // user membatalkan dialog

    final path = outputPath.toLowerCase().endsWith('.pdf') ? outputPath : '$outputPath.pdf';
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    return path;
  }

  static pw.Widget _th(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
    );
  }

  static pw.Widget _td(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9.5), textAlign: align),
    );
  }
}
