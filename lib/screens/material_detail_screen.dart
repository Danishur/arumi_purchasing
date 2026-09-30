import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/material_discount.dart';
import '../models/material_item.dart';
import '../providers/material_provider.dart';
import '../utils/app_theme.dart';
import 'material_form_screen.dart';

final _rupiahFmt = NumberFormat.decimalPattern('id_ID');

/// Layar Detail Material -- pola sama persis dengan
/// CustomerDetailScreen/VendorDetailScreen: tap di list = lihat Detail
/// (bukan buka Form lagi), tombol pensil = buka Form untuk edit.
class MaterialDetailScreen extends StatefulWidget {
  final MaterialItem material;

  const MaterialDetailScreen({super.key, required this.material});

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  late MaterialItem _material;
  List<MaterialDiscount> _discounts = [];
  bool _loading = true;
  bool _hasError = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _material = widget.material;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final discounts = await context.read<MaterialProvider>().getDiscountsForMaterial(_material.id!);
      if (!mounted) return;
      setState(() {
        _discounts = discounts;
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
      MaterialPageRoute(builder: (_) => MaterialFormScreen(material: _material)),
    );
    if (saved == true && mounted) {
      _changed = true;
      final refreshed = context.read<MaterialProvider>().findById(_material.id!);
      setState(() => _material = refreshed ?? _material);
      _showSnack('Material berhasil diupdate.');
      await _load();
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Material?'),
        content: Text(
          'Yakin ingin menghapus "${_material.itemDescription ?? _material.materialCode}"?\n'
          'Semua data diskon yang terhubung juga akan ikut terhapus.',
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
    if (confirmed != true || _material.id == null || !mounted) return;

    try {
      await context.read<MaterialProvider>().deleteMaterial(_material.id!);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Gagal menghapus material: $e', isError: true);
    }
  }

  String _formatDate(DateTime? dt) => dt == null ? '-' : DateFormat('dd/MM/yyyy').format(dt);
  String _formatDateTime(DateTime? dt) => dt == null ? '-' : DateFormat('dd/MM/yyyy HH:mm:ss').format(dt);
  String _rupiah(double v) => 'Rp ${_rupiahFmt.format(v)}';

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
          title: const Text('Material Detail'),
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
                    Wrap(
                      spacing: 8,
                      children: [
                        _badge(_material.isActive ? 'Aktif' : 'Nonaktif', _material.isActive),
                        _badge(_material.isTransaction ? 'Transaction: Y' : 'Transaction: N',
                            _material.isTransaction),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _sectionTitle('Informasi Material'),
                    _field('Registered Item', _material.materialCode),
                    _field('Vendor', _material.vendorName),
                    _field('Scope of Work', _material.scopeOfWork),
                    _field('Sub-SOW', _material.subSow),
                    _field('Brand - unit installed on', _material.brandUnitInstalledOn),
                    _field('Type - unit installed on', _material.typeUnitInstalledOn),

                    _sectionTitle('Item Information'),
                    _field('Item Description', _material.itemDescription),
                    _field('Category', _material.category),
                    _field('Item Manufacturer', _material.itemManufacturer),
                    _field('Origin Country', _material.originCountry),
                    _field('Item Type', _material.itemType),
                    _field('Item Part Number', _material.itemPartNumber),
                    _field('Size', _material.size),
                    if ((_material.photoPath ?? '').isNotEmpty) _photoPreview(_material.photoPath!),
                    _field('Reference Genuine Part Number', _material.referenceGenuinePartNumber),
                    _field('Existing Item Description (if replacement)', _material.existingItemDescription),

                    _sectionTitle('Quantity & Price'),
                    _field('Quantity',
                        '${_material.quantity}${_material.unit != null ? ' ${_material.unit}' : ''}'),
                    _field('Price - Quote', _rupiah(_material.priceQuote)),
                    _field('Date Update (Quote)', _formatDate(_material.priceQuoteDate)),
                    _field('Total Discount', _rupiah(_material.totalDiscount)),
                    _field('Price - Discount', _rupiah(_material.priceDiscount)),
                    _field('Total Price', _rupiah(_material.totalPrice)),
                    _field('VAT', _material.vat ? 'Yes' : 'No'),
                    _field('DPP', _rupiah(_material.dpp)),
                    _field('VAT Value', _rupiah(_material.vatValue)),

                    if (_discounts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      const Text('Rincian Diskon',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      ..._discounts.asMap().entries.map((e) => _discountLine(e.key + 1, e.value)),
                      const SizedBox(height: 12),
                    ],

                    _sectionTitle('Delivery'),
                    _field('Lead time (Days)', '${_material.leadTimeDays}'),
                    _field('Delivery Terms', _material.deliveryTerms),
                    _field('Delivery Address', _material.deliveryAddress),

                    _sectionTitle('Packaging'),
                    _field(
                      'Dimension (P x L x T)',
                      (_material.dimP == null && _material.dimL == null && _material.dimT == null)
                          ? null
                          : '${_material.dimP ?? '-'} x ${_material.dimL ?? '-'} x ${_material.dimT ?? '-'} ${_material.dimUnit ?? ''}',
                    ),
                    _field(
                      'Weight',
                      _material.weight == null ? null : '${_material.weight} ${_material.weightUnit ?? ''}',
                    ),

                    _sectionTitle('Other'),
                    _field('Documents', _material.documents.isEmpty ? null : _material.documents.join(', ')),
                    _field('Updated data', _formatDateTime(_material.updatedAt)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
      ),
    );
  }

  Widget _badge(String text, bool positive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: positive ? AppColors.secondary.withOpacity(0.12) : Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: positive ? AppColors.secondary : Colors.grey.shade700,
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

  Widget _photoPreview(String path) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Photo',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 160,
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade100,
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _discountLine(int index, MaterialDiscount d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text('Diskon $index', style: const TextStyle(fontSize: 13))),
          Expanded(child: Text(_rupiah(d.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          Text(_formatDate(d.date), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
