import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'brand_logo.dart';
import 'theme_toggle.dart';

class PremiumHeader extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBrand;
  final bool showThemeToggle;

  const PremiumHeader({
    super.key,
    this.title,
    this.subtitle,
    this.actions,
    this.showBrand = false,
    this.showThemeToggle = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 80 : 96);

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          gradient: context.agroHeaderGradient,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AgroColors.gold.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -50,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 12, 12),
                  child: Row(
                    children: [
                      if (showBrand) ...[
                        const BrandLogo(size: 48, radius: 16),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (title != null && title!.trim().isNotEmpty)
                              Text(
                                title!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AgroColors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            if (subtitle != null) ...[
                              if (title != null && title!.trim().isNotEmpty)
                                const SizedBox(height: 3),
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AgroColors.champagne.withValues(alpha: 0.95),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (showThemeToggle) const ThemeToggleButton(compact: true),
                      ...?actions,
                    ],
                  ),
                ),
                Container(
                  height: 2.5,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0x0038BDF8),
                        Color(0xFFBAE6FD), // कम गहरा आइस स्काई
                        Color(0xFF38BDF8), // ग्लोइंग वाइब्रेंट स्काई
                        Color(0xFF0284C7), // गहरा स्काई 600
                        Color(0x000284C7),
                      ],
                      stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}
