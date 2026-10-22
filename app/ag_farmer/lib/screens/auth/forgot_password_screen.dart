import 'package:flutter/material.dart';
import '../../services/agro_scope.dart';
import '../../services/app_services.dart';
import '../../services/page_analytics.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/soft_card.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with PageHit {
  @override
  String get analyticsPage => 'forgot_password';
  late final TextEditingController _email;
  bool _sent = false;
  String? _masked;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String _friendly(String? code, dynamic s) {
    switch (code) {
      case 'invalid_email':
        return s.errInvalidEmail as String;
      case 'account_not_found':
        return s.errAccountNotFound as String;
      case 'email_send_failed':
        return s.errEmailSendFailed as String;
      case 'email_auth_disabled':
        return s.errEmailAuthDisabled as String;
      case 'network':
        return s.errNetwork as String;
      default:
        return code ?? s.errGeneric as String;
    }
  }

  Future<void> _sendResetMail() async {
    final s = AgroScope.of(context).s;
    if (_email.text.trim().isEmpty || !_email.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.errInvalidEmail)),
      );
      return;
    }

    final res = await authService.requestPasswordReset(email: _email.text);
    if (!mounted) return;
    if (res == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendly(authService.error, s))),
      );
      return;
    }

    setState(() {
      _sent = true;
      _masked = '${res['emailMasked'] ?? _email.text.trim()}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;

    return ListenableBuilder(
      listenable: authService,
      builder: (context, _) {
        return AuthScaffold(
          title: s.forgotPasswordTitle,
          subtitle: s.forgotPasswordSubtitle,
          child: SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_sent) ...[
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: s.emailLabel,
                      prefixIcon: const Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: authService.busy ? null : _sendResetMail,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AgroColors.forest,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: authService.busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            s.sendResetLinkBtn,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ] else ...[
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 56,
                    color: context.isDark ? AgroColors.mint : AgroColors.deepGreen,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    s.resetLinkSentTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: context.agroText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.resetLinkSentBody(_masked ?? _email.text.trim()),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.agroMuted,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AgroColors.forest,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      s.backToLoginBtn,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  TextButton(
                    onPressed: authService.busy ? null : _sendResetMail,
                    child: Text(s.resendResetLinkBtn),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
