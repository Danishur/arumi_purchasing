import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../widgets/auth_widgets.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';

/// Layar Login. Hanya user yang sudah disetujui owner yang bisa masuk.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
      await context.read<AuthProvider>().login(_email.text, _password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
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
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: 250,
            color: AppColors.primary,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: 40,
                    width: double.infinity,
                    child: CustomPaint(painter: _WavePainter()),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        ArumiLogo(size: 92),
                        SizedBox(height: 10),
                        Text('Arumi Purchasing',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('PT Arumi Solusi Negeri', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AuthBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Welcome Back', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  const Text('Please login to your account', style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 18),
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
                  const SizedBox(height: 18),
                  PrimaryButton(label: 'Login', loading: _loading, onPressed: _login),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or', style: TextStyle(color: AppColors.textMuted)),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Register / Create Account'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetPasswordScreen())),
                    child: const Text('Forgot Password?'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.55)
      ..cubicTo(w * 0.22, h * 0.1, w * 0.45, 0, w * 0.62, h * 0.25)
      ..cubicTo(w * 0.78, h * 0.48, w * 0.9, h * 0.55, w, h * 0.35)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.background);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
