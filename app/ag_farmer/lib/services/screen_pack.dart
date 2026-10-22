import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

const _cacheKey = 'ag_screen_pack_v1';

/// Remote copy + labels for login/chat/course UI (`screen.pack` API).
class ScreenPack extends ChangeNotifier {
  ScreenPack._();
  static final ScreenPack instance = ScreenPack._();

  Map<String, dynamic> _screens = {};

  Map<String, dynamic> get screens => _screens;

  Future<void> loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _screens = Map<String, dynamic>.from(decoded);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('screen pack cache skipped: $e');
    }
  }

  Future<void> refresh() async {
    try {
      final res = await ApiClient.instance.call(
        'screen.pack',
        timeout: const Duration(seconds: 10),
      );
      final screens = res['screens'];
      if (screens is Map) {
        _screens = Map<String, dynamic>.from(screens);
        notifyListeners();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(_screens));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('screen.pack skipped: $e');
    }
  }

  Map<String, dynamic>? _block(String screen) {
    final raw = _screens[screen];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  /// Boolean flag under a screen block (`showGoogle`, `showSend`, …).
  bool on(String screen, String key, [bool fallback = false]) {
    final block = _block(screen);
    if (block == null) return fallback;
    final v = block[key];
    if (v is bool) return v;
    return fallback;
  }

  /// Localized string: `{ "hi": "...", "en": "..." }` or plain string.
  String t(bool hi, String screen, String key, String fallback) {
    final block = _block(screen);
    if (block == null) return fallback;
    final raw = block[key];
    if (raw is String && raw.trim().isNotEmpty) return raw;
    if (raw is Map) {
      final prefer = hi ? raw['hi'] : raw['en'];
      final other = hi ? raw['en'] : raw['hi'];
      final text = '${prefer ?? other ?? ''}'.trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  /// Prompt chips for [ServerPromptStrip]: `{textHi,textEn,cropId?}`.
  List<Map<String, dynamic>> prompts(String screen) {
    final block = _block(screen);
    final raw = block?['prompts'];
    if (raw is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final row in raw) {
      if (row is Map) out.add(Map<String, dynamic>.from(row));
    }
    return out;
  }

  /// Slot order for [ServerBody], or null → use widget fallback.
  List<String>? order(String screen) {
    final block = _block(screen);
    final raw = block?['order'] ?? block?['blocks'];
    if (raw is! List) return null;
    return raw.map((e) => '$e').where((e) => e.isNotEmpty).toList();
  }
}

final screenPack = ScreenPack.instance;
