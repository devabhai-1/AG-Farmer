import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? color;
  final VoidCallback? onTap;
  final bool glass;
  final bool premiumBorder;

  /// When true (default), soft pastel fills are remapped in dark mode.
  /// Pure white is kept — needed on blue hero headers / language picker.
  final bool remapSoftFills;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.gradient,
    this.color,
    this.onTap,
    this.glass = false,
    this.premiumBorder = false,
    this.remapSoftFills = true,
  });

  Color _resolveFill(BuildContext context) {
    final isDark = context.isDark;
    if (glass) {
      return isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.78);
    }

    final fallback = context.agroCard;
    if (color == null) return fallback;
    if (!isDark || !remapSoftFills) return color!;

    final c = color!;
    // Only remap soft pastel fills that clash on dark scaffolds.
    // Never remap pure / translucent white (hero overlays need them).
    final softPastels = {
      AgroColors.softGold,
      AgroColors.softMint,
      AgroColors.mist,
      AgroColors.skyMist,
      AgroColors.skySoft,
      AgroColors.skyIce,
    };
    if (softPastels.contains(c) ||
        c == const Color(0xFFF0F9FF) ||
        c == const Color(0xFFE0F2FE) ||
        c == const Color(0xFFBAE6FD)) {
      return context.agroSoftGoldFill;
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final baseColor = _resolveFill(context);
    // Alpha is ignored by computeLuminance — translucent white on a dark
    // hero must not be treated as a light fill (that made Hindi charcoal).
    final fillIsLight = gradient == null &&
        baseColor.a >= 0.5 &&
        baseColor.computeLuminance() > 0.42;

    final borderColor = premiumBorder
        ? context.agroGold.withValues(alpha: isDark ? 0.45 : 0.38)
        : gradient != null
            ? Colors.white.withValues(alpha: 0.14)
            : fillIsLight
                ? const Color(0xFFBAE6FD)
                : context.agroBorder.withValues(alpha: isDark ? 0.95 : 1);

    final defaultFg = gradient != null
        ? Colors.white
        : fillIsLight
            ? AgroColors.charcoal
            : context.agroText;

    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? baseColor : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: premiumBorder ? 1.2 : 1),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AgroColors.forest)
                .withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: isDark ? 14 : 10,
            offset: const Offset(0, 4),
          ),
          if (premiumBorder)
            BoxShadow(
              color: context.agroGold.withValues(alpha: isDark ? 0.08 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: defaultFg),
        child: IconTheme.merge(
          data: IconThemeData(color: defaultFg),
          child: child,
        ),
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: content,
      ),
    );
  }
}
