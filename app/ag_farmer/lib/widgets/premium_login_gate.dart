import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'brand_logo.dart';

/// Full-screen / sheet premium gate — makes login feel exclusive.
class PremiumLoginGate extends StatelessWidget {
  const PremiumLoginGate({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.benefits,
    required this.ctaLabel,
    required this.onCta,
    this.onSecondary,
    this.secondaryLabel,
    this.emoji = '✨',
    this.compact = false,
  });

  final String badge;
  final String title;
  final String subtitle;
  final List<String> benefits;
  final String ctaLabel;
  final VoidCallback onCta;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;
  final String emoji;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (!compact) const SizedBox(height: 8),
        _HeroCrest(emoji: emoji, badge: badge),
        SizedBox(height: compact ? 18 : 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 22 : 26,
            height: 1.2,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
            color: context.agroText,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.45,
            fontWeight: FontWeight.w600,
            color: context.agroMuted,
          ),
        ),
        SizedBox(height: compact ? 18 : 24),
        ...benefits.map(
          (b) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BenefitRow(text: b),
          ),
        ),
        SizedBox(height: compact ? 16 : 22),
        _PremiumCta(label: ctaLabel, onTap: onCta),
        if (onSecondary != null && secondaryLabel != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onSecondary,
            child: Text(
              secondaryLabel!,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: context.agroMuted,
              ),
            ),
          ),
        ],
      ],
    );

    if (compact) {
      return Container(
        decoration: BoxDecoration(
          color: context.agroCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AgroColors.skyDeep.withValues(alpha: dark ? 0.55 : 0.12),
                      AgroColors.skyVibrant.withValues(alpha: dark ? 0.2 : 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: context.agroBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  body,
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: dark
            ? AgroColors.premiumHeroDark
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF032B43),
                  Color(0xFF073A5C),
                  Color(0xFFE0F2FE),
                  Color(0xFFF0F9FF),
                ],
                stops: [0.0, 0.28, 0.62, 1.0],
              ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  const BrandLogo(size: 40, radius: 12),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AG Farmer',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: dark ? AgroColors.nightText : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 18),
                decoration: BoxDecoration(
                  color: context.agroCard,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AgroColors.skyIce.withValues(alpha: 0.7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AgroColors.skyDeep.withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCrest extends StatelessWidget {
  const _HeroCrest({required this.emoji, required this.badge});
  final String emoji;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AgroColors.triColorCard,
            boxShadow: [
              BoxShadow(
                color: AgroColors.skyVibrant.withValues(alpha: 0.35),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 36)),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: AgroColors.goldSheen,
            boxShadow: [
              BoxShadow(
                color: AgroColors.skyPrimary.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            badge,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: context.agroSoftFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.agroBorder.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AgroColors.skyVibrant.withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.check_rounded,
                size: 18, color: AgroColors.skyPrimary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                height: 1.3,
                color: context.agroText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCta extends StatelessWidget {
  const _PremiumCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: AgroColors.triColorCard,
            boxShadow: [
              BoxShadow(
                color: AgroColors.skyDeep.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_open_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
