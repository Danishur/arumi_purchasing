import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/material_discount.dart';
import '../models/material_item.dart';
import '../models/vendor.dart';
import '../providers/material_provider.dart';
import '../providers/vendor_provider.dart';
import '../utils/app_theme.dart';
import '../utils/material_options.dart';
import '../utils/vendor_options.dart';
import '../widgets/multi_option_picker_dialog.dart';
import '../widgets/option_picker_dialog.dart';

final _rupiahFmt = NumberFormat.decimalPattern('id_ID');

/// Satu baris "+ Add Discount" di form Material.
class _DiscountRow {
  final TextEditingController amountCtrl;
  DateTime? date;

  _DiscountRow({String amount = '0', this.date})
      : amountCtrl = TextEditingController(text: amount);

  double get amountValue => double.tryParse(amountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

  void dispose() => amountCtrl.dispose();
}

class MaterialFormScreen extends StatefulWidget {
  final MaterialItem? material; // null = mode tambah, terisi = mode edit

  const MaterialFormScreen({super.key, this.material});

  @override
  State<MaterialFormScreen> createState() => _MaterialFormScreenState();
}

class _MaterialFormScreenState extends State<MaterialFormScreen> {
  int? _vendorId;
  String? _scopeOfWork;
  String? _subSow;
  final _brandCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();

  final _itemDescCtrl = TextEditingController();
  String? _category;
  final _itemManufacturerCtrl = TextEditingController();
  final _originCountryCtrl = TextEditingController();
  final _itemTypeCtrl = TextEditingController();
  final _itemPartNumberCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  String? _photoPath;
  final _refGenuinePartCtrl = TextEditingController();
  final _existingItemDescCtrl = TextEditingController();


  final _priceQuoteCtrl = TextEditingController(text: '0');
  DateTime? _priceQuoteDate;
  final List<_DiscountRow> _discountRows = [];
  bool _vat = false;

  final _leadTimeCtrl = TextEditingController(text: '0');
  String? _deliveryTerms;
  final _deliveryAddressCtrl = TextEditingController();

  final _dimPCtrl = TextEditingController();
  final _dimLCtrl = TextEditingController();
  final _dimTCtrl = TextEditingController();
  String _dimUnit = 'MM';
  final _weightCtrl = TextEditingController();
  String _weightUnit = 'KG';

  List<String> _documents = [];
  bool _isTransaction = false;
  bool _isActive = true;

  bool _loadingRelated = true;
  bool _isSaving = false;
  bool _loadingVendors = true;
  List<Vendor> _vendors = [];

  bool get _isEditMode => widget.material != null;

  @override
  void initState() {
    super.initState();
    final m = widget.material;
    if (m != null) {
      _vendorId = m.vendorId;
      _scopeOfWork = m.scopeOfWork;
      _subSow = m.subSow;
      _brandCtrl.text = m.brandUnitInstalledOn ?? '';
      _typeCtrl.text = m.typeUnitInstalledOn ?? '';
      _itemDescCtrl.text = m.itemDescription ?? '';
      _category = m.category;
      _itemManufacturerCtrl.text = m.itemManufacturer ?? '';
      _originCountryCtrl.text = m.originCountry ?? '';
      _itemTypeCtrl.text = m.itemType ?? '';
      _itemPartNumberCtrl.text = m.itemPartNumber ?? '';
      _sizeCtrl.text = m.size ?? '';
      _photoPath = m.photoPath;
      _refGenuinePartCtrl.text = m.referenceGenuinePartNumber ?? '';
      _existingItemDescCtrl.text = m.existingItemDescription ?? '';
      _priceQuoteCtrl.text = _trimZero(m.priceQuote);
      _priceQuoteDate = m.priceQuoteDate;
      _vat = m.vat;
      _leadTimeCtrl.text = '${m.leadTimeDays}';
      _deliveryTerms = m.deliveryTerms;
      _deliveryAddressCtrl.text = m.deliveryAddress ?? '';
      if (m.dimP != null) _dimPCtrl.text = _trimZero(m.dimP!);
      if (m.dimL != null) _dimLCtrl.text = _trimZero(m.dimL!);
      if (m.dimT != null) _dimTCtrl.text = _trimZero(m.dimT!);
      _dimUnit = m.dimUnit ?? 'MM';
      if (m.weight != null) _weightCtrl.text = _trimZero(m.weight!);
      _weightUnit = m.weightUnit ?? 'KG';
      _documents = List.of(m.documents);
      _isTransaction = m.isTransaction;
      _isActive = m.isActive;
    }
    _priceQuoteCtrl.addListener(_onCalcInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVendors();
      _loadDiscounts();
    });
  }

  String _trimZero(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void _onCalcInputChanged() => setState(() {});

  Future<void> _loadVendors() async {
    try {
      final provider = context.read<VendorProvider>();
      if (provider.vendors.isEmpty) {
        await provider.loadVendors();
      }
      if (!mounted) return;
      setState(() {
        _vendors = provider.vendors;
        _loadingVendors = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingVendors = false);
      _showSnack('Gagal memuat daftar Vendor: $e', isError: true);
    }
  }

  Future<void> _loadDiscounts() async {
    final m = widget.material;
    if (m == null || m.id == null) {
      setState(() => _loadingRelated = false);
      return;
    }
    try {
      final discounts = await context.read<MaterialProvider>().getDiscountsForMaterial(m.id!);
      if (!mounted) return;
      setState(() {
        _discountRows.addAll(discounts.map((d) => _DiscountRow(
              amount: _trimZero(d.amount),
              date: d.date,
            )..amountCtrl.addListener(_onCalcInputChanged)));
        _loadingRelated = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingRelated = false);
      _showSnack('Gagal memuat data diskon: $e', isError: true);
    }
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _typeCtrl.dispose();
    _itemDescCtrl.dispose();
    _itemManufacturerCtrl.dispose();
    _originCountryCtrl.dispose();
    _itemTypeCtrl.dispose();
    _itemPartNumberCtrl.dispose();
    _sizeCtrl.dispose();
    _refGenuinePartCtrl.dispose();
    _existingItemDescCtrl.dispose();
    _priceQuoteCtrl.dispose();
    _leadTimeCtrl.dispose();
    _deliveryAddressCtrl.dispose();
    _dimPCtrl.dispose();
    _dimLCtrl.dispose();
    _dimTCtrl.dispose();
    _weightCtrl.dispose();
    for (final row in _discountRows) {
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

  // ---------------- Kalkulasi harga (live, ikut berubah tiap input) ----------------
  // CATATAN ASUMSI: DPP & VAT Value dihitung otomatis pakai PPN 11%
  // standar Indonesia (DPP = Total Price, VAT Value = DPP x 11% kalau
  // VAT = Yes). Kalau rumus/persen yang dipakai di perusahaan beda,
  // tinggal kasih tau, saya sesuaikan -- cukup ubah di 1 tempat ini.
  double get _priceQuoteValue =>
      double.tryParse(_priceQuoteCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

  double get _totalDiscount => _discountRows.fold(0.0, (sum, r) => sum + r.amountValue);

  double get _priceDiscount {
    final v = _priceQuoteValue - _totalDiscount;
    return v < 0 ? 0 : v;
  }

  double get _totalPrice => _discountRows.isEmpty ? _priceQuoteValue : _priceDiscount;

  double get _dpp => _totalPrice;

  double get _vatValue => _vat ? _dpp * 0.11 : 0;

  void _addDiscountRow() {
    setState(() {
      final row = _DiscountRow()..amountCtrl.addListener(_onCalcInputChanged);
      _discountRows.add(row);
    });
  }

  void _removeDiscountRow(int index) {
    setState(() {
      _discountRows[index].dispose();
      _discountRows.removeAt(index);
    });
  }

  Future<void> _pickDiscountDate(int index) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _discountRows[index].date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _discountRows[index].date = picked);
  }

  Future<void> _pickQuoteDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _priceQuoteDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _priceQuoteDate = picked);
  }

  Future<void> _pickScopeOfWork() async {
    final result = await showOptionPickerDialog(
      context: context,
      title: 'Scope of Work',
      options: VendorOptions.scopeOfWork,
      selectedValue: _scopeOfWork,
      withSearch: false,
    );
    if (result != null) setState(() => _scopeOfWork = result);
  }

  Future<void> _pickSubSow() async {
    final result = await showOptionPickerDialog(
      context: context,
      title: 'Sub-SoW',
      options: VendorOptions.subSow,
      selectedValue: _subSow,
      withSearch: true,
    );
    if (result != null) setState(() => _subSow = result);
  }

  Future<void> _pickCategory() async {
    final result = await showOptionPickerDialog(
      context: context,
      title: 'Category',
      options: MaterialOptions.category,
      selectedValue: _category,
      withSearch: false,
    );
    if (result != null) setState(() => _category = result);
  }


  Future<void> _pickDocuments() async {
    final result = await showMultiOptionPickerDialog(
      context: context,
      title: 'Documents',
      options: MaterialOptions.documents,
      selectedValues: _documents,
      withSearch: true,
    );
    if (result != null) setState(() => _documents = result);
  }

  Future<void> _pickVendor() async {
    if (_loadingVendors) return;
    if (_vendors.isEmpty) {
      _showSnack('Belum ada data Vendor. Tambahkan Vendor dulu di modul Vendor.', isError: true);
      return;
    }
    final options = _vendors.map((v) => v.vendorName).toList();
    final currentName = _vendorId == null
        ? null
        : _vendors.firstWhere((v) => v.id == _vendorId, orElse: () => _vendors.first).vendorName;
    final result = await showOptionPickerDialog(
      context: context,
      title: 'Vendor',
      options: options,
      selectedValue: currentName,
      withSearch: true,
    );
    if (result != null) {
      final selected = _vendors.firstWhere((v) => v.vendorName == result);
      setState(() => _vendorId = selected.id);
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: false,
      );
      if (result != null && result.files.single.path != null) {
        setState(() => _photoPath = result.files.single.path);
      }
    } catch (e) {
      _showSnack('Gagal memilih foto: $e', isError: true);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final discounts = _discountRows
        .map((r) => MaterialDiscount(amount: r.amountValue, date: r.date))
        .where((d) => d.amount > 0)
        .toList();

    final material = MaterialItem(
      id: widget.material?.id,
      vendorId: _vendorId,
      scopeOfWork: _scopeOfWork,
      subSow: _subSow,
      brandUnitInstalledOn: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      typeUnitInstalledOn: _typeCtrl.text.trim().isEmpty ? null : _typeCtrl.text.trim(),
      itemDescription: _itemDescCtrl.text.trim().isEmpty ? null : _itemDescCtrl.text.trim(),
      category: _category,
      itemManufacturer:
          _itemManufacturerCtrl.text.trim().isEmpty ? null : _itemManufacturerCtrl.text.trim(),
      originCountry: _originCountryCtrl.text.trim().isEmpty ? null : _originCountryCtrl.text.trim(),
      itemType: _itemTypeCtrl.text.trim().isEmpty ? null : _itemTypeCtrl.text.trim(),
      itemPartNumber:
          _itemPartNumberCtrl.text.trim().isEmpty ? null : _itemPartNumberCtrl.text.trim(),
      size: _sizeCtrl.text.trim().isEmpty ? null : _sizeCtrl.text.trim(),
      photoPath: _photoPath,
      referenceGenuinePartNumber:
          _refGenuinePartCtrl.text.trim().isEmpty ? null : _refGenuinePartCtrl.text.trim(),
      existingItemDescription:
          _existingItemDescCtrl.text.trim().isEmpty ? null : _existingItemDescCtrl.text.trim(),
      priceQuote: _priceQuoteValue,
      priceQuoteDate: _priceQuoteDate,
      totalDiscount: _totalDiscount,
      priceDiscount: _priceDiscount,
      totalPrice: _totalPrice,
      vat: _vat,
      dpp: _dpp,
      vatValue: _vatValue,
      leadTimeDays: int.tryParse(_leadTimeCtrl.text) ?? 0,
      deliveryTerms: _deliveryTerms,
      deliveryAddress:
          _deliveryAddressCtrl.text.trim().isEmpty ? null : _deliveryAddressCtrl.text.trim(),
      dimP: double.tryParse(_dimPCtrl.text),
      dimL: double.tryParse(_dimLCtrl.text),
      dimT: double.tryParse(_dimTCtrl.text),
      dimUnit: _dimUnit,
      weight: double.tryParse(_weightCtrl.text),
      weightUnit: _weightUnit,
      documents: _documents,
      isTransaction: _isTransaction,
      isActive: _isActive,
    );

    setState(() => _isSaving = true);
    try {
      final provider = context.read<MaterialProvider>();
      if (_isEditMode) {
        await provider.updateMaterial(material, discounts);
      } else {
        await provider.addMaterial(material, discounts);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Gagal menyimpan material: $e', isError: true);
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
            Icon(Icons.inventory_2_outlined, size: 22),
            SizedBox(width: 8),
            Text('Material Form'),
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
                  _sectionTitle('Informasi Material'),

                  // 1. Registered Item
                  _label('Registered Item', required: true),
                  _readOnlyBox(
                    _isEditMode ? widget.material!.materialCode : 'Otomatis setelah disimpan',
                  ),
                  const SizedBox(height: 16),

                  // 2. Vendor
                  _label('Vendor'),
                  _pickerBox(
                    value: _vendorId == null
                        ? null
                        : _vendors
                            .firstWhere((v) => v.id == _vendorId, orElse: () => Vendor(vendorName: ''))
                            .vendorName,
                    hint: _loadingVendors ? 'Memuat data vendor...' : '-- Pilih Vendor --',
                    onTap: _pickVendor,
                  ),
                  const SizedBox(height: 16),

                  // 3. Scope of Work
                  _label('Scope of Work'),
                  _pickerBox(
                    value: _scopeOfWork,
                    hint: '-- Pilih Scope of Work --',
                    onTap: _pickScopeOfWork,
                  ),
                  const SizedBox(height: 16),

                  // 4. Sub-SOW
                  _label('Sub-SOW'),
                  _pickerBox(value: _subSow, hint: '-- Pilih Sub-SOW --', onTap: _pickSubSow),
                  const SizedBox(height: 16),

                  // 5. Brand - unit installed on
                  _label('Brand - unit installed on'),
                  _textField(controller: _brandCtrl, hint: 'Mis. Komatsu'),
                  const SizedBox(height: 16),

                  // 6. Type - unit installed on
                  _label('Type - unit installed on'),
                  _textField(controller: _typeCtrl, hint: 'Mis. PC200-8'),
                  const SizedBox(height: 20),

                  _sectionTitle('Item Information'),

                  // 7. Item Description
                  _label('Item Description'),
                  _textField(controller: _itemDescCtrl, hint: 'Deskripsi item', maxLines: 3),
                  const SizedBox(height: 16),

                  // 8. Category
                  _label('Category'),
                  _pickerBox(value: _category, hint: '-- Pilih Category --', onTap: _pickCategory),
                  const SizedBox(height: 16),

                  // 9. Item Manufacturer
                  _label('Item Manufacturer'),
                  _textField(controller: _itemManufacturerCtrl, hint: 'Nama pabrikan'),
                  const SizedBox(height: 16),

                  // 10. Origin Country
                  _label('Origin Country'),
                  _textField(controller: _originCountryCtrl, hint: 'Mis. Japan'),
                  const SizedBox(height: 16),

                  // 11. Item Type
                  _label('Item Type'),
                  _textField(controller: _itemTypeCtrl, hint: 'Mis. Filter Oli'),
                  const SizedBox(height: 16),

                  // 12. Item Part Number
                  _label('Item Part Number'),
                  _textField(controller: _itemPartNumberCtrl, hint: 'Part number'),
                  const SizedBox(height: 16),

                  // 13. Size
                  _label('Size'),
                  _textField(controller: _sizeCtrl, hint: 'Ukuran'),
                  const SizedBox(height: 16),

                  // 14. Photo
                  _label('Photo'),
                  _photoPicker(),
                  const SizedBox(height: 16),

                  // 15. Reference Genuine Part Number
                  _label('Reference Genuine Part Number – for OEM / Non-Brand / Private Label only'),
                  _textField(controller: _refGenuinePartCtrl, hint: 'Part number genuine acuan'),
                  const SizedBox(height: 16),

                  // 16. Existing Item Description
                  _label('Existing Item Description – if replacement'),
                  const SizedBox(height: 4),
                  const Text(
                    'Diisi hanya kalau item ini pengganti/beda dari mesin/part awal '
                    '(mis. supply printer HP menggantikan Canon) -- kosongkan kalau sama '
                    'dengan yang sudah ada.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  _textField(controller: _existingItemDescCtrl, hint: 'Deskripsi item lama (opsional)', maxLines: 2),
                  const SizedBox(height: 20),

                  // CATATAN REVISI: section "Quantity & Price" sekarang cuma
                  // "Price" saja -- Quantity & Unit dipindah ke RFQ (dipilih
                  // per baris Material List di form RFQ), sesuai revisi owner.
                  _sectionTitle('Price'),

                  // 19. Price - Quote
                  _label('Price - Quote'),
                  _rupiahField(_priceQuoteCtrl),
                  const SizedBox(height: 12),
                  _label('Date Update'),
                  _datePickerBox(_priceQuoteDate, _pickQuoteDate),
                  const SizedBox(height: 16),

                  // 20. Price - Discount (harga akhir, live)
                  _label('Price - Discount'),
                  _readOnlyBox('Rp ${_rupiahFmt.format(_priceDiscount)}'),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _label('Add Discount'),
                      OutlinedButton.icon(
                        onPressed: _addDiscountRow,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Discount'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._discountRows.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Discount ${index + 1}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  InkWell(
                                    onTap: () => _removeDiscountRow(index),
                                    child: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _rupiahField(row.amountCtrl, dense: true),
                              const SizedBox(height: 8),
                              _datePickerBox(row.date, () => _pickDiscountDate(index), dense: true),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (_discountRows.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Discount', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('Rp ${_rupiahFmt.format(_totalDiscount)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // 21. Total Price
                  _label('Total Price'),
                  const SizedBox(height: 2),
                  const Text(
                    'Mengacu ke Quote, kalau sudah ada diskon maka mengacu ke Price - Discount.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  _readOnlyBox('Rp ${_rupiahFmt.format(_totalPrice)}'),
                  const SizedBox(height: 16),

                  // 22. VAT
                  _label('VAT'),
                  const SizedBox(height: 6),
                  _twoOptionToggle(
                    leftLabel: 'Yes',
                    rightLabel: 'No',
                    isLeftSelected: _vat,
                    onLeftTap: () => setState(() => _vat = true),
                    onRightTap: () => setState(() => _vat = false),
                  ),
                  const SizedBox(height: 16),

                  // 23-24. DPP & VAT Value (auto, PPN 11%)
                  _label('DPP'),
                  _readOnlyBox('Rp ${_rupiahFmt.format(_dpp)}'),
                  const SizedBox(height: 12),
                  _label('VAT Value'),
                  _readOnlyBox('Rp ${_rupiahFmt.format(_vatValue)}'),
                  const SizedBox(height: 20),

                  _sectionTitle('Delivery'),

                  // 25. Lead Time
                  _label('Lead time (Days)'),
                  _stepperField(controller: _leadTimeCtrl),
                  const SizedBox(height: 16),

                  // 26. Delivery Terms
                  _label('Delivery Terms'),
                  const SizedBox(height: 6),
                  _twoOptionToggle(
                    leftLabel: 'Franco',
                    rightLabel: 'Loco',
                    isLeftSelected: _deliveryTerms != 'Loco',
                    onLeftTap: () => setState(() => _deliveryTerms = 'Franco'),
                    onRightTap: () => setState(() => _deliveryTerms = 'Loco'),
                  ),
                  const SizedBox(height: 16),

                  // 27. Delivery Address
                  _label('Delivery Address'),
                  _textField(controller: _deliveryAddressCtrl, hint: 'Isi alamat', maxLines: 3),
                  const SizedBox(height: 20),

                  _sectionTitle('Packaging'),

                  // 28. Dimension
                  _label('Dimension (Panjang x Lebar x Tinggi)'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _numberField(controller: _dimPCtrl, hint: 'P')),
                      const SizedBox(width: 8),
                      Expanded(child: _numberField(controller: _dimLCtrl, hint: 'L')),
                      const SizedBox(width: 8),
                      Expanded(child: _numberField(controller: _dimTCtrl, hint: 'T')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _inlineUnitToggle(
                    options: MaterialOptions.dimensionUnit,
                    selected: _dimUnit,
                    onSelect: (u) => setState(() => _dimUnit = u),
                  ),
                  const SizedBox(height: 16),

                  // 29. Weight
                  _label('Weight'),
                  const SizedBox(height: 6),
                  _numberField(controller: _weightCtrl, hint: 'Masukkan angka'),
                  const SizedBox(height: 8),
                  _inlineUnitToggle(
                    options: MaterialOptions.weightUnit,
                    selected: _weightUnit,
                    onSelect: (u) => setState(() => _weightUnit = u),
                  ),
                  const SizedBox(height: 20),

                  _sectionTitle('Other'),

                  // 30. Documents
                  _label('Documents'),
                  _multiPickerBox(values: _documents, hint: '-- Pilih Documents --', onTap: _pickDocuments),
                  const SizedBox(height: 16),

                  // 31. Transaction
                  _label('Transaction'),
                  const SizedBox(height: 6),
                  _twoOptionToggle(
                    leftLabel: 'N',
                    rightLabel: 'Y',
                    isLeftSelected: !_isTransaction,
                    onLeftTap: () => setState(() => _isTransaction = false),
                    onRightTap: () => setState(() => _isTransaction = true),
                  ),
                  const SizedBox(height: 20),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Status Aktif', style: TextStyle(fontSize: 14)),
                    value: _isActive,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _isActive = val),
                  ),
                  const SizedBox(height: 12),

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

  // ---------------- Widget helper ----------------

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
      ),
    );
  }

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
    bool dense = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          isDense: dense,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 10 : 14),
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

  Widget _numberField({required TextEditingController controller, required String hint}) {
    return _textField(
      controller: controller,
      hint: hint,
      dense: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  Widget _rupiahField(TextEditingController controller, {bool dense = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          prefixText: 'Rp ',
          hintText: '0',
          isDense: dense,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 10 : 14),
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
      child: Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600)),
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

  Widget _multiPickerBox({required List<String> values, required String hint, required VoidCallback onTap}) {
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
                  values.isEmpty ? hint : values.join(', '),
                  style: TextStyle(fontSize: 14, color: values.isEmpty ? Colors.grey.shade400 : Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.add, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datePickerBox(DateTime? date, VoidCallback onTap, {bool dense = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 10 : 14),
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
    );
  }

  Widget _stepperField({required TextEditingController controller}) {
    void change(int delta) {
      final current = int.tryParse(controller.text) ?? 0;
      final next = current + delta;
      controller.text = '${next < 0 ? 0 : next}';
      setState(() {});
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: () => change(-1)),
          IconButton(icon: const Icon(Icons.add, size: 18), onPressed: () => change(1)),
        ],
      ),
    );
  }

  Widget _twoOptionToggle({
    required String leftLabel,
    required String rightLabel,
    required bool isLeftSelected,
    required VoidCallback onLeftTap,
    required VoidCallback onRightTap,
  }) {
    Widget button(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade300, width: 1.2),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : Colors.black87,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        button(leftLabel, isLeftSelected, onLeftTap),
        const SizedBox(width: 10),
        button(rightLabel, !isLeftSelected, onRightTap),
      ],
    );
  }

  Widget _inlineUnitToggle({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Wrap(
      spacing: 8,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return ChoiceChip(
          label: Text(opt, style: const TextStyle(fontSize: 12)),
          selected: isSelected,
          selectedColor: AppColors.primary.withOpacity(0.15),
          labelStyle: TextStyle(color: isSelected ? AppColors.primary : Colors.black87),
          onSelected: (_) => onSelect(opt),
        );
      }).toList(),
    );
  }

  Widget _photoPicker() {
    final hasPhoto = _photoPath != null && _photoPath!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasPhoto
                ? Image.file(
                    File(_photoPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.broken_image_outlined, color: Colors.grey.shade400),
                  )
                : Icon(Icons.image_outlined, color: Colors.grey.shade400),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(hasPhoto ? 'Ganti Foto' : 'Pilih Foto'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
          if (hasPhoto)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.danger),
              onPressed: () => setState(() => _photoPath = null),
            ),
        ],
      ),
    );
  }
}
