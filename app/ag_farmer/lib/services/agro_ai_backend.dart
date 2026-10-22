import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import 'agro_ai_service.dart';
import 'api_client.dart';
import 'weather_service.dart';

/// Calls backend AI chat. API keys stay on the server only.
/// [provider] = `gemini` | `openai` — user-selected model (no silent switch).
/// Server maps plan → model tier: High plans (₹299+) get advanced models;
/// free / local always use low-cost models.
class AgroAiBackend {
  static Future<AgroAiResponse> ask(
    String query, {
    String? activeCropId,
    bool isHi = true,
    String mode = 'chat',
    String provider = 'openai',
    String? planId,
    bool hasImage = false,
    String? imageBase64,
    List<String>? images,
    String? sessionId,
    String? chatName,
    bool deepResearch = false,
    bool voice = false,
    List<ChatMessage> history = const [],
    double? lat,
    double? lon,
  }) async {
    try {
      final farm = await WeatherService.savedFarm();
      final useLat = lat ?? farm?.lat;
      final useLon = lon ?? farm?.lon;
      final res = await ApiClient.instance.call(
        'chat',
        auth: ApiClient.instance.hasSession,
        data: {
          'message': query,
          'lang': isHi ? 'hi' : 'en',
          'isHi': isHi,
          'mode': mode,
          'provider': provider,
          'hasImage': hasImage,
          if (voice) 'voice': true,
          if (planId != null && planId.isNotEmpty) 'planId': planId,
          if (imageBase64 != null && imageBase64.isNotEmpty)
            'imageBase64': imageBase64,
          if (images != null && images.isNotEmpty) 'images': images,
          if (activeCropId != null &&
              activeCropId.isNotEmpty &&
              activeCropId != 'all')
            'cropId': activeCropId,
          if (sessionId != null && sessionId.isNotEmpty) 'sessionId': sessionId,
          if (chatName != null && chatName.isNotEmpty) 'chatName': chatName,
          if (deepResearch) 'deepResearch': true,
          if (useLat != null) 'lat': useLat,
          if (useLon != null) 'lon': useLon,
          if (farm != null && farm.place.isNotEmpty) 'place': farm.place,
        },
      );

      final text = '${res['text'] ?? res['reply'] ?? ''}'.trim();
      final meta = res['meta'] is Map
          ? Map<String, dynamic>.from(res['meta'] as Map)
          : <String, dynamic>{};
      final source =
          '${meta['source'] ?? provider}'.trim().toLowerCase();
      final model = '${meta['model'] ?? ''}'.trim();

      if (text.isEmpty) {
        return _retry(isHi);
      }

      final savedImage = '${meta['imageUrl'] ?? ''}'.trim();
      final dosage = res['dosageHighlight']?.toString();
      final quick = (res['quickReplies'] as List?)
              ?.map((e) => '$e')
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const <String>[];

      return AgroAiResponse(
        text: text,
        dosageHighlight: (dosage == null || dosage.isEmpty) ? null : dosage,
        quickReplies: quick,
        category: source,
        provider: source,
        model: model.isEmpty ? null : model,
        blocked: meta['blocked'] == true,
        blockReason: meta['reason']?.toString(),
        imageUrl: savedImage.startsWith('http') ? savedImage : null,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('AI backend chat failed: $e');
      return _retry(isHi);
    }
  }

  static AgroAiResponse _retry(bool isHi) {
    return AgroAiResponse(
      text: isHi
          ? 'जवाब अभी नहीं आ पाया। एक बार फिर भेजें।'
          : 'The answer did not come through. Please send it once more.',
      category: 'retry',
      provider: 'local',
    );
  }
}
