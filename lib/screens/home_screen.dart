import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'customer_list_screen.dart';
import 'material_list_screen.dart';
import 'rfq_list_screen.dart';
import 'settings_screen.dart';
import 'vendor_list_screen.dart';

/// Layar Home -- menu navigasi ke tiap modul (Customer, Vendor,
/// Material, RFQ, Settings).
/// Sebelumnya `home:` di main.dart langsung ke CustomerListScreen
/// (minggu 1, waktu modul Vendor belum ada) -- sekarang dengan 2 modul
/// aktif, perlu 1 pintu masuk supaya user bisa pilih mau buka yang mana.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Purchasing Intermediary'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _menuCard(
            context,
            icon: Icons.account_circle_outlined,
            title: 'Customer',
            subtitle: 'Data master customer & PIC',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerListScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _menuCard(
            context,
            icon: Icons.storefront_outlined,
            title: 'Vendor',
            subtitle: 'Data master vendor, PIC, & Produk/Brand',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VendorListScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _menuCard(
            context,
            icon: Icons.inventory_2_outlined,
            title: 'Material',
            subtitle: 'Data master barang, harga, & pengiriman',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MaterialListScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _menuCard(
            context,
            icon: Icons.request_quote_outlined,
            title: 'RFQ',
            subtitle: 'Permintaan quotation ke vendor berdasarkan Material',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RfqListScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _menuCard(
            context,
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Edit Dropdown & Update Valuta',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
