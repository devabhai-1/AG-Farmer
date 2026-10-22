import 'package:flutter/material.dart';

import 'chat_answer_body.dart';

class LiveStudioColors {
  const LiveStudioColors({
    required this.accent,
    required this.accentDeep,
    required this.userFill,
  });

  final Color accent;
  final Color accentDeep;
  final Color userFill;

  static const live = LiveStudioColors(
    accent: Color(0xFF38BDF8),
    accentDeep: Color(0xFF0284C7),
    userFill: Color(0xFF0C4A6E),
  );

  static const video = LiveStudioColors(
    accent: Color(0xFFE8B84A),
    accentDeep: Color(0xFFB45309),
    userFill: Color(0xFF5C3D0A),
  );
}

class LiveStudioBackdrop extends StatelessWidget {
  const LiveStudioBackdrop({super.key, required this.colors, required this.child});

  final LiveStudioColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF021018), Color(0xFF032B43), Color(0xFF02141F)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: _Glow(color: colors.accent, size: 220, opacity: 0.16),
          ),
          Positioned(
            bottom: 80,
            left: -60,
            child: _Glow(color: colors.accentDeep, size: 200, opacity: 0.12),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size, required this.opacity});
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

class LiveStudioHeader extends StatelessWidget {
  const LiveStudioHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.status,
    required this.colors,
    required this.onClose,
    this.live = false,
    this.error = false,
  });

  final String eyebrow;
  final String title;
  final String status;
  final LiveStudioColors colors;
  final VoidCallback onClose;
  final bool live;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          _GlassIconButton(icon: Icons.close_rounded, onTap: onClose),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _LiveBadge(label: eyebrow, colors: colors, live: live, error: error),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({
    required this.label,
    required this.colors,
    required this.live,
    required this.error,
  });

  final String label;
  final LiveStudioColors colors;
  final bool live;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? const Color(0xFFEF4444) : colors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                if (live)
                  BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white70, size: 22),
        ),
      ),
    );
  }
}

class LiveOrb extends StatefulWidget {
  const LiveOrb({
    super.key,
    required this.status,
    required this.colors,
    this.size = 148,
  });

  final String status;
  final LiveStudioColors colors;
  final double size;

  @override
  State<LiveOrb> createState() => _LiveOrbState();
}

class _LiveOrbState extends State<LiveOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.status == 'error';
    final accent = error ? const Color(0xFFEF4444) : widget.colors.accent;
    final icon = switch (widget.status) {
      'speaking' => Icons.volume_up_rounded,
      'thinking' => Icons.auto_awesome_rounded,
      'error' => Icons.error_outline_rounded,
      _ => Icons.graphic_eq_rounded,
    };
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _ring(widget.size, accent.withValues(alpha: 0.10 + t * 0.08)),
              _ring(widget.size * (0.78 + t * 0.04), accent.withValues(alpha: 0.16)),
              Container(
                width: widget.size * 0.58,
                height: widget.size * 0.58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [widget.colors.accentDeep, accent],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35 + t * 0.15),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: widget.size * 0.22),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ring(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.4),
      ),
    );
  }
}

class LiveBubble extends StatelessWidget {
  const LiveBubble({
    super.key,
    required this.mine,
    required this.text,
    required this.colors,
    this.typing = false,
    this.trailing,
  });

  final bool mine;
  final String text;
  final LiveStudioColors colors;
  final bool typing;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width * 0.86;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.fromLTRB(14, 11, trailing == null ? 14 : 6, 11),
        constraints: BoxConstraints(maxWidth: wide),
        width: mine ? null : wide,
        decoration: BoxDecoration(
          color: mine ? colors.userFill : const Color(0xCC082236),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 6),
            bottomRight: Radius.circular(mine ? 6 : 18),
          ),
          border: Border.all(
            color: (mine ? colors.accent : Colors.white).withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: mine || typing
                  ? Text.rich(
                      TextSpan(
                        text: text,
                        children: [
                          if (typing)
                            TextSpan(
                              text: ' ▍',
                              style: TextStyle(color: colors.accent),
                            ),
                        ],
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : ChatAnswerBody(text: text, onDark: true, compact: true),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class LiveGlassPanel extends StatelessWidget {
  const LiveGlassPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xB3081A28),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

class LiveDock extends StatelessWidget {
  const LiveDock({
    super.key,
    required this.endLabel,
    required this.onEnd,
    required this.colors,
    this.voiceOn = false,
    this.onStop,
    this.stopLabel,
    this.error = false,
    this.retryLabel,
    this.onRetry,
  });

  final String endLabel;
  final VoidCallback onEnd;
  final LiveStudioColors colors;
  final bool voiceOn;
  final VoidCallback? onStop;
  final String? stopLabel;
  final bool error;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (voiceOn && onStop != null) ...[
              Expanded(
                child: _DockButton(
                  label: stopLabel ?? 'Stop',
                  icon: Icons.stop_rounded,
                  color: const Color(0xFF1E3A5F),
                  onTap: onStop!,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: voiceOn ? 1 : 1,
              child: _DockButton(
                label: endLabel,
                icon: Icons.call_end_rounded,
                color: const Color(0xFFB91C1C),
                onTap: onEnd,
              ),
            ),
          ],
        ),
        if (error && onRetry != null && retryLabel != null)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(minimumSize: const Size(44, 40)),
            child: Text(
              retryLabel!,
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiveCameraFrame extends StatelessWidget {
  const LiveCameraFrame({
    super.key,
    required this.colors,
    required this.child,
    this.live = false,
    this.caption,
  });

  final LiveStudioColors colors;
  final Widget child;
  final bool live;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.accent.withValues(alpha: 0.38), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.12),
            blurRadius: 18,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66021018), Color(0x00000000), Color(0x73021018)],
                  stops: [0, 0.28, 1],
                ),
              ),
            ),
            Positioned(top: 12, left: 12, child: _Corner(colors.accent, flipX: false, flipY: false)),
            Positioned(top: 12, right: 12, child: _Corner(colors.accent, flipX: true, flipY: false)),
            Positioned(bottom: 12, left: 12, child: _Corner(colors.accent, flipX: false, flipY: true)),
            Positioned(bottom: 12, right: 12, child: _Corner(colors.accent, flipX: true, flipY: true)),
            if (live)
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: _LiveBadge(
                    label: 'REC',
                    colors: colors,
                    live: true,
                    error: false,
                  ),
                ),
              ),
            if (caption != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner(this.color, {required this.flipX, required this.flipY});
  final Color color;
  final bool flipX;
  final bool flipY;

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: flipX,
      flipY: flipY,
      child: SizedBox(
        width: 18,
        height: 18,
        child: CustomPaint(painter: _CornerPainter(color)),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) => oldDelegate.color != color;
}
