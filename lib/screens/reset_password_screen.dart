import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../widgets/auth_widgets.dart';

/// Layar "Lupa password": user mengisi email + password baru, lalu
/// "Send for Approve". Password baru berlaku setelah owner menyetujui
/// (Management User > New User).
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _email = TextEditingController();
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _pw1.text.isEmpty || _pw2.text.isEmpty) {
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
    setState(() => _loading = true);
    try {
      await DatabaseService.instance.requestPasswordReset(_email.text.trim(), _pw1.text);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: AppColors.secondary, size: 40),
          title: const Text('Permintaan terkirim'),
          content: const Text('Password baru berlaku setelah disetujui owner. Login pakai password lama dulu.'),
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
        title: const Text('Reset Password'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: AuthBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(color: Color(0xFFE3EAF8), shape: BoxShape.circle),
                child: const Icon(Icons.lock_outline, size: 40, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Lupa password?',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              'Masukkan email dan password baru. Perubahan berlaku setelah disetujui owner.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 22),
            AuthField(controller: _email, hint: 'User / Email', icon: Icons.mail_outline),
            const SizedBox(height: 14),
            AuthField(controller: _pw1, hint: 'Password baru', icon: Icons.lock_outline, obscure: true),
            const SizedBox(height: 14),
            AuthField(
              controller: _pw2,
              hint: 'Ulangi password baru',
              icon: Icons.lock_outline,
              obscure: true,
              action: TextInputAction.done,
              onSubmitted: _submit,
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Send for Approve', icon: Icons.send, loading: _loading, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
