import 'package:flutter/material.dart';
import '../import/import_specs.dart';
import '../import/import_types.dart';
import '../utils/app_theme.dart';
import 'import_screen.dart';

/// Settings > Update DB: pilih modul yang mau di-import dari Excel.
class UpdateDbScreen extends StatelessWidget {
  const UpdateDbScreen({super.key});

  static const _icons = {
    ImportModule.customer: Icons.business,
    ImportModule.vendor: Icons.store,
    ImportModule.material: Icons.inventory_2,
    ImportModule.rfq: Icons.request_quote,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Update DB'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withOpacity(0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: AppColors.accent),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Urutan import: Customer dan Vendor dulu, lalu Material, terakhir RFQ.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final m in ImportModule.values) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: ListTile(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ImportScreen(module: m)),
                ),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Icon(_icons[m], color: AppColors.primary),
                ),
                title: Row(
                  children: [
                    Text(ImportSpecs.title(m), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(ImportSpecs.prerequisite(m),
                          style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                    ),
                  ],
                ),
                subtitle: Text(ImportSpecs.description(m), style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
