import 'package:shared_preferences/shared_preferences.dart';

/// Persists AI family choice. New users default to AG Expert (openai).
class AiProviderPrefs {
  static const _key = 'ag_ai_provider';
  static const defaultProvider = 'openai'; // AG Expert

  static Future<String> load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = (prefs.getString(_key) ?? '').toLowerCase().trim();
    if (v == 'gemini' || v == 'openai') return v;
    return defaultProvider;
  }

  static Future<void> save(String provider) async {
    final p = provider.toLowerCase().trim();
    if (p != 'gemini' && p != 'openai') return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, p);
  }
}
