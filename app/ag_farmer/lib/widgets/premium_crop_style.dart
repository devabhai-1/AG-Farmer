import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared premium look for Afim vs Lasun in course lists.
class PremiumCropStyle {
  const PremiumCropStyle._({
    required this.fillLight,
    required this.fillDark,
    required this.badge,
    required this.border,
    required this.accent,
  });

  final Color fillLight;
  final Color fillDark;
  final Color badge;
  final Color border;
  final Color accent;

  static const afim = PremiumCropStyle._(
    fillLight: Color(0xFFEDE9FE),
    fillDark: Color(0xFF1E1B4B),
    badge: Color(0xFF7C3AED),
    border: Color(0xFFA78BFA),
    accent: Color(0xFF6D28D9),
  );

  static const lasun = PremiumCropStyle._(
    fillLight: Color(0xFFDCFCE7),
    fillDark: Color(0xFF052E16),
    badge: Color(0xFF059669),
    border: Color(0xFF6EE7B7),
    accent: Color(0xFF047857),
  );

  static PremiumCropStyle? of(String cropId) {
    switch (cropId) {
      case 'afim':
      case 'afim_live':
        return afim;
      case 'lasun':
      case 'lahsun':
      case 'garlic':
        return lasun;
      default:
        return null;
    }
  }

  static bool isPremium(String cropId) => of(cropId) != null;

  Color fill(BuildContext context) =>
      context.isDark ? fillDark : fillLight;
}

/// External corner badge — sits outside the card edge.
class PremiumCornerBadge extends StatelessWidget {
  const PremiumCornerBadge({
    super.key,
    required this.style,
    required this.label,
  });

  final PremiumCropStyle style;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: style.badge,
      elevation: 3,
      shadowColor: style.badge.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

/// Wraps a course tile so Premium sits on the outer top-right.
class PremiumCropFrame extends StatelessWidget {
  const PremiumCropFrame({
    super.key,
    required this.cropId,
    required this.child,
    this.badgeLabel = 'PREMIUM',
  });

  final String cropId;
  final Widget child;
  final String badgeLabel;

  @override
  Widget build(BuildContext context) {
    final style = PremiumCropStyle.of(cropId);
    if (style == null) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -8,
          right: 10,
          child: PremiumCornerBadge(style: style, label: badgeLabel),
        ),
      ],
    );
  }
}
