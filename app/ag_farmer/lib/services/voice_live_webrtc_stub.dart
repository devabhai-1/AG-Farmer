class VoiceLiveWebrtcImpl {
  static bool get isSupported => false;

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
  }) async {
    throw UnsupportedError('voice_live_unsupported');
  }

  static Future<void> disconnect() async {}

  static void interrupt() {}
}
