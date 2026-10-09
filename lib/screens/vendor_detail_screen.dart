import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/vendor.dart';
import '../models/vendor_bank_account.dart';
import '../models/vendor_contact.dart';
import '../models/vendor_product.dart';
import '../providers/vendor_provider.dart';
import '../utils/app_theme.dart';
import 'vendor_form_screen.dart';

/// Layar Detail Vendor -- pola sama persis dengan CustomerDetailScreen:
/// tap di list = lihat Detail (bukan buka Form lagi), tombol pensil =
/// buka Form untuk edit.
class VendorDetailScreen extends StatefulWidget {
  final Vendor vendor;

  const VendorDetailScreen({super.key, required this.vendor});

  @override
  State<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends State<VendorDetailScreen> {
  late Vendor _vendor;
  List<VendorContact> _contacts = [];
  List<VendorProduct> _products = [];
  List<VendorBankAccount> _bankAccounts = [];
  bool _loading = true;
  bool _hasError = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _vendor = widget.vendor;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final provider = context.read<VendorProvider>();
      final contacts = await provider.getContactsForVendor(_vendor.id!);
      final products = await provider.getProductsForVendor(_vendor.id!);
      final bankAccounts = await provider.getBankAccountsForVendor(_vendor.id!);
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _products = products;
        _bankAccounts = bankAccounts;
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
      MaterialPageRoute(builder: (_) => VendorFormScreen(vendor: _vendor)),
    );
    if (saved == true && mounted) {
      _changed = true;
      final refreshed = context.read<VendorProvider>().findById(_vendor.id!);
      setState(() => _vendor = refreshed ?? _vendor);
      _showSnack('Vendor berhasil diupdate.');
      await _load();
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Vendor?'),
        content: Text(
          'Yakin ingin menghapus "${_vendor.vendorName}"?\nSemua data PIC & Produk/Brand yang terhubung juga akan ikut terhapus.',
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
    if (confirmed != true || _vendor.id == null || !mounted) return;

    try {
      await context.read<VendorProvider>().deleteVendor(_vendor.id!);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Gagal menghapus vendor: $e', isError: true);
    }
  }

  String _formatUpdatedAt(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(dt);
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
          title: const Text('Vendor Detail'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus',
              onPressed: _confirmDelete,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Muat ulang',
              onPressed: _load,
            ),
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
                        _badge(_vendor.isActive ? 'Aktif' : 'Nonaktif', _vendor.isActive),
                        _badge(_vendor.isVerified ? 'Verified' : 'Unverified', _vendor.isVerified),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _field('Vendor Name', _vendor.vendorName),
                    _field('Vendor ID', _vendor.vendorCode),
                    _field('Legal Standing', _vendor.legalStanding),
                    _field('NPWP', _vendor.npwp),
                    _field('Term of Payment', _vendor.termsOfPayment),
                    _field('Produk / Brand', _products.isEmpty
                        ? null
                        : _products.map((p) => p.productName).join(', ')),
                    _field('Scope of Work', _vendor.scopeOfWork.isEmpty ? null : _vendor.scopeOfWork.join(', ')),
                    _field('Sub-SoW', _vendor.subSow.isEmpty ? null : _vendor.subSow.join(', ')),
                    _field('Supply Chain Classification', _vendor.supplyChainClassification),
                    _field('Internal Note', _vendor.internalNote),
                    _field('Vendor Address', _vendor.vendorAddress),
                    _field('PIC-Website', _vendor.picWebsite),

                    const SizedBox(height: 8),
                    const Text('Bank Information',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    if (_bankAccounts.isEmpty)
                      const Text('Belum ada Bank Information.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13))
                    else
                      ..._bankAccounts.map(_bankInfoCard),
                    const SizedBox(height: 16),

                    _field('Updated data', _formatUpdatedAt(_vendor.updatedAt)),

                    const SizedBox(height: 8),
                    const Text('PIC & Contact PIC',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    if (_hasError)
                      const Text('Gagal memuat data PIC.',
                          style: TextStyle(color: AppColors.danger, fontSize: 13))
                    else if (_contacts.isEmpty)
                      const Text('Belum ada PIC.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13))
                    else
                      ..._contacts.asMap().entries.map((entry) => _picCard(entry.key + 1, entry.value)),
                  ],
                ),
              ),
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
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            (value == null || value.isEmpty) ? '-' : value,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  /// REVISI: 1 vendor sekarang bisa punya lebih dari 1 Bank Information
  /// -- tiap rekening ditampilkan sebagai card terpisah.
  Widget _bankInfoCard(VendorBankAccount b) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bankLine('Bank Name', b.bankName),
            _bankLine('Account Number', b.accountNumber),
            _bankLine('Account Holder / Name', b.accountHolder),
            _bankLine('Currency', b.currency),
            _bankLine('SWIFT CODE', b.swiftCode),
          ],
        ),
      ),
    );
  }

  Widget _bankLine(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(
              (value == null || value.isEmpty) ? '-' : value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _picCard(int index, VendorContact contact) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text('$index', style: const TextStyle(color: AppColors.primary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.picName.isEmpty ? '-' : contact.picName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  if (contact.position.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        contact.position,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                  const SizedBox(height: 6),
                  if (contact.contact.isNotEmpty) _picLine(Icons.phone_outlined, contact.contact),
                  if (contact.email.isNotEmpty) _picLine(Icons.email_outlined, contact.email),
                  if (contact.contact.isEmpty && contact.email.isEmpty)
                    const Text('-', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _picLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
