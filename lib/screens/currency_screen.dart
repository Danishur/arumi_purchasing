import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/currency_rate.dart';
import '../providers/currency_provider.dart';
import '../utils/app_theme.dart';
import '../utils/vendor_options.dart';
import '../widgets/option_picker_dialog.dart';

final _numFmt = NumberFormat.decimalPattern('id_ID');

/// Layar "Update Valuta" (Settings -> Update Valuta), sesuai desain
/// referensi: form Add Currency (pilih mata uang + nilai dalam IDR)
/// di atas, daftar "Added Currencies" di bawah dengan tombol
/// edit/hapus per baris.
///
/// Mata uang yang bisa dipilih di sini SENGAJA sama dengan
/// VendorOptions.currency (field "Bank Account-Currency" di Vendor
/// Form), sesuai permintaan: "isian currency-nya mengambil dari bank
/// currency yg ada di vendor form".
class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  String? _selectedCurrency;
  final _valueCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  int? _editingId; // != null kalau sedang edit baris yang sudah ada

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      await context.read<CurrencyProvider>().loadRates();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.secondary,
      ),
    );
  }

  Future<void> _pickCurrency() async {
    final result = await showOptionPickerDialog(
      context: context,
      title: 'Currency',
      options: VendorOptions.currency,
      selectedValue: _selectedCurrency,
      withSearch: true,
    );
    if (result != null) setState(() => _selectedCurrency = result);
  }

  double get _valueNumber =>
      double.tryParse(_valueCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

  Future<void> _submit() async {
    if (_selectedCurrency == null) {
      _showSnack('Pilih currency dulu.', isError: true);
      return;
    }
    if (_valueNumber <= 0) {
      _showSnack('Isi nilai (IDR) lebih dari 0.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<CurrencyProvider>().addOrUpdateRate(_selectedCurrency!, _valueNumber);
      if (!mounted) return;
      _showSnack(_editingId != null ? 'Currency berhasil diupdate.' : 'Currency berhasil ditambahkan.');
      setState(() {
        _selectedCurrency = null;
        _valueCtrl.clear();
        _editingId = null;
      });
    } catch (e) {
      _showSnack('Gagal menyimpan currency: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _startEdit(CurrencyRate rate) {
    setState(() {
      _selectedCurrency = rate.currencyCode;
      _valueCtrl.text = _numFmt.format(rate.rateToIdr);
      _editingId = rate.id;
    });
  }

  Future<void> _confirmDelete(CurrencyRate rate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Currency?'),
        content: Text('Yakin ingin menghapus "${rate.currencyCode}" dari daftar Update Valuta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || rate.id == null) return;
    try {
      await context.read<CurrencyProvider>().deleteRate(rate.id!);
      _showSnack('Currency dihapus.');
    } catch (e) {
      _showSnack('Gagal menghapus currency: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rates = context.watch<CurrencyProvider>().rates;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Currency'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Manage and update your currency values. You can add multiple currencies and set their exchange rate or value manually.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.swap_horiz, color: AppColors.primary),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _editingId != null ? 'Edit Currency' : 'Add Currency',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Select a currency and enter the value (in IDR).',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 14),
                        const Text('Currency',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickCurrency,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedCurrency ?? 'Search currency',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _selectedCurrency == null
                                          ? Colors.grey.shade400
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text('Value (IDR)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _valueCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Enter amount',
                            suffixText: 'IDR',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    _editingId != null ? 'Update' : 'Add',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                          ),
                        ),
                        if (_editingId != null)
                          Center(
                            child: TextButton(
                              onPressed: () => setState(() {
                                _selectedCurrency = null;
                                _valueCtrl.clear();
                                _editingId = null;
                              }),
                              child: const Text('Batal edit'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Added Currencies',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('${rates.length} currencies',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 10),
                if (rates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Belum ada currency ditambahkan.',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  )
                else
                  ...rates.map((r) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: Text(
                              r.currencyCode.isNotEmpty ? r.currencyCode[0] : '?',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(r.currencyCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${_numFmt.format(r.rateToIdr)} IDR'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                                onPressed: () => _startEdit(r),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                onPressed: () => _confirmDelete(r),
                              ),
                            ],
                          ),
                        ),
                      )),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Values are entered manually. Make sure the amounts are up to date.',
                          style: TextStyle(fontSize: 12, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
