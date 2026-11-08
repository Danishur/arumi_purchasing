import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vendor.dart';
import '../providers/vendor_provider.dart';
import '../utils/app_theme.dart';
import '../utils/vendor_export.dart';
import 'vendor_detail_screen.dart';
import 'vendor_form_screen.dart';

class VendorListScreen extends StatefulWidget {
  const VendorListScreen({super.key});

  @override
  State<VendorListScreen> createState() => _VendorListScreenState();
}

class _VendorListScreenState extends State<VendorListScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  bool _selectionMode = false;
  final Set<int> _selectedIds = {};
  bool _isExportingRecap = false;

  // TAMBAHAN: fitur search -- filter list by nama/kode vendor.
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // REVISI: search sekarang mencakup SEMUA field data vendor (alamat,
  // NPWP, terms of payment, scope of work, sub SOW, supply chain
  // classification, internal note, dst) termasuk data PIC & produk.
  List<Vendor> _filtered(List<Vendor> vendors) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return vendors;
    return vendors.where((v) {
      final fields = <String>[
        v.vendorName,
        v.vendorCode,
        v.legalStanding ?? '',
        v.npwp ?? '',
        v.termsOfPayment ?? '',
        ...v.scopeOfWork,
        ...v.subSow,
        v.supplyChainClassification ?? '',
        v.internalNote ?? '',
        v.vendorAddress ?? '',
        v.picWebsite ?? '',
        v.isVerified ? 'verified' : 'belum verified',
        v.isActive ? 'aktif' : 'nonaktif',
        for (final p in v.contacts) ...[p.picName, p.position, p.contact, p.email],
        for (final p in v.products) p.productName,
      ];
      return fields.any((f) => f.toLowerCase().contains(q));
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadVendors());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVendors() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      await context.read<VendorProvider>().loadVendors();
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

  Future<void> _openForm({Vendor? vendor}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VendorFormScreen(vendor: vendor)),
    );
    if (saved == true) {
      _showSnack(vendor == null ? 'Vendor berhasil ditambahkan.' : 'Vendor berhasil diupdate.');
    }
  }

  Future<void> _openDetail(Vendor v) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VendorDetailScreen(vendor: v)),
    );
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

  void _selectAll(List<Vendor> vendors) {
    setState(() {
      final allIds = vendors.where((v) => v.id != null).map((v) => v.id!).toSet();
      if (_selectedIds.length == allIds.length) {
        _selectedIds.clear();
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
        title: const Text('Hapus Vendor Terpilih?'),
        content: Text(
          'Yakin ingin menghapus ${_selectedIds.length} vendor terpilih?\n'
          'Semua data PIC & Produk/Brand yang terhubung juga akan ikut terhapus.',
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
      await context.read<VendorProvider>().deleteVendors(_selectedIds.toList());
      if (!mounted) return;
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
      _showSnack('$count vendor dihapus.');
    } catch (e) {
      _showSnack('Gagal menghapus vendor terpilih: $e', isError: true);
    }
  }

  /// TAMBAHAN: Export Excel Rekap dari Vendor yang dipilih (mode select).
  Future<void> _exportRecapExcel(List<Vendor> allVendors) async {
    if (_selectedIds.isEmpty || _isExportingRecap) return;
    setState(() => _isExportingRecap = true);
    try {
      final selected = allVendors.where((v) => v.id != null && _selectedIds.contains(v.id)).toList();
      final path = await VendorExport.exportExcelRekap(selected);
      if (path == null) return; // user batal pilih lokasi simpan
      if (!mounted) return;
      _showSnack('Export berhasil');
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
    } catch (e) {
      _showSnack('Gagal export Excel rekap: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExportingRecap = false);
    }
  }

  Future<void> _confirmDelete(Vendor v) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Vendor?'),
        content: Text(
          'Yakin ingin menghapus "${v.vendorName}"?\nSemua data PIC & Produk/Brand yang terhubung juga akan ikut terhapus.',
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

    if (confirmed != true || v.id == null) return;

    try {
      await context.read<VendorProvider>().deleteVendor(v.id!);
      _showSnack('Vendor dihapus.');
    } catch (e) {
      _showSnack('Gagal menghapus vendor: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VendorProvider>();
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
                    _selectedIds.length == provider.vendors.length && provider.vendors.isNotEmpty
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  tooltip: 'Pilih semua',
                  onPressed: () => _selectAll(provider.vendors),
                ),
                IconButton(
                  icon: _isExportingRecap
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.file_download_outlined),
                  tooltip: 'Export Excel Rekap',
                  onPressed: _selectedIds.isEmpty || _isExportingRecap
                      ? null
                      : () => _exportRecapExcel(provider.vendors),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Hapus yang dipilih',
                  onPressed: _selectedIds.isEmpty ? null : _confirmDeleteSelected,
                ),
              ],
            )
          : AppBar(
              title: const Text('Data Vendor'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: 'Pilih beberapa',
                  onPressed: provider.vendors.isEmpty ? null : _toggleSelectionMode,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Muat ulang',
                  onPressed: _loadVendors,
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
              ElevatedButton(onPressed: _loadVendors, child: const Text('Coba Lagi')),
              const SizedBox(height: 8),
              const Text(
                'Pastikan MySQL (XAMPP) sudah dijalankan dan tabel vendor sudah\n'
                'dibuat lewat sql/03_create_vendor_tables.sql.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<VendorProvider>(
      builder: (context, provider, _) {
        if (provider.vendors.isEmpty) {
          return Column(
            children: [
              _searchBar(),
              const Expanded(
                child: Center(
                  child: Text(
                    'Belum ada vendor.\nTekan + untuk menambah.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        }
        final filtered = _filtered(provider.vendors);
        return Column(
          children: [
            _searchBar(),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('Tidak ada vendor yang cocok.',
                          style: TextStyle(color: AppColors.textMuted)),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadVendors,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final v = filtered[index];
              final isSelected = v.id != null && _selectedIds.contains(v.id);
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
                      if (v.id != null) _toggleSelected(v.id!);
                    } else {
                      _openDetail(v);
                    }
                  },
                  onLongPress: () {
                    if (!_selectionMode) {
                      setState(() => _selectionMode = true);
                    }
                    if (v.id != null) _toggleSelected(v.id!);
                  },
                  leading: _selectionMode
                      ? Checkbox(
                          value: isSelected,
                          activeColor: AppColors.primary,
                          onChanged: (_) {
                            if (v.id != null) _toggleSelected(v.id!);
                          },
                        )
                      : CircleAvatar(
                          backgroundColor: v.isActive ? AppColors.primary : Colors.grey,
                          child: Text(
                            v.vendorName.isNotEmpty ? v.vendorName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                  title: Text(v.vendorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${v.vendorCode}${v.legalStanding != null ? '  •  ${v.legalStanding}' : ''}'),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: v.isVerified
                                    ? AppColors.secondary.withOpacity(0.12)
                                    : AppColors.accent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                v.isVerified ? 'Verified' : 'Unverified',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: v.isVerified ? AppColors.secondary : Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: v.isActive
                                    ? AppColors.secondary.withOpacity(0.12)
                                    : Colors.grey.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                v.isActive ? 'Aktif' : 'Nonaktif',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: v.isActive ? AppColors.secondary : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
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
                              onPressed: () => _openForm(vendor: v),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                              tooltip: 'Hapus',
                              onPressed: () => _confirmDelete(v),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Cari nama / kode vendor...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() {
                    _searchCtrl.clear();
                    _searchQuery = '';
                  }),
                ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}
