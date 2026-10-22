import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/agro_scope.dart';
import '../services/page_analytics.dart';
import '../services/screen_pack.dart';
import '../services/live_voice_gate.dart';
import '../services/accurate_listen_service.dart';
import '../services/speech_listen_service.dart';
import '../services/speech_speak_service.dart';
import '../widgets/ai_report_sheet.dart';
import '../widgets/live_studio.dart';

/// AG Live, one turn at a time:
/// greet → wait for voice → same chat speech-to-text → GPT → speak.
class VoiceLiveScreen extends StatefulWidget {
  const VoiceLiveScreen({
    super.key,
    required this.onAsk,
    this.isHi = true,
    this.initialLines = const [],
  });

  final Future<String?> Function(String text) onAsk;
  final bool isHi;
  final List<({String role, String text})> initialLines;

  @override
  State<VoiceLiveScreen> createState() => _VoiceLiveScreenState();
}

class _VoiceLiveScreenState extends State<VoiceLiveScreen> with PageHit {
  @override
  String get analyticsPage => 'ag_live';
  static const _greetHi =
      'राम-राम किसान भाई, बताओ क्या सहायता चाहिए। यहाँ मुझे बोलकर बताएं।';
  static const _greetEn = 'Ram-ram. Tell me what help you need. Say it here.';

  String _status = 'connecting';
  String? _error;
  bool _alive = true;
  int _turn = 0;
  int _replayGen = 0;
  int? _playingLine;
  bool _holdMic = false;
  bool _textMode = false;
  String _heard = '';
  int _textGen = 0;
  Completer<String?>? _hearDone;
  final List<({String role, String text, bool typing})> _lines = [];
  final ScrollController _scroll = ScrollController();

  String get _greeting => widget.isHi ? _greetHi : _greetEn;

  @override
  void initState() {
    super.initState();
    for (final line in widget.initialLines) {
      final text = line.text.trim();
      if (text.isEmpty) continue;
      _lines.add((role: line.role, text: text, typing: false));
    }
    speechSpeakService.addListener(_onSpeakTick);
    screenPack.addListener(_onScreens);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keepLatestVisible();
      _run();
    });
  }

  void _onSpeakTick() {
    if (mounted) setState(() {});
  }

  void _onScreens() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _alive = false;
    _turn++;
    speechSpeakService.removeListener(_onSpeakTick);
    speechListenService.onStatusChange = null;
    liveVoiceGate.stop();
    accurateListen.cancel();
    speechListenService.cancel();
    speechSpeakService.stop();
    screenPack.removeListener(_onScreens);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    unawaited(speechListenService.init());
    final alreadyGreeted = _lines.any((line) => line.role == 'assistant');
    if (!alreadyGreeted) {
      await _speak(_greeting);
    }
    if (_alive) {
      try {
        await speechSpeakService.stop();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }
    while (_alive && mounted) {
      final said = await _capture();
      if (!_alive || !mounted) return;
      if (said == null || said.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        continue;
      }
      final thinkAt = _writeActivity(
        widget.isHi ? 'सोच रहा हूँ...' : 'Thinking...',
        status: 'thinking',
      );
      String? reply;
      try {
        reply = await widget.onAsk(said);
      } catch (e) {
        debugPrint('AG Live chat failed: $e');
      }
      if (!_alive || !mounted) return;
      if (reply == null || reply.isEmpty) {
        _writeActivity(
          widget.isHi
              ? 'जवाब नहीं आ पाया। फिर बोलें।'
              : 'No answer came through. Speak again.',
          status: 'listening',
          at: thinkAt,
          typing: false,
        );
        continue;
      }
      await _speak(reply, at: thinkAt);
      if (_alive) {
        try {
          await speechSpeakService.stop();
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
    }
  }

  Future<void> _untilMicFree() async {
    var held = false;
    while (_alive && mounted && _holdMic) {
      held = true;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    if (held && _alive) {
      await Future<void>.delayed(const Duration(milliseconds: 320));
    }
  }

  Future<void> _abortListen() async {
    _turn++;
    final hear = _hearDone;
    _hearDone = null;
    if (hear != null && !hear.isCompleted) hear.complete(null);
    await liveVoiceGate.stop();
    await accurateListen.cancel();
    await speechListenService.cancel();
  }

  Future<String?> _capture() async {
    await _untilMicFree();
    if (!_alive || !mounted) return null;
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
        silence: const Duration(seconds: 7),
        cancelled: () => !_alive || token != _turn || _holdMic,
        onPartial: (text) {
          if (!_alive || token != _turn || _holdMic) return;
          _setUserLine(text, typing: true);
          if (mounted && _status == 'listening') {
            setState(() => _status = 'writing');
          }
        },
      );
      if (!_alive || token != _turn || _holdMic) return null;
      final text = (said ?? '').trim();
      if (text.isEmpty) return null;
      _setUserLine(text, typing: false);
      return text;
    } catch (e) {
      if (!_alive || token != _turn) return null;
      _showMicError(e);
      await _untilReady();
      return null;
    }
  }

  Future<void> _untilReady() async {
    while (_alive && mounted && _status == 'error') {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  void _showMicError(Object e) {
    if (!mounted || !_alive) return;
    final missing = e.toString().contains('speech_unavailable');
    setState(() {
      _status = 'error';
      _error = missing
          ? (widget.isHi
                ? 'माइक की अनुमति दें, फिर फिर कोशिश करें।'
                : 'Allow microphone permission, then try again.')
          : (widget.isHi
                ? 'बोलना टाइप नहीं हो पाया। फिर कोशिश करें।'
                : 'Could not type what you said. Try again.');
    });
  }

  int _writeActivity(
    String text, {
    required String status,
    int? at,
    bool typing = true,
  }) {
    if (!mounted || !_alive) return at ?? -1;
    var index = at ?? -1;
    setState(() {
      _status = status;
      _error = null;
      final line = (role: 'assistant', text: text, typing: typing);
      if (index >= 0 && index < _lines.length) {
        _lines[index] = line;
      } else {
        _lines.add(line);
        index = _lines.length - 1;
      }
    });
    _keepLatestVisible();
    return index;
  }

  Future<void> _speak(String full, {int? at}) async {
    if (!_alive || !mounted || full.trim().isEmpty) return;
    await liveVoiceGate.stop();
    await accurateListen.cancel();
    await speechListenService.cancel();
    final index = _writeActivity(
      full,
      status: 'speaking',
      at: at,
      typing: true,
    );
    final spoken = speechSpeakService.speakNeural(full, hindi: widget.isHi);
    try {
      await spoken;
    } catch (_) {
      if (mounted && _alive) {
        setState(() {
          _error = widget.isHi
              ? 'जवाब लिख दिया है। आवाज़ अभी नहीं बनी।'
              : 'The answer is written. The voice did not play.';
        });
      }
    }
    if (!mounted || !_alive) return;
    if (index < _lines.length) {
      setState(() {
        _lines[index] = (role: 'assistant', text: full, typing: false);
        if (_status == 'speaking') _status = 'listening';
      });
    }
  }

  bool _canPlay(({String role, String text, bool typing}) line) {
    final text = line.text.trim();
    if (line.typing || text.isEmpty || _isWorkLine(text)) return false;
    return true;
  }

  Future<void> _replay(int index) async {
    final line = _lines[index];
    if (!_canPlay(line)) return;
    if (_playingLine == index && speechSpeakService.isSpeaking) {
      await _stopVoice();
      return;
    }
    HapticFeedback.selectionClick();
    final gen = ++_replayGen;
    setState(() {
      _playingLine = index;
      _holdMic = true;
    });
    await _abortListen();
    try {
      await speechSpeakService.speakNeural(line.text, hindi: widget.isHi);
    } catch (_) {
      if (mounted && _alive && gen == _replayGen) {
        setState(() {
          _error = widget.isHi
              ? 'यह लाइन अभी नहीं बोली जा सकी।'
              : 'This line could not be spoken.';
        });
      }
    } finally {
      if (gen == _replayGen) {
        _holdMic = false;
        if (mounted) {
          setState(() => _playingLine = null);
        } else {
          _playingLine = null;
        }
      }
    }
  }

  Future<void> _stopVoice() async {
    HapticFeedback.mediumImpact();
    _replayGen++;
    _holdMic = false;
    await speechSpeakService.stop();
    if (!mounted) return;
    setState(() {
      _playingLine = null;
      if (_status == 'speaking') _status = 'listening';
    });
  }

  void _setUserLine(String text, {required bool typing}) {
    if (!mounted || !_alive) return;
    final said = text.trim();
    if (said.isEmpty) return;
    setState(() {
      final lastIsUser = _lines.isNotEmpty && _lines.last.role == 'user';
      if (lastIsUser) {
        _lines[_lines.length - 1] = (role: 'user', text: said, typing: typing);
      } else {
        _lines.add((role: 'user', text: said, typing: typing));
      }
    });
    _keepLatestVisible();
  }

  List<Map<String, String>> _keptLines() {
    return _lines
        .map((line) => (role: line.role, text: line.text.trim()))
        .where((line) => line.text.isNotEmpty && !_isWorkLine(line.text))
        .map((line) => {'role': line.role, 'text': line.text})
        .toList();
  }

  Future<void> _setTextMode(bool on) async {
    if (on == _textMode) return;
    HapticFeedback.selectionClick();
    if (on) {
      final gen = ++_textGen;
      setState(() {
        _textMode = true;
        _heard = '';
        _holdMic = true;
      });
      try {
        await speechSpeakService.stop();
      } catch (_) {}
      await _abortListen();
      if (!mounted || !_alive || !_textMode || gen != _textGen) return;
      await _listenForText(gen);
      return;
    }
    _textGen++;
    setState(() {
      _textMode = false;
      _heard = '';
      _holdMic = false;
    });
    await accurateListen.cancel();
  }

  Future<void> _listenForText(int gen) async {
    if (!_alive || !mounted || !_textMode || gen != _textGen) return;
    try {
      final said = await accurateListen.listenUntilSilence(
        hindi: widget.isHi,
        silence: const Duration(seconds: 2),
        cancelled: () => !_alive || !_textMode || gen != _textGen,
        onPartial: (text) {
          if (!_alive || !_textMode || gen != _textGen || !mounted) return;
          setState(() => _heard = text.trim());
        },
      );
      if (!_alive || !mounted || !_textMode || gen != _textGen) return;
      final text = (said ?? _heard).trim();
      if (text.isEmpty) {
        await _listenForText(gen);
        return;
      }
      _alive = false;
      Navigator.of(context).pop({'mode': 'text', 'text': text});
    } catch (_) {
      if (!_alive || !mounted || !_textMode || gen != _textGen) return;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await _listenForText(gen);
    }
  }

  Future<void> _end() async {
    HapticFeedback.mediumImpact();
    _alive = false;
    _replayGen++;
    _holdMic = false;
    final hear = _hearDone;
    _hearDone = null;
    if (hear != null && !hear.isCompleted) hear.complete(null);
    _turn++;
    await liveVoiceGate.stop();
    await accurateListen.cancel();
    await speechListenService.cancel();
    await speechSpeakService.stop();
    if (!mounted) return;
    Navigator.of(context).pop(_keptLines());
  }

  void _keepLatestVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_alive || !_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if ((_scroll.offset - target).abs() < 2) return;
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  String _tx(String key, String fallback) =>
      screenPack.t(widget.isHi, 'live', key, fallback);

  bool _isWorkLine(String text) {
    final t = text.trim();
    return t == 'सोच रहा हूँ...' ||
        t == 'Thinking...' ||
        t == _tx('thinking', 'सोच रहा हूँ...');
  }

  String _statusLabel(dynamic s) {
    if (_holdMic && _playingLine != null && _status != 'speaking') {
      return _tx(
        'replay',
        widget.isHi
            ? 'यह लाइन फिर से बोल रहा हूँ।'
            : 'Playing this line again.',
      );
    }
    switch (_status) {
      case 'listening':
        return _tx(
          'listening',
          widget.isHi ? 'सुन रहा हूँ। बोलिए।' : 'Listening. Speak now.',
        );
      case 'writing':
        return _tx(
          'writing',
          widget.isHi
              ? 'सुन रहा हूँ। सोचकर बोलिए, मैं इंतज़ार करूँगा।'
              : 'Listening. Take your time. I will wait.',
        );
      case 'thinking':
        return _tx(
          'thinking',
          widget.isHi ? 'सोच रहा हूँ...' : 'Thinking...',
        );
      case 'speaking':
        return _tx('speaking', s.voiceLiveSpeaking as String);
      case 'error':
        return (_error ??
            _tx('unavailable', s.voiceLiveUnavailable as String));
      default:
        return _tx(
          'start',
          widget.isHi ? 'बोलना शुरू करें' : 'Start speaking',
        );
    }
  }

  Future<void> _reportCall(bool hi) async {
    var text = hi ? 'इस ऑडियो कॉल की AI सामग्री' : 'AI content in this audio call';
    for (final line in _lines.reversed) {
      if (line.role != 'user' && line.text.trim().isNotEmpty) {
        text = line.text;
        break;
      }
    }
    final messenger = ScaffoldMessenger.of(context);
    final s = AgroScope.of(context).s;
    final ok = await showAiContentReportSheet(
      context,
      messageId: 'voice_${DateTime.now().millisecondsSinceEpoch}',
      messageText: text,
      source: 'voice',
    );
    if (!ok || !mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(s.reportSuccess)));
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    const colors = LiveStudioColors.live;
    final live =
        _status == 'listening' ||
        _status == 'speaking' ||
        _status == 'thinking' ||
        _status == 'writing';
    final voiceOn = speechSpeakService.isSpeaking || _playingLine != null;
    final showOrb = _lines.length < 3 && _status != 'error';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _end();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF021018),
        body: LiveStudioBackdrop(
          colors: colors,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LiveStudioHeader(
                    eyebrow: _tx('eyebrow', 'LIVE'),
                    title: _tx('title', s.voiceModeLiveTitle),
                    status: _statusLabel(s),
                    colors: colors,
                    onClose: _end,
                    live: live && !_textMode,
                    error: _status == 'error',
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _textMode
                                    ? (widget.isHi
                                          ? 'आवाज़ से लिखो'
                                          : 'Voice to text')
                                    : 'AG Live',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              widget.isHi ? 'लिखो' : 'Type',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            Switch(
                              value: _textMode,
                              activeThumbColor: colors.accent,
                              onChanged: _setTextMode,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_textMode && _heard.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        _heard,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  if (_error != null && _status != 'error')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (showOrb)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Center(
                        child: LiveOrb(status: _status, colors: colors),
                      ),
                    ),
                  Expanded(
                    child: LiveGlassPanel(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                      child: _lines.isEmpty
                          ? Center(
                              child: Text(
                                _tx(
                                  'empty',
                                  widget.isHi
                                      ? 'माइक खुला है। फसल की बात बोलिए।'
                                      : 'Mic is open. Speak about the crop.',
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.48),
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
                                final play = _canPlay(line);
                                final playing =
                                    _playingLine == i &&
                                    speechSpeakService.isSpeaking;
                                return LiveBubble(
                                  mine: line.role == 'user',
                                  text: line.text,
                                  typing: line.typing,
                                  colors: colors,
                                  trailing: play
                                      ? IconButton(
                                          onPressed: playing
                                              ? _stopVoice
                                              : () => _replay(i),
                                          tooltip: playing
                                              ? (widget.isHi ? 'रोकें' : 'Stop')
                                              : (widget.isHi
                                                    ? 'फिर सुनें'
                                                    : 'Play again'),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 40,
                                            minHeight: 40,
                                          ),
                                          icon: Icon(
                                            playing
                                                ? Icons.stop_circle_rounded
                                                : Icons.volume_up_rounded,
                                            color: playing
                                                ? colors.accent
                                                : Colors.white70,
                                            size: 22,
                                          ),
                                        )
                                      : null,
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  LiveReportButton(
                    endLabel: s.voiceLiveEndCall,
                    onEnd: _end,
                    colors: colors,
                    reportLabel: s.reportAiButton,
                    onReport: () => _reportCall(s.isHi),
                    voiceOn: voiceOn,
                    onStop: voiceOn ? _stopVoice : null,
                    stopLabel: widget.isHi ? 'आवाज़ बंद' : 'Stop voice',
                    error: _status == 'error',
                    retryLabel: s.isHi ? 'फिर कोशिश करें' : 'Try again',
                    onRetry: () {
                      setState(() {
                        _status = 'listening';
                        _error = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
