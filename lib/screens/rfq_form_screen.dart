import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../models/material_item.dart';
import '../models/rfq.dart';
import '../models/rfq_material.dart';
import '../providers/customer_provider.dart';
import '../providers/material_provider.dart';
import '../providers/rfq_provider.dart';
import '../utils/app_theme.dart';
import '../utils/material_options.dart';
import '../utils/rfq_options.dart';
import '../widgets/multi_option_picker_dialog.dart';
import '../widgets/option_picker_dialog.dart';

/// Satu baris Material terpilih di "Material List" -- bawa Quantity &
/// Unit sendiri (dipindah dari Material ke RFQ sesuai revisi owner).
class _RfqMaterialRow {
  final int materialId;
  final String label;
  final TextEditingController quantityCtrl;
  String? unit;

  _RfqMaterialRow({
    required this.materialId,
    required this.label,
    String quantity = '0',
    this.unit,
  }) : quantityCtrl = TextEditingController(text: quantity);

  void dispose() => quantityCtrl.dispose();
}

class RfqFormScreen extends StatefulWidget {
  final Rfq? rfq; // null = mode tambah, terisi = mode edit

  const RfqFormScreen({super.key, this.rfq});

  @override
  State<RfqFormScreen> createState() => _RfqFormScreenState();
}

class _RfqFormScreenState extends State<RfqFormScreen> {
  final _referenceCtrl = TextEditingController();
  final _picCtrl = TextEditingController();
  final _internalNoteCtrl = TextEditingController();

  DateTime? _dateRequest;
  DateTime? _dueDate;
  int? _customerId;
  String? _status;

  final List<_RfqMaterialRow> _materialRows = [];

  bool _loadingRelated = true;
  bool _isSaving = false;
  bool _loadingCustomers = true;
  bool _loadingMaterials = true;
  List<Customer> _customers = [];
  List<MaterialItem> _materials = [];

  bool get _isEditMode => widget.rfq != null;

  @override
  void initState() {
    super.initState();
    final r = widget.rfq;
    if (r != null) {
      _referenceCtrl.text = r.reference ?? '';
      _picCtrl.text = r.pic ?? '';
      _internalNoteCtrl.text = r.internalNote ?? '';
      _dateRequest = r.dateRequest;
      _dueDate = r.dueDate;
      _customerId = r.customerId;
      _status = r.status;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomers();
      _loadMaterials();
      _loadMaterialLines();
    });
  }

  Future<void> _loadCustomers() async {
    try {
      final provider = context.read<CustomerProvider>();
      if (provider.customers.isEmpty) {
        await provider.loadCustomers();
      }
      if (!mounted) return;
      setState(() {
        _customers = provider.customers;
        _loadingCustomers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCustomers = false);
      _showSnack('Gagal memuat daftar Customer: $e', isError: true);
    }
  }

  Future<void> _loadMaterials() async {
    try {
      final provider = context.read<MaterialProvider>();
      if (provider.materials.isEmpty) {
        await provider.loadMaterials();
      }
      if (!mounted) return;
      setState(() {
        _materials = provider.materials;
        _loadingMaterials = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMaterials = false);
      _showSnack('Gagal memuat daftar Material: $e', isError: true);
    }
  }

  Future<void> _loadMaterialLines() async {
    final r = widget.rfq;
    if (r == null || r.id == null) {
      setState(() => _loadingRelated = false);
      return;
    }
    try {
      final lines = await context.read<RfqProvider>().getMaterialLinesForRfq(r.id!);
      if (!mounted) return;
      setState(() {
        _materialRows.addAll(lines.map((l) => _RfqMaterialRow(
              materialId: l.materialId,
              label: l.displayLabel,
              quantity: '${l.quantity}',
              unit: l.unit,
            )));
        _loadingRelated = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingRelated = false);
      _showSnack('Gagal memuat Material List: $e', isError: true);
    }
  }

  @override
  void dispose() {
    _referenceCtrl.dispose();
    _picCtrl.dispose();
    _internalNoteCtrl.dispose();
    for (final row in _materialRows) {
      row.dispose();
    }
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

  String _materialOptionLabel(MaterialItem m) {
    final desc = (m.itemDescription ?? '').trim();
    return desc.isEmpty ? m.materialCode : '$desc (${m.materialCode})';
  }

  Future<void> _pickDateRequest() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateRequest ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dateRequest = picked);
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickCustomer() async {
    if (_loadingCustomers) return;
    if (_customers.isEmpty) {
      _showSnack('Belum ada data Customer. Tambahkan Customer dulu di modul Customer.', isError: true);
      return;
    }
    final options = _customers.map((c) => c.name).toList();
    final currentName = _customerId == null
        ? null
        : _customers.firstWhere((c) => c.id == _customerId, orElse: () => _customers.first).name;
    final result = await showOptionPickerDialog(
      context: context,
      title: 'Customer',
      options: options,
      selectedValue: currentName,
      withSearch: true,
    );
    if (result != null) {
      final selected = _customers.firstWhere((c) => c.name == result);
      setState(() => _customerId = selected.id);
    }
  }

  Future<void> _pickMaterialList() async {
    if (_loadingMaterials) return;
    if (_materials.isEmpty) {
      _showSnack('Belum ada data Material. Tambahkan Material dulu di modul Material.', isError: true);
      return;
    }
    final labelToMaterial = {for (final m in _materials) _materialOptionLabel(m): m};
    final options = labelToMaterial.keys.toList();
    final currentLabels = _materialRows.map((r) => r.label).toList();

    final result = await showMultiOptionPickerDialog(
      context: context,
      title: 'Material List',
      options: options,
      selectedValues: currentLabels,
      withSearch: true,
    );
    if (result == null) return;

    final selectedIds =
        result.map((label) => labelToMaterial[label]?.id).whereType<int>().toSet();

    setState(() {
      _materialRows.removeWhere((row) {
        final stillSelected = selectedIds.contains(row.materialId);
        if (!stillSelected) row.dispose();
        return !stillSelected;
      });
      final existingIds = _materialRows.map((row) => row.materialId).toSet();
      for (final label in result) {
        final m = labelToMaterial[label];
        if (m?.id == null || existingIds.contains(m!.id)) continue;
        _materialRows.add(_RfqMaterialRow(materialId: m.id!, label: label));
      }
    });
  }

  Future<void> _pickRowUnit(_RfqMaterialRow row) async {
    final result = await showOptionPickerDialog(
      context: context,
      title: 'Unit',
      options: MaterialOptions.unit,
      selectedValue: row.unit,
      withSearch: true,
    );
    if (result != null) setState(() => row.unit = result);
  }

  Future<void> _pickStatus() async {
    final result = await showOptionPickerDialog(
      context: context,
      title: 'Status',
      options: RfqOptions.status,
      selectedValue: _status,
      withSearch: false,
    );
    if (result != null) setState(() => _status = result);
  }

  Future<void> _save() async {
    if (_isSaving) return;

    for (final row in _materialRows) {
      final qty = int.tryParse(row.quantityCtrl.text) ?? 0;
      if (qty <= 0) {
        _showSnack('Quantity untuk "${row.label}" harus lebih dari 0.', isError: true);
        return;
      }
    }

    final rfq = Rfq(
      id: widget.rfq?.id,
      reference: _referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim(),
      pic: _picCtrl.text.trim().isEmpty ? null : _picCtrl.text.trim(),
      dateRequest: _dateRequest,
      dueDate: _dueDate,
      customerId: _customerId,
      internalNote: _internalNoteCtrl.text.trim().isEmpty ? null : _internalNoteCtrl.text.trim(),
      status: _status,
    );

    final lines = _materialRows
        .map((row) => RfqMaterialLine(
              materialId: row.materialId,
              quantity: int.tryParse(row.quantityCtrl.text) ?? 0,
              unit: row.unit,
            ))
        .toList();

    setState(() => _isSaving = true);
    try {
      final provider = context.read<RfqProvider>();
      if (_isEditMode) {
        await provider.updateRfq(rfq, lines);
      } else {
        await provider.addRfq(rfq, lines);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Gagal menyimpan RFQ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: const [
            Icon(Icons.request_quote_outlined, size: 22),
            SizedBox(width: 8),
            Text('RFQ Form'),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _loadingRelated
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. RFQ Number
                  _label('RFQ Number'),
                  _readOnlyBox(_isEditMode ? widget.rfq!.rfqCode : 'Otomatis setelah disimpan'),
                  const SizedBox(height: 16),

                  // 2. Reference
                  _label('Reference'),
                  _textField(controller: _referenceCtrl, hint: 'Nomor referensi (opsional)'),
                  const SizedBox(height: 16),

                  // 3. PIC
                  _label('PIC'),
                  _textField(controller: _picCtrl, hint: 'Nama PIC yang menangani RFQ ini'),
                  const SizedBox(height: 16),

                  // 4. Date Request
                  _label('Date Request'),
                  _datePickerBox(_dateRequest, _pickDateRequest),
                  const SizedBox(height: 16),

                  // 5. Due Date
                  _label('Due Date'),
                  _datePickerBox(_dueDate, _pickDueDate),
                  const SizedBox(height: 16),

                  // 6. Customer
                  _label('Customer'),
                  _pickerBox(
                    value: _customerId == null
                        ? null
                        : _customers
                            .firstWhere((c) => c.id == _customerId,
                                orElse: () => Customer(name: ''))
                            .name,
                    hint: _loadingCustomers ? 'Memuat data customer...' : '-- Pilih Customer --',
                    onTap: _pickCustomer,
                  ),
                  const SizedBox(height: 16),

                  // 7-9. Material List (tiap baris bawa Quantity & Unit sendiri)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _label('Material List'),
                      OutlinedButton.icon(
                        onPressed: _pickMaterialList,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Pilih Material'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Bisa pilih lebih dari 1 Material. Quantity & Unit diisi per Material.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  if (_materialRows.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Text('Belum ada Material dipilih.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    )
                  else
                    ..._materialRows.map((row) => _materialLineCard(row)),
                  const SizedBox(height: 16),

                  // 10. Internal Note
                  _label('Internal Note'),
                  _textField(
                    controller: _internalNoteCtrl,
                    hint: 'Catatan internal (tidak tampil ke customer/vendor)',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // 11. Status
                  _label('Status'),
                  _pickerBox(value: _status, hint: '-- Pilih Status --', onTap: _pickStatus),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                          child: const Text('Cancel', style: TextStyle(color: Colors.black87)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _materialLineCard(_RfqMaterialRow row) {
    void changeQty(int delta) {
      final current = int.tryParse(row.quantityCtrl.text) ?? 0;
      final next = current + delta;
      row.quantityCtrl.text = '${next < 0 ? 0 : next}';
      setState(() {});
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(row.label,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  InkWell(
                    onTap: () => setState(() {
                      row.dispose();
                      _materialRows.remove(row);
                    }),
                    child: const Icon(Icons.close, size: 18, color: AppColors.danger),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quantity',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: row.quantityCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13),
                                  decoration:
                                      const InputDecoration(border: InputBorder.none, isDense: true),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove, size: 16),
                                onPressed: () => changeQty(-1),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 16),
                                onPressed: () => changeQty(1),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Unit', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _pickRowUnit(row),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    row.unit ?? '-- Unit --',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: row.unit == null ? Colors.grey.shade400 : Colors.black87,
                                    ),
                                  ),
                                ),
                                Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey.shade600),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  // ---------------- Widget helper ----------------

  Widget _label(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
        children: [
          TextSpan(text: text),
          if (required) const TextSpan(text: ' *', style: TextStyle(color: AppColors.danger)),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _readOnlyBox(String text) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(text,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  Widget _pickerBox({required String? value, required String hint, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: onTap,
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
              Expanded(
                child: Text(
                  value ?? hint,
                  style: TextStyle(fontSize: 14, color: value == null ? Colors.grey.shade400 : Colors.black87),
                ),
              ),
              Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datePickerBox(DateTime? date, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: onTap,
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
              Expanded(
                child: Text(
                  date == null ? 'dd/mm/yyyy' : DateFormat('dd/MM/yyyy').format(date),
                  style: TextStyle(fontSize: 14, color: date == null ? Colors.grey.shade400 : Colors.black87),
                ),
              ),
              Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }
}
