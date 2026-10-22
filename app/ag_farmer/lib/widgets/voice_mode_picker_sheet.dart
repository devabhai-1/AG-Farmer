import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/agro_scope.dart';
import '../theme/app_theme.dart';

enum VoiceModeChoice { speakToType, liveTalk }

/// Two voice logos: STT (speak→type) vs AG Live (OpenAI Realtime).
class VoiceModePickerSheet extends StatelessWidget {
  const VoiceModePickerSheet({super.key, required this.onChosen});

  final void Function(VoiceModeChoice mode) onChosen;

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: context.agroBorder,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.voiceModePickerTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: context.agroText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.voiceModePickerSub,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.agroMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ModeLogo(
                    icon: Icons.mic_rounded,
                    title: s.voiceModeSttTitle,
                    subtitle: s.voiceModeSttSub,
                    colors: const [AgroColors.deepGreen, AgroColors.leaf],
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      onChosen(VoiceModeChoice.speakToType);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModeLogo(
                    icon: Icons.headphones_rounded,
                    title: s.voiceModeLiveTitle,
                    subtitle: s.voiceModeLiveSub,
                    colors: const [Color(0xFF0369A1), Color(0xFF38BDF8)],
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      onChosen(VoiceModeChoice.liveTalk);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeLogo extends StatelessWidget {
  const _ModeLogo({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.agroCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.agroBorder),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: colors),
                  boxShadow: [
                    BoxShadow(
                      color: colors.last.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: context.agroText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.3,
                  color: context.agroMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
