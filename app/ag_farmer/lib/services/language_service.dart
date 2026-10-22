import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/strings.dart';
import 'api_client.dart';

class LanguageService extends ChangeNotifier {
  static const _prefsKey = 'agro_gpt_language';

  AppLang? _lang;
  bool _ready = false;

  AppLang? get lang => _lang;
  bool get ready => _ready;
  bool get hasLanguage => _lang != null;
  S get s => S(_lang ?? AppLang.english);
  bool get isHindi => _lang == AppLang.hindi;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null) {
      _lang = AppLang.fromCode(code);
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> setLanguage(AppLang lang) async {
    if (_lang == lang) return;
    _lang = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, lang.code);
    notifyListeners();

    // Don't block UI / spam timeouts when offline or logged out.
    if (!ApiClient.instance.hasSession || ApiClient.instance.isLikelyDown) {
      return;
    }
    // Fire-and-forget with short timeout.
    // ignore: unawaited_futures
    () async {
      try {
        await ApiClient.instance.call(
          'users.me.update',
          auth: true,
          data: {'language': lang.code},
          timeout: const Duration(seconds: 4),
        );
      } catch (e) {
        debugPrint('Language save via API skipped: $e');
      }
    }();
  }

  Future<void> clearLanguage() async {
    _lang = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    notifyListeners();
  }
}
