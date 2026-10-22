import 'package:flutter/material.dart';

import '../services/screen_pack.dart';
import '../theme/app_theme.dart';

/// Horizontal suggestion chips driven by `screen.pack` → `prompts`.
class ServerPromptStrip extends StatelessWidget {
  const ServerPromptStrip({
    super.key,
    required this.screen,
    required this.hi,
    required this.onTap,
  });

  final String screen;
  final bool hi;
  final void Function(String text, String? cropId) onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: screenPack,
      builder: (context, _) {
        if (!screenPack.on(screen, 'showPrompts', false)) {
          return const SizedBox.shrink();
        }
        final rows = screenPack.prompts(screen);
        if (rows.isEmpty) return const SizedBox.shrink();

        final chips = <Widget>[];
        for (final row in rows) {
          final textHi = '${row['textHi'] ?? row['hi'] ?? row['text'] ?? ''}'.trim();
          final textEn = '${row['textEn'] ?? row['en'] ?? row['text'] ?? ''}'.trim();
          final text = (hi ? textHi : textEn).isNotEmpty
              ? (hi ? textHi : textEn)
              : (textHi.isNotEmpty ? textHi : textEn);
          if (text.isEmpty) continue;
          final cropId = '${row['cropId'] ?? ''}'.trim();
          chips.add(
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: context.agroText,
                  ),
                ),
                backgroundColor: context.agroSoftFill,
                side: BorderSide(color: context.agroBorder),
                onPressed: () =>
                    onTap(text, cropId.isEmpty ? null : cropId),
              ),
            ),
          );
        }
        if (chips.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            children: chips,
          ),
        );
      },
    );
  }
}
