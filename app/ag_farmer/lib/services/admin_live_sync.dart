import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_services.dart';

/// Pulls admin catalog (sale price, crops) and chat/shot limits.
/// Admin panel save → next pull (resume or ~12s) updates the open app.
class AdminLiveSync {
  AdminLiveSync._();
  static final AdminLiveSync instance = AdminLiveSync._();

  Timer? _timer;
  bool _busy = false;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => pull());
    unawaited(pull());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> pull() async {
    if (_busy) return;
    _busy = true;
    try {
      await Future.wait([
        catalogService.refresh(),
        chatLimitsService.load(),
      ]);
    } catch (e) {
      debugPrint('admin live sync skipped: $e');
    } finally {
      _busy = false;
    }
  }
}
