import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Clock time for a sent message, shown when the chat is swiped sideways.
String messageSentTime(DateTime time, {required bool hi}) {
  final t = time.toLocal();
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  if (!hi) {
    return '$h12:$m ${t.hour < 12 ? 'AM' : 'PM'}';
  }
  final part = t.hour < 5 || t.hour >= 21
      ? 'रात'
      : t.hour < 12
          ? 'सुबह'
          : t.hour < 17
              ? 'दोपहर'
              : 'शाम';
  return '$h12:$m $part';
}

/// Swipe the message list a little to the left to reveal send times.
class SwipeMessageTime extends StatefulWidget {
  const SwipeMessageTime({super.key, required this.builder});

  final Widget Function(BuildContext context, double reveal) builder;

  @override
  State<SwipeMessageTime> createState() => _SwipeMessageTimeState();
}

class _SwipeMessageTimeState extends State<SwipeMessageTime>
    with SingleTickerProviderStateMixin {
  static const _max = 78.0;
  double _reveal = 0;
  double _from = 0;
  late final AnimationController _back;

  @override
  void initState() {
    super.initState();
    _back = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  double get _shown =>
      _back.isAnimating ? _from * (1 - _back.value) : _reveal;

  void _drag(DragUpdateDetails d) {
    if (_back.isAnimating) _back.stop();
    setState(() {
      _reveal = (_reveal - d.delta.dx).clamp(0.0, _max);
    });
  }

  void _end(DragEndDetails _) {
    _from = _reveal;
    _reveal = 0;
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _drag,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: () => _end(DragEndDetails()),
      child: widget.builder(context, _shown),
    );
  }
}

/// Shifts one row left and shows [time] on the right while [reveal] is open.
class MessageTimeSlot extends StatelessWidget {
  const MessageTimeSlot({
    super.key,
    required this.reveal,
    required this.child,
    this.time,
  });

  final double reveal;
  final String? time;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shown = time != null && reveal > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: Offset(-reveal, 0),
          child: child,
        ),
        if (shown)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: (reveal / 48).clamp(0.0, 1.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    time!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: context.agroMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
