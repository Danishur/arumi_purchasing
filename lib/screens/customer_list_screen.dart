import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../providers/customer_provider.dart';
import '../utils/app_theme.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Fitur select multi: aktif kalau user tap ikon "select" di AppBar,
  // atau long-press salah satu item di list.
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCustomers());
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      await context.read<CustomerProvider>().loadCustomers();
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
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

  Future<void> _openForm({Customer? customer}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CustomerFormScreen(customer: customer)),
    );
    if (saved == true) {
      _showSnack(customer == null ? 'Customer berhasil ditambahkan.' : 'Customer berhasil diupdate.');
    }
  }

  // BUG FIX: sebelumnya tap di data customer yang sudah tersimpan malah
  // membuka lagi Customer Form (tercampur mode tambah), bukan menampilkan
  // detail data yang sudah disimpan. Sekarang tap = buka layar Detail;
  // untuk edit datanya, pakai tombol pensil di list atau di layar Detail.
  Future<void> _openDetail(Customer c) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: c)),
    );
    // updateCustomer/deleteCustomer di layar Detail sudah memanggil
    // loadCustomers() lewat provider, jadi list ini otomatis ikut update
    // (lihat Consumer<CustomerProvider> di _buildBody) tanpa perlu
    // reload manual di sini lagi.
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<Customer> customers) {
    setState(() {
      final allIds = customers.where((c) => c.id != null).map((c) => c.id!).toSet();
      if (_selectedIds.length == allIds.length) {
        _selectedIds.clear(); // semua sudah kepilih -> unselect semua
      } else {
        _selectedIds
          ..clear()
          ..addAll(allIds);
      }
    });
  }

  Future<void> _confirmDeleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Customer Terpilih?'),
        content: Text(
          'Yakin ingin menghapus ${_selectedIds.length} customer terpilih?\n'
          'Semua data PIC/kontak yang terhubung juga akan ikut terhapus.',
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

    if (confirmed != true) return;

    try {
      final count = _selectedIds.length;
      await context.read<CustomerProvider>().deleteCustomers(_selectedIds.toList());
      if (!mounted) return;
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
      _showSnack('$count customer dihapus.');
    } catch (e) {
      _showSnack('Gagal menghapus customer terpilih: $e', isError: true);
    }
  }

  Future<void> _confirmDelete(Customer c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Customer?'),
        content: Text(
          'Yakin ingin menghapus "${c.name}"?\nSemua data PIC/kontak yang terhubung juga akan ikut terhapus.',
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

    if (confirmed != true || c.id == null) return;

    try {
      await context.read<CustomerProvider>().deleteCustomer(c.id!);
      _showSnack('Customer dihapus.');
    } catch (e) {
      _showSnack('Gagal menghapus customer: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _selectionMode
          ? AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Batal pilih',
                onPressed: _toggleSelectionMode,
              ),
              title: Text('${_selectedIds.length} dipilih'),
              actions: [
                IconButton(
                  icon: Icon(
                    _selectedIds.length == provider.customers.length &&
                            provider.customers.isNotEmpty
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  tooltip: 'Pilih semua',
                  onPressed: () => _selectAll(provider.customers),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Hapus yang dipilih',
                  onPressed: _selectedIds.isEmpty ? null : _confirmDeleteSelected,
                ),
              ],
            )
          : AppBar(
              title: const Text('Data Customer'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: 'Pilih beberapa',
                  onPressed: provider.customers.isEmpty ? null : _toggleSelectionMode,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Muat ulang',
                  onPressed: _loadCustomers,
                ),
              ],
            ),
      body: _buildBody(),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () => _openForm(),
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: AppColors.danger, size: 42),
              const SizedBox(height: 10),
              const Text(
                'Gagal terhubung ke database MySQL.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadCustomers, child: const Text('Coba Lagi')),
              const SizedBox(height: 8),
              const Text(
                'Pastikan MySQL (XAMPP) sudah dijalankan dan pengaturan di\n'
                'lib/config/db_config.dart sudah sesuai. Lihat TUTORIAL_MYSQL.md.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<CustomerProvider>(
      builder: (context, provider, _) {
        if (provider.customers.isEmpty) {
          return const Center(
            child: Text(
              'Belum ada customer.\nTekan + untuk menambah.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _loadCustomers,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: provider.customers.length,
            itemBuilder: (context, index) {
              final c = provider.customers[index];
              final isSelected = c.id != null && _selectedIds.contains(c.id);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: isSelected ? AppColors.primary.withOpacity(0.06) : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isSelected
                      ? const BorderSide(color: AppColors.primary, width: 1.2)
                      : BorderSide.none,
                ),
                child: ListTile(
                  onTap: () {
                    if (_selectionMode) {
                      if (c.id != null) _toggleSelected(c.id!);
                    } else {
                      _openDetail(c);
                    }
                  },
                  onLongPress: () {
                    if (!_selectionMode) {
                      setState(() => _selectionMode = true);
                    }
                    if (c.id != null) _toggleSelected(c.id!);
                  },
                  leading: _selectionMode
                      ? Checkbox(
                          value: isSelected,
                          activeColor: AppColors.primary,
                          onChanged: (_) {
                            if (c.id != null) _toggleSelected(c.id!);
                          },
                        )
                      : CircleAvatar(
                          backgroundColor: c.isActive ? AppColors.primary : Colors.grey,
                          child: Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${c.customerCode}${c.customerType != null ? '  •  ${c.customerType}' : ''}'),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.isActive
                                ? AppColors.secondary.withOpacity(0.12)
                                : Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c.isActive ? 'Aktif' : 'Nonaktif',
                            style: TextStyle(
                              fontSize: 11,
                              color: c.isActive ? AppColors.secondary : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  isThreeLine: true,
                  trailing: _selectionMode
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                              tooltip: 'Edit',
                              onPressed: () => _openForm(customer: c),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                              tooltip: 'Hapus',
                              onPressed: () => _confirmDelete(c),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
