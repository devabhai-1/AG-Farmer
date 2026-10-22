import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'feature_controls.dart';

/// Single backend address — all actions go through this one URL.
/// No Firebase API keys live in the app.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String _tokenKey = 'ag_session_token';
  static const String _uidKey = 'ag_session_uid';
  static const String _emailKey = 'ag_session_email';
  static const String _apiUrlKey = 'ag_api_url_working';
  static const String _installIdKey = 'ag_install_id';
  static const String _installAtKey = 'ag_install_at';

  /// The only API. Contabo, reached through the subdomain over TLS.
  /// Override: --dart-define=AG_API_URL=https://...
  static const String _prodApi = 'https://api.ag-farmer.com/api';

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('AG_API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return _prodApi;
  }

  static List<String> get _urlCandidates {
    const fromEnv = String.fromEnvironment('AG_API_URL');
    if (fromEnv.isNotEmpty) return [fromEnv];
    return const [_prodApi];
  }

  String? _token;
  String? _uid;
  String? _email;

  /// Set by the release gate. Older than the server line is refused.
  static int buildCode = 0;
  String? _installId;
  int? _firstInstallAt;

  /// After a network failure, skip non-critical calls briefly so boot isn't stuck.
  DateTime? _downUntil;
  bool get isLikelyDown =>
      _downUntil != null && DateTime.now().isBefore(_downUntil!);

  String? get token => _token;
  String? get uid => _uid;
  String? get email => _email;
  bool get hasSession => _token != null && _token!.isNotEmpty;

  static bool _isAuthAction(String action) =>
      action.startsWith('auth.') || action == 'health';

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _uid = prefs.getString(_uidKey);
    _email = prefs.getString(_emailKey);
    if (prefs.containsKey(_apiUrlKey)) {
      await prefs.remove(_apiUrlKey);
    }
  }

  Future<void> setSession({
    required String token,
    required String uid,
    String? email,
  }) async {
    _token = token;
    _uid = uid;
    if (email != null && email.trim().isNotEmpty) {
      _email = email.trim().toLowerCase();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_uidKey, uid);
    if (_email != null && _email!.isNotEmpty) {
      await prefs.setString(_emailKey, _email!);
    }
  }

  Future<void> clearSession() async {
    _token = null;
    _uid = null;
    _email = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_uidKey);
    await prefs.remove(_emailKey);
  }

  void _markDown() {
    _downUntil = DateTime.now().add(const Duration(seconds: 12));
  }

  void markUp() {
    _downUntil = null;
  }

  Future<Map<String, dynamic>> call(
    String action, {
    Map<String, dynamic>? data,
    bool auth = false,
    String? adminKey,
    Duration? timeout,
    String? baseUrl,
  }) async {
    if (featureControls.blocks(action, data)) {
      throw Exception('feature_closed');
    }
    final isChat = action == 'chat';
    final isAuth = _isAuthAction(action);
    final isVoiceLive = action == 'voice.realtime.session';
    final isJankari =
        action == 'jankari.list' ||
        action == 'jankari.search' ||
        action == 'jankari.meta';
    final isSoft =
        action == 'analytics.page' ||
        action == 'client.log' ||
        action == 'screen.pack';
    final wait =
        timeout ??
        (isChat || isVoiceLive
            ? const Duration(seconds: 75)
            : isAuth
            ? const Duration(seconds: 25)
            : isJankari
            ? const Duration(seconds: 40)
            : const Duration(seconds: 12));

    // Never block login/register or the article feed behind the boot circuit-breaker.
    if (!isChat && !isAuth && !isVoiceLive && !isJankari && !isSoft && isLikelyDown) {
      throw Exception('Server unreachable');
    }

    final body = <String, dynamic>{'action': action, ...?data};
    if (_email != null && _email!.isNotEmpty && body['email'] == null) {
      body['email'] = _email;
    }
    if (adminKey != null && adminKey.isNotEmpty) {
      body['adminKey'] = adminKey;
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (buildCode > 0) headers['X-App-Build'] = '$buildCode';

    final needAuth = auth || hasSession;
    if (needAuth) {
      _token ??= (await SharedPreferences.getInstance()).getString(_tokenKey);
      if (_token != null && _token!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_token';
      }
    }

    final payload = jsonEncode(body);
    Object? lastError;

    final urls = (baseUrl != null && baseUrl.isNotEmpty)
        ? [baseUrl]
        : _urlCandidates;
    for (final url in urls) {
      try {
        final res = await http
            .post(Uri.parse(url), headers: headers, body: payload)
            .timeout(wait);

        markUp();

        Map<String, dynamic> json;
        try {
          json = jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {
          throw Exception('Invalid server response (${res.statusCode})');
        }

        if (res.statusCode >= 400 || json['ok'] == false) {
          throw Exception(
            json['error']?.toString() ?? 'API error ${res.statusCode}',
          );
        }

        return json;
      } catch (e) {
        lastError = e;
        // Auth/API business errors should not try the next host.
        final msg = e.toString();
        if (msg.contains('Invalid server response') ||
            msg.contains('API error') ||
            (!msg.contains('Server unreachable') &&
                !msg.contains('SocketException') &&
                !msg.contains('TimeoutException') &&
                !msg.contains('ClientException') &&
                !msg.contains('Connection'))) {
          // Likely a real API error from a reachable host — stop.
          if (msg.contains('Exception: ') &&
              !msg.contains('Failed host lookup') &&
              !msg.contains('Connection refused') &&
              !msg.contains('Connection timed out') &&
              !msg.contains('TimeoutException')) {
            rethrow;
          }
        }
        if (kDebugMode) {
          debugPrint('ApiClient try $url failed: $e');
        }
      }
    }

    // A slow answer on a weak network (cold TLS handshake on 3G / budget
    // phones) is not an outage: only a hard connection failure trips the
    // boot circuit-breaker, otherwise one slow call would make every other
    // boot request fail instantly for 12 seconds.
    if (lastError is! TimeoutException && !isSoft) _markDown();
    if (kDebugMode) debugPrint('ApiClient network error: $lastError');
    throw Exception('Server unreachable');
  }

  Future<Map<String, dynamic>> health() =>
      call('health', timeout: const Duration(seconds: 10));

  Future<Map<String, dynamic>> config() =>
      call('config', timeout: const Duration(seconds: 10));

  /// Pulls the backend switches into the app.
  Future<void> refreshFeatures() async {
    try {
      final res = await config();
      final features = res['features'];
      if (features is Map) {
        featureControls.apply(Map<String, dynamic>.from(features));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('features skipped: $e');
    }
  }

  Future<Map<String, dynamic>> phoneLookup(String phone) =>
      call('auth.phone.lookup', data: {'phone': phone});

  Future<Map<String, dynamic>> otpSend(String phone) =>
      call('auth.otp.send', data: {'phone': phone});

  Future<Map<String, dynamic>> otpVerify({
    required String phone,
    required String otp,
    String? requestId,
    String? name,
  }) => call(
    'auth.otp.verify',
    data: {
      'phone': phone,
      'otp': otp,
      if (requestId != null) 'requestId': requestId,
      if (name != null) 'name': name,
    },
  );

  Future<Map<String, dynamic>> verifyToken(String idToken) =>
      call('auth.verify', data: {'idToken': idToken});

  Future<Map<String, dynamic>> storageUploadUrl({
    String kind = 'chat',
    String filename = 'upload.jpg',
    String contentType = 'image/jpeg',
  }) => call(
    'storage.upload',
    auth: true,
    data: {'kind': kind, 'filename': filename, 'contentType': contentType},
  );

  Future<Map<String, dynamic>> storageDownloadUrl(String objectPath) =>
      call('storage.download', auth: true, data: {'objectPath': objectPath});

  Future<Map<String, dynamic>> catalogCrops() => call('catalog.crops');

  Future<Map<String, dynamic>> catalogPlans() => call('catalog.plans');

  Future<Map<String, dynamic>> chat(
    String message, {
    String? cropId,
    String mode = 'chat',
    bool isHi = true,
  }) => call(
    'chat',
    auth: hasSession,
    data: {
      'message': message,
      'lang': isHi ? 'hi' : 'en',
      'isHi': isHi,
      'mode': mode,
      if (cropId != null) 'cropId': cropId,
    },
    timeout: const Duration(seconds: 55),
  );

  Future<void> logPage(String page, {String? extra}) async {
    try {
      await call(
        'analytics.page',
        data: {
          'page': page,
          if (extra != null && extra.trim().isNotEmpty) 'extra': extra.trim(),
        },
        timeout: const Duration(seconds: 6),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('analytics.page skipped: $e');
    }
  }

  /// Fire-and-forget: har chhoti activity email ke saath RTDB me.
  Future<void> logActivity(
    String type, {
    Map<String, dynamic>? detail,
    Map<String, dynamic>? state,
  }) async {
    if (!hasSession) return;
    try {
      await call(
        'activity.log',
        auth: true,
        data: {
          'type': type,
          if (detail != null) 'detail': detail,
          if (state != null) 'state': state,
        },
        timeout: const Duration(seconds: 8),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('activity.log skipped: $e');
    }
  }

  Future<void> _ensureInstall() async {
    if (_installId != null && _firstInstallAt != null) return;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_installIdKey);
    var at = prefs.getInt(_installAtKey);
    if (id == null || id.isEmpty) {
      id = 'i_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9000) + 1000}';
      at = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString(_installIdKey, id);
      await prefs.setInt(_installAtKey, at);
    }
    _installId = id;
    _firstInstallAt = at;
  }

  /// Guest + logged-in heartbeat so admin can see IP / online / install.
  Future<void> pingPresence({String? screen}) async {
    try {
      await _ensureInstall();
      await call(
        'presence.ping',
        auth: hasSession,
        data: {
          'installId': _installId,
          'firstInstallAt': _firstInstallAt,
          if (screen != null && screen.isNotEmpty) 'screen': screen,
        },
        timeout: const Duration(seconds: 6),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('presence.ping skipped: $e');
    }
  }
}
