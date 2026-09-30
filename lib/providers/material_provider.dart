import 'package:flutter/material.dart';
import '../models/material_discount.dart';
import '../models/material_item.dart';
import '../services/database_service.dart';

class MaterialProvider extends ChangeNotifier {
  List<MaterialItem> _materials = [];
  List<MaterialItem> get materials => _materials;

  /// Dipakai layar list Material. SENGAJA tidak memuat daftar diskon di
  /// sini (biar tidak query berkali-kali untuk tiap baris di list) --
  /// diambil belakangan lewat [getDiscountsForMaterial] saat user
  /// benar-benar buka form edit material tertentu.
  Future<void> loadMaterials() async {
    final data = await DatabaseService.instance.getMaterials();
    _materials = data.map((e) => MaterialItem.fromMap(e)).toList();
    notifyListeners();
  }

  Future<List<MaterialDiscount>> getDiscountsForMaterial(int materialId) async {
    final data = await DatabaseService.instance.getDiscountsByMaterialId(materialId);
    return data.map((e) => MaterialDiscount.fromMap(e)).toList();
  }

  Future<void> addMaterial(MaterialItem material, List<MaterialDiscount> discounts) async {
    await DatabaseService.instance.insertMaterial(
      material.toMap(),
      discounts.map((d) => d.toMap()).toList(),
    );
    await loadMaterials();
  }

  Future<void> updateMaterial(MaterialItem material, List<MaterialDiscount> discounts) async {
    await DatabaseService.instance.updateMaterial(
      material.toMap(),
      discounts.map((d) => d.toMap()).toList(),
    );
    await loadMaterials();
  }

  Future<void> deleteMaterial(int id) async {
    await DatabaseService.instance.deleteMaterial(id);
    await loadMaterials();
  }

  /// Hapus beberapa material sekaligus (fitur select multi di layar list).
  Future<void> deleteMaterials(List<int> ids) async {
    await DatabaseService.instance.deleteMaterials(ids);
    await loadMaterials();
  }

  /// Ambil ulang 1 material terbaru dari list yang sudah dimuat (dipakai
  /// layar Detail setelah balik dari Edit, supaya tampilannya ikut
  /// update tanpa perlu query manual terpisah).
  MaterialItem? findById(int id) {
    for (final m in _materials) {
      if (m.id == id) return m;
    }
    return null;
  }
}
