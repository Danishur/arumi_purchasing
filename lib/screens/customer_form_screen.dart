import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../models/customer_contact.dart';
import '../providers/customer_provider.dart';
import '../utils/app_theme.dart';
import '../utils/customer_options.dart';
import '../widgets/option_picker_dialog.dart';

/// Satu baris PIC di form -- pakai TextEditingController sendiri per
/// baris supaya tiap baris independen (nambah/hapus baris lain tidak
/// mempengaruhi isi baris yang sudah diketik).
class _ContactRow {
  final TextEditingController nameCtrl;
  final TextEditingController positionCtrl; // Posisi / Jabatan -- isian bebas
  final TextEditingController contactCtrl; // No. HP
  final TextEditingController emailCtrl;

  _ContactRow({
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

class CustomerFormScreen extends StatefulWidget {
  final Customer? customer; // null = mode tambah, terisi = mode edit

  const CustomerFormScreen({super.key, this.customer});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _nameCtrl = TextEditingController();
  final _npwpCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  String? _termsOfPayment;
  String? _customerType;
  bool _isActive = true;

  final List<_ContactRow> _contactRows = [];

  bool _loadingContacts = true;
  bool _isSaving = false;

  bool get _isEditMode => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    if (c != null) {
      _nameCtrl.text = c.name;
      _npwpCtrl.text = c.npwpNumber ?? '';
      _addressCtrl.text = c.address ?? '';
      _termsOfPayment = c.termsOfPayment;
      _customerType = c.customerType;
      _isActive = c.isActive;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContacts());
  }

  Future<void> _loadContacts() async {
    final c = widget.customer;
    if (c == null || c.id == null) {
      // Mode tambah customer baru: langsung mulai dengan 1 baris PIC
      // kosong biar user tidak perlu tap "+ Tambah PIC" dulu.
      setState(() {
        _contactRows.add(_ContactRow());
        _loadingContacts = false;
      });
      return;
    }

    try {
      final contacts = await context.read<CustomerProvider>().getContactsForCustomer(c.id!);
      if (!mounted) return;
      setState(() {
        _contactRows.addAll(
          contacts.isEmpty
              ? [_ContactRow()]
              : contacts.map((ct) => _ContactRow(
                    name: ct.picName,
                    position: ct.position,
                    contact: ct.contact,
                    email: ct.email,
                  )),
        );
        _loadingContacts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _contactRows.add(_ContactRow());
        _loadingContacts = false;
      });
      _showSnack('Gagal memuat data PIC: $e', isError: true);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _npwpCtrl.dispose();
    _addressCtrl.dispose();
    for (final row in _contactRows) {
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

  void _addContactRow() {
    setState(() => _contactRows.add(_ContactRow()));
  }

  void _removeContactRow(int index) {
    setState(() {
      _contactRows[index].dispose();
      _contactRows.removeAt(index);
    });
  }

  Future<void> _pickTermsOfPayment() async {
    final result = await showOptionPickerDialog(
      context: context,
      title: 'Terms of Payment',
      options: CustomerOptions.termsOfPayment,
      selectedValue: _termsOfPayment,
      withSearch: true,
    );
    if (result != null) setState(() => _termsOfPayment = result);
  }

  Future<void> _pickCustomerType() async {
    final result = await showOptionPickerDialog(
      context: context,
      title: 'Customer Type',
      options: CustomerOptions.customerType,
      selectedValue: _customerType,
      withSearch: false,
    );
    if (result != null) setState(() => _customerType = result);
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Customer Name wajib diisi.', isError: true);
      return;
    }

    // PIC bersifat opsional per baris -- baris yang KEDUA field-nya
    // (nama & kontak) kosong dianggap "belum diisi" dan dilewati saat
    // disimpan, supaya user tidak perlu hapus manual baris kosong yang
    // sengaja ditinggalkan.
    final contacts = _contactRows
        .where((r) =>
            r.nameCtrl.text.trim().isNotEmpty ||
            r.positionCtrl.text.trim().isNotEmpty ||
            r.contactCtrl.text.trim().isNotEmpty ||
            r.emailCtrl.text.trim().isNotEmpty)
        .map((r) => CustomerContact(
              picName: r.nameCtrl.text.trim(),
              position: r.positionCtrl.text.trim(),
              contact: r.contactCtrl.text.trim(),
              email: r.emailCtrl.text.trim(),
            ))
        .toList();

    // Validasi ringan: kalau salah satu dari nama/kontak di suatu baris
    // diisi tapi yang satunya kosong, itu kemungkinan besar belum
    // selesai diisi -- kasih tau user daripada diam-diam menyimpan data
    // PIC yang tidak lengkap.
    for (final row in _contactRows) {
      final hasName = row.nameCtrl.text.trim().isNotEmpty;
      final hasContact = row.contactCtrl.text.trim().isNotEmpty;
      if (hasName != hasContact) {
        _showSnack('Ada baris PIC yang belum lengkap (nama atau kontak kosong).',
            isError: true);
        return;
      }
    }

    final customer = Customer(
      id: widget.customer?.id,
      name: name,
      npwpNumber: _npwpCtrl.text.trim().isEmpty ? null : _npwpCtrl.text.trim(),
      termsOfPayment: _termsOfPayment,
      customerType: _customerType,
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      isActive: _isActive,
    );

    setState(() => _isSaving = true);
    try {
      final provider = context.read<CustomerProvider>();
      if (_isEditMode) {
        await provider.updateCustomer(customer, contacts);
      } else {
        await provider.addCustomer(customer, contacts);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      // BUG FIX pattern yang konsisten dengan project sebelumnya: error
      // simpan HARUS tampil jelas ke user, bukan gagal diam-diam.
      _showSnack('Gagal menyimpan customer: $e', isError: true);
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
            Icon(Icons.account_circle_outlined, size: 22),
            SizedBox(width: 8),
            Text('Customer Form'),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _loadingContacts
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Customer ID', required: true),
                  _readOnlyBox(
                    _isEditMode ? widget.customer!.customerCode : 'Otomatis setelah disimpan',
                  ),
                  const SizedBox(height: 16),

                  _label('Customer Name', required: true),
                  _textField(controller: _nameCtrl, hint: 'PT. Nusantara Perdagangan'),
                  const SizedBox(height: 20),

                  _label('PIC & Contact PIC'),
                  const SizedBox(height: 4),
                  const Text(
                    '1 customer boleh punya lebih dari 1 PIC.',
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
                              _textField(
                                controller: row.nameCtrl,
                                hint: 'Nama PIC',
                                dense: true,
                              ),
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

                  _label('NPWP Number'),
                  _textField(controller: _npwpCtrl, hint: '01.234.567.8-901.000'),
                  const SizedBox(height: 20),

                  _label('Terms of Payment'),
                  _pickerBox(
                    value: _termsOfPayment,
                    hint: '-- Pilih Terms of Payment --',
                    onTap: _pickTermsOfPayment,
                  ),
                  const SizedBox(height: 20),

                  _label('Customer Type'),
                  _pickerBox(
                    value: _customerType,
                    hint: '-- Pilih Customer Type --',
                    onTap: _pickCustomerType,
                  ),
                  const SizedBox(height: 20),

                  _label('Address'),
                  _textField(
                    controller: _addressCtrl,
                    hint: 'Jl. Merdeka No. 12, Jakarta Pusat, DKI Jakarta',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),

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
      child: Text(text, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
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
}
