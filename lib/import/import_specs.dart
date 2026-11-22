import 'import_types.dart';

/// Kolom template Excel per modul. Urutan di sini = urutan kolom di
/// template. Saat import, kolom dikenali dari JUDULNYA (bukan urutan),
/// jadi kalau user menggeser/menambah kolom lain, import tetap jalan.
class ImportSpecs {
  static String title(ImportModule m) {
    switch (m) {
      case ImportModule.customer:
        return 'Customer';
      case ImportModule.vendor:
        return 'Vendor';
      case ImportModule.material:
        return 'Material';
      case ImportModule.rfq:
        return 'RFQ';
    }
  }

  static String description(ImportModule m) {
    switch (m) {
      case ImportModule.customer:
        return 'Data customer beserta PIC';
      case ImportModule.vendor:
        return 'Vendor, PIC, produk, dan bank';
      case ImportModule.material:
        return 'Material dan diskon. Butuh vendor.';
      case ImportModule.rfq:
        return 'RFQ dan daftar material';
    }
  }

  static String prerequisite(ImportModule m) {
    switch (m) {
      case ImportModule.customer:
      case ImportModule.vendor:
        return 'Urutan 1';
      case ImportModule.material:
        return 'Urutan 2';
      case ImportModule.rfq:
        return 'Urutan 3';
    }
  }

  /// Catatan cara isi yang tampil di sheet "Petunjuk" pada template.
  static List<String> notes(ImportModule m) {
    switch (m) {
      case ImportModule.customer:
        return [
          'Satu baris = satu PIC. Customer dengan banyak PIC: ulangi Customer Name di baris berikutnya, isi PIC yang lain (kolom customer lain boleh dikosongkan).',
          'Terms of Payment dan Customer Type harus sama dengan isi Settings > Edit Dropdown.',
          'Status: Aktif / Nonaktif (kosong = Aktif).',
        ];
      case ImportModule.vendor:
        return [
          'Satu baris = satu PIC / produk / rekening. Vendor dengan banyak PIC, produk, atau rekening: ulangi Vendor Name di baris berikutnya.',
          'Scope of Work, Sub SOW, dan Document boleh lebih dari satu, pisahkan dengan koma.',
          'Kode Lama (mis. VS001) disimpan ke Internal Note supaya kode dari Excel lama tidak hilang.',
          'Verified: Yes / No. Status: Aktif / Nonaktif.',
        ];
      case ImportModule.material:
        return [
          'Vendor Name harus sudah ada di aplikasi (import Vendor dulu).',
          'Price Currency kosong = IDR. Mata uang selain IDR harus sudah ada di Settings > Update Valuta.',
          'Price Quote (IDR) boleh dikosongkan; kalau kosong dihitung dari Price x kurs.',
          'Total Price, DPP, dan VAT Value dihitung otomatis seperti di form Material.',
          'Document Available boleh lebih dari satu, pisahkan dengan koma.',
          'Tanggal ditulis yyyy-mm-dd atau dd/mm/yyyy.',
        ];
      case ImportModule.rfq:
        return [
          'Satu baris = satu material di RFQ. RFQ dengan banyak material: ulangi No. RFQ Lama di baris berikutnya.',
          'No. RFQ Lama dipakai untuk mengelompokkan baris dan disimpan ke Internal Note.',
          'Customer Name harus sudah ada di aplikasi (import Customer dulu).',
          'Kolom Material diisi Item Description material yang sudah ada, atau kodenya (mis. MATL12). Isi Vendor (Material) kalau ada item description yang sama di beberapa vendor.',
          'Qty harus bilangan bulat.',
        ];
    }
  }

  static List<ColumnSpec> columns(ImportModule m) {
    switch (m) {
      case ImportModule.customer:
        return const [
          ColumnSpec('name', 'Customer Name', required: true, example: 'PT Semen Indonesia Logistik'),
          ColumnSpec('npwp', 'NPWP', example: '01.234.567.8-901.000'),
          ColumnSpec('top', 'Terms of Payment', example: '30 Days after invoice received'),
          ColumnSpec('type', 'Customer Type', example: 'BUMN'),
          ColumnSpec('address', 'Address', example: 'Jl. Merdeka No. 1, Gresik'),
          ColumnSpec('status', 'Status', example: 'Aktif'),
          ColumnSpec('picName', 'PIC Name', example: 'Budi'),
          ColumnSpec('picPosition', 'PIC Position', example: 'Purchasing'),
          ColumnSpec('picContact', 'PIC Contact', example: '081234567890'),
          ColumnSpec('picEmail', 'PIC Email', example: 'budi@contoh.co.id'),
        ];
      case ImportModule.vendor:
        return const [
          ColumnSpec('oldCode', 'Kode Lama', example: 'VS001'),
          ColumnSpec('name', 'Vendor Name', required: true, example: 'Damai Gresik'),
          ColumnSpec('legal', 'Legal Standing', example: 'Toko'),
          ColumnSpec('npwp', 'NPWP'),
          ColumnSpec('verified', 'Verified', example: 'Yes'),
          ColumnSpec('top', 'Terms of Payment', example: 'Cash'),
          ColumnSpec('scope', 'Scope of Work', example: 'Warehouse, Trucking'),
          ColumnSpec('sub', 'Sub SOW', example: 'Sparepart, Electrical'),
          ColumnSpec('scc', 'Supply Chain Classification', example: 'Distributor'),
          ColumnSpec('note', 'Internal Note'),
          ColumnSpec('address', 'Address', example: 'Jl. Jaksa Agung Suprapto 93, Gresik'),
          ColumnSpec('website', 'Website'),
          ColumnSpec('status', 'Status', example: 'Aktif'),
          ColumnSpec('picName', 'PIC Name', example: 'Admin'),
          ColumnSpec('picPosition', 'PIC Position'),
          ColumnSpec('picContact', 'PIC Contact', example: '081259184075'),
          ColumnSpec('picEmail', 'PIC Email'),
          ColumnSpec('product', 'Brand / Produk', example: 'Isuzu Giga'),
          ColumnSpec('bankName', 'Bank Name', example: 'BCA'),
          ColumnSpec('bankNumber', 'Account Number', example: '1234567890'),
          ColumnSpec('bankHolder', 'Account Holder', example: 'Damai Gresik'),
          ColumnSpec('bankCurrency', 'Bank Currency', example: 'IDR'),
          ColumnSpec('bankSwift', 'SWIFT Code'),
        ];
      case ImportModule.material:
        return const [
          ColumnSpec('vendor', 'Vendor Name', required: true, example: 'Damai Gresik'),
          ColumnSpec('scope', 'Scope of Work', example: 'Warehouse'),
          ColumnSpec('sub', 'Sub SOW', example: 'Electrical'),
          ColumnSpec('brand', 'Unit Brand', example: 'SWAN'),
          ColumnSpec('unitType', 'Unit Type', example: 'HWP-310'),
          ColumnSpec('desc', 'Item Description', required: true, example: 'Air compressors - CONTACTOR'),
          ColumnSpec('category', 'Category', example: 'OEM'),
          ColumnSpec('manufacturer', 'Item Manufacturer', example: 'Mitsubishi'),
          ColumnSpec('origin', 'Origin Country'),
          ColumnSpec('itemType', 'Item Type'),
          ColumnSpec('part', 'Item Part Number', example: 'TH-N20KP'),
          ColumnSpec('size', 'Size', example: '15 A'),
          ColumnSpec('refPart', 'Reference Genuine Part Number'),
          ColumnSpec('existing', 'Existing Item Description'),
          ColumnSpec('currency', 'Price Currency', example: 'IDR'),
          ColumnSpec('foreign', 'Price', example: '265000'),
          ColumnSpec('quoteIdr', 'Price Quote (IDR)'),
          ColumnSpec('priceDate', 'Price Date', example: '2025-07-15'),
          ColumnSpec('vat', 'VAT', example: 'Yes'),
          ColumnSpec('lead', 'Lead Time (Hari)', example: '7'),
          ColumnSpec('delivTerms', 'Delivery Terms', example: 'Franco'),
          ColumnSpec('delivAddress', 'Delivery Address'),
          ColumnSpec('dimP', 'Dimensi P'),
          ColumnSpec('dimL', 'Dimensi L'),
          ColumnSpec('dimT', 'Dimensi T'),
          ColumnSpec('dimUnit', 'Dimensi Unit', example: 'CM'),
          ColumnSpec('weight', 'Weight'),
          ColumnSpec('weightUnit', 'Weight Unit', example: 'KG'),
          ColumnSpec('docs', 'Document Available', example: 'MSDS, Guarantee Letter'),
          ColumnSpec('transaction', 'Transaction', example: 'Yes'),
          ColumnSpec('status', 'Status', example: 'Aktif'),
          ColumnSpec('discount', 'Discount Amount'),
          ColumnSpec('discountDate', 'Discount Date'),
        ];
      case ImportModule.rfq:
        return const [
          ColumnSpec('oldNo', 'No. RFQ Lama', required: true, example: 'RFQ250001'),
          ColumnSpec('reference', 'Reference'),
          ColumnSpec('customer', 'Customer Name', required: true, example: 'PT Semen Indonesia Logistik'),
          ColumnSpec('pic', 'PIC'),
          ColumnSpec('dateRequest', 'Date Request', example: '2025-01-25'),
          ColumnSpec('dueDate', 'Due Date', example: '2025-01-31'),
          ColumnSpec('note', 'Internal Note'),
          ColumnSpec('docReq', 'Document Requirement', example: 'MSDS'),
          ColumnSpec('status', 'Status', example: 'Complete'),
          ColumnSpec('material', 'Material', required: true, example: 'Air compressors - CONTACTOR'),
          ColumnSpec('materialVendor', 'Vendor (Material)', example: 'Damai Gresik'),
          ColumnSpec('qty', 'Qty', required: true, example: '3'),
          ColumnSpec('unit', 'Unit', example: 'Ea'),
        ];
    }
  }
}
