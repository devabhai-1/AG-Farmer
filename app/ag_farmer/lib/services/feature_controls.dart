import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cacheKey = 'ag_feature_controls';

/// Same switches as the server `controls.json`.
/// The app refuses a closed feature before the request leaves the phone.
class FeatureControls extends ChangeNotifier {
  FeatureControls._();
  static final FeatureControls instance = FeatureControls._();

  final Map<String, bool> _on = {
    'openaiSpeech': false,
    'chatterbox': false,
    'geminiLive': false,
    'transcribe': false,
    'chat': true,
    'course': true,
    'image': true,
    'voiceCall': true,
    'videoCall': true,
    'deep': true,
    'jankari': true,
    'weather': true,
    'billing': true,
    'storage': true,
    'tracks': true,
    'support': true,
    'announcements': true,
    'googleLogin': true,
    'otp': true,
    'credits': true,
    'reports': true,
    'notify': true,
  };

  bool on(String flag) => _on[flag] ?? false;

  Future<void> loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) apply(decoded, persist: false);
    } catch (e) {
      debugPrint('feature controls cache skipped: $e');
    }
  }

  void apply(Map raw, {bool persist = true}) {
    for (final key in _on.keys) {
      final value = raw[key];
      if (value is bool) _on[key] = value;
    }
    notifyListeners();
    if (persist) {
      Future<void>(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, jsonEncode(_on));
        } catch (_) {}
      });
    }
  }

  /// True when this call must not leave the phone.
  bool blocks(String action, Map<String, dynamic>? data) {
    for (final flag in _flags(action, data)) {
      if (!on(flag)) return true;
    }
    return false;
  }

  static bool _hasImage(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['hasImage'] == true) return true;
    if (data['imageBase64'] != null || data['image'] != null) return true;
    final images = data['images'];
    return images is List && images.isNotEmpty;
  }

  static const _one = <String, String>{
    'auth.google': 'googleLogin',
    'auth.otp.send': 'otp',
    'auth.otp.verify': 'otp',
    'auth.phone.lookup': 'otp',
    'jankari.list': 'jankari',
    'jankari.meta': 'jankari',
    'jankari.search': 'jankari',
    'jankari.tts': 'jankari',
    'announcement.list': 'announcements',
    'voice.speak': 'openaiSpeech',
    'tts.chatterbox.test': 'chatterbox',
    'voice.transcribe': 'transcribe',
    'voice.realtime.session': 'geminiLive',
    'video.start': 'videoCall',
    'weather.search': 'weather',
    'weather.forecast': 'weather',
    'billing.subscription.create': 'billing',
    'billing.subscription.verify': 'billing',
    'billing.subscription.cancel': 'billing',
    'billing.checkout.create': 'billing',
    'billing.checkout.verify': 'billing',
    'storage.upload': 'storage',
    'storage.upload-url': 'storage',
    'storage.uploadUrl': 'storage',
    'storage.download': 'storage',
    'storage.download-url': 'storage',
    'storage.downloadUrl': 'storage',
    'storage.list': 'storage',
    'storage.my-files': 'storage',
    'storage.delete': 'storage',
    'tracks.list': 'tracks',
    'tracks.save': 'tracks',
    'tracks.log': 'tracks',
    'tracks.delete': 'tracks',
    'support.create': 'support',
    'support.mine': 'support',
    'credit.status': 'credits',
    'credit.redeem': 'credits',
    'credit.create': 'credits',
    'report.create': 'reports',
    'notify.token': 'notify',
  };

  List<String> _flags(String action, Map<String, dynamic>? data) {
    if (action == 'chat.sync' ||
        action == 'chat.restore' ||
        action == 'chat.sessions' ||
        action == 'chat.sessions.list' ||
        action == 'chat.sessions.create' ||
        action == 'chat.sessions.delete') {
      return [data?['mode'] == 'course' ? 'course' : 'chat'];
    }
    if (action == 'chat') {
      final flags = <String>[data?['mode'] == 'course' ? 'course' : 'chat'];
      final voice = data?['voice'] == true;
      final image = _hasImage(data);
      if (voice && image) {
        flags.add('videoCall');
      } else if (voice) {
        flags.add('voiceCall');
      }
      if (image) flags.add('image');
      if (data?['deepResearch'] == true || data?['deep'] == true) {
        flags.add('deep');
      }
      return flags;
    }
    final one = _one[action];
    return one == null ? const [] : [one];
  }
}

final featureControls = FeatureControls.instance;
