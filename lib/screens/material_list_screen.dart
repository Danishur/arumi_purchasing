import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/material_item.dart';
import '../providers/material_provider.dart';
import '../utils/app_theme.dart';
import 'material_detail_screen.dart';
import 'material_form_screen.dart';

class MaterialListScreen extends StatefulWidget {
  const MaterialListScreen({super.key});

  @override
  State<MaterialListScreen> createState() => _MaterialListScreenState();
}

class _MaterialListScreenState extends State<MaterialListScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMaterials());
  }

  Future<void> _loadMaterials() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      await context.read<MaterialProvider>().loadMaterials();
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

  Future<void> _openForm({MaterialItem? material}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MaterialFormScreen(material: material)),
    );
    if (saved == true) {
      _showSnack(material == null ? 'Material berhasil ditambahkan.' : 'Material berhasil diupdate.');
    }
  }

  Future<void> _openDetail(MaterialItem m) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MaterialDetailScreen(material: m)),
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

  void _selectAll(List<MaterialItem> materials) {
    setState(() {
      final allIds = materials.where((m) => m.id != null).map((m) => m.id!).toSet();
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
        title: const Text('Hapus Material Terpilih?'),
        content: Text(
          'Yakin ingin menghapus ${_selectedIds.length} material terpilih?\n'
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

    if (confirmed != true) return;

    try {
      final count = _selectedIds.length;
      await context.read<MaterialProvider>().deleteMaterials(_selectedIds.toList());
      if (!mounted) return;
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
      _showSnack('$count material dihapus.');
    } catch (e) {
      _showSnack('Gagal menghapus material terpilih: $e', isError: true);
    }
  }

  Future<void> _confirmDelete(MaterialItem m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Material?'),
        content: Text(
          'Yakin ingin menghapus "${m.itemDescription ?? m.materialCode}"?\n'
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

    if (confirmed != true || m.id == null) return;

    try {
      await context.read<MaterialProvider>().deleteMaterial(m.id!);
      _showSnack('Material dihapus.');
    } catch (e) {
      _showSnack('Gagal menghapus material: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MaterialProvider>();
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
                    _selectedIds.length == provider.materials.length && provider.materials.isNotEmpty
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  tooltip: 'Pilih semua',
                  onPressed: () => _selectAll(provider.materials),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Hapus yang dipilih',
                  onPressed: _selectedIds.isEmpty ? null : _confirmDeleteSelected,
                ),
              ],
            )
          : AppBar(
              title: const Text('Data Material'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: 'Pilih beberapa',
                  onPressed: provider.materials.isEmpty ? null : _toggleSelectionMode,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Muat ulang',
                  onPressed: _loadMaterials,
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
              ElevatedButton(onPressed: _loadMaterials, child: const Text('Coba Lagi')),
              const SizedBox(height: 8),
              const Text(
                'Pastikan MySQL (XAMPP) sudah dijalankan dan tabel material sudah\n'
                'dibuat lewat sql/04_create_material_tables.sql.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<MaterialProvider>(
      builder: (context, provider, _) {
        if (provider.materials.isEmpty) {
          return const Center(
            child: Text(
              'Belum ada material.\nTekan + untuk menambah.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _loadMaterials,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: provider.materials.length,
            itemBuilder: (context, index) {
              final m = provider.materials[index];
              final isSelected = m.id != null && _selectedIds.contains(m.id);
              final title = (m.itemDescription != null && m.itemDescription!.isNotEmpty)
                  ? m.itemDescription!
                  : (m.itemType ?? m.materialCode);
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
                      if (m.id != null) _toggleSelected(m.id!);
                    } else {
                      _openDetail(m);
                    }
                  },
                  onLongPress: () {
                    if (!_selectionMode) {
                      setState(() => _selectionMode = true);
                    }
                    if (m.id != null) _toggleSelected(m.id!);
                  },
                  leading: _selectionMode
                      ? Checkbox(
                          value: isSelected,
                          activeColor: AppColors.primary,
                          onChanged: (_) {
                            if (m.id != null) _toggleSelected(m.id!);
                          },
                        )
                      : CircleAvatar(
                          backgroundColor: m.isActive ? AppColors.primary : Colors.grey,
                          child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 18),
                        ),
                  title: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${m.materialCode}${m.vendorName != null ? '  •  ${m.vendorName}' : ''}'),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: [
                            if (m.category != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(m.category!,
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: m.isActive
                                    ? AppColors.secondary.withOpacity(0.12)
                                    : Colors.grey.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                m.isActive ? 'Aktif' : 'Nonaktif',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: m.isActive ? AppColors.secondary : Colors.grey.shade700,
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
                              onPressed: () => _openForm(material: m),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                              tooltip: 'Hapus',
                              onPressed: () => _confirmDelete(m),
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
