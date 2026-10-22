import 'dart:async';

import 'package:flutter/material.dart';

/// Types out [text] character-by-character, then calls [onDone].
class AnswerPipe extends StatefulWidget {
  const AnswerPipe({
    super.key,
    required this.text,
    this.style,
    this.cursorColor,
    this.onDone,
    this.charsPerTick = 3,
    this.tick = const Duration(milliseconds: 16),
  });

  final String text;
  final TextStyle? style;
  final Color? cursorColor;
  final VoidCallback? onDone;
  final int charsPerTick;
  final Duration tick;

  @override
  State<AnswerPipe> createState() => _AnswerPipeState();
}

class _AnswerPipeState extends State<AnswerPipe> {
  int _shown = 0;
  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant AnswerPipe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _timer?.cancel();
      _shown = 0;
      _finished = false;
      _start();
    }
  }

  void _start() {
    if (widget.text.isEmpty) {
      _finish();
      return;
    }
    _timer = Timer.periodic(widget.tick, (_) {
      if (!mounted) return;
      final next = (_shown + widget.charsPerTick).clamp(0, widget.text.length);
      setState(() => _shown = next);
      if (_shown >= widget.text.length) {
        _timer?.cancel();
        _finish();
      }
    });
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onDone?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.text.substring(0, _shown.clamp(0, widget.text.length));
    final showCursor = !_finished && _shown < widget.text.length;
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: visible),
          if (showCursor)
            TextSpan(
              text: '▍',
              style: TextStyle(
                color: widget.cursorColor ?? Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
