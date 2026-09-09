import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Dialog pilihan MULTI-select bergaya sama dengan
/// [showOptionPickerDialog], bedanya pakai checkbox (bukan radio) dan
/// ada tombol "Select All". Dipakai untuk "Scope of Work" (withSearch:
/// false) dan "Sub-SoW" (withSearch: true), sesuai referensi desain.
///
/// Return: daftar string yang dipilih user, atau null kalau dibatalkan
/// (tap di luar dialog).
Future<List<String>?> showMultiOptionPickerDialog({
  required BuildContext context,
  required String title,
  required List<String> options,
  List<String> selectedValues = const [],
  bool withSearch = true,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => _MultiOptionPickerDialog(
      title: title,
      options: options,
      initialValues: selectedValues,
      withSearch: withSearch,
    ),
  );
}

class _MultiOptionPickerDialog extends StatefulWidget {
  final String title;
  final List<String> options;
  final List<String> initialValues;
  final bool withSearch;

  const _MultiOptionPickerDialog({
    required this.title,
    required this.options,
    required this.initialValues,
    required this.withSearch,
  });

  @override
  State<_MultiOptionPickerDialog> createState() => _MultiOptionPickerDialogState();
}

class _MultiOptionPickerDialogState extends State<_MultiOptionPickerDialog> {
  late Set<String> _selected;
  final TextEditingController _searchCtrl = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValues.toSet();
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

  void _toggleSelectAll() {
    setState(() {
      final allSelected = _selected.length == widget.options.length;
      if (allSelected) {
        _selected.clear();
      } else {
        _selected = widget.options.toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _selected.length == widget.options.length && widget.options.isNotEmpty;

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
                          return CheckboxListTile(
                            value: _selected.contains(option),
                            title: Text(option, style: const TextStyle(fontSize: 14)),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: AppColors.primary,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selected.add(option);
                                } else {
                                  _selected.remove(option);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _toggleSelectAll,
                    child: Text(
                      allSelected ? 'Unselect All' : 'Select All',
                      style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selected.toList()),
                    child: const Text(
                      'Done',
                      style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
