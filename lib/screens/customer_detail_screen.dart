import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../models/customer_contact.dart';
import '../providers/customer_provider.dart';
import '../utils/app_theme.dart';
import 'customer_form_screen.dart';

/// Layar Detail Customer -- dibuka saat user tap salah satu data
/// customer di list. Sebelumnya tap di list malah membuka lagi
/// Customer Form (mode tambah/edit tercampur), sekarang dipisah:
/// tap = lihat Detail, tombol Edit (pensil) di list/detail = buka Form.
class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Customer _customer;
  List<CustomerContact> _contacts = [];
  bool _loading = true;
  bool _hasError = false;
  bool _changed = false; // dikirim balik ke list: perlu refresh atau tidak

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final contacts = await context
          .read<CustomerProvider>()
          .getContactsForCustomer(_customer.id!);
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
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
      MaterialPageRoute(builder: (_) => CustomerFormScreen(customer: _customer)),
    );
    if (saved == true && mounted) {
      _changed = true;
      // Data terbaru sudah ada di provider (updateCustomer memanggil
      // loadCustomers()) -- ambil ulang dari sana supaya detail ikut
      // ter-update tanpa query manual lagi.
      final refreshed = context.read<CustomerProvider>().findById(_customer.id!);
      setState(() => _customer = refreshed ?? _customer);
      _showSnack('Customer berhasil diupdate.');
      await _load();
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Customer?'),
        content: Text(
          'Yakin ingin menghapus "${_customer.name}"?\nSemua data PIC/kontak yang terhubung juga akan ikut terhapus.',
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
    if (confirmed != true || _customer.id == null || !mounted) return;

    try {
      await context.read<CustomerProvider>().deleteCustomer(_customer.id!);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Gagal menghapus customer: $e', isError: true);
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
          title: const Text('Customer Detail'),
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
                    _statusBadge(),
                    const SizedBox(height: 16),
                    _field('Customer Name', _customer.name),
                    _field('Customer ID', _customer.customerCode),
                    _field('NPWP Number', _customer.npwpNumber),
                    _field('Terms of Payment', _customer.termsOfPayment),
                    _field('Customer Type', _customer.customerType),
                    _field('Address', _customer.address),
                    const SizedBox(height: 8),
                    const Text(
                      'PIC & Contact PIC',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    if (_hasError)
                      const Text(
                        'Gagal memuat data PIC.',
                        style: TextStyle(color: AppColors.danger, fontSize: 13),
                      )
                    else if (_contacts.isEmpty)
                      const Text(
                        'Belum ada PIC.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      )
                    else
                      ..._contacts.asMap().entries.map(
                            (entry) => _picCard(entry.key + 1, entry.value),
                          ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _customer.isActive
            ? AppColors.secondary.withOpacity(0.12)
            : Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _customer.isActive ? 'Aktif' : 'Nonaktif',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _customer.isActive ? AppColors.secondary : Colors.grey.shade700,
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

  Widget _picCard(int index, CustomerContact contact) {
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
