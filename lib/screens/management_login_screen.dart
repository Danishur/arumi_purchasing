import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../widgets/auth_widgets.dart';
import 'management_user_screen.dart';

/// Login tambahan untuk membuka Management User. Hanya akun owner yang
/// bisa masuk -- user biasa tetap ditolak walau password-nya benar.
class ManagementLoginScreen extends StatefulWidget {
  const ManagementLoginScreen({super.key});

  @override
  State<ManagementLoginScreen> createState() => _ManagementLoginScreenState();
}

class _ManagementLoginScreenState extends State<ManagementLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      showAuthSnack(context, 'Isi user / email dan password.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final u = await DatabaseService.instance.loginUser(_email.text.trim(), _password.text);
      if ((u['role'] ?? '') != 'owner') {
        throw AuthException('Management User hanya bisa dibuka oleh owner.');
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ManagementUserScreen()));
    } on AuthException catch (e) {
      if (mounted) showAuthSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showAuthSnack(context, 'Tidak bisa login: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
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
      ),
      body: AuthBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 104,
                height: 104,
                decoration: const BoxDecoration(color: Color(0xFFE3EAF8), shape: BoxShape.circle),
                child: const Icon(Icons.groups_2_outlined, size: 52, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Management User',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Login dulu untuk membuka pengaturan user.\nHanya untuk owner.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 26),
            AuthField(controller: _email, hint: 'User / Email', icon: Icons.mail_outline),
            const SizedBox(height: 14),
            AuthField(
              controller: _password,
              hint: 'Password',
              icon: Icons.lock_outline,
              obscure: true,
              action: TextInputAction.done,
              onSubmitted: _login,
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Login', icon: Icons.login, loading: _loading, onPressed: _login),
          ],
        ),
      ),
    );
  }
}
