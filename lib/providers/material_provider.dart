import 'package:flutter/material.dart';
import '../models/material_discount.dart';
import '../models/material_item.dart';
import '../services/database_service.dart';
import '../utils/search_index.dart';

class MaterialProvider extends ChangeNotifier {
  List<MaterialItem> _materials = [];
  List<MaterialItem> get materials => _materials;

  /// Dipakai layar list Material. SENGAJA tidak memuat daftar diskon di
  /// sini (biar tidak query berkali-kali untuk tiap baris di list) --
  /// diambil belakangan lewat [getDiscountsForMaterial] saat user
  /// benar-benar buka form edit material tertentu.
  Future<void> loadMaterials() async {
    final data = await DatabaseService.instance.getMaterials();
    // Global Search: semua baris diskon dimuat sekaligus (1 query) khusus
    // untuk membangun index.
    var discountRows = <Map<String, dynamic>>[];
    try {
      discountRows = await DatabaseService.instance.getAllChildRows('material_discounts');
    } catch (_) {}
    final byMaterial = SearchIndex.groupBy(discountRows, 'material_id');
    _searchIndex = {};
    _materials = data.map((e) {
      final m = MaterialItem.fromMap(e);
      final id = m.id;
      if (id != null) {
        _searchIndex[id] = SearchIndex.build(
          e,
          children: byMaterial[id] ?? const [],
          extra: [m.materialCode, m.isActive ? 'aktif' : 'nonaktif'],
        );
      }
      return m;
    }).toList();
    notifyListeners();
  }

  Map<int, String> _searchIndex = {};

  /// Teks index Global Search untuk 1 material (semua kolom + diskon + vendor).
  String searchTextOf(int? id) => id == null ? '' : (_searchIndex[id] ?? '');

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
