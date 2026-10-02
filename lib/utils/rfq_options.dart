/// Daftar pilihan tetap untuk field "Status" di form RFQ, sesuai
/// screenshot referensi desain yang dikirim.
///
/// CATATAN: "Unit" di form RFQ (dipilih per baris Material List)
/// SENGAJA pakai daftar yang SAMA dengan MaterialOptions.unit --
/// lihat pemakaiannya di rfq_form_screen.dart, tidak diduplikasi di
/// sini.
class RfqOptions {
  static const List<String> status = [
    'Clarification-Customer',
    'Clarification-Vendor',
    'Complete',
    'Canceled',
  ];
}
