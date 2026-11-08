import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'edit_dropdown_screen.dart';

/// TAMBAHAN: Settings > Edit Dropdown -- pintu masuk ke pengelolaan isi
/// dropdown tiap modul. Sesuai sketsa referensi: list menu Customer,
/// Vendor, Material, RFQ, dan Update Valuta, masing-masing membuka
/// [EditDropdownScreen] berisi field-field dropdown milik modul itu.
class EditDropdownMenuScreen extends StatelessWidget {
  const EditDropdownMenuScreen({super.key});

  // Field dropdown per modul yang bisa diedit -- sesuai daftar yang
  // diminta owner. `category` adalah kunci baris di tabel
  // `dropdown_options` (lihat DropdownOptionsCache); beberapa field
  // SENGAJA berbagi kategori yang sama dengan field di modul lain
  // (lihat catatan masing-masing kategori) karena memang sumber datanya
  // sama persis dengan yang dipakai form terkait.
  static const Map<String, List<DropdownFieldConfig>> moduleFields = {
    'Customer': [
      DropdownFieldConfig('customer_terms_of_payment', 'Terms of Payment'),
      DropdownFieldConfig('customer_customer_type', 'Customer Type'),
    ],
    'Vendor': [
      DropdownFieldConfig('vendor_legal_standing', 'Legal Standing'),
      DropdownFieldConfig('vendor_terms_of_payment', 'Terms of Payment'),
      DropdownFieldConfig('scope_of_work', 'Scope of Work'),
      DropdownFieldConfig('sub_sow', 'Sub SOW'),
      DropdownFieldConfig('vendor_supply_chain_classification', 'Supply Chain Classification'),
    ],
    'Material': [
      DropdownFieldConfig('scope_of_work', 'Scope of Work'),
      DropdownFieldConfig('sub_sow', 'Sub SOW'),
      DropdownFieldConfig('material_category', 'Category'),
      DropdownFieldConfig('material_documents', 'Documents'),
    ],
    'RFQ': [
      DropdownFieldConfig('material_documents', 'Document Requirement'),
      DropdownFieldConfig('rfq_status', 'Status'),
    ],
    'Update Valuta': [
      DropdownFieldConfig('currency', 'Currency'),
    ],
  };

  static const Map<String, IconData> moduleIcons = {
    'Customer': Icons.account_circle_outlined,
    'Vendor': Icons.storefront_outlined,
    'Material': Icons.inventory_2_outlined,
    'RFQ': Icons.request_quote_outlined,
    'Update Valuta': Icons.currency_exchange,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Dropdown'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Kelola data dropdown untuk setiap halaman.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          for (final module in moduleFields.keys) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Icon(moduleIcons[module], color: AppColors.primary),
                ),
                title: Text(module, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  moduleFields[module]!.map((f) => f.label).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditDropdownScreen(
                      module: module,
                      fields: moduleFields[module]!,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// 1 field dropdown yang bisa diedit: `category` = kunci baris di tabel
/// `dropdown_options`, `label` = nama yang ditampilkan ke user.
class DropdownFieldConfig {
  final String category;
  final String label;

  const DropdownFieldConfig(this.category, this.label);
}
