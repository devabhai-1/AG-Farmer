import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/agro_scope.dart';
import '../services/api_client.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import 'live_studio.dart';

/// In-app report for AI text. Stays inside the app.
Future<bool> showAiContentReportSheet(
  BuildContext context, {
  required String messageId,
  required String messageText,
  required String source,
}) async {
  final s = AgroScope.of(context).s;
  HapticFeedback.lightImpact();
  var selected = s.reportReasonOffensive;
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.agroCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final reasons = [
            s.reportReasonOffensive,
            s.reportReasonPesticide,
            s.reportReasonInaccurate,
            s.reportReasonOther,
          ];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.agroBorder,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.reportAiTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: context.agroText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.reportAiSubtitle,
                    style: TextStyle(fontSize: 12, color: context.agroTextMuted),
                  ),
                  const SizedBox(height: 12),
                  ...reasons.map((reason) {
                    final on = selected == reason;
                    return InkWell(
                      onTap: () => setModalState(() => selected = reason),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              on
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: on ? AgroColors.deepGreen : context.agroMuted,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                reason,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      on ? FontWeight.w800 : FontWeight.w500,
                                  color: context.agroText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: Text(s.reportSubmitBtn),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AgroColors.deepGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  if (sent != true) return false;
  final snippet = messageText.trim();
  try {
    await ApiClient.instance.call(
      'report.create',
      auth: true,
      data: {
        'report': {
          'messageId': messageId,
          'messageSnippet': snippet.length > 200
              ? '${snippet.substring(0, 200)}...'
              : snippet,
          'reason': selected,
          'source': source,
          'userEmail': authService.user?.email ?? '',
          'reportedAt': DateTime.now().toIso8601String(),
        },
      },
    );
  } catch (_) {}
  return true;
}

/// Report plus end-call on a dark voice or video screen.
class LiveReportButton extends StatelessWidget {
  const LiveReportButton({
    super.key,
    required this.endLabel,
    required this.onEnd,
    required this.colors,
    this.onReport,
    this.reportLabel,
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
  final VoidCallback? onReport;
  final String? reportLabel;
  final bool voiceOn;
  final VoidCallback? onStop;
  final String? stopLabel;
  final bool error;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    const reportColor = Color(0xFFFECACA);
    final reportBtn = onReport == null
        ? null
        : OutlinedButton.icon(
            onPressed: onReport,
            icon: const Icon(Icons.flag_rounded, size: 18),
            label: Text(
              reportLabel ?? 'रिपोर्ट करें',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: reportColor,
              side: const BorderSide(color: reportColor, width: 1.4),
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
    final endBtn = FilledButton.icon(
      onPressed: onEnd,
      icon: const Icon(Icons.call_end_rounded, size: 20),
      label: Text(
        endLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (error && onRetry != null) ...[
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              retryLabel ?? 'Try again',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (voiceOn && onStop != null) ...[
          OutlinedButton(
            onPressed: onStop,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.accent,
              side: BorderSide(color: colors.accent),
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              stopLabel ?? 'Stop voice',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            if (reportBtn != null) ...[
              Expanded(child: reportBtn),
              const SizedBox(width: 8),
            ],
            Expanded(child: endBtn),
          ],
        ),
      ],
    );
  }
}
