import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/admin_live_sync.dart';
import '../services/agro_ai_backend.dart';
import '../services/agro_scope.dart';
import '../services/page_analytics.dart';
import '../services/app_services.dart';
import '../services/live_voice_gate.dart';
import '../services/accurate_listen_service.dart';
import '../services/speech_listen_service.dart';
import '../services/speech_speak_service.dart';
import '../services/video_jpeg.dart';
import '../services/weather_service.dart';
import '../widgets/live_studio.dart';

/// Treatment video without Gemini Live.
/// Camera stays on the phone. One still + spoken question → same cheap
/// chat model → free on-device TTS.
class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({
    super.key,
    this.cropId,
    this.mode = 'chat',
    this.sessionId,
    this.isHi = true,
    this.onLine,
    this.recent = const [],
  });

  final String? cropId;
  final String mode;
  final String? sessionId;
  final bool isHi;
  final void Function(String role, String text)? onLine;
  final List<Map<String, String>> recent;

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> with PageHit {
  @override
  String get analyticsPage => 'video_call';
  @override
  String? get analyticsExtra => widget.cropId;
  CameraController? _camera;
  Uint8List? _latestJpeg;
  String _status = 'connecting';
  String? _error;
  bool _closed = false;
  bool _encoding = false;
  int _turn = 0;
  Completer<String?>? _hearDone;
  final ScrollController _scroll = ScrollController();
  final List<({String role, String text, bool typing})> _lines = [];
  final List<Uint8List> _shots = [];
  DateTime? _lastShotAt;
  double? _lat;
  double? _lon;

  static const _shotGap = Duration(milliseconds: 2500);

  int get _maxShots =>
      chatLimitsService.videoShotsFor(profileService.plan).clamp(1, 12);

  String get _greeting => widget.isHi
      ? 'राम-राम भाई, फसल की तरफ कैमरा रखो और बोलो क्या दिख रहा है।'
      : 'Ram-ram. Point the camera at the crop and tell me what you see.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _closed = true;
    _turn++;
    final hear = _hearDone;
    _hearDone = null;
    if (hear != null && !hear.isCompleted) hear.complete(null);
    liveVoiceGate.stop();
    accurateListen.cancel();
    speechListenService.cancel();
    speechSpeakService.stop();
    _scroll.dispose();
    final cam = _camera;
    _camera = null;
    if (cam != null) unawaited(_releaseCamera(cam));
    super.dispose();
  }

  Future<void> _releaseCamera(CameraController cam) async {
    try {
      if (cam.value.isStreamingImages) await cam.stopImageStream();
    } catch (_) {}
    try {
      await cam.dispose();
    } catch (_) {}
  }

  CameraDescription _mainBack(List<CameraDescription> cameras) {
    final backs = cameras
        .where((cam) => cam.lensDirection == CameraLensDirection.back)
        .toList();
    final pool = backs.isEmpty ? cameras : backs;
    for (final cam in pool) {
      if (cam.name == '0') return cam;
    }
    return pool.first;
  }

  Future<void> _openCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw StateError('no_camera');
    final controller = CameraController(
      _mainBack(cameras),
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller.initialize();
    if (!mounted || _closed) {
      await _releaseCamera(controller);
      return;
    }
    setState(() => _camera = controller);
    unawaited(WeatherService.fixNow().then((geo) {
      if (geo == null || _closed) return;
      _lat = geo.lat;
      _lon = geo.lon;
    }));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted || _closed || _camera != controller) return;
    try {
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } catch (_) {}
    if (!controller.value.isStreamingImages) {
      await controller.startImageStream(_onCameraImage);
    }
  }

  Widget _preview(CameraController cam, BoxConstraints constraints) {
    final sensorRatio = cam.value.aspectRatio;
    if (!sensorRatio.isFinite || sensorRatio <= 0) return CameraPreview(cam);
    final orientation =
        cam.value.lockedCaptureOrientation ?? cam.value.deviceOrientation;
    final landscape =
        orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight;
    final previewRatio = landscape ? sensorRatio : 1 / sensorRatio;
    final w = constraints.maxWidth;
    final h = w / previewRatio;
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(width: w, height: h, child: CameraPreview(cam)),
      ),
    );
  }

  void _onCameraImage(CameraImage image) {
    if (_closed || _encoding) return;
    final turns = _camera?.description.sensorOrientation ?? 90;
    final frame = CameraFrame.copy(
      image,
      turns: turns,
      maxSide: 512,
      quality: 55,
    );
    _encoding = true;
    unawaited(
      encodeFrameJpeg(frame).then((jpeg) {
        _encoding = false;
        if (_closed || jpeg == null || jpeg.isEmpty) return;
        _latestJpeg = jpeg;
        final now = DateTime.now();
        if (_lastShotAt != null && now.difference(_lastShotAt!) < _shotGap) {
          return;
        }
        _lastShotAt = now;
        _shots.add(jpeg);
        while (_shots.length > _maxShots) {
          _shots.removeAt(0);
        }
      }).catchError((_) {
        _encoding = false;
      }),
    );
  }

  void _finish(String? result) {
    if (_closed) return;
    _closed = true;
    _turn++;
    final hear = _hearDone;
    _hearDone = null;
    if (hear != null && !hear.isCompleted) hear.complete(null);
    unawaited(liveVoiceGate.stop());
    unawaited(accurateListen.cancel());
    unawaited(speechListenService.cancel());
    unawaited(speechSpeakService.stop());
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  void _retry() {
    if (_closed || !mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _status = 'connecting';
      _error = null;
    });
    _start();
  }

  Future<void> _start() async {
    await AdminLiveSync.instance.pull();
    if (!mounted || _closed) return;
    final s = AgroScope.of(context).s;
    try {
      if (_camera == null) await _openCamera();
      if (!mounted || _closed) return;
      setState(() => _status = 'listening');
      unawaited(_run());
    } catch (e) {
      final msg = e.toString();
      if (!mounted || _closed) return;
      final denied =
          msg.contains('CameraAccessDenied') ||
          msg.contains('AudioAccessDenied') ||
          msg.contains('NotAllowedError') ||
          msg.contains('Permission');
      setState(() {
        _status = 'error';
        _error = denied
            ? (s.isHi
                  ? 'कैमरा और माइक की अनुमति दें, फिर फिर कोशिश करें।'
                  : 'Allow camera and microphone permission, then try again.')
            : msg.contains('no_camera') || msg.contains('Camera')
            ? (s.isHi ? 'कैमरा नहीं खुल पाया।' : 'Camera did not open.')
            : (s.isHi
                  ? 'वीडियो कॉल शुरू नहीं हुई।'
                  : 'Video call did not start.');
      });
    }
  }

  void _keepLatestVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_closed || !_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if ((_scroll.offset - target).abs() < 2) return;
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  void _setUserLine(String text, {required bool typing}) {
    if (!mounted || _closed) return;
    final said = text.trim();
    if (said.isEmpty) return;
    setState(() {
      final open = _lines.lastIndexWhere(
        (line) => line.role == 'user' && line.typing,
      );
      if (open >= 0) {
        final prev = _lines[open].text.trim();
        final keep = said.length >= prev.length ? said : prev;
        _lines[open] = (role: 'user', text: keep, typing: typing);
      } else {
        _lines.add((role: 'user', text: said, typing: typing));
      }
    });
    _keepLatestVisible();
  }

  void _finalizeUserTyping() {
    if (!mounted || _closed) return;
    final open = _lines.lastIndexWhere(
      (line) => line.role == 'user' && line.typing,
    );
    if (open < 0) return;
    setState(() {
      _lines[open] = (
        role: 'user',
        text: _lines[open].text,
        typing: false,
      );
    });
  }

  void _addAssistant(String text) {
    if (!mounted || _closed) return;
    final line = text.trim();
    if (line.isEmpty) return;
    setState(() {
      _lines.add((role: 'assistant', text: line, typing: false));
    });
    _keepLatestVisible();
  }

  Future<void> _run() async {
    unawaited(speechListenService.init());
    _addAssistant(_greeting);
    await _speak(_greeting);
    if (!_closed) {
      try {
        await speechSpeakService.stop();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 550));
    }
    while (!_closed && mounted) {
      final said = await _capture();
      if (_closed || !mounted) return;
      if (said == null || said.isEmpty) {
        _finalizeUserTyping();
        continue;
      }
      _setUserLine(said, typing: false);
      widget.onLine?.call('user', said);
      if (mounted) setState(() => _status = 'thinking');
      String? reply;
      try {
        final bundled = _shots.isNotEmpty
            ? _shots
            : (_latestJpeg == null || _latestJpeg!.isEmpty
                ? const <Uint8List>[]
                : <Uint8List>[_latestJpeg!]);
        final encoded = [
          for (final shot in bundled) base64Encode(shot),
        ];
        final ai = await AgroAiBackend.ask(
          said,
          activeCropId: widget.cropId,
          isHi: widget.isHi,
          mode: widget.mode,
          sessionId: widget.sessionId,
          provider: 'openai',
          voice: true,
          hasImage: encoded.isNotEmpty,
          imageBase64: encoded.isEmpty ? null : encoded.last,
          images: encoded,
          lat: _lat,
          lon: _lon,
          planId: profileService.planId,
        );
        if (ai.blocked) {
          final reason = ai.blockReason ?? '';
          if (reason.contains('upgrade') || reason.contains('plan')) {
            _finish('upgrade');
            return;
          }
          if (reason.contains('credit') || reason.contains('limit')) {
            _finish('credit');
            return;
          }
        }
        reply = ai.text.trim();
      } catch (e) {
        debugPrint('video ask failed: $e');
      }
      if (_closed || !mounted) return;
      if (reply == null || reply.isEmpty) {
        reply = widget.isHi
            ? 'जवाब नहीं आ पाया। फिर बोलें।'
            : 'No answer came through. Speak again.';
      } else {
        widget.onLine?.call('assistant', reply);
      }
      _addAssistant(reply);
      await _speak(reply);
      if (!_closed) {
        try {
          await speechSpeakService.stop();
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 550));
      }
    }
  }

  Future<void> _speak(String text) async {
    if (_closed || !mounted || text.trim().isEmpty) return;
    await liveVoiceGate.stop();
    await accurateListen.cancel();
    await speechListenService.cancel();
    if (mounted) setState(() => _status = 'speaking');
    try {
      await speechSpeakService.speakNeural(text, hindi: widget.isHi);
    } catch (_) {}
    if (!_closed && mounted && _status == 'speaking') {
      setState(() => _status = 'listening');
    }
  }

  Future<String?> _capture() async {
    if (_closed || !mounted) return null;
    final token = ++_turn;
    if (mounted) {
      setState(() {
        _status = 'listening';
        _error = null;
      });
    }
    try {
      final said = await accurateListen.listenUntilSilence(
        hindi: widget.isHi,
        besideCamera: true,
        cancelled: () => _closed || token != _turn,
      );
      if (_closed || token != _turn) return null;
      final text = (said ?? '').trim();
      if (text.isEmpty) return null;
      _setUserLine(text, typing: false);
      return text;
    } catch (e) {
      if (_closed || token != _turn) return null;
      _showMicError(e);
      return null;
    }
  }

  void _showMicError(Object e) {
    if (!mounted || _closed) return;
    setState(() {
      _status = 'error';
      _error = widget.isHi
          ? 'बोलना टाइप नहीं हो पाया। फिर कोशिश करें।'
          : 'Could not type what you said. Try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final cam = _camera;
    const colors = LiveStudioColors.video;
    final isError = _status == 'error';
    final live = !isError && _status != 'connecting';
    final statusText =
        _error ??
        (isError
            ? (s.isHi
                  ? 'वीडियो कॉल नहीं जुड़ी। कैमरा और माइक की अनुमति देखकर फिर कोशिश करें।'
                  : 'The video call did not connect. Check camera and mic permission, then try again.')
            : _status == 'speaking'
            ? (s.isHi ? 'जवाब बोल रहा हूँ।' : 'Speaking the answer.')
            : _status == 'thinking'
            ? (s.isHi ? 'सोच रहा हूँ...' : 'Thinking...')
            : _status == 'writing'
            ? (s.isHi
                  ? 'सुन रहा हूँ। सोचकर बोलिए।'
                  : 'Listening. Take your time.')
            : _status == 'listening'
            ? (s.isHi
                  ? 'पौधा कैमरे के सामने रखो और बोलो।'
                  : 'Hold the plant in front of the camera and speak.')
            : (s.isHi ? 'कैमरा खुल रहा है।' : 'Opening the camera.'));
    return Scaffold(
      backgroundColor: const Color(0xFF021018),
      body: LiveStudioBackdrop(
        colors: colors,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Column(
              children: [
                LiveStudioHeader(
                  eyebrow: 'VIDEO',
                  title: s.isHi ? 'इलाज वीडियो' : 'Treatment video',
                  status: statusText,
                  colors: colors,
                  onClose: () => _finish(null),
                  live: live,
                  error: isError,
                ),
                Expanded(
                  flex: 3,
                  child: LiveCameraFrame(
                    colors: colors,
                    live: live,
                    caption: live
                        ? (s.isHi ? 'फसल कैमरे में रखें' : 'Keep the crop in frame')
                        : null,
                    child: ColoredBox(
                      color: Colors.black,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (cam != null && cam.value.isInitialized) {
                            return _preview(cam, constraints);
                          }
                          if (isError) {
                            return const Center(
                              child: Icon(
                                Icons.videocam_off_rounded,
                                color: Colors.white54,
                                size: 56,
                              ),
                            );
                          }
                          return Center(
                            child: LiveOrb(
                              status: 'connecting',
                              colors: colors,
                              size: 112,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  flex: 2,
                  child: LiveGlassPanel(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                    child: Column(
                      children: [
                        Expanded(
                          child: _lines.isEmpty
                              ? Center(
                                  child: Text(
                                    s.isHi
                                        ? 'यहाँ बोला और जवाब दिखेगा।'
                                        : 'Spoken words and answers appear here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.45),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scroll,
                                  padding: const EdgeInsets.only(bottom: 8),
                                  itemCount: _lines.length,
                                  itemBuilder: (context, i) {
                                    final line = _lines[i];
                                    return LiveBubble(
                                      mine: line.role == 'user',
                                      text: line.text,
                                      typing: line.typing,
                                      colors: colors,
                                    );
                                  },
                                ),
                        ),
                        LiveDock(
                          endLabel: s.voiceLiveEndCall,
                          onEnd: () => _finish(null),
                          colors: colors,
                          error: isError,
                          retryLabel: s.isHi ? 'फिर कोशिश करें' : 'Try again',
                          onRetry: isError ? _retry : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
