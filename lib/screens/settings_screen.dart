import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'currency_screen.dart';
import 'edit_dropdown_menu_screen.dart';
import 'management_login_screen.dart';
import 'update_db_screen.dart';

/// Layar Settings -- dibuka dari Home. Isinya 4 menu: "Edit Dropdown",
/// "Update Valuta", "Update DB" (import data lama dari Excel), dan
/// "Management User" (khusus owner).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _menuCard(
            context,
            icon: Icons.tune,
            title: 'Edit Dropdown',
            subtitle: 'Edit isi pilihan dropdown di semua form',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditDropdownMenuScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _menuCard(
            context,
            icon: Icons.currency_exchange,
            title: 'Update Valuta',
            subtitle: 'Kelola nilai tukar mata uang ke IDR',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CurrencyScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _menuCard(
            context,
            icon: Icons.upload_file,
            title: 'Update DB',
            subtitle: 'Import data lama dari file Excel',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UpdateDbScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _menuCard(
            context,
            icon: Icons.groups_2_outlined,
            title: 'Management User',
            subtitle: 'Kelola akun, persetujuan user, dan riwayat (owner)',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManagementLoginScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        enabled: enabled,
        onTap: enabled ? onTap : null,
        leading: CircleAvatar(
          backgroundColor: enabled ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade200,
          child: Icon(icon, color: enabled ? AppColors.primary : Colors.grey),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: enabled ? const Icon(Icons.chevron_right) : null,
      ),
    );
  }
}
