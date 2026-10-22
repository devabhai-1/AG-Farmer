import 'voice_live_webrtc_stub.dart'
    if (dart.library.html) 'voice_live_webrtc_web.dart'
    if (dart.library.io) 'voice_live_webrtc_io.dart' as impl;

/// OpenAI Realtime bridge (web + Android/iOS).
class VoiceLiveWebrtc {
  static bool get isSupported => impl.VoiceLiveWebrtcImpl.isSupported;

  static Future<void> connect({
    required String accessToken,
    required String wsUrl,
    required String model,
    required String voice,
    required String instructions,
    bool premium = false,
    bool video = false,
    void Function(String status)? onStatus,
    void Function(String role, String text)? onTranscript,
  }) =>
      impl.VoiceLiveWebrtcImpl.connect(
        accessToken: accessToken,
        wsUrl: wsUrl,
        model: model,
        voice: voice,
        instructions: instructions,
        premium: premium,
        video: video,
        onStatus: onStatus,
        onTranscript: onTranscript,
      );

  static Future<void> disconnect() => impl.VoiceLiveWebrtcImpl.disconnect();

  static void interrupt() => impl.VoiceLiveWebrtcImpl.interrupt();
}
