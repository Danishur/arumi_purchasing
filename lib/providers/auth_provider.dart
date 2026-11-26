import 'package:flutter/foundation.dart';
import '../services/database_service.dart';

/// User yang sedang login di aplikasi. Saat login, nama & id user juga
/// dititipkan ke [DatabaseService] supaya setiap tambah / ubah / hapus
/// data otomatis tercatat di Riwayat Aktivitas atas nama user ini.
class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;

  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _user != null;
  String get name => (_user?['name'] ?? '').toString();
  String get email => (_user?['email'] ?? '').toString();
  bool get isOwner => (_user?['role'] ?? '') == 'owner';

  /// Melempar [AuthException] kalau gagal.
  Future<void> login(String email, String password) async {
    final u = await DatabaseService.instance.loginUser(email.trim(), password);
    _user = u;
    DatabaseService.actorId = (u['id'] as num).toInt();
    DatabaseService.actorName = (u['name'] ?? u['email']).toString();
    notifyListeners();
  }

  void logout() {
    _user = null;
    DatabaseService.actorId = null;
    DatabaseService.actorName = '';
    notifyListeners();
  }
}
