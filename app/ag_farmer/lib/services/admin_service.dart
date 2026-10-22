import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// In-app admin unlock gate (legacy pay wall; server may return gone).
class AdminService extends ChangeNotifier {
  AdminService._();
  static final AdminService instance = AdminService._();

  bool _busy = false;
  String? _error;
  int price = 499;

  bool get busy => _busy;
  String? get error => _error;

  Future<bool> payAndUnlock({String? email, String? name}) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.instance.call(
        'admin.unlock.self',
        auth: true,
        data: {
          if (email != null && email.isNotEmpty) 'email': email,
          if (name != null && name.isNotEmpty) 'name': name,
        },
      );
      _busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('gone') || msg.contains('410')) {
        _error = 'Admin unlock via app payment is closed.';
      } else {
        _error = msg.replaceFirst(RegExp(r'^Exception:\s*'), '');
      }
      if (kDebugMode) debugPrint('admin unlock: $e');
      _busy = false;
      notifyListeners();
      return false;
    }
  }
}

final adminService = AdminService.instance;
