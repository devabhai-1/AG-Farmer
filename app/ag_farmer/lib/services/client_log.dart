import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Soft client diagnostics → `client.log` (never blocks UI).
class ClientLog {
  ClientLog._();

  static void layout(String message) => _send(
        kind: 'layout',
        message: message,
      );

  static void login(String? message, {String? screen}) => _send(
        kind: 'login',
        message: message ?? 'login_error',
        screen: screen,
      );

  static void _send({
    required String kind,
    required String message,
    String? screen,
    String? code,
  }) {
    Future<void>(() async {
      try {
        await ApiClient.instance.call(
          'client.log',
          data: {
            'kind': kind,
            'message': message.length > 500 ? message.substring(0, 500) : message,
            if (code != null && code.isNotEmpty) 'code': code,
            if (screen != null && screen.isNotEmpty) 'screen': screen,
          },
          timeout: const Duration(seconds: 6),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('client.log skipped: $e');
      }
    });
  }
}
