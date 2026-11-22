import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../import/import_excel_io.dart';
import '../import/import_specs.dart';
import '../import/import_types.dart';
import '../import/importers.dart';
import '../providers/customer_provider.dart';
import '../providers/material_provider.dart';
import '../providers/rfq_provider.dart';
import '../providers/vendor_provider.dart';
import '../utils/app_theme.dart';

enum _Phase { setup, preview, result }

/// Layar import 1 modul. 4 langkah: (1) download template, (2) pilih
/// file Excel, (3) cek hasil analisis, (4) import -> hasil.
class ImportScreen extends StatefulWidget {
  final ImportModule module;
  const ImportScreen({super.key, required this.module});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  _Phase _phase = _Phase.setup;
  bool _busy = false;
  String _busyText = '';
  String? _fileName;
  ParsedSheet? _sheet;
  ImportPreview? _preview;
  ImportReport? _report;
  bool _autoDropdown = false;

  ImportModule get _m => widget.module;
  String get _title => ImportSpecs.title(_m);

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _downloadTemplate() async {
    try {
      final path = await ImportExcelIo.saveTemplate(_m);
      if (path != null) _toast('Template disimpan: $path');
    } catch (e) {
      _toast('Gagal menyimpan template: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final picked = await ImportExcelIo.pickFile();
      if (picked == null) return;
      setState(() {
        _busy = true;
        _busyText = 'Membaca file...';
      });
      final sheet = ImportExcelIo.parse(picked.bytes, _m);
      _fileName = picked.path.split(RegExp(r'[\\/]')).last;
      _sheet = sheet;
      await _analyze();
      if (mounted) setState(() => _phase = _Phase.preview);
    } catch (e) {
      _toast('Gagal membaca file: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _analyze() async {
    final sheet = _sheet;
    if (sheet == null) return;
    final p = await Importers.analyze(_m, sheet, autoAddDropdown: _autoDropdown);
    if (mounted) setState(() => _preview = p);
  }

  Future<void> _toggleAuto(bool v) async {
    setState(() {
      _autoDropdown = v;
      _busy = true;
      _busyText = 'Memeriksa ulang...';
    });
    try {
      await _analyze();
    } catch (e) {
      _toast('Gagal memeriksa: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runImport() async {
    final p = _preview;
    if (p == null || p.readyCount == 0) return;
    setState(() {
      _busy = true;
      _busyText = 'Mengimpor 0 / ${p.readyCount}...';
    });
    try {
      final report = await Importers.commit(
        p,
        autoAddDropdown: _autoDropdown,
        onProgress: (d, t) {
          if (mounted) setState(() => _busyText = 'Mengimpor $d / $t...');
        },
      );
      await _reloadProviders();
      if (!mounted) return;
      setState(() {
        _report = report;
        _phase = _Phase.result;
      });
    } catch (e) {
      _toast('Import gagal: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reloadProviders() async {
    try {
      switch (_m) {
        case ImportModule.customer:
          await context.read<CustomerProvider>().loadCustomers();
          break;
        case ImportModule.vendor:
          await context.read<VendorProvider>().loadVendors();
          break;
        case ImportModule.material:
          await context.read<MaterialProvider>().loadMaterials();
          break;
        case ImportModule.rfq:
          await context.read<RfqProvider>().loadRfqs();
          break;
      }
    } catch (_) {
      // daftar akan ter-refresh saat layar list dibuka lagi
    }
  }

  Future<void> _downloadReport() async {
    final r = _report;
    if (r == null) return;
    try {
      final path = await ImportExcelIo.saveFailureReport(_m, r.failed);
      if (path != null) _toast('Laporan disimpan: $path');
    } catch (e) {
      _toast('Gagal menyimpan laporan: $e');
    }
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Import $_title'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_phase == _Phase.setup) ..._setupBody(),
                  if (_phase == _Phase.preview) ..._previewBody(),
                  if (_phase == _Phase.result) ..._resultBody(),
                ],
              ),
            ),
          ),
          if (_busy)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
                          const SizedBox(width: 16),
                          Text(_busyText),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepCard(int n, String title, Widget child, {bool done = false}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: done ? AppColors.secondary : AppColors.primary,
                  child: done
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text('$n', style: const TextStyle(color: Colors.white, fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  List<Widget> _setupBody() {
    return [
      _stepCard(
        1,
        'Download template',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Isi data di template Excel ini. Judul kolom jangan diubah. ${ImportSpecs.description(_m)}.',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _downloadTemplate,
              icon: const Icon(Icons.download),
              label: Text('Download template $_title'),
            ),
          ],
        ),
      ),
      _stepCard(
        2,
        'Pilih file Excel',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih file .xlsx yang sudah diisi. Data belum disimpan sebelum kamu konfirmasi.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Pilih file .xlsx'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _tile(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }

  List<Widget> _previewBody() {
    final p = _preview;
    if (p == null) return [];
    final problems = p.items.where((i) => i.status != ImportStatus.ready).toList();
    final blocked = p.fileProblems.isNotEmpty;
    final pendingCount = p.pendingDropdown.values.fold<int>(0, (s, l) => s + l.length);

    return [
      _stepCard(2, 'File dipilih', Text(_fileName ?? '', style: const TextStyle(fontSize: 13)), done: true),
      _stepCard(
        3,
        'Cek hasil',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final f in p.fileProblems)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(f, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ),
            Row(
              children: [
                _tile('siap', p.readyCount, AppColors.secondary),
                const SizedBox(width: 10),
                _tile('dilewati', p.skippedCount, AppColors.accent),
                const SizedBox(width: 10),
                _tile('bermasalah', p.errorCount, AppColors.danger),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _autoDropdown,
              onChanged: _busy ? null : _toggleAuto,
              title: const Text('Tambah otomatis nilai dropdown yang belum ada', style: TextStyle(fontSize: 13)),
              subtitle: Text(
                _autoDropdown && pendingCount > 0
                    ? '$pendingCount nilai baru akan ditambahkan ke Settings > Edit Dropdown'
                    : 'Mati: baris dengan nilai dropdown yang tidak dikenal dianggap bermasalah',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (problems.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Baris yang perlu diperhatikan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              _problemTable(problems),
            ],
          ],
        ),
      ),
      _stepCard(
        4,
        'Konfirmasi import',
        Row(
          children: [
            OutlinedButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _phase = _Phase.setup;
                        _preview = null;
                        _sheet = null;
                      }),
              child: const Text('Ganti file'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: (_busy || blocked || p.readyCount == 0) ? null : _runImport,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: Text('Import ${p.readyCount} data'),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _problemTable(List<PreparedItem> items) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      constraints: const BoxConstraints(maxHeight: 320),
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const Row(
              children: [
                SizedBox(width: 90, child: Text('Baris', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(child: Text('Masalah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (_, i) {
                final it = items[i];
                final isErr = it.status == ImportStatus.error;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 90, child: Text(_rowsText(it.excelRows), style: const TextStyle(fontSize: 12))),
                      Expanded(
                        child: Text(
                          '${it.label}: ${it.message ?? ''}',
                          style: TextStyle(fontSize: 12, color: isErr ? AppColors.danger : AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _rowsText(List<int> rows) {
    if (rows.length <= 3) return rows.join(', ');
    return '${rows.first}-${rows.last}';
  }

  List<Widget> _resultBody() {
    final r = _report;
    if (r == null) return [];
    return [
      _stepCard(
        4,
        'Hasil import',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _tile('berhasil', r.success, AppColors.secondary),
                const SizedBox(width: 10),
                _tile('dilewati', r.skipped, AppColors.accent),
                const SizedBox(width: 10),
                _tile('gagal', r.failed.length, AppColors.danger),
              ],
            ),
            if (r.failed.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Yang gagal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              _problemTable(r.failed),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _downloadReport,
                icon: const Icon(Icons.download),
                label: const Text('Download laporan baris gagal'),
              ),
            ],
          ],
        ),
        done: true,
      ),
      Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: const Text('Selesai'),
        ),
      ),
    ];
  }
}
