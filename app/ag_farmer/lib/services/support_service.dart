import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/subscription_plan.dart';
import '../models/support_request.dart';
import 'api_client.dart';

class SupportService extends ChangeNotifier {
  final List<SupportRequest> _myRequests = [];
  final List<SupportRequest> _allRequests = [];
  bool _listening = false;
  bool _busy = false;
  String? _error;
  String? _lastToken;

  List<SupportRequest> get myRequests => List.unmodifiable(_myRequests);
  List<SupportRequest> get allRequests => List.unmodifiable(_allRequests);
  bool get busy => _busy;
  String? get error => _error;
  String? get lastToken => _lastToken;

  static String? get _adminKey {
    const fromEnv = String.fromEnvironment('AG_ADMIN_KEY');
    return fromEnv.isEmpty ? null : fromEnv;
  }

  void startListening() {
    if (_listening) return;
    _listening = true;
    refreshMine();
    unawaited(refreshAll());
  }

  Future<void> refreshMine() async {
    final uid = ApiClient.instance.uid;
    if (uid == null) {
      _myRequests.clear();
      notifyListeners();
      return;
    }
    try {
      final res = await ApiClient.instance.call('support.mine', auth: true);
      _applyMine(res['requests']);
    } catch (e) {
      debugPrint('Support refresh failed: $e');
    }
    notifyListeners();
  }

  void _applyMine(dynamic raw) {
    final list = _parseList(raw);
    _myRequests
      ..clear()
      ..addAll(list);
  }

  List<SupportRequest> _parseList(dynamic raw) {
    final list = <SupportRequest>[];
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is Map) {
          list.add(
            SupportRequest.fromMap(
              key.toString(),
              Map<dynamic, dynamic>.from(value),
            ),
          );
        }
      });
    } else if (raw is List) {
      for (final row in raw) {
        if (row is! Map) continue;
        final m = Map<dynamic, dynamic>.from(row);
        list.add(SupportRequest.fromMap('${m['id'] ?? ''}', m));
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> refreshAll() async {
    try {
      final res = await ApiClient.instance.call(
        'admin.support.list',
        auth: true,
        adminKey: _adminKey,
      );
      _allRequests
        ..clear()
        ..addAll(_parseList(res['requests']));
    } catch (e) {
      debugPrint('Support all refresh failed: $e');
    }
    notifyListeners();
  }

  Future<void> updateStatus({
    required String requestId,
    required SupportStatus status,
    String? adminNote,
  }) async {
    await ApiClient.instance.call(
      'admin.support.update',
      auth: true,
      adminKey: _adminKey,
      data: {
        'id': requestId,
        'status': status.name,
        if (adminNote != null) 'adminNote': adminNote,
      },
    );
    await refreshAll();
    await refreshMine();
  }

  Future<SupportRequest?> submitLiveSupportRequest({
    required PlanTier plan,
    String message = '',
  }) async {
    if (plan == PlanTier.free) {
      _error = 'not_paid';
      notifyListeners();
      return null;
    }

    if (!ApiClient.instance.hasSession) {
      _error = 'login_required';
      notifyListeners();
      return null;
    }

    _busy = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiClient.instance.call(
        'support.create',
        auth: true,
        data: {
          'message': message.trim().isEmpty ? 'Live support request' : message.trim(),
        },
      );
      final raw = res['request'];
      SupportRequest? request;
      if (raw is Map) {
        request = SupportRequest.fromMap(
          (raw['id'] ?? '').toString(),
          Map<dynamic, dynamic>.from(raw),
        );
      }
      final token = request?.token;
      if (token != null && token.isNotEmpty) _lastToken = token;
      await refreshMine();
      _busy = false;
      notifyListeners();
      return request;
    } catch (e) {
      _error = e.toString();
      _busy = false;
      notifyListeners();
      return null;
    }
  }
}
