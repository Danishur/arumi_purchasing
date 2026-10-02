import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/rfq.dart';
import '../providers/rfq_provider.dart';
import '../utils/app_theme.dart';
import '../utils/rfq_excel_exporter.dart';
import 'rfq_detail_screen.dart';
import 'rfq_form_screen.dart';

class RfqListScreen extends StatefulWidget {
  const RfqListScreen({super.key});

  @override
  State<RfqListScreen> createState() => _RfqListScreenState();
}

class _RfqListScreenState extends State<RfqListScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRfqs());
  }

  Future<void> _loadRfqs() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      await context.read<RfqProvider>().loadRfqs();
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

  Future<void> _openForm({Rfq? rfq}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RfqFormScreen(rfq: rfq)),
    );
    if (saved == true) {
      _showSnack(rfq == null ? 'RFQ berhasil ditambahkan.' : 'RFQ berhasil diupdate.');
    }
  }

  Future<void> _openDetail(Rfq r) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RfqDetailScreen(rfq: r)),
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

  void _selectAll(List<Rfq> rfqs) {
    setState(() {
      final allIds = rfqs.where((r) => r.id != null).map((r) => r.id!).toSet();
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
        title: const Text('Hapus RFQ Terpilih?'),
        content: Text(
          'Yakin ingin menghapus ${_selectedIds.length} RFQ terpilih?\n'
          'Semua Material List yang terhubung juga akan ikut terhapus.',
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
      await context.read<RfqProvider>().deleteRfqs(_selectedIds.toList());
      if (!mounted) return;
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
      _showSnack('$count RFQ dihapus.');
    } catch (e) {
      _showSnack('Gagal menghapus RFQ terpilih: $e', isError: true);
    }
  }

  Future<void> _confirmDelete(Rfq r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus RFQ?'),
        content: Text(
          'Yakin ingin menghapus "${r.rfqCode}"?\nSemua Material List yang terhubung juga akan ikut terhapus.',
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

    if (confirmed != true || r.id == null) return;

    try {
      await context.read<RfqProvider>().deleteRfq(r.id!);
      _showSnack('RFQ dihapus.');
    } catch (e) {
      _showSnack('Gagal menghapus RFQ: $e', isError: true);
    }
  }

  Future<void> _exportExcel(Rfq r) async {
    if (r.id == null) return;
    try {
      final lines = await context.read<RfqProvider>().getMaterialLinesForRfq(r.id!);
      final path = await RfqExcelExporter.export(r, lines);
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
    final provider = context.watch<RfqProvider>();
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
                    _selectedIds.length == provider.rfqs.length && provider.rfqs.isNotEmpty
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  tooltip: 'Pilih semua',
                  onPressed: () => _selectAll(provider.rfqs),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Hapus yang dipilih',
                  onPressed: _selectedIds.isEmpty ? null : _confirmDeleteSelected,
                ),
              ],
            )
          : AppBar(
              title: const Text('Data RFQ'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: 'Pilih beberapa',
                  onPressed: provider.rfqs.isEmpty ? null : _toggleSelectionMode,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Muat ulang',
                  onPressed: _loadRfqs,
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
              ElevatedButton(onPressed: _loadRfqs, child: const Text('Coba Lagi')),
              const SizedBox(height: 8),
              const Text(
                'Pastikan MySQL (XAMPP) sudah dijalankan dan tabel RFQ sudah\n'
                'dibuat lewat sql/05_alter_materials_and_create_rfq_tables.sql.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<RfqProvider>(
      builder: (context, provider, _) {
        if (provider.rfqs.isEmpty) {
          return const Center(
            child: Text(
              'Belum ada RFQ.\nTekan + untuk menambah.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _loadRfqs,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: provider.rfqs.length,
            itemBuilder: (context, index) {
              final r = provider.rfqs[index];
              final isSelected = r.id != null && _selectedIds.contains(r.id);
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
                      if (r.id != null) _toggleSelected(r.id!);
                    } else {
                      _openDetail(r);
                    }
                  },
                  onLongPress: () {
                    if (!_selectionMode) {
                      setState(() => _selectionMode = true);
                    }
                    if (r.id != null) _toggleSelected(r.id!);
                  },
                  leading: _selectionMode
                      ? Checkbox(
                          value: isSelected,
                          activeColor: AppColors.primary,
                          onChanged: (_) {
                            if (r.id != null) _toggleSelected(r.id!);
                          },
                        )
                      : CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.request_quote_outlined, color: Colors.white, size: 18),
                        ),
                  title: Text(r.rfqCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.customerName ?? '-'),
                        const SizedBox(height: 2),
                        Text(
                          r.dueDate == null
                              ? 'Due date: -'
                              : 'Due date: ${DateFormat('dd/MM/yyyy').format(r.dueDate!)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 4),
                        if (r.status != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _statusColor(r.status).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              r.status!,
                              style: TextStyle(
                                fontSize: 11,
                                color: _statusColor(r.status),
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
                              icon: const Icon(Icons.file_download_outlined, color: AppColors.secondary),
                              tooltip: 'Export Excel',
                              onPressed: () => _exportExcel(r),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                              tooltip: 'Edit',
                              onPressed: () => _openForm(rfq: r),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                              tooltip: 'Hapus',
                              onPressed: () => _confirmDelete(r),
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
