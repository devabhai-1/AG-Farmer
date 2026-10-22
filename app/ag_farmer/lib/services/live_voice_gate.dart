import 'package:flutter/foundation.dart';

import 'voice_live_webrtc.dart';

/// Ensures only one live/mic owner holds the audio path.
/// Call [stop] before device STT / TTS or when leaving live screens.
class LiveVoiceGate {
  LiveVoiceGate._();
  static final LiveVoiceGate instance = LiveVoiceGate._();

  Future<void> stop() async {
    try {
      VoiceLiveWebrtc.interrupt();
    } catch (_) {}
    try {
      await VoiceLiveWebrtc.disconnect();
    } catch (e) {
      if (kDebugMode) debugPrint('liveVoiceGate.stop: $e');
    }
  }
}

final liveVoiceGate = LiveVoiceGate.instance;
