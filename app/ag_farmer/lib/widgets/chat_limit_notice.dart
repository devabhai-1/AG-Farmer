import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bottom banner when guest lock or plan limit blocks sending.
class ChatLimitNotice extends StatelessWidget {
  const ChatLimitNotice({
    super.key,
    required this.login,
    required this.isHi,
    required this.onPressed,
  });

  final bool login;
  final bool isHi;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final title = login
        ? (isHi ? 'और चैट के लिए लॉगिन करें' : 'Login to keep chatting')
        : (isHi ? 'आज की लिमिट पूरी' : 'Daily limit reached');
    final body = login
        ? (isHi
            ? 'मेंबर अकाउंट से अनलिमिटेड सलाह जारी रखें।'
            : 'Sign in to continue with member chat.')
        : (isHi
            ? 'प्लान अपग्रेड करके और मैसेज भेजें।'
            : 'Upgrade your plan for more messages.');
    final cta = login
        ? (isHi ? 'लॉगिन' : 'Login')
        : (isHi ? 'अपग्रेड' : 'Upgrade');

    return Material(
      color: context.agroSoftGoldFill,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Icon(
              login ? Icons.lock_outline_rounded : Icons.bolt_rounded,
              color: context.agroGold,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: context.agroText,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: TextStyle(
                      color: context.agroMuted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                foregroundColor: context.agroGold,
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              child: Text(cta),
            ),
          ],
        ),
      ),
    );
  }
}
