import 'package:flutter/material.dart';

/// A short pull from the top shows a spinning ring, then refreshes.
class HalfPullRefresh extends StatefulWidget {
  const HalfPullRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  State<HalfPullRefresh> createState() => _HalfPullRefreshState();
}

class _HalfPullRefreshState extends State<HalfPullRefresh> {
  static const _arm = 56.0;

  double _pull = 0;
  bool _atTop = true;
  bool _busy = false;
  int? _pointer;

  bool _onScroll(ScrollNotification note) {
    if (note.metrics.axis != Axis.vertical) return false;
    _atTop = note.metrics.pixels <= note.metrics.minScrollExtent + 2;
    return false;
  }

  void _down(PointerDownEvent event) {
    if (_busy || !_atTop) return;
    _pointer = event.pointer;
  }

  void _move(PointerMoveEvent event) {
    if (_busy || event.pointer != _pointer || !_atTop) return;
    final next = (_pull + event.delta.dy).clamp(0.0, 64.0);
    if (next == _pull) return;
    setState(() => _pull = next);
  }

  void _up(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (_busy) return;
    if (_pull >= _arm) {
      _run();
      return;
    }
    setState(() => _pull = 0);
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pull = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gap = _busy ? 48.0 : _pull;
    final spinning = _busy || _pull >= 18;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Listener(
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: Column(
          children: [
            AnimatedContainer(
              duration: _pull == 0 && !_busy
                  ? const Duration(milliseconds: 180)
                  : Duration.zero,
              height: gap,
              alignment: Alignment.center,
              child: spinning
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}
