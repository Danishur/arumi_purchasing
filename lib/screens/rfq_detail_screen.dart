import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/rfq.dart';
import '../models/rfq_material.dart';
import '../providers/rfq_provider.dart';
import '../utils/app_theme.dart';
import '../utils/rfq_excel_exporter.dart';
import 'rfq_form_screen.dart';

/// Layar Detail RFQ -- pola sama persis dengan
/// CustomerDetailScreen/VendorDetailScreen/MaterialDetailScreen: tap
/// di list = lihat Detail (bukan buka Form lagi), tombol pensil = buka
/// Form untuk edit.
class RfqDetailScreen extends StatefulWidget {
  final Rfq rfq;

  const RfqDetailScreen({super.key, required this.rfq});

  @override
  State<RfqDetailScreen> createState() => _RfqDetailScreenState();
}

class _RfqDetailScreenState extends State<RfqDetailScreen> {
  late Rfq _rfq;
  List<RfqMaterialLine> _lines = [];
  bool _loading = true;
  bool _hasError = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _rfq = widget.rfq;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final lines = await context.read<RfqProvider>().getMaterialLinesForRfq(_rfq.id!);
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.secondary,
      ),
    );
  }

  Future<void> _openEdit() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RfqFormScreen(rfq: _rfq)),
    );
    if (saved == true && mounted) {
      _changed = true;
      final refreshed = context.read<RfqProvider>().findById(_rfq.id!);
      setState(() => _rfq = refreshed ?? _rfq);
      _showSnack('RFQ berhasil diupdate.');
      await _load();
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus RFQ?'),
        content: Text(
          'Yakin ingin menghapus "${_rfq.rfqCode}"?\nSemua Material List yang terhubung juga akan ikut terhapus.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || _rfq.id == null || !mounted) return;

    try {
      await context.read<RfqProvider>().deleteRfq(_rfq.id!);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Gagal menghapus RFQ: $e', isError: true);
    }
  }

  String _formatDate(DateTime? dt) => dt == null ? '-' : DateFormat('dd/MM/yyyy').format(dt);
  String _formatDateTime(DateTime? dt) => dt == null ? '-' : DateFormat('dd/MM/yyyy HH:mm:ss').format(dt);

  Future<void> _exportExcel() async {
    try {
      final path = await RfqExcelExporter.export(_rfq, _lines);
      if (path == null) return; // user batal pilih lokasi simpan
      _showSnack('Export berhasil');
    } catch (e) {
      _showSnack('Gagal export Excel: $e', isError: true);
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'Complete':
        return AppColors.secondary;
      case 'Canceled':
        return AppColors.danger;
      case 'Clarification-Customer':
      case 'Clarification-Vendor':
        return AppColors.accent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _changed);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _changed),
          ),
          title: const Text('RFQ Detail'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Hapus', onPressed: _confirmDelete),
            IconButton(icon: const Icon(Icons.refresh), tooltip: 'Muat ulang', onPressed: _load),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.accent,
          onPressed: _openEdit,
          child: const Icon(Icons.edit, color: Colors.white),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  children: [
                    if (_rfq.status != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(_rfq.status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _rfq.status!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(_rfq.status),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _field('RFQ Number', _rfq.rfqCode),
                    _field('Reference', _rfq.reference),
                    _field('PIC', _rfq.pic),
                    _field('Date Request', _formatDate(_rfq.dateRequest)),
                    _field('Due Date', _formatDate(_rfq.dueDate)),
                    _field('Customer', _rfq.customerName),

                    const SizedBox(height: 8),
                    const Text('Material List',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    if (_hasError)
                      const Text('Gagal memuat Material List.',
                          style: TextStyle(color: AppColors.danger, fontSize: 13))
                    else if (_lines.isEmpty)
                      const Text('Belum ada Material dipilih.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13))
                    else
                      ..._lines.map(_materialLine),
                    const SizedBox(height: 16),

                    _field('Internal Note', _rfq.internalNote),
                    _field('Document Requirement',
                        _rfq.documentRequirement.isEmpty ? null : _rfq.documentRequirement.join(', ')),
                    _field('Updated data', _formatDateTime(_rfq.updatedAt)),

                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _exportExcel,
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('Export Excel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.secondary,
                          side: const BorderSide(color: AppColors.secondary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _field(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            (value == null || value.isEmpty) ? '-' : value,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _materialLine(RfqMaterialLine line) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        dense: true,
        title: Text(line.displayLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Qty: ${line.quantity}${line.unit != null ? ' ${line.unit}' : ''}',
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}
