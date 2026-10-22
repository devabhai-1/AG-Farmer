import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Device speech → text (Hindi + English).
/// Indian dialects (RJ/MP/Gujarat belt) are captured best with hi-IN;
/// a light normalizer maps common dialect words into Hindi.
class SpeechListenService {
  SpeechListenService._();
  static final SpeechListenService instance = SpeechListenService._();

  final SpeechToText _speech = SpeechToText();
  bool _ready = false;
  List<LocaleName> _locales = const [];
  void Function(String status)? onStatusChange;

  bool get isAvailable => _ready;
  bool get isListening => _speech.isListening;

  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _speech.initialize(
        onError: (e) {
          if (kDebugMode) debugPrint('STT error: ${e.errorMsg}');
        },
        onStatus: (s) {
          if (kDebugMode) debugPrint('STT status: $s');
          onStatusChange?.call(s);
        },
      );
      if (_ready) {
        _locales = await _speech.locales();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('STT init failed: $e');
      _ready = false;
    }
    return _ready;
  }

  /// Prefer Hindi for Indian dialects; English when asked.
  String resolveLocaleId({required bool preferHindi}) {
    if (_locales.isEmpty) {
      return preferHindi ? 'hi_IN' : 'en_IN';
    }

    String? pick(List<String> candidates) {
      for (final c in candidates) {
        for (final loc in _locales) {
          final id = loc.localeId.replaceAll('-', '_');
          final want = c.replaceAll('-', '_');
          if (id.toLowerCase() == want.toLowerCase() ||
              id.toLowerCase().startsWith('${want.split('_').first.toLowerCase()}_')) {
            return loc.localeId;
          }
        }
      }
      return null;
    }

    if (preferHindi) {
      return pick(const [
            'hi_IN',
            'hi-IN',
            'hi',
            'mr_IN', // Marathi often helps farm speech → still normalize to Hindi words
            'gu_IN',
          ]) ??
          _locales.first.localeId;
    }
    return pick(const ['en_IN', 'en-IN', 'en_US', 'en-US', 'en']) ??
        _locales.first.localeId;
  }

  Future<void> start({
    required void Function(String text, bool finalResult) onResult,
    required bool preferHindi,
    void Function(double level)? onSoundLevel,
    void Function(String text)? onPartial,
    Duration listenFor = const Duration(seconds: 45),
    Duration pauseFor = const Duration(seconds: 3),
    bool haptic = true,
    bool cancelOnError = true,
  }) async {
    final ok = await init();
    if (!ok) {
      throw StateError('speech_unavailable');
    }
    final localeId = resolveLocaleId(preferHindi: preferHindi);
    await _speech.listen(
      onResult: (result) {
        final raw = result.recognizedWords.trim();
        if (raw.isEmpty) return;
        final text = preferHindi ? normalizeToHindi(raw) : raw;
        if (!result.finalResult) onPartial?.call(text);
        onResult(text, result.finalResult);
      },
      onSoundLevelChange: onSoundLevel,
      listenFor: listenFor,
      pauseFor: pauseFor,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: cancelOnError,
        partialResults: true,
        autoPunctuation: true,
        enableHapticFeedback: haptic,
        localeId: localeId,
      ),
    );
  }

  Future<void> stop() => _speech.stop();
  Future<void> cancel() => _speech.cancel();

  /// Light dialect → Hindi cleanup for RJ / MP / Gujarat / Marathi farm speech.
  static String normalizeToHindi(String input) {
    var t = input.trim();
    if (t.isEmpty) return t;

    // Phrase-level (longer first)
    const phrases = <String, String>{
      'काई करूं': 'क्या करूँ',
      'काई करुं': 'क्या करूँ',
      'केई करूं': 'क्या करूँ',
      'थारो खेत': 'आपका खेत',
      'थारी फसल': 'आपकी फसल',
      'म्हारो खेत': 'मेरा खेत',
      'म्हारी फसल': 'मेरी फसल',
      'पाणी लावो': 'पानी दो',
      'पाणी देवो': 'पानी दो',
      'बीमारी लाग गी': 'बीमारी लग गई',
      'पीलो पड़ग्यो': 'पीला पड़ गया',
      'पीलो पड्यो': 'पीला पड़ गया',
      'कीड़ो लाग्यो': 'कीड़ा लगा',
      'कीडा लाग्यो': 'कीड़ा लगा',
      'दवाई बताओ': 'दवा बताओ',
      'दवाई बतावो': 'दवा बताओ',
      'स्प्रे करूं': 'स्प्रे करूँ',
      'काय करायचं': 'क्या करना है',
      'काय करायचे': 'क्या करना है',
      'पाणी द्यायचं': 'पानी देना है',
      'शुं करवुं': 'क्या करना है',
      'પાણી': 'पानी',
    };

    for (final e in phrases.entries) {
      t = t.replaceAll(e.key, e.value);
    }

    // Word-level
    const words = <String, String>{
      'काई': 'क्या',
      'केई': 'क्या',
      'काय': 'क्या',
      'शुं': 'क्या',
      'थारो': 'आपका',
      'थारी': 'आपकी',
      'थांरो': 'आपका',
      'म्हारो': 'मेरा',
      'म्हारी': 'मेरी',
      'आपो': 'आप',
      'तमे': 'आप',
      'तुम्ही': 'आप',
      'पाणी': 'पानी',
      'पाण्य': 'पानी',
      'दवाई': 'दवा',
      'औषध': 'दवा',
      'औषधी': 'दवा',
      'खत': 'खाद',
      'कीड़ो': 'कीड़ा',
      'कीडा': 'कीड़ा',
      'कीड': 'कीड़ा',
      'पीलो': 'पीला',
      'पिलो': 'पीला',
      'हरियो': 'हरा',
      'लावो': 'दो',
      'देवो': 'दो',
      'बतावो': 'बताओ',
      'करूं': 'करूँ',
      'करुं': 'करूँ',
      'लाग्यो': 'लगा',
      'लाग गी': 'लग गई',
      'पड़ग्यो': 'पड़ गया',
      'पड्यो': 'पड़ गया',
      'आजकल': 'आजकल',
      'अठे': 'यहाँ',
      'उठे': 'वहाँ',
      'केवाई': 'कैसे',
      'कित्ता': 'कितना',
      'कित्तो': 'कितना',
    };

    final parts = t.split(RegExp(r'\s+'));
    final out = parts.map((w) {
      final clean = w.replaceAll(RegExp(r'[^\u0900-\u097F\w]'), '');
      final punct = w.substring(clean.length);
      if (words.containsKey(clean)) return '${words[clean]}$punct';
      // case-insensitive latin leftovers stay
      return w;
    }).join(' ');

    return out.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

final speechListenService = SpeechListenService.instance;
