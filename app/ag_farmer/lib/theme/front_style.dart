import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Soft front-page palette (login / chat / course / jankari).
class Face {
  const Face({
    required this.dark,
    required this.pageBg,
    required this.page,
    required this.panel,
    required this.field,
    required this.line,
    required this.ink,
    required this.muted,
    required this.gold,
    required this.onGold,
    required this.sheen,
  });

  final bool dark;
  final Color pageBg;
  final LinearGradient page;
  final Color panel;
  final Color field;
  final Color line;
  final Color ink;
  final Color muted;
  final Color gold;
  final Color onGold;
  final LinearGradient sheen;

  static Face of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return Face(
        dark: true,
        pageBg: AgroColors.night,
        page: AgroColors.premiumHeroDark,
        panel: AgroColors.nightCard,
        field: AgroColors.nightElevated,
        line: AgroColors.nightBorder,
        ink: AgroColors.nightText,
        muted: AgroColors.nightMuted,
        gold: AgroColors.nightGold,
        onGold: AgroColors.night,
        sheen: AgroColors.goldSheen,
      );
    }
    return Face(
      dark: false,
      pageBg: AgroColors.mist,
      page: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFF0F9FF),
          Color(0xFFE0F2FE),
          Color(0xFFF8FBFF),
        ],
      ),
      panel: AgroColors.white,
      field: AgroColors.white,
      line: const Color(0xFFBAE6FD),
      ink: AgroColors.charcoal,
      muted: AgroColors.slate,
      gold: AgroColors.deepGreen,
      onGold: AgroColors.white,
      sheen: AgroColors.goldSheen,
    );
  }
}

/// Marks a subtree that uses [Face] chrome (safe no-op wrapper).
class FrontScope extends StatelessWidget {
  const FrontScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Compact branded top bar for front screens.
class FrontBar extends StatelessWidget {
  const FrontBar({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.actions,
  });

  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final face = Face.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return Material(
      color: face.panel.withValues(alpha: 0.96),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, top + 8, 12, 10),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null && title!.trim().isNotEmpty)
                    Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: face.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    if (title != null && title!.trim().isNotEmpty)
                      const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: face.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (actions != null) ...actions!,
          ],
        ),
      ),
    );
  }
}

/// Alias kept for older imports / docs.
typedef FrontStyle = Face;
