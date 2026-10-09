import 'package:flutter/material.dart';
import '../models/currency_rate.dart';
import '../services/database_service.dart';

class CurrencyProvider extends ChangeNotifier {
  List<CurrencyRate> _rates = [];
  List<CurrencyRate> get rates => _rates;

  Future<void> loadRates() async {
    final data = await DatabaseService.instance.getCurrencyRates();
    _rates = data.map((e) => CurrencyRate.fromMap(e)).toList();
    notifyListeners();
  }

  /// Cari rate (1 unit currency -> IDR) buat currency tertentu. Balik
  /// 1 (anggap sudah IDR / tidak ketemu) kalau belum pernah diisi di
  /// Update Valuta -- dipakai sebagai fallback aman di Material Form
  /// supaya tidak error kalau mata uangnya belum terdaftar.
  double rateFor(String? currencyCode) {
    if (currencyCode == null || currencyCode.isEmpty || currencyCode == 'IDR') return 1;
    final match = _rates.where((r) => r.currencyCode == currencyCode);
    if (match.isEmpty) return 1;
    return match.first.rateToIdr;
  }

  /// Tambah currency baru ke Update Valuta. Kalau currency itu sudah
  /// ada di daftar, dianggap edit (update value-nya saja).
  Future<void> addOrUpdateRate(String currencyCode, double rateToIdr) async {
    final existing = _rates.where((r) => r.currencyCode == currencyCode);
    if (existing.isNotEmpty) {
      await DatabaseService.instance.updateCurrencyRate(existing.first.id!, rateToIdr);
    } else {
      await DatabaseService.instance.insertCurrencyRate(currencyCode, rateToIdr);
    }
    await loadRates();
  }

  Future<void> deleteRate(int id) async {
    await DatabaseService.instance.deleteCurrencyRate(id);
    await loadRates();
  }
}
