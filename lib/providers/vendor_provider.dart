import 'package:flutter/material.dart';
import '../models/vendor.dart';
import '../models/vendor_bank_account.dart';
import '../models/vendor_contact.dart';
import '../models/vendor_product.dart';
import '../services/database_service.dart';
import '../utils/search_index.dart';

class VendorProvider extends ChangeNotifier {
  List<Vendor> _vendors = [];
  List<Vendor> get vendors => _vendors;

  /// Dipakai layar list Vendor. SENGAJA tidak memuat PIC/Produk/Bank di
  /// sini (biar tidak query berkali-kali untuk tiap baris vendor di
  /// list) -- diambil belakangan lewat getContactsForVendor /
  /// getProductsForVendor / getBankAccountsForVendor saat user benar-
  /// benar buka form edit vendor tertentu.
  Future<void> loadVendors() async {
    final data = await DatabaseService.instance.getVendors();
    // Global Search: PIC, Produk/Brand & Bank Information dimuat
    // sekaligus (1 query per tabel) khusus untuk membangun index.
    Future<List<Map<String, dynamic>>> safe(String t) async {
      try {
        return await DatabaseService.instance.getAllChildRows(t);
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }

    final contacts = SearchIndex.groupBy(await safe('vendor_contacts'), 'vendor_id');
    final products = SearchIndex.groupBy(await safe('vendor_products'), 'vendor_id');
    final banks = SearchIndex.groupBy(await safe('vendor_bank_accounts'), 'vendor_id');
    _searchIndex = {};
    _vendors = data.map((e) {
      final v = Vendor.fromMap(e);
      final id = v.id;
      if (id != null) {
        _searchIndex[id] = SearchIndex.build(
          e,
          children: [
            ...(contacts[id] ?? const []),
            ...(products[id] ?? const []),
            ...(banks[id] ?? const []),
          ],
          extra: [
            v.vendorCode,
            v.isActive ? 'aktif' : 'nonaktif',
            v.isVerified ? 'verified' : 'belum verified',
          ],
        );
      }
      return v;
    }).toList();
    notifyListeners();
  }

  Map<int, String> _searchIndex = {};

  /// Teks index Global Search untuk 1 vendor (semua kolom + PIC + produk + bank).
  String searchTextOf(int? id) => id == null ? '' : (_searchIndex[id] ?? '');

  Future<List<VendorContact>> getContactsForVendor(int vendorId) async {
    final data = await DatabaseService.instance.getContactsByVendorId(vendorId);
    return data.map((e) => VendorContact.fromMap(e)).toList();
  }

  Future<List<VendorProduct>> getProductsForVendor(int vendorId) async {
    final data = await DatabaseService.instance.getProductsByVendorId(vendorId);
    return data.map((e) => VendorProduct.fromMap(e)).toList();
  }

  /// REVISI: Bank Information sekarang bisa lebih dari 1 per vendor.
  Future<List<VendorBankAccount>> getBankAccountsForVendor(int vendorId) async {
    final data = await DatabaseService.instance.getBankAccountsByVendorId(vendorId);
    return data.map((e) => VendorBankAccount.fromMap(e)).toList();
  }

  Future<void> addVendor(
    Vendor vendor,
    List<VendorContact> contacts,
    List<VendorProduct> products,
    List<VendorBankAccount> bankAccounts,
  ) async {
    await DatabaseService.instance.insertVendor(
      vendor.toMap(),
      contacts.map((c) => c.toMap()).toList(),
      products.map((p) => p.toMap()).toList(),
      bankAccounts.map((b) => b.toMap()).toList(),
    );
    await loadVendors();
  }

  Future<void> updateVendor(
    Vendor vendor,
    List<VendorContact> contacts,
    List<VendorProduct> products,
    List<VendorBankAccount> bankAccounts,
  ) async {
    await DatabaseService.instance.updateVendor(
      vendor.toMap(),
      contacts.map((c) => c.toMap()).toList(),
      products.map((p) => p.toMap()).toList(),
      bankAccounts.map((b) => b.toMap()).toList(),
    );
    await loadVendors();
  }

  Future<void> deleteVendor(int id) async {
    await DatabaseService.instance.deleteVendor(id);
    await loadVendors();
  }

  /// Hapus beberapa vendor sekaligus (fitur select multi di layar list).
  Future<void> deleteVendors(List<int> ids) async {
    await DatabaseService.instance.deleteVendors(ids);
    await loadVendors();
  }

  /// Ambil ulang 1 vendor terbaru dari list yang sudah dimuat (dipakai
  /// layar Detail setelah balik dari Edit, supaya tampilannya ikut
  /// update tanpa perlu query manual terpisah).
  Vendor? findById(int id) {
    for (final v in _vendors) {
      if (v.id == id) return v;
    }
    return null;
  }
}
