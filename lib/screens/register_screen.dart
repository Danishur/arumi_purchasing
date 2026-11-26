import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../utils/user_options.dart';
import '../widgets/auth_widgets.dart';

/// Layar Register: user mengisi data lalu "Send for Approve". Akun baru
/// baru bisa dipakai login setelah disetujui owner (Management User >
/// New User).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _idNumber = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _position;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _idNumber.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _position == null ||
        _idNumber.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty) {
      showAuthSnack(context, 'Semua kolom wajib diisi.', error: true);
      return;
    }
    if (_password.text.length < 6) {
      showAuthSnack(context, 'Password minimal 6 karakter.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await DatabaseService.instance.registerUser(
        name: _name.text.trim(),
        position: _position!,
        idNumber: _idNumber.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: AppColors.secondary, size: 40),
          title: const Text('Permintaan terkirim'),
          content: const Text('Akun kamu menunggu persetujuan owner. Kamu bisa login setelah disetujui.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) showAuthSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showAuthSnack(context, 'Gagal mengirim: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Register'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: AuthBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const ArumiLogo(size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Buat akun baru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Isi data berikut untuk meminta akun. Owner akan menyetujui dulu.',
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 20),
            AuthField(controller: _name, hint: 'Nama', icon: Icons.person_outline),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _position,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: 'Posisi',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.work_outline, color: AppColors.textMuted),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              items: [for (final p in UserOptions.positions) DropdownMenuItem(value: p, child: Text(p))],
              onChanged: (v) => setState(() => _position = v),
            ),
            const SizedBox(height: 14),
            AuthField(controller: _idNumber, hint: 'ID Number', icon: Icons.badge_outlined),
            const SizedBox(height: 14),
            AuthField(controller: _email, hint: 'User / Email', icon: Icons.mail_outline),
            const SizedBox(height: 14),
            AuthField(
              controller: _password,
              hint: 'Password',
              icon: Icons.lock_outline,
              obscure: true,
              action: TextInputAction.done,
              onSubmitted: _submit,
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Send for Approve', icon: Icons.send, loading: _loading, onPressed: _submit),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Sudah punya akun? ', style: TextStyle(color: AppColors.textMuted)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text('Login',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
