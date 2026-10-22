import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

const _storeUrl = 'https://play.google.com/store/apps/details?id=com.agfarmer.app';
const _minKey = 'ag_release_min_build';
const _urlKey = 'ag_release_store_url';
const _playKey = 'ag_release_play_code';

/// The update screen follows Play. A higher version on Play locks this install.
/// The server line is a separate lock and stays off until it is set.
class AppRelease extends ChangeNotifier {
  AppRelease._();
  static final AppRelease instance = AppRelease._();

  static const _channel = MethodChannel('ag_farmer/app_release');

  int build = 0;
  int minBuild = 0;
  int playOffered = 0;
  String storeUrl = _storeUrl;
  bool ready = false;

  bool get _serverLock => ready && minBuild > 0 && build > 0 && build < minBuild;

  bool get _playLock => ready && build > 0 && playOffered > build;

  /// Play has a newer build for this install, or the server line says so.
  bool get blocked => _serverLock || _playLock;

  /// A saved lock is waiting on the build number, so the home screen must not flash.
  bool get checking => !ready && (minBuild > 0 || playOffered > 0);

  Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();
    minBuild = prefs.getInt(_minKey) ?? 0;
    playOffered = prefs.getInt(_playKey) ?? 0;
    final savedUrl = prefs.getString(_urlKey);
    if (savedUrl != null && savedUrl.startsWith('https://')) storeUrl = savedUrl;
    build = await _readBuild();
    ApiClient.buildCode = build;
    if (build > 0 && playOffered <= build) {
      playOffered = 0;
      await prefs.remove(_playKey);
    }
    ready = true;
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final cfg = await ApiClient.instance.config();
      final release = cfg['release'];
      if (release is Map) {
        final nextMin = _asInt(release['minBuild']);
        final nextUrl = release['storeUrl']?.toString().trim() ?? '';
        minBuild = nextMin;
        if (nextUrl.startsWith('https://')) storeUrl = nextUrl;
        final prefs = await SharedPreferences.getInstance();
        if (nextMin > 0) {
          await prefs.setInt(_minKey, nextMin);
        } else {
          await prefs.remove(_minKey);
        }
        if (storeUrl.startsWith('https://')) {
          await prefs.setString(_urlKey, storeUrl);
        }
      }
      if (build <= 0) {
        build = await _readBuild();
        ApiClient.buildCode = build;
      }
      ready = true;
    } catch (e) {
      if (kDebugMode) debugPrint('release check skipped: $e');
    }
    await _askPlay();
    notifyListeners();
  }

  /// Play's own answer. "no" clears a saved lock. A failed check leaves it.
  Future<void> _askPlay() async {
    if (kIsWeb) return;
    try {
      final raw = await _channel
          .invokeMethod<dynamic>('playUpdate')
          .timeout(const Duration(seconds: 8));
      if (raw is! Map) return;
      final state = raw['state']?.toString() ?? '';
      final prefs = await SharedPreferences.getInstance();
      if (state == 'yes') {
        final code = _asInt(raw['versionCode']);
        if (build > 0 && code > build) {
          playOffered = code;
          await prefs.setInt(_playKey, code);
        }
      } else if (state == 'no') {
        playOffered = 0;
        await prefs.remove(_playKey);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('play update check skipped: $e');
    }
  }

  /// Play's update screen when Play can install it, otherwise the store page.
  Future<void> beginUpdate() async {
    if (!kIsWeb) {
      try {
        final started = await _channel
            .invokeMethod<bool>('startUpdate')
            .timeout(const Duration(seconds: 8));
        if (started == true) return;
      } catch (e) {
        if (kDebugMode) debugPrint('play update start skipped: $e');
      }
    }
    await openStore();
  }

  Future<void> openStore() async {
    try {
      await _channel.invokeMethod<void>('openStore');
    } catch (e) {
      if (kDebugMode) debugPrint('store open skipped: $e');
    }
  }

  Future<int> _readBuild() async {
    if (kIsWeb) return 0;
    try {
      final raw = await _channel.invokeMethod<dynamic>('version');
      if (raw is Map) {
        final code = raw['code'];
        if (code is int) return code;
        if (code is num) return code.toInt();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('build read skipped: $e');
    }
    return 0;
  }

  int _asInt(Object? value) {
    final parsed = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;
    return parsed < 0 ? 0 : parsed;
  }
}

final appRelease = AppRelease.instance;
