import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../widgets/auth_widgets.dart';
import 'activity_history_screen.dart';

/// Management User (khusus owner): Existing User, New User (setuju /
/// tolak), Change Password, dan pintu ke Riwayat Aktivitas.
class ManagementUserScreen extends StatefulWidget {
  const ManagementUserScreen({super.key});

  @override
  State<ManagementUserScreen> createState() => _ManagementUserScreenState();
}

class _ManagementUserScreenState extends State<ManagementUserScreen> {
  List<Map<String, dynamic>> _active = [];
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;
  String? _error;

  bool _openExisting = true;
  bool _openNew = true;
  bool _openPassword = true;

  final _pwEmail = TextEditingController();
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pwEmail.dispose();
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final a = await DatabaseService.instance.getActiveUsers();
      final p = await DatabaseService.instance.getPendingRequests();
      if (!mounted) return;
      setState(() {
        _active = a;
        _pending = p;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(Map<String, dynamic> req, bool approve) async {
    final id = (req['id'] as num).toInt();
    final isReset = req['request_type'] == 'reset';
    try {
      final db = DatabaseService.instance;
      if (isReset) {
        approve ? await db.approveReset(id) : await db.rejectReset(id);
      } else {
        approve ? await db.approveUser(id) : await db.rejectUser(id);
      }
      if (!mounted) return;
      showAuthSnack(context, approve ? 'Disetujui.' : 'Ditolak.');
      await _load();
    } catch (e) {
      if (mounted) showAuthSnack(context, 'Gagal: $e', error: true);
    }
  }

  Future<void> _savePassword() async {
    if (_pwEmail.text.trim().isEmpty || _pw1.text.isEmpty || _pw2.text.isEmpty) {
      showAuthSnack(context, 'Semua kolom wajib diisi.', error: true);
      return;
    }
    if (_pw1.text.length < 6) {
      showAuthSnack(context, 'Password minimal 6 karakter.', error: true);
      return;
    }
    if (_pw1.text != _pw2.text) {
      showAuthSnack(context, 'Konfirmasi password tidak sama.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await DatabaseService.instance.setUserPassword(_pwEmail.text.trim(), _pw1.text);
      if (!mounted) return;
      _pwEmail.clear();
      _pw1.clear();
      _pw2.clear();
      showAuthSnack(context, 'Password berhasil diganti.');
    } on AuthException catch (e) {
      if (mounted) showAuthSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showAuthSnack(context, 'Gagal: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Management User'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(tooltip: 'Muat ulang', icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                    const SizedBox(height: 10),
                    OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
                  ]),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _section(
                          icon: Icons.groups_2_outlined,
                          color: AppColors.primary,
                          title: 'Existing User',
                          subtitle: 'List of registered users',
                          open: _openExisting,
                          onToggle: () => setState(() => _openExisting = !_openExisting),
                          child: _existingTable(),
                        ),
                        const SizedBox(height: 14),
                        _section(
                          icon: Icons.access_time,
                          color: const Color(0xFFB36B00),
                          title: 'New User',
                          subtitle: 'Pending approval requests (${_pending.length})',
                          open: _openNew,
                          onToggle: () => setState(() => _openNew = !_openNew),
                          child: _newTable(),
                        ),
                        const SizedBox(height: 14),
                        _section(
                          icon: Icons.lock_outline,
                          color: const Color(0xFF6A3FC4),
                          title: 'Change Password',
                          subtitle: 'Update user password',
                          open: _openPassword,
                          onToggle: () => setState(() => _openPassword = !_openPassword),
                          child: _passwordForm(),
                        ),
                        const SizedBox(height: 14),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: ListTile(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ActivityHistoryScreen()),
                            ),
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFDDF3E2),
                              child: Icon(Icons.history, color: AppColors.secondary),
                            ),
                            title: const Text('Riwayat Aktivitas', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              'Siapa menambah / mengubah / menghapus data. '
                              'Otomatis dihapus setelah ${DatabaseService.historyRetentionMonths} bulan.',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _section({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool open,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Row(children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ]),
              ),
              Icon(open ? Icons.expand_less : Icons.expand_more),
            ]),
          ),
          if (open) ...[const SizedBox(height: 12), child],
        ],
      ),
    );
  }

  Widget _tableShell(List<Widget> header, List<Widget> rows, String emptyText) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          color: const Color(0xFFE3EAF8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(children: header),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(emptyText, style: const TextStyle(color: AppColors.textMuted)),
          )
        else
          ...rows,
      ]),
    );
  }

  static const _hStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);

  Widget _existingTable() {
    final rows = <Widget>[];
    for (var i = 0; i < _active.length; i++) {
      final u = _active[i];
      final isOwner = u['role'] == 'owner';
      rows.add(Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          SizedBox(width: 36, child: Text('${i + 1}')),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((u['email'] ?? '').toString(), style: const TextStyle(fontSize: 13)),
              Text('${u['name'] ?? ''} - ${u['position'] ?? ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ]),
          ),
          _chip(isOwner ? 'Owner' : 'Active', isOwner ? const Color(0xFF1F5FBF) : const Color(0xFF1B6B2F),
              isOwner ? const Color(0xFFE3EAF8) : const Color(0xFFDDF3E2)),
        ]),
      ));
    }
    return _tableShell(
      const [
        SizedBox(width: 36, child: Text('No.', style: _hStyle)),
        Expanded(child: Text('User / Email', style: _hStyle)),
        Text('Status', style: _hStyle),
      ],
      rows,
      'Belum ada user.',
    );
  }

  Widget _newTable() {
    final rows = <Widget>[];
    for (var i = 0; i < _pending.length; i++) {
      final r = _pending[i];
      final isReset = r['request_type'] == 'reset';
      rows.add(Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          SizedBox(width: 36, child: Text('${i + 1}')),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((r['email'] ?? '').toString(), style: const TextStyle(fontSize: 13)),
              Text(
                isReset
                    ? 'Minta reset password - ${r['name'] ?? ''}'
                    : 'Akun baru - ${r['name'] ?? ''} (${r['position'] ?? ''})',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ]),
          ),
          IconButton(
            tooltip: 'Setujui',
            onPressed: () => _decide(r, true),
            style: IconButton.styleFrom(backgroundColor: const Color(0xFFDDF3E2)),
            icon: const Icon(Icons.check, color: Color(0xFF1B6B2F)),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Tolak',
            onPressed: () => _decide(r, false),
            style: IconButton.styleFrom(backgroundColor: const Color(0xFFFBE0E0)),
            icon: const Icon(Icons.close, color: Color(0xFFC62828)),
          ),
        ]),
      ));
    }
    return _tableShell(
      const [
        SizedBox(width: 36, child: Text('No.', style: _hStyle)),
        Expanded(child: Text('User / Email', style: _hStyle)),
        SizedBox(width: 90, child: Text('Action', style: _hStyle, textAlign: TextAlign.center)),
      ],
      rows,
      'Tidak ada permintaan baru.',
    );
  }

  Widget _passwordForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AuthField(controller: _pwEmail, hint: 'User / Email', icon: Icons.person_outline),
      const SizedBox(height: 10),
      AuthField(controller: _pw1, hint: 'New Password', icon: Icons.lock_outline, obscure: true),
      const SizedBox(height: 10),
      AuthField(
        controller: _pw2,
        hint: 'Confirm Password',
        icon: Icons.lock_outline,
        obscure: true,
        action: TextInputAction.done,
        onSubmitted: _savePassword,
      ),
      const SizedBox(height: 12),
      PrimaryButton(label: 'Save Changes', icon: Icons.save_outlined, loading: _saving, onPressed: _savePassword),
    ]);
  }

  Widget _chip(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}
