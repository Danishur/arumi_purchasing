import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Dialog pilihan single-select bergaya referensi desain: judul di atas,
/// opsional kolom search, daftar radio button, tombol "Done" di kanan
/// bawah. Dipakai untuk "Terms of Payment" (withSearch: true) dan
/// "Customer Type" (withSearch: false).
///
/// Return: string yang dipilih user, atau null kalau dibatalkan (tap di
/// luar dialog).
Future<String?> showOptionPickerDialog({
  required BuildContext context,
  required String title,
  required List<String> options,
  String? selectedValue,
  bool withSearch = true,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _OptionPickerDialog(
      title: title,
      options: options,
      initialValue: selectedValue,
      withSearch: withSearch,
    ),
  );
}

class _OptionPickerDialog extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? initialValue;
  final bool withSearch;

  const _OptionPickerDialog({
    required this.title,
    required this.options,
    required this.initialValue,
    required this.withSearch,
  });

  @override
  State<_OptionPickerDialog> createState() => _OptionPickerDialogState();
}

class _OptionPickerDialogState extends State<_OptionPickerDialog> {
  String? _selected;
  final TextEditingController _searchCtrl = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
    _filtered = widget.options;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filtered = widget.options
          .where((o) => o.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 20),
              if (widget.withSearch) ...[
                TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    labelText: 'Search',
                    labelStyle: const TextStyle(color: AppColors.accent),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Flexible(
                child: _filtered.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Tidak ada hasil.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final option = _filtered[index];
                          return RadioListTile<String>(
                            value: option,
                            groupValue: _selected,
                            title: Text(option, style: const TextStyle(fontSize: 14)),
                            dense: true,
                            activeColor: AppColors.primary,
                            onChanged: (val) => setState(() => _selected = val),
                          );
                        },
                      ),
              ),
              const Divider(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: const Text(
                    'Done',
                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
