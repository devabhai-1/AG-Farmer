import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Device text → speech for "बोलकर सुनो".
class SpeechSpeakService extends ChangeNotifier {
  SpeechSpeakService._();
  static final SpeechSpeakService instance = SpeechSpeakService._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _speaking = false;
  bool _queue = false;
  int _token = 0;
  String? _activeId;
  VoidCallback? _onDone;
  VoidCallback? _onStart;
  VoidCallback? _onCancel;

  /// Which article is being read, if the caller passed an id.
  String? get activeId => _activeId;

  bool get isSpeaking => _speaking;

  Future<bool> init() async {
    if (_ready) return true;
    try {
      _tts.setStartHandler(() {
        _speaking = true;
        _onStart?.call();
      });
      _tts.setCompletionHandler(() {
        if (_queue) return;
        _speaking = false;
        _activeId = null;
        _onDone?.call();
        notifyListeners();
      });
      _tts.setCancelHandler(() {
        if (_queue) return;
        _speaking = false;
        _activeId = null;
        _onCancel?.call();
        notifyListeners();
      });
      _tts.setErrorHandler((msg) {
        if (kDebugMode) debugPrint('TTS error: $msg');
        _speaking = false;
        _activeId = null;
        _queue = false;
        _onCancel?.call();
        notifyListeners();
      });

      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      try {
        await _tts.setSharedInstance(true);
      } catch (_) {}

      _ready = true;
    } catch (e) {
      if (kDebugMode) debugPrint('TTS init failed: $e');
      _ready = false;
    }
    return _ready;
  }

  void bindHandlers({
    VoidCallback? onStart,
    VoidCallback? onDone,
    VoidCallback? onCancel,
  }) {
    _onStart = onStart;
    _onDone = onDone;
    _onCancel = onCancel;
  }

  Future<void> speak(
    String text, {
    required bool hindi,
  }) async {
    final clean = _cleanForSpeech(text);
    if (clean.isEmpty) return;

    final ok = await init();
    if (!ok) {
      throw StateError('tts_unavailable');
    }

    await stop();
    await _setLanguage(hindi);

    _speaking = true;
    _activeId = null;
    notifyListeners();
    await _tts.speak(clean);
  }

  /// Natural neural-style TTS for live / video answers (device voice).
  Future<void> speakNeural(
    String text, {
    required bool hindi,
  }) =>
      speak(text, hindi: hindi);

  /// Read a full article in pieces so the phone voice does not cut it off.
  Future<void> speakArticle(
    String text, {
    required bool hindi,
    String? id,
    String? postId,
    String? cropId,
  }) async {
    final clean = _cleanForSpeech(text, maxChars: null);
    if (clean.isEmpty) return;
    final ok = await init();
    if (!ok) throw StateError('tts_unavailable');

    final token = ++_token;
    _queue = true;
    try {
      await _tts.stop();
    } catch (_) {}
    if (token != _token) return;
    await _setLanguage(hindi);
    _speaking = true;
    _activeId = id;
    notifyListeners();

    final parts = _chunks(clean);
    try {
      for (final part in parts) {
        if (token != _token) return;
        await _tts.speak(part);
      }
    } finally {
      if (token == _token) {
        _queue = false;
        _speaking = false;
        _activeId = null;
        notifyListeners();
      }
    }
  }

  List<String> _chunks(String text, [int size = 1500]) {
    if (text.length <= size) return [text];
    final parts = <String>[];
    var i = 0;
    while (i < text.length) {
      var end = i + size;
      if (end < text.length) {
        final slice = text.substring(i, end);
        final hindiStop = slice.lastIndexOf('।');
        final dot = slice.lastIndexOf('. ');
        final cut = hindiStop > 400
            ? hindiStop + 1
            : (dot > 400 ? dot + 1 : slice.length);
        end = i + cut;
      } else {
        end = text.length;
      }
      final part = text.substring(i, end).trim();
      if (part.isNotEmpty) parts.add(part);
      i = end;
    }
    return parts;
  }

  Future<void> _setLanguage(bool hindi) async {
    final candidates = hindi
        ? ['hi-IN', 'hi_IN', 'hin', 'hi']
        : ['en-IN', 'en_IN', 'en-US', 'en'];
    try {
      final langs = await _tts.getLanguages;
      if (langs is List && langs.isNotEmpty) {
        for (final want in candidates) {
          final w = want.toLowerCase().replaceAll('_', '-');
          for (final raw in langs) {
            final id = '$raw'.toLowerCase().replaceAll('_', '-');
            if (id == w || id.startsWith('$w-') || id.startsWith(w.split('-').first)) {
              await _tts.setLanguage('$raw');
              return;
            }
          }
        }
      }
    } catch (_) {}
    await _tts.setLanguage(hindi ? 'hi-IN' : 'en-IN');
  }

  Future<void> stop() async {
    _token++;
    _queue = false;
    _speaking = false;
    _activeId = null;
    try {
      await _tts.stop();
    } catch (_) {}
    notifyListeners();
  }

  /// Strip markdown / emoji noise so TTS sounds natural.
  String _cleanForSpeech(String raw, {int? maxChars = 2500}) {
    var t = raw
        .replaceAll(RegExp(r'[*_`#~>]+'), ' ')
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\[[^\]]*\]\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'https?://\S+'), ' ')
        .replaceAll(RegExp(r'[🙏🔊✅❌⚠️•·]+'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    if (maxChars != null && t.length > maxChars) {
      t = '${t.substring(0, maxChars)}…';
    }
    return t;
  }
}

final speechSpeakService = SpeechSpeakService.instance;
