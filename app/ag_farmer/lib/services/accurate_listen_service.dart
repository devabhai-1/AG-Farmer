import 'dart:async';

import 'package:flutter/foundation.dart';

import 'speech_listen_service.dart';

/// Device mic → on-device speech-to-text. Only the words go to the server.
class AccurateListenService {
  AccurateListenService._();
  static final AccurateListenService instance = AccurateListenService._();

  int _gen = 0;
  String _last = '';

  Future<void> cancel() async {
    _gen++;
    _last = '';
    await speechListenService.cancel();
  }

  /// Chat mic: start now, [finish] when the farmer taps stop.
  Future<void> beginManual({
    required bool hindi,
    void Function(double level)? onLevel,
  }) async {
    await cancel();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final gen = ++_gen;
    _last = '';
    final ok = await speechListenService.init();
    if (!ok) throw StateError('speech_unavailable');
    await speechListenService.start(
      preferHindi: hindi,
      listenFor: const Duration(seconds: 90),
      pauseFor: const Duration(seconds: 8),
      haptic: false,
      cancelOnError: false,
      onSoundLevel: onLevel,
      onResult: (text, isFinal) {
        if (gen != _gen) return;
        final t = text.trim();
        if (t.isNotEmpty) _last = t;
      },
    );
  }

  Future<String> finishManual({required bool hindi}) async {
    await speechListenService.stop();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final text = _last.trim();
    _last = '';
    return text;
  }

  /// Live / video: phone writes the words, then chat gets only that text.
  Future<String?> listenUntilSilence({
    required bool hindi,
    required bool Function() cancelled,
    void Function(double level)? onLevel,
    void Function(String text)? onPartial,
    bool besideCamera = false,
    Duration maxFor = const Duration(seconds: 45),
    Duration silence = const Duration(milliseconds: 1800),
  }) async {
    await cancel();
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final gen = ++_gen;
    _last = '';
    if (cancelled()) return null;

    final ok = await speechListenService.init();
    if (!ok) throw StateError('speech_unavailable');

    final done = Completer<String?>();
    void finish([String? text]) {
      if (!done.isCompleted)
        done.complete(text ?? (_last.isEmpty ? null : _last));
    }

    final prevStatus = speechListenService.onStatusChange;
    speechListenService.onStatusChange = (status) {
      prevStatus?.call(status);
      if (gen != _gen || done.isCompleted) return;
      if (status == 'done' || status == 'notListening') {
        if (_last.isNotEmpty) finish(_last);
      }
    };

    try {
      await speechListenService.start(
        preferHindi: hindi,
        listenFor: maxFor,
        pauseFor: silence,
        haptic: false,
        cancelOnError: false,
        onSoundLevel: onLevel,
        onPartial: (text) {
          if (gen != _gen || cancelled()) return;
          final t = text.trim();
          if (t.isEmpty) return;
          _last = t;
          onPartial?.call(t);
        },
        onResult: (text, isFinal) {
          if (gen != _gen || cancelled()) return;
          final t = text.trim();
          if (t.isEmpty) return;
          _last = t;
          if (!isFinal) onPartial?.call(t);
          if (isFinal) finish(t);
        },
      );
      var opened = false;
      for (var i = 0; i < 25; i++) {
        if (speechListenService.isListening) {
          opened = true;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      if (!opened && kDebugMode) {
        debugPrint('device STT: mic not marked listening yet');
      }
    } catch (e) {
      speechListenService.onStatusChange = prevStatus;
      if (kDebugMode) debugPrint('device listen failed: $e');
      throw StateError('speech_unavailable');
    }

    final started = DateTime.now();
    while (!done.isCompleted) {
      if (gen != _gen || cancelled()) {
        speechListenService.onStatusChange = prevStatus;
        await speechListenService.cancel();
        return null;
      }
      if (DateTime.now().difference(started) >= maxFor) {
        finish(_last.isEmpty ? null : _last);
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    speechListenService.onStatusChange = prevStatus;
    try {
      await speechListenService.stop();
    } catch (_) {}
    if (gen != _gen || cancelled()) return null;
    final text = (await done.future)?.trim() ?? _last.trim();
    _last = '';
    return text.isEmpty ? null : text;
  }
}

final accurateListen = AccurateListenService.instance;
