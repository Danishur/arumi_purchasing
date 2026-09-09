import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/vendor.dart';
import '../models/vendor_contact.dart';
import '../models/vendor_product.dart';
import '../providers/vendor_provider.dart';
import '../utils/app_theme.dart';
import '../utils/vendor_options.dart';
import '../widgets/multi_option_picker_dialog.dart';
import '../widgets/option_picker_dialog.dart';

/// Satu baris PIC di form Vendor -- pola persis sama dengan
/// _ContactRow di CustomerFormScreen (Nama, Posisi, No HP, Email).
class _VendorContactRow {
  final TextEditingController nameCtrl;
  final TextEditingController positionCtrl;
  final TextEditingController contactCtrl;
  final TextEditingController emailCtrl;

  _VendorContactRow({
    String name = '',
    String position = '',
    String contact = '',
    String email = '',
  })  : nameCtrl = TextEditingController(text: name),
        positionCtrl = TextEditingController(text: position),
        contactCtrl = TextEditingController(text: contact),
        emailCtrl = TextEditingController(text: email);

  void dispose() {
    nameCtrl.dispose();
    positionCtrl.dispose();
    contactCtrl.dispose();
    emailCtrl.dispose();
  }
}

class VendorFormScreen extends StatefulWidget {
  final Vendor? vendor; // null = mode tambah, terisi = mode edit

  const VendorFormScreen({super.key, this.vendor});

  @override
  State<VendorFormScreen> createState() => _VendorFormScreenState();
}

class _VendorFormScreenState extends State<VendorFormScreen> {
  final _nameCtrl = TextEditingController();
  final _npwpCtrl = TextEditingController();
  final _internalNoteCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankAccountNumberCtrl = TextEditingController();
  final _bankAccountHolderCtrl = TextEditingController();
  final _bankSwiftCodeCtrl = TextEditingController();

  String? _legalStanding;
  bool _isVerified = false;
  String? _termsOfPayment;
  List<String> _scopeOfWork = [];
  List<String> _subSow = [];
  String? _supplyChainClassification;
  String? _bankCurrency;
  bool _isActive = true;

  final List<TextEditingController> _productCtrls = [];
  final List<_VendorContactRow> _contactRows = [];

  bool _loadingRelated = true;
  bool _isSaving = false;

  bool get _isEditMode => widget.vendor != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vendor;
    if (v != null) {
      _nameCtrl.text = v.vendorName;
      _npwpCtrl.text = v.npwp ?? '';
      _internalNoteCtrl.text = v.internalNote ?? '';
      _addressCtrl.text = v.vendorAddress ?? '';
      _websiteCtrl.text = v.picWebsite ?? '';
      _bankNameCtrl.text = v.bankName ?? '';
      _bankAccountNumberCtrl.text = v.bankAccountNumber ?? '';
      _bankAccountHolderCtrl.text = v.bankAccountHolder ?? '';
      _bankSwiftCodeCtrl.text = v.bankSwiftCode ?? '';
      _legalStanding = v.legalStanding;
      _isVerified = v.isVerified;
      _termsOfPayment = v.termsOfPayment;
      _scopeOfWork = List.of(v.scopeOfWork);
      _subSow = List.of(v.subSow);
      _supplyChainClassification = v.supplyChainClassification;
      _bankCurrency = v.bankCurrency;
      _isActive = v.isActive;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRelated());
  }

  Future<void> _loadRelated() async {
    final v = widget.vendor;
    if (v == null || v.id == null) {
      // Mode tambah vendor baru: langsung mulai dengan 1 baris PIC dan
      // 1 baris Produk/Brand kosong biar user tidak perlu tap "+" dulu.
      setState(() {
        _contactRows.add(_VendorContactRow());
        _productCtrls.add(TextEditingController());
        _loadingRelated = false;
      });
      return;
    }

    try {
      final provider = context.read<VendorProvider>();
      final contacts = await provider.getContactsForVendor(v.id!);
      final products = await provider.getProductsForVendor(v.id!);
      if (!mounted) return;
      setState(() {
        _contactRows.addAll(
          contacts.isEmpty
              ? [_VendorContactRow()]
              : contacts.map((ct) => _VendorContactRow(
                    name: ct.picName,
                    position: ct.position,
                    contact: ct.contact,
                    email: ct.email,
                  )),
        );
        _productCtrls.addAll(
          products.isEmpty
              ? [TextEditingController()]
              : products.map((p) => TextEditingController(text: p.productName)),
        );
        _loadingRelated = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _contactRows.add(_VendorContactRow());
        _productCtrls.add(TextEditingController());
        _loadingRelated = false;
      });
      _showSnack('Gagal memuat data PIC/Produk: $e', isError: true);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _npwpCtrl.dispose();
    _internalNoteCtrl.dispose();
    _addressCtrl.dispose();
    _websiteCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccountNumberCtrl.dispose();
    _bankAccountHolderCtrl.dispose();
    _bankSwiftCodeCtrl.dispose();
    for (final row in _contactRows) {
      row.dispose();
    }
    for (final ctrl in _productCtrls) {
      ctrl.dispose();
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

  void _addContactRow() {
    setState(() => _contactRows.add(_VendorContactRow()));
  }

  void _removeContactRow(int index) {
    setState(() {
      _contactRows[index].dispose();
      _contactRows.removeAt(index);
    });
  }

  void _addProductField() {
    setState(() => _productCtrls.add(TextEditingController()));
  }

  void _removeProductField(int index) {
    setState(() {
      _productCtrls[index].dispose();
      _productCtrls.removeAt(index);
    });
  }

  Future<void> _pickLegalStanding() async {
    final result = await showOptionPickerDialog(
      context: context,
      title: 'Legal Standing',
      options: VendorOptions.legalStanding,
      selectedValue: _legalStanding,
      withSearch: true,
    );
    if (result != null) setState(() => _legalStanding = result);
  }

  Future<void> _pickTermsOfPayment() async {
    final result = await showOptionPickerDialog(
      context: context,
      title: 'Term of Payment',
      options: VendorOptions.termsOfPayment,
      selectedValue: _termsOfPayment,
      withSearch: true,
    );
    if (result != null) setState(() => _termsOfPayment = result);
  }

  Future<void> _pickScopeOfWork() async {
    final result = await showMultiOptionPickerDialog(
      context: context,
      title: 'Scope of work',
      options: VendorOptions.scopeOfWork,
      selectedValues: _scopeOfWork,
      withSearch: false,
    );
    if (result != null) setState(() => _scopeOfWork = result);
  }

  Future<void> _pickSubSow() async {
    final result = await showMultiOptionPickerDialog(
      context: context,
      title: 'Sub-SoW',
      options: VendorOptions.subSow,
      selectedValues: _subSow,
      withSearch: true,
    );
    if (result != null) setState(() => _subSow = result);
  }

  Future<void> _pickSupplyChainClassification() async {
    final result = await showOptionPickerDialog(
      context: context,
      title: 'Supply Chain Classification',
      options: VendorOptions.supplyChainClassification,
      selectedValue: _supplyChainClassification,
      withSearch: true,
    );
    if (result != null) setState(() => _supplyChainClassification = result);
  }

  Future<void> _pickCurrency() async {
    final result = await showOptionPickerDialog(
      context: context,
      title: 'Bank Account-Currency',
      options: VendorOptions.currency,
      selectedValue: _bankCurrency,
      withSearch: true,
    );
    if (result != null) setState(() => _bankCurrency = result);
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Vendor Name wajib diisi.', isError: true);
      return;
    }

    // PIC bersifat opsional per baris, sama seperti Customer -- baris
    // yang semua field-nya kosong dianggap "belum diisi" dan dilewati.
    final contacts = _contactRows
        .where((r) =>
            r.nameCtrl.text.trim().isNotEmpty ||
            r.positionCtrl.text.trim().isNotEmpty ||
            r.contactCtrl.text.trim().isNotEmpty ||
            r.emailCtrl.text.trim().isNotEmpty)
        .map((r) => VendorContact(
              picName: r.nameCtrl.text.trim(),
              position: r.positionCtrl.text.trim(),
              contact: r.contactCtrl.text.trim(),
              email: r.emailCtrl.text.trim(),
            ))
        .toList();

    for (final row in _contactRows) {
      final hasName = row.nameCtrl.text.trim().isNotEmpty;
      final hasContact = row.contactCtrl.text.trim().isNotEmpty;
      if (hasName != hasContact) {
        _showSnack('Ada baris PIC yang belum lengkap (nama atau kontak kosong).',
            isError: true);
        return;
      }
    }

    // Produk/Brand: baris kosong dilewati begitu saja, boleh 0 (tidak
    // wajib diisi) sesuai catatan "bisa ditambah / dikurangi".
    final products = _productCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .map((t) => VendorProduct(productName: t))
        .toList();

    final vendor = Vendor(
      id: widget.vendor?.id,
      vendorName: name,
      legalStanding: _legalStanding,
      npwp: _npwpCtrl.text.trim().isEmpty ? null : _npwpCtrl.text.trim(),
      isVerified: _isVerified,
      termsOfPayment: _termsOfPayment,
      scopeOfWork: _scopeOfWork,
      subSow: _subSow,
      supplyChainClassification: _supplyChainClassification,
      internalNote: _internalNoteCtrl.text.trim().isEmpty ? null : _internalNoteCtrl.text.trim(),
      vendorAddress: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      picWebsite: _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
      bankName: _bankNameCtrl.text.trim().isEmpty ? null : _bankNameCtrl.text.trim(),
      bankAccountNumber:
          _bankAccountNumberCtrl.text.trim().isEmpty ? null : _bankAccountNumberCtrl.text.trim(),
      bankAccountHolder:
          _bankAccountHolderCtrl.text.trim().isEmpty ? null : _bankAccountHolderCtrl.text.trim(),
      bankCurrency: _bankCurrency,
      bankSwiftCode: _bankSwiftCodeCtrl.text.trim().isEmpty ? null : _bankSwiftCodeCtrl.text.trim(),
      isActive: _isActive,
    );

    setState(() => _isSaving = true);
    try {
      final provider = context.read<VendorProvider>();
      if (_isEditMode) {
        await provider.updateVendor(vendor, contacts, products);
      } else {
        await provider.addVendor(vendor, contacts, products);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Gagal menyimpan vendor: $e', isError: true);
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
            Icon(Icons.storefront_outlined, size: 22),
            SizedBox(width: 8),
            Text('Vendor Form'),
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
                  // 1. Vendor ID
                  _label('Vendor ID', required: true),
                  _readOnlyBox(
                    _isEditMode ? widget.vendor!.vendorCode : 'Otomatis setelah disimpan',
                  ),
                  const SizedBox(height: 16),

                  // 2. Vendor Name
                  _label('Vendor Name', required: true),
                  _textField(controller: _nameCtrl, hint: 'PT. Sejahtera Sparepart'),
                  const SizedBox(height: 20),

                  // 3. Legal Standing
                  _label('Legal Standing'),
                  _pickerBox(
                    value: _legalStanding,
                    hint: '-- Pilih Legal Standing --',
                    onTap: _pickLegalStanding,
                  ),
                  const SizedBox(height: 20),

                  // 4. NPWP
                  _label('NPWP'),
                  _textField(controller: _npwpCtrl, hint: '01.234.567.8-901.000'),
                  const SizedBox(height: 20),

                  // 5. Verified
                  _label('Verified'),
                  const SizedBox(height: 6),
                  _verifiedToggle(),
                  const SizedBox(height: 20),

                  // 6. Term of Payment
                  _label('Term of Payment'),
                  _pickerBox(
                    value: _termsOfPayment,
                    hint: '-- Pilih Term of Payment --',
                    onTap: _pickTermsOfPayment,
                  ),
                  const SizedBox(height: 20),

                  // 7. Produk/Brand
                  _label('Produk / Brand'),
                  const SizedBox(height: 4),
                  const Text(
                    'Bisa ditambah / dikurangi, bisa lebih dari 1.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  ..._productCtrls.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ctrl = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _textField(
                              controller: ctrl,
                              hint: 'Nama Produk / Brand',
                              dense: true,
                            ),
                          ),
                          if (_productCtrls.length > 1)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                              onPressed: () => _removeProductField(index),
                            ),
                        ],
                      ),
                    );
                  }),
                  OutlinedButton.icon(
                    onPressed: _addProductField,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah Produk / Brand'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                  const SizedBox(height: 20),

                  // 8. Scope of Work
                  _label('Scope of work'),
                  _multiPickerBox(
                    values: _scopeOfWork,
                    hint: '-- Pilih Scope of Work --',
                    onTap: _pickScopeOfWork,
                  ),
                  const SizedBox(height: 20),

                  // 9. Sub-SoW
                  _label('Sub-SoW'),
                  _multiPickerBox(
                    values: _subSow,
                    hint: '-- Pilih Sub-SoW --',
                    onTap: _pickSubSow,
                  ),
                  const SizedBox(height: 20),

                  // 10. Supply Chain Classification
                  _label('Supply Chain Classification'),
                  _pickerBox(
                    value: _supplyChainClassification,
                    hint: '-- Pilih Supply Chain Classification --',
                    onTap: _pickSupplyChainClassification,
                  ),
                  const SizedBox(height: 20),

                  // 11. Internal Note
                  _label('Internal Note'),
                  _textField(
                    controller: _internalNoteCtrl,
                    hint: 'Catatan internal (tidak tampil ke vendor)',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),

                  // 12. PIC & Contact PIC
                  _label('PIC & Contact PIC'),
                  const SizedBox(height: 4),
                  const Text(
                    '1 vendor boleh punya lebih dari 1 PIC.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  ..._contactRows.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
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
                                  Text('PIC ${index + 1}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 12)),
                                  if (_contactRows.length > 1)
                                    InkWell(
                                      onTap: () => _removeContactRow(index),
                                      child: const Icon(Icons.close,
                                          size: 18, color: AppColors.danger),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _textField(controller: row.nameCtrl, hint: 'Nama PIC', dense: true),
                              const SizedBox(height: 8),
                              _textField(
                                controller: row.positionCtrl,
                                hint: 'Posisi / Jabatan PIC',
                                dense: true,
                              ),
                              const SizedBox(height: 8),
                              _textField(
                                controller: row.contactCtrl,
                                hint: 'No. HP PIC',
                                dense: true,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 8),
                              _textField(
                                controller: row.emailCtrl,
                                hint: 'Email PIC',
                                dense: true,
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  OutlinedButton.icon(
                    onPressed: _addContactRow,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah PIC'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                  const SizedBox(height: 20),

                  // 13. Vendor Address
                  _label('Vendor Address'),
                  _textField(
                    controller: _addressCtrl,
                    hint: 'Jl. Industri Raya No. 8, Cikarang, Jawa Barat',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),

                  // 14. PIC-Website
                  _label('PIC-Website'),
                  _textField(controller: _websiteCtrl, hint: 'www.namavendor.com'),
                  const SizedBox(height: 20),

                  // 15. Bank Information
                  _label('Bank Information'),
                  const SizedBox(height: 8),
                  Card(
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
                          _textField(controller: _bankNameCtrl, hint: 'Bank Name', dense: true),
                          const SizedBox(height: 8),
                          _textField(
                            controller: _bankAccountNumberCtrl,
                            hint: 'Account Number',
                            dense: true,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),
                          _textField(
                            controller: _bankAccountHolderCtrl,
                            hint: 'Account Holder / Name',
                            dense: true,
                          ),
                          const SizedBox(height: 8),
                          _pickerBox(
                            value: _bankCurrency,
                            hint: '-- Pilih Currency --',
                            onTap: _pickCurrency,
                          ),
                          const SizedBox(height: 8),
                          _textField(
                            controller: _bankSwiftCodeCtrl,
                            hint: 'SWIFT CODE (if any)',
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 16. Update Data (read-only, cuma tampil kalau sudah pernah disimpan)
                  if (_isEditMode) ...[
                    _label('Updated data'),
                    _readOnlyBox(_formatUpdatedAt(widget.vendor!.updatedAt),
                        icon: Icons.calendar_today_outlined),
                    const SizedBox(height: 20),
                  ],

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
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
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

  String _formatUpdatedAt(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(dt);
  }

  Widget _verifiedToggle() {
    return Row(
      children: [
        Expanded(
          child: _toggleButton(
            label: 'Verified',
            selected: _isVerified,
            onTap: () => setState(() => _isVerified = true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _toggleButton(
            label: 'Unverified',
            selected: !_isVerified,
            onTap: () => setState(() => _isVerified = false),
          ),
        ),
      ],
    );
  }

  Widget _toggleButton({required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
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
    );
  }

  Widget _label(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(text: ' *', style: TextStyle(color: AppColors.danger)),
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

  Widget _readOnlyBox(String text, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, style: TextStyle(color: Colors.grey.shade500, fontSize: 14))),
          if (icon != null) Icon(icon, size: 18, color: Colors.grey.shade500),
        ],
      ),
    );
  }

  Widget _pickerBox({
    required String? value,
    required String hint,
    required VoidCallback onTap,
  }) {
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
                  style: TextStyle(
                    fontSize: 14,
                    color: value == null ? Colors.grey.shade400 : Colors.black87,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }

  /// Sama seperti [_pickerBox], tapi untuk field multi-select (Scope of
  /// Work, Sub-SoW) -- nilainya digabung koma, ada tanda "+" bukan
  /// panah bawah, sesuai referensi desain.
  Widget _multiPickerBox({
    required List<String> values,
    required String hint,
    required VoidCallback onTap,
  }) {
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
                  style: TextStyle(
                    fontSize: 14,
                    color: values.isEmpty ? Colors.grey.shade400 : Colors.black87,
                  ),
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
}
