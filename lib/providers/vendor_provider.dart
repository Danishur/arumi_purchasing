import 'package:flutter/material.dart';
import '../models/vendor.dart';
import '../models/vendor_contact.dart';
import '../models/vendor_product.dart';
import '../services/database_service.dart';

class VendorProvider extends ChangeNotifier {
  List<Vendor> _vendors = [];
  List<Vendor> get vendors => _vendors;

  /// Dipakai layar list Vendor. SENGAJA tidak memuat PIC/Produk di sini
  /// (biar tidak query berkali-kali untuk tiap baris vendor di list) --
  /// diambil belakangan lewat [getContactsForVendor]/[getProductsForVendor]
  /// saat user benar-benar buka form edit vendor tertentu.
  Future<void> loadVendors() async {
    final data = await DatabaseService.instance.getVendors();
    _vendors = data.map((e) => Vendor.fromMap(e)).toList();
    notifyListeners();
  }

  Future<List<VendorContact>> getContactsForVendor(int vendorId) async {
    final data = await DatabaseService.instance.getContactsByVendorId(vendorId);
    return data.map((e) => VendorContact.fromMap(e)).toList();
  }

  Future<List<VendorProduct>> getProductsForVendor(int vendorId) async {
    final data = await DatabaseService.instance.getProductsByVendorId(vendorId);
    return data.map((e) => VendorProduct.fromMap(e)).toList();
  }

  Future<void> addVendor(
    Vendor vendor,
    List<VendorContact> contacts,
    List<VendorProduct> products,
  ) async {
    await DatabaseService.instance.insertVendor(
      vendor.toMap(),
      contacts.map((c) => c.toMap()).toList(),
      products.map((p) => p.toMap()).toList(),
    );
    await loadVendors();
  }

  Future<void> updateVendor(
    Vendor vendor,
    List<VendorContact> contacts,
    List<VendorProduct> products,
  ) async {
    await DatabaseService.instance.updateVendor(
      vendor.toMap(),
      contacts.map((c) => c.toMap()).toList(),
      products.map((p) => p.toMap()).toList(),
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
