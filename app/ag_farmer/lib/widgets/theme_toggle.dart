import 'package:flutter/material.dart';
import '../services/app_services.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';

class ThemeToggleButton extends StatelessWidget {
  final bool compact;
  final bool showLabel;

  const ThemeToggleButton({
    super.key,
    this.compact = false,
    this.showLabel = false,
  });

  IconData _icon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.auto:
        return Icons.brightness_auto_rounded;
      case AppThemeMode.light:
        return Icons.light_mode_rounded;
      case AppThemeMode.dark:
        return Icons.dark_mode_rounded;
    }
  }

  String _label(AppThemeMode mode, bool hi) {
    switch (mode) {
      case AppThemeMode.auto:
        return hi ? 'ऑटो' : 'Auto';
      case AppThemeMode.light:
        return hi ? 'लाइट' : 'Light';
      case AppThemeMode.dark:
        return hi ? 'डार्क' : 'Dark';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hi = Localizations.maybeLocaleOf(context)?.languageCode == 'hi';

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final mode = themeService.mode;
        final isDark = context.isDark;

        if (showLabel) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: themeService.cycle,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AgroColors.softMint,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AgroColors.nightBorder
                        : AgroColors.softMint,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _icon(mode),
                      size: 18,
                      color: isDark ? AgroColors.nightGold : AgroColors.deepGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _label(mode, hi),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: isDark ? AgroColors.nightText : AgroColors.deepGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return IconButton(
          tooltip: _label(mode, hi),
          onPressed: themeService.cycle,
          style: IconButton.styleFrom(
            backgroundColor: compact
                ? Colors.white.withValues(alpha: 0.14)
                : (isDark ? AgroColors.nightElevated : AgroColors.softMint),
            foregroundColor: compact
                ? AgroColors.champagne
                : (isDark ? AgroColors.nightGold : AgroColors.deepGreen),
            side: compact
                ? BorderSide(color: AgroColors.gold.withValues(alpha: 0.45))
                : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: Icon(_icon(mode), size: compact ? 20 : 22),
        );
      },
    );
  }
}

class ThemeModeSegment extends StatelessWidget {
  const ThemeModeSegment({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final hi = Localizations.maybeLocaleOf(context)?.languageCode == 'hi';

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        Widget chip(AppThemeMode mode, String label, IconData icon) {
          final selected = themeService.mode == mode;
          return Expanded(
            child: InkWell(
              onTap: () => themeService.setMode(mode),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          colors: isDark
                              ? const [Color(0xFF0F2D44), Color(0xFF0284C7)]
                              : const [AgroColors.deepGreen, AgroColors.leaf],
                        )
                      : null,
                  color: selected
                      ? null
                      : (isDark ? AgroColors.nightElevated : AgroColors.softMint),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: selected
                          ? Colors.white
                          : (isDark ? AgroColors.nightMuted : AgroColors.deepGreen),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? Colors.white
                            : (isDark ? AgroColors.nightMuted : AgroColors.deepGreen),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Row(
          children: [
            chip(AppThemeMode.auto, hi ? 'ऑटो' : 'Auto', Icons.brightness_auto_rounded),
            const SizedBox(width: 8),
            chip(AppThemeMode.light, hi ? 'लाइट' : 'Light', Icons.light_mode_rounded),
            const SizedBox(width: 8),
            chip(AppThemeMode.dark, hi ? 'डार्क' : 'Dark', Icons.dark_mode_rounded),
          ],
        );
      },
    );
  }
}

/// Theme row for the chat menu. Three clear choices, not a tiny icon.
class ThemeMenuPick extends StatelessWidget {
  const ThemeMenuPick({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFF0F9FF) : const Color(0xFF0F2744);
    final field = dark ? const Color(0xFF123652) : const Color(0xFFF0F9FF);
    final line = dark ? const Color(0xFF1B4E74) : const Color(0xFFBAE6FD);
    final hi = languageService.isHindi;

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        Widget choice(AppThemeMode mode, String label, IconData icon) {
          final selected = themeService.mode == mode;
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => themeService.setMode(mode),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: selected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: dark
                                ? const [Color(0xFF0369A1), Color(0xFF0284C7)]
                                : const [Color(0xFF0284C7), Color(0xFF38BDF8)],
                          )
                        : null,
                    color: selected ? null : (dark ? const Color(0xFF0B2942) : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? Colors.transparent : line),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 22,
                        color: selected ? Colors.white : ink,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: selected ? Colors.white : ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: field,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hi ? 'थीम' : 'Theme',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    choice(AppThemeMode.auto, hi ? 'ऑटो' : 'Auto', Icons.brightness_auto_rounded),
                    const SizedBox(width: 8),
                    choice(AppThemeMode.light, hi ? 'लाइट' : 'Light', Icons.light_mode_rounded),
                    const SizedBox(width: 8),
                    choice(AppThemeMode.dark, hi ? 'डार्क' : 'Dark', Icons.dark_mode_rounded),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
