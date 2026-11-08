import 'package:flutter/material.dart';
import '../models/dropdown_option.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../utils/dropdown_options_cache.dart';
import 'edit_dropdown_menu_screen.dart';

/// TAMBAHAN: Settings > Edit Dropdown > <Modul> -- layar generik untuk
/// CRUD isi 1 (atau lebih, lewat selector di atas) kategori dropdown
/// milik 1 modul, sesuai referensi screenshot "Edit Dropdown Scope of
/// Work" / "Edit Dropdown VENDOR": selector field di atas (panah ke
/// bawah untuk pindah ke field lain di modul yang sama), kotak search,
/// tombol "+ Tambah Data", tabel No/<Field>/Aksi, dan pagination.
///
/// Dibuat 1 widget generik (bukan 1 screen per field) supaya ke-5
/// modul x total belasan field dropdown tidak perlu belasan file
/// terpisah -- cukup diberi daftar [fields] lewat konstruktor.
class EditDropdownScreen extends StatefulWidget {
  final String module;
  final List<DropdownFieldConfig> fields;

  const EditDropdownScreen({super.key, required this.module, required this.fields});

  @override
  State<EditDropdownScreen> createState() => _EditDropdownScreenState();
}

class _EditDropdownScreenState extends State<EditDropdownScreen> {
  static const int _pageSize = 5;

  late DropdownFieldConfig _activeField;
  bool _isLoading = true;
  bool _hasError = false;
  List<DropdownOption> _options = [];
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _activeField = widget.fields.first;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final rows =
          await DatabaseService.instance.getDropdownOptionsByCategory(_activeField.category);
      final options = rows.map((r) => DropdownOption.fromMap(r)).toList();
      // DB belum punya baris untuk kategori ini (mis. belum sempat
      // di-seed) -- tampilkan default-nya dulu (read-only sampai user
      // tambah data sendiri) supaya layar tidak kosong begitu saja.
      if (options.isEmpty) {
        final defaults = DropdownOptionsCache.defaultValues[_activeField.category] ?? const [];
        options.addAll(defaults.map((v) => DropdownOption(category: _activeField.category, value: v)));
      }
      if (!mounted) return;
      setState(() {
        _options = options;
        _isLoading = false;
        _page = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _switchField(DropdownFieldConfig field) {
    if (field.category == _activeField.category && field.label == _activeField.label) return;
    setState(() {
      _activeField = field;
      _searchCtrl.clear();
      _searchQuery = '';
    });
    _load();
  }

  List<DropdownOption> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _options;
    return _options.where((o) => o.value.toLowerCase().contains(q)).toList();
  }

  Future<void> _showFormDialog({DropdownOption? existing}) async {
    final ctrl = TextEditingController(text: existing?.value ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null
            ? 'Tambah Data ${_activeField.label}'
            : 'Edit Data ${_activeField.label}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Simpan'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    try {
      if (existing == null) {
        await DatabaseService.instance.insertDropdownOption(_activeField.category, value);
      } else {
        await DatabaseService.instance.updateDropdownOption(existing.id!, value);
      }
      await DropdownOptionsCache.refreshCategory(_activeField.category);
      await _load();
      if (!mounted) return;
      _showSnack('Data berhasil disimpan');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal menyimpan: $e', isError: true);
    }
  }

  Future<void> _delete(DropdownOption option) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Data'),
        content: Text('Hapus "${option.value}" dari ${_activeField.label}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      if (option.id != null) {
        await DatabaseService.instance.deleteDropdownOption(option.id!);
      }
      await DropdownOptionsCache.refreshCategory(_activeField.category);
      await _load();
      if (!mounted) return;
      _showSnack('Data berhasil dihapus');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal menghapus: $e', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? AppColors.danger : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalPages = filtered.isEmpty ? 1 : ((filtered.length - 1) ~/ _pageSize) + 1;
    final page = _page.clamp(0, totalPages - 1);
    final start = page * _pageSize;
    final pageItems = filtered.skip(start).take(_pageSize).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Edit Dropdown ${widget.module}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Gagal memuat data dropdown.'),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _load, child: const Text('Coba Lagi')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Kelola data dropdown untuk setiap halaman.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    _fieldSelector(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() {
                              _searchQuery = v;
                              _page = 0;
                            }),
                            decoration: InputDecoration(
                              hintText: 'Cari ${_activeField.label.toLowerCase()}...',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showFormDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah Data'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _table(pageItems, start),
                    const SizedBox(height: 12),
                    _paginationFooter(filtered.length, page, totalPages),
                  ],
                ),
    );
  }

  Widget _fieldSelector() {
    // Dropdown pemilih field, sesuai referensi "Scope of Work ▾" /
    // "Legal Standing ▾" -- pindah ke field lain dalam modul yang sama
    // tanpa harus balik ke menu Edit Dropdown.
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<DropdownFieldConfig>(
            isExpanded: true,
            value: _activeField,
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
            items: widget.fields
                .map((f) => DropdownMenuItem(
                      value: f,
                      child: Row(
                        children: [
                          const Icon(Icons.widgets_outlined, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Text(f.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (f) {
              if (f != null) _switchField(f);
            },
            selectedItemBuilder: (context) => widget.fields
                .map((f) => Row(
                      children: [
                        const Icon(Icons.widgets_outlined, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Text(f.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _table(List<DropdownOption> items, int start) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text('Belum ada data.', style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 36, child: Text('No.', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    child: Text(_activeField.label, style: const TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(width: 140, child: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 36, child: Text('${start + i + 1}')),
                  Expanded(child: Text(items[i].value)),
                  SizedBox(
                    width: 140,
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _showFormDialog(existing: items[i]),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                        ),
                        IconButton(
                          onPressed: () => _delete(items[i]),
                          icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                          tooltip: 'Hapus',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paginationFooter(int total, int page, int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Menampilkan ${total == 0 ? 0 : (page * _pageSize) + 1}-'
            '${((page + 1) * _pageSize).clamp(0, total)} dari $total data'),
        Row(
          children: [
            IconButton(
              onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            for (var p = 0; p < totalPages; p++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => setState(() => _page = p),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p == page ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      '${p + 1}',
                      style: TextStyle(color: p == page ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
              ),
            IconButton(
              onPressed: page < totalPages - 1 ? () => setState(() => _page = page + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}
