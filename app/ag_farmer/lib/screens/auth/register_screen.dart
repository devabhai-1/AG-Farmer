import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/agro_scope.dart';
import '../../services/app_services.dart';
import '../../services/page_analytics.dart';
import '../../services/screen_pack.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/soft_card.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with PageHit {
  @override
  String get analyticsPage => 'register';
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  int? _age;
  bool _policy = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  // Covers the whole submit flow (register + profile sync) so the button
  // can't be tapped again in the gap after authService.busy drops.
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _address.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String _friendlyError(String? code, dynamic s) {
    switch (code) {
      case 'accept_policy':
        return s.acceptPolicyFirst as String;
      case 'email_in_use':
        return s.errEmailInUse as String;
      case 'account_pending_deletion':
        return s.errAccountPending as String;
      case 'invalid_email':
        return s.errInvalidEmail as String;
      case 'invalid_phone':
        return s.errInvalidPhone as String;
      case 'weak_password':
        return s.errWeakPassword as String;
      case 'network':
        return s.errNetwork as String;
      default:
        return code ?? s.errGeneric as String;
    }
  }

  bool _validPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return true;
    if (digits.length == 12 && digits.startsWith('91')) return true;
    if (digits.length == 11 && digits.startsWith('0')) return true;
    return false;
  }

  Future<void> _create() async {
    if (_submitting || authService.busy) return;
    final s = AgroScope.of(context).s;
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _address.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _confirm.text.isEmpty ||
        _age == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.fillAllFields)));
      return;
    }
    if (!_validPhone(_phone.text)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.errInvalidPhone)));
      return;
    }
    if (_password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.errWeakPassword)));
      return;
    }
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.passwordMismatch)));
      return;
    }
    if (!_policy) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.acceptPolicyFirst)));
      return;
    }

    setState(() => _submitting = true);
    try {
      final ok = await authService.register(
        name: _name.text,
        email: _email.text,
        address: _address.text,
        phone: _phone.text,
        password: _password.text,
        age: _age!,
        acceptedPolicy: _policy,
      );
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(authService.error, s))),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AgroColors.deepGreen, content: Text(s.accountCreated)),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;

    return ListenableBuilder(
      listenable: Listenable.merge([authService, screenPack]),
      builder: (context, _) {
        final hi = s.isHi;
        return AuthScaffold(
          title: screenPack.t(hi, 'register', 'title', s.createAccountTitle),
          subtitle: screenPack.t(
              hi, 'register', 'subtitle', s.createAccountSubtitle),
          child: SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: s.farmerName,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: s.emailLabel,
                    prefixIcon: const Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _address,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: s.addressLabel,
                    prefixIcon: const Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: s.phoneNumber,
                    hintText: s.phoneHint,
                    counterText: '',
                    prefixText: '+91 ',
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _password,
                  obscureText: _obscure1,
                  decoration: InputDecoration(
                    labelText: s.passwordLabel,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                      icon: Icon(_obscure1 ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _confirm,
                  obscureText: _obscure2,
                  decoration: InputDecoration(
                    labelText: s.confirmPasswordLabel,
                    prefixIcon: const Icon(Icons.lock_person_outlined),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                      icon: Icon(_obscure2 ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                AgeDropdown(
                  value: _age,
                  onChanged: (v) => setState(() => _age = v),
                ),
                const SizedBox(height: 8),
                PolicyCheckbox(
                  value: _policy,
                  onChanged: (v) => setState(() => _policy = v),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  style: (authService.busy || _submitting)
                      ? ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(74),
                        )
                      : null,
                  onPressed: (authService.busy || _submitting) ? null : _create,
                  child: (authService.busy || _submitting)
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(hi ? 'बनाया जा रहा है' : 'Creating your account'),
                          ],
                        )
                      : Text(screenPack.t(
                          hi, 'register', 'button', s.createAccountBtn)),
                ),
                TextButton(
                  onPressed: (authService.busy || _submitting)
                      ? null
                      : () => Navigator.pop(context),
                  child: Text(s.alreadyHaveAccount),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
