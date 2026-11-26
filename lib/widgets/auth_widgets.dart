import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Logo PT Arumi bulat.
class ArumiLogo extends StatelessWidget {
  final double size;
  const ArumiLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_arumi.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Logo PT Arumi',
    );
  }
}

/// Kolom isian bergaya kartu putih dengan ikon di kiri. [obscure] = kolom
/// password dengan tombol lihat / sembunyikan.
class AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputAction action;
  final VoidCallback? onSubmitted;
  final TextInputType? keyboardType;

  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.action = TextInputAction.next,
    this.onSubmitted,
    this.keyboardType,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _hidden,
      textInputAction: widget.action,
      keyboardType: widget.keyboardType,
      onSubmitted: widget.onSubmitted == null ? null : (_) => widget.onSubmitted!(),
      decoration: InputDecoration(
        hintText: widget.hint,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(widget.icon, color: AppColors.textMuted),
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Tampilkan password' : 'Sembunyikan password',
                icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.textMuted),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
    );
  }
}

/// Tombol utama biru lebar penuh. [loading] menampilkan spinner.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 10)],
                  Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }
}

/// Isi layar form dibatasi lebar 420 supaya tetap rapi di jendela desktop.
class AuthBody extends StatelessWidget {
  final Widget child;
  const AuthBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: child),
      ),
    );
  }
}

void showAuthSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : null,
    ));
}
