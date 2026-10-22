import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart' as pcm;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class VoiceLiveWebrtcImpl {
  static WebSocketChannel? _socket;
  static final AudioRecorder _recorder = AudioRecorder();
  static StreamSubscription<Uint8List>? _micSub;
  static StreamSubscription<dynamic>? _socketSub;
  static bool _setupReady = false;
  static bool _micStarted = false;
  static bool _heardAudio = false;
  static bool _replyFinished = false;
  static bool _closing = false;
  static int _micGen = 0;
  static int _queuedSamples = 0;
  static DateTime? _playOrigin;
  static final List<String> _pending = [];
  static bool _playerReady = false;
  static Timer? _setupTimer;
  static Timer? _listenTimer;
  static void Function(String status)? _onStatus;
  static String _userBuf = '';
  static String _assistantBuf = '';
  static void Function(String role, String text)? _onTranscript;
  static DateTime? _lastSpeechAt;
  static bool _turnAudioOpen = false;
  static final List<Uint8List> _preRoll = [];
  static int _preRollBytes = 0;
  static bool _premium = false;
  static bool _video = false;
  static bool _videoGreeted = false;
  static bool _videoFallback = false;
  static int _videoFrames = 0;

  static bool get isSupported => true;

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
    await disconnect();
    _closing = false;
    _userBuf = '';
    _assistantBuf = '';
    _lastSpeechAt = null;
    _turnAudioOpen = false;
    _preRoll.clear();
    _preRollBytes = 0;
    _premium = premium;
    _video = video;
    _videoGreeted = false;
    _videoFallback = false;
    _videoFrames = 0;
    _onStatus = onStatus;
    _onTranscript = onTranscript;
    onStatus?.call('mic');

    if (!await _recorder.hasPermission()) {
      throw StateError('Permission denied');
    }

    try {
      await Helper.setSpeakerphoneOn(true);
    } catch (_) {}

    await _ensurePlayer();

    final uri = Uri.parse(wsUrl).replace(
      queryParameters: {
        ...Uri.parse(wsUrl).queryParameters,
        'access_token': accessToken,
      },
    );
    final socket = IOWebSocketChannel.connect(uri);
    _socket = socket;
    _setupReady = false;
    _pending.clear();

    _socketSub = socket.stream.listen(
      (raw) => _onMessage(raw),
      onError: (_) {
        if (!_closing) _onStatus?.call('error');
      },
      onDone: () {
        if (!_closing && !_heardAudio) _onStatus?.call('error');
      },
    );

    final maxOut = 180;
    socket.sink.add(jsonEncode({
      'setup': {
        'model': 'models/$model',
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'maxOutputTokens': maxOut,
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': voice},
            },
          },
        },
        'contextWindowCompression': {
          'triggerTokens': _premium ? 2000 : 1200,
          'slidingWindow': {'targetTokens': _premium ? 800 : 500},
        },
        'systemInstruction': {
          'parts': [
            {'text': instructions},
          ],
        },
        'realtimeInputConfig': {
          'activityHandling': 'NO_INTERRUPTION',
          'automaticActivityDetection': {
            'silenceDurationMs': 1100,
            'prefixPaddingMs': 400,
            'endOfSpeechSensitivity': 'END_SENSITIVITY_LOW',
          },
        },
        'inputAudioTranscription': {},
        'outputAudioTranscription': {},
      },
    }));

    _setupTimer?.cancel();
    _setupTimer = Timer(const Duration(seconds: 12), () {
      if (!_setupReady && !_closing) _onStatus?.call('error');
    });
    onStatus?.call('offer');
  }

  static Future<void> _ensurePlayer() async {
    if (_playerReady) return;
    await pcm.FlutterPcmSound.setLogLevel(pcm.LogLevel.none);
    await pcm.FlutterPcmSound.setup(
      sampleRate: 24000,
      channelCount: 1,
      iosAudioCategory: pcm.IosAudioCategory.playAndRecord,
    );
    _playerReady = true;
  }

  static Future<void> _startMic() async {
    if (_micStarted || _closing || _socket == null || !_replyFinished) return;
    _micStarted = true;
    try {
      await _openMic();
    } catch (_) {
      _micStarted = false;
      if (!_closing && _replyFinished) _onStatus?.call('error');
    }
    if (!_replyFinished) _micStarted = false;
  }

  static Future<void> _openMic() async {
    final gen = ++_micGen;
    try {
      await Helper.setSpeakerphoneOn(true);
    } catch (_) {}
    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
          speakerphone: true,
          manageBluetooth: false,
          muteAudio: false,
        ),
      ),
    );
    if (gen != _micGen || !_replyFinished || _closing) {
      try {
        await _recorder.stop();
      } catch (_) {}
      return;
    }
    _micSub = stream.listen((chunk) {
      if (chunk.isEmpty || _closing || !_replyFinished) return;
      if (_isSpeech(chunk)) {
        if (!_turnAudioOpen) {
          for (final prev in _preRoll) {
            _sendPcm(prev);
          }
          _preRoll.clear();
          _preRollBytes = 0;
        }
        _lastSpeechAt = DateTime.now();
        _turnAudioOpen = true;
        _sendPcm(chunk);
        return;
      }
      if (!_turnAudioOpen) {
        _preRoll.add(Uint8List.fromList(chunk));
        _preRollBytes += chunk.length;
        while (_preRollBytes > (_premium ? 9600 : 6400) && _preRoll.isNotEmpty) {
          _preRollBytes -= _preRoll.first.length;
          _preRoll.removeAt(0);
        }
        return;
      }
      _sendPcm(chunk);
      final last = _lastSpeechAt;
      if (last != null &&
          DateTime.now().difference(last) > const Duration(milliseconds: 1300)) {
        _turnAudioOpen = false;
        _preRoll.clear();
        _preRollBytes = 0;
      }
    });
    _onStatus?.call('listening');
  }

  static void sendVideoFrame(List<int> jpeg) {
    if (jpeg.isEmpty || _closing || !_setupReady || _socket == null) return;
    if (_video && !_videoGreeted) {
      _videoFrames += 1;
      if (_videoFrames < 2) return;
      _videoGreeted = true;
      _sendPlantLook(jpeg);
      return;
    }
    _send(jsonEncode({
      'realtimeInput': {
        'video': {
          'mimeType': 'image/jpeg',
          'data': base64Encode(jpeg),
        },
      },
    }));
  }

  static void _sendPlantLook(List<int> jpeg) {
    final socket = _socket;
    if (socket == null) return;
    socket.sink.add(jsonEncode({
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {
                'inlineData': {
                  'mimeType': 'image/jpeg',
                  'data': base64Encode(jpeg),
                },
              },
              {
                'text':
                    'Look at this plant photo. First say exactly: राम-राम किसान भाई. Then one short Hindi treatment.',
              },
            ],
          },
        ],
        'turnComplete': true,
      },
    }));
    _listenTimer?.cancel();
    _listenTimer = Timer(const Duration(seconds: 20), () {
      if (!_heardAudio && !_closing) _onStatus?.call('error');
    });
  }

  static void _sendPcm(Uint8List chunk) {
    _send(jsonEncode({
      'realtimeInput': {
        'audio': {
          'mimeType': 'audio/pcm;rate=16000',
          'data': base64Encode(chunk),
        },
      },
    }));
  }

  static bool _isSpeech(Uint8List chunk) {
    if (chunk.length < 320) return false;
    final data = ByteData.sublistView(chunk);
    final samples = data.lengthInBytes ~/ 2;
    var sum = 0;
    for (var i = 0; i < samples; i++) {
      sum += data.getInt16(i * 2, Endian.little).abs();
    }
    return samples > 0 && sum ~/ samples > 220;
  }

  static void _sendGreeting() {
    final socket = _socket;
    if (socket == null) return;
    socket.sink.add(jsonEncode({
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {
                'text':
                    'Say only these words: राम-राम किसान भाई',
              },
            ],
          },
        ],
        'turnComplete': true,
      },
    }));
    _listenTimer?.cancel();
    _listenTimer = Timer(const Duration(seconds: 15), () {
      if (!_heardAudio && !_closing) _onStatus?.call('error');
    });
  }

  static Future<void> _stopMic() async {
    _micGen++;
    _micStarted = false;
    final sub = _micSub;
    _micSub = null;
    try {
      await sub?.cancel();
    } catch (_) {}
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (_) {}
  }

  static void _onReplyAudio(int sampleCount) {
    _replyFinished = false;
    _listenTimer?.cancel();
    if (_playOrigin == null || _micStarted) {
      _playOrigin = DateTime.now();
      _queuedSamples = 0;
    }
    _queuedSamples += sampleCount;
    _turnAudioOpen = false;
    _preRoll.clear();
    _preRollBytes = 0;
    _stopMic();
  }

  static void _scheduleListenAfterPlayback() {
    _listenTimer?.cancel();
    if (!_replyFinished || _closing || !_heardAudio) return;
    final origin = _playOrigin ?? DateTime.now();
    final playMs = (_queuedSamples / 24000 * 1000).round();
    final end = origin.add(Duration(milliseconds: playMs + 900));
    var wait = end.difference(DateTime.now());
    if (wait.isNegative) wait = const Duration(milliseconds: 200);
    _listenTimer = Timer(wait, () {
      if (_replyFinished && !_closing && _heardAudio) _startMic();
    });
  }

  static void _send(String packet) {
    final socket = _socket;
    if (socket == null) return;
    if (!_setupReady) {
      if (_pending.length > 40) _pending.removeAt(0);
      _pending.add(packet);
      return;
    }
    socket.sink.add(packet);
  }

  static String? _decodeFrame(dynamic raw) {
    if (raw is String) return raw;
    if (raw is Uint8List) return utf8.decode(raw);
    if (raw is List<int>) return utf8.decode(raw);
    return null;
  }

  static void _onMessage(dynamic raw) {
    Map<String, dynamic> msg;
    try {
      final text = _decodeFrame(raw);
      if (text == null || text.trim().isEmpty) return;
      final decoded = jsonDecode(text);
      if (decoded is! Map) return;
      msg = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }

    if (msg.containsKey('setupComplete')) {
      _setupReady = true;
      _setupTimer?.cancel();
      final socket = _socket;
      if (socket != null) {
        for (final packet in _pending) {
          socket.sink.add(packet);
        }
      }
      _pending.clear();
      if (_video) {
        _listenTimer?.cancel();
        _listenTimer = Timer(const Duration(seconds: 8), () {
          if (!_videoGreeted && !_closing) {
            _videoGreeted = true;
            _sendGreeting();
          }
        });
        return;
      }
      _sendGreeting();
      return;
    }

    final err = msg['error'];
    if (err != null) {
      if (_video && !_heardAudio && !_videoFallback && !_closing) {
        _videoFallback = true;
        _videoGreeted = true;
        _sendGreeting();
        return;
      }
      _onStatus?.call('error');
      return;
    }

    final sc = msg['serverContent'];
    if (sc is! Map) return;
    final content = Map<String, dynamic>.from(sc);
    final turn = content['modelTurn'];
    if (turn is Map) {
      final parts = turn['parts'];
      if (parts is List) {
        for (final part in parts) {
          if (part is! Map) continue;
          final inline = part['inlineData'];
          if (inline is! Map) continue;
          final mime = '${inline['mimeType'] ?? ''}';
          final data = '${inline['data'] ?? ''}';
          if (!mime.contains('audio') || data.isEmpty) continue;
          final pcmBytes = base64Decode(data);
          if (pcmBytes.isEmpty) continue;
          _heardAudio = true;
          _onReplyAudio(pcmBytes.length ~/ 2);
          final copy = ByteData(pcmBytes.length);
          copy.buffer.asUint8List().setAll(0, pcmBytes);
          pcm.FlutterPcmSound.feed(pcm.PcmArrayInt16(bytes: copy));
          _onStatus?.call('speaking');
        }
      }
    }
    _noteTranscripts(content);
    if (content['turnComplete'] == true) {
      _flushTranscripts();
      if (_heardAudio) {
        _replyFinished = true;
        _scheduleListenAfterPlayback();
      }
    }
  }

  static void _emitLine(String role, String text) {
    final line = text.trim();
    if (line.isEmpty) return;
    _onTranscript?.call(role, line);
  }

  static void _flushTranscripts() {
    final user = _userBuf;
    final bot = _assistantBuf;
    _userBuf = '';
    _assistantBuf = '';
    _emitLine('user', user);
    _emitLine('assistant', bot);
  }

  static void _noteTranscripts(Map<String, dynamic> content) {
    final input = content['inputTranscription'];
    if (input is Map) {
      _userBuf += '${input['text'] ?? ''}';
    }
    final output = content['outputTranscription'];
    if (output is Map) {
      final piece = '${output['text'] ?? ''}';
      if (piece.isNotEmpty && _userBuf.trim().isNotEmpty) {
        final user = _userBuf;
        _userBuf = '';
        _emitLine('user', user);
      }
      _assistantBuf += piece;
    }
  }

  static Future<void> disconnect() async {
    _closing = true;
    _setupReady = false;
    _micStarted = false;
    _heardAudio = false;
    _replyFinished = false;
    _queuedSamples = 0;
    _playOrigin = null;
    _pending.clear();
    _setupTimer?.cancel();
    _listenTimer?.cancel();
    _flushTranscripts();
    _onStatus = null;
    _onTranscript = null;
    try {
      await _micSub?.cancel();
    } catch (_) {}
    _micSub = null;
    try {
      await _socketSub?.cancel();
    } catch (_) {}
    _socketSub = null;
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (_) {}
    try {
      await _socket?.sink.close();
    } catch (_) {}
    _socket = null;
    try {
      await pcm.FlutterPcmSound.release();
    } catch (_) {}
    _playerReady = false;
    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}
  }

  static void interrupt() {
    // Best-effort: drop pending playback buffer.
    _pending.clear();
    _queuedSamples = 0;
    _playOrigin = null;
  }
}
