import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../utils/dropdown_options_cache.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';

/// Layar pembuka: logo Arumi + tulisan "PT ARUMI", lalu langsung ke
/// halaman Login. Sambil tampil, app menyiapkan database (tabel user &
/// riwayat, hapus riwayat lama) dan isi dropdown.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      final minShow = Future.delayed(const Duration(milliseconds: 1800));
      await DatabaseService.instance.ensureAuthTables();
      await DropdownOptionsCache.loadAll();
      await minShow;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ArumiLogo(size: 150),
            const SizedBox(height: 20),
            const Text(
              'PT ARUMI',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 28),
            if (_error == null)
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  children: [
                    const Text('Tidak bisa terhubung ke database.',
                        style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
