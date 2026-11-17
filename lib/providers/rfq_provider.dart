import 'package:flutter/material.dart';
import '../models/rfq.dart';
import '../models/rfq_material.dart';
import '../services/database_service.dart';
import '../utils/search_index.dart';

class RfqProvider extends ChangeNotifier {
  List<Rfq> _rfqs = [];
  List<Rfq> get rfqs => _rfqs;

  /// Dipakai layar list RFQ. SENGAJA tidak memuat daftar Material di
  /// sini (biar tidak query berkali-kali untuk tiap baris di list) --
  /// diambil belakangan lewat [getMaterialLinesForRfq] saat user
  /// benar-benar buka form edit RFQ tertentu.
  Future<void> loadRfqs() async {
    final data = await DatabaseService.instance.getRfqs();
    // Global Search: semua baris Material List RFQ dimuat sekaligus (1
    // query) khusus untuk membangun index.
    var lineRows = <Map<String, dynamic>>[];
    try {
      lineRows = await DatabaseService.instance.getAllRfqMaterialLines();
    } catch (_) {}
    final byRfq = SearchIndex.groupBy(lineRows, 'rfq_id');
    _searchIndex = {};
    _rfqs = data.map((e) {
      final r = Rfq.fromMap(e);
      final id = r.id;
      if (id != null) {
        _searchIndex[id] = SearchIndex.build(
          e,
          children: byRfq[id] ?? const [],
          extra: [r.rfqCode],
        );
      }
      return r;
    }).toList();
    notifyListeners();
  }

  Map<int, String> _searchIndex = {};

  /// Teks index Global Search untuk 1 RFQ (semua kolom + customer + material).
  String searchTextOf(int? id) => id == null ? '' : (_searchIndex[id] ?? '');

  Future<List<RfqMaterialLine>> getMaterialLinesForRfq(int rfqId) async {
    final data = await DatabaseService.instance.getRfqMaterialsByRfqId(rfqId);
    return data.map((e) => RfqMaterialLine.fromMap(e)).toList();
  }

  Future<void> addRfq(Rfq rfq, List<RfqMaterialLine> lines) async {
    await DatabaseService.instance.insertRfq(
      rfq.toMap(),
      lines.map((l) => l.toMap()).toList(),
    );
    await loadRfqs();
  }

  Future<void> updateRfq(Rfq rfq, List<RfqMaterialLine> lines) async {
    await DatabaseService.instance.updateRfq(
      rfq.toMap(),
      lines.map((l) => l.toMap()).toList(),
    );
    await loadRfqs();
  }

  Future<void> deleteRfq(int id) async {
    await DatabaseService.instance.deleteRfq(id);
    await loadRfqs();
  }

  /// Hapus beberapa RFQ sekaligus (fitur select multi di layar list).
  Future<void> deleteRfqs(List<int> ids) async {
    await DatabaseService.instance.deleteRfqs(ids);
    await loadRfqs();
  }

  /// Ambil ulang 1 RFQ terbaru dari list yang sudah dimuat (dipakai
  /// layar Detail setelah balik dari Edit, supaya tampilannya ikut
  /// update tanpa perlu query manual terpisah).
  Rfq? findById(int id) {
    for (final r in _rfqs) {
      if (r.id == id) return r;
    }
    return null;
  }
}
