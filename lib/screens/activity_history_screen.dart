import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';

/// Riwayat Aktivitas: siapa menambah / mengubah / menghapus data, kapan
/// (tanggal, bulan, tahun, jam). Riwayat yang umurnya lebih dari
/// [DatabaseService.historyRetentionMonths] bulan otomatis dihapus waktu
/// app dibuka.
class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  static const _modules = ['Customer', 'Vendor', 'Material', 'RFQ', 'Valuta', 'Dropdown', 'User'];
  final _fmt = DateFormat('dd/MM/yyyy HH:mm');
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _logs = [];
  String? _module;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await DatabaseService.instance.getActivityLogs(module: _module, search: _searchCtrl.text);
      if (mounted) setState(() => _logs = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ({String text, IconData icon, Color color}) _actionInfo(String a) {
    switch (a) {
      case 'create':
        return (text: 'menambah', icon: Icons.add_circle_outline, color: AppColors.secondary);
      case 'delete':
        return (text: 'menghapus', icon: Icons.delete_outline, color: AppColors.danger);
      default:
        return (text: 'mengubah', icon: Icons.edit_outlined, color: AppColors.accent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Riwayat Aktivitas'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [IconButton(tooltip: 'Muat ulang', icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'Cari nama user atau data...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final m in [null, ..._modules])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(m ?? 'Semua'),
                          selected: _module == m,
                          onSelected: (_) {
                            setState(() => _module = m);
                            _load();
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Riwayat otomatis dihapus setelah ${DatabaseService.historyRetentionMonths} bulan.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)));
    }
    if (_logs.isEmpty) {
      return const Center(child: Text('Belum ada riwayat.', style: TextStyle(color: AppColors.textMuted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final l = _logs[i];
        final info = _actionInfo((l['action'] ?? '').toString());
        final when = l['created_at'];
        final detail = (l['detail'] ?? '').toString();
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(info.icon, color: info.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: (l['user_name'] ?? '-').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: ' ${info.text} '),
                  TextSpan(text: (l['module'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ])),
                const SizedBox(height: 2),
                Text(
                  [(l['record_label'] ?? '').toString(), if (detail.isNotEmpty) detail].where((e) => e.isNotEmpty).join(' - '),
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            Text(when is DateTime ? _fmt.format(when) : '$when',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ]),
        );
      },
    );
  }
}
