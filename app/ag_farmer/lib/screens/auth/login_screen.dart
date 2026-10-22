import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/agro_scope.dart';
import '../../services/app_services.dart';
import '../../services/feature_controls.dart';
import '../../services/page_analytics.dart';
import '../../services/screen_pack.dart';
import '../../theme/front_style.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/brand_logo.dart';
import 'forgot_password_screen.dart';
import 'google_complete_screen.dart';

/// Premium member door. Login and create-account sit on the same screen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.embedded = false,
    this.startOnLogin = false,
    this.belowForm,
  });

  /// Course tab shows this in place. There is no back button.
  final bool embedded;

  /// Profile "लॉगिन" opens the login tab. New account stays the default.
  final bool startOnLogin;

  /// Sits under the login / create-account card. Profile uses this for privacy.
  final Widget? belowForm;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with PageHit {
  @override
  String get analyticsPage => 'login';

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  int? _age;
  bool _policy = false;
  bool _create = true;
  bool _obscure = true;
  bool _obscure2 = true;
  bool _submitting = false;
  _Wait _wait = _Wait.idle;

  @override
  void initState() {
    super.initState();
    if (widget.startOnLogin) _create = false;
    unawaited(screenPack.refresh());
  }

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
      case 'bad_credentials':
        return s.errBadCredentials;
      case 'too_many_attempts_blocked_24h':
      case 'rate_limit_exceeded':
      case 'service_unavailable':
        return s.errTooManyRequests;
      case 'invalid_email':
        return s.errInvalidEmail;
      case 'email_in_use':
        return s.errEmailInUse;
      case 'account_pending_deletion':
        return s.errAccountPending;
      case 'invalid_phone':
        return s.errInvalidPhone;
      case 'weak_password':
        return s.errWeakPassword;
      case 'accept_policy':
        return s.acceptPolicyFirst;
      case 'network':
        return s.errNetwork;
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

  Future<void> _login() async {
    final s = AgroScope.of(context).s;
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.fillAllFields)),
      );
      return;
    }
    setState(() => _wait = _Wait.login);
    try {
      final ok = await authService.login(
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(authService.error, s))),
        );
        return;
      }
      _finish(s.loginSuccess);
    } finally {
      if (mounted) setState(() => _wait = _Wait.idle);
    }
  }

  Future<void> _register() async {
    if (_submitting || authService.busy) return;
    final s = AgroScope.of(context).s;
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _address.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _confirm.text.isEmpty ||
        _age == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.fillAllFields)),
      );
      return;
    }
    if (!_validPhone(_phone.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.errInvalidPhone)),
      );
      return;
    }
    if (_password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.errWeakPassword)),
      );
      return;
    }
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.passwordMismatch)),
      );
      return;
    }
    if (!_policy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.acceptPolicyFirst)),
      );
      return;
    }
    setState(() {
      _submitting = true;
      _wait = _Wait.create;
    });
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
      _finish(s.accountCreated);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _wait = _Wait.idle;
        });
      }
    }
  }

  Future<void> _google() async {
    final s = AgroScope.of(context).s;
    setState(() => _wait = _Wait.google);
    bool ok = false;
    try {
      ok = await authService.signInWithGoogle();
    } finally {
      if (mounted) setState(() => _wait = _Wait.idle);
    }
    if (!mounted) return;
    if (!ok) {
      final err = authService.error;
      if (err == null || err.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(err, s))),
      );
      return;
    }
    if (authService.needsProfileCompletion) {
      final page = MaterialPageRoute(builder: (_) => const GoogleCompleteScreen());
      if (widget.embedded) {
        Navigator.of(context).push(page);
      } else {
        Navigator.of(context).pushReplacement(page);
      }
      return;
    }
    _finish(s.loginSuccess);
  }

  void _finish(String message) {
    profileService.syncSession();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF14532D),
        content: Text(message),
      ),
    );
    if (!widget.embedded && Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  InputDecoration _box(String label, IconData icon) {
    final face = Face.of(context);
    final border = OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: face.line),
    );
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: face.field,
      labelStyle: TextStyle(color: face.gold, fontWeight: FontWeight.w700),
      floatingLabelStyle: TextStyle(color: face.gold, fontWeight: FontWeight.w800),
      hintStyle: TextStyle(color: face.muted),
      prefixStyle: TextStyle(color: face.ink, fontWeight: FontWeight.w800),
      prefixIcon: Icon(icon, color: face.gold),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: face.gold, width: 1.6),
      ),
    );
  }

  ThemeData _formTheme(BuildContext context) {
    final face = Face.of(context);
    final border = OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: face.line),
    );
    final base = Theme.of(context);
    return base.copyWith(
      canvasColor: face.panel,
      colorScheme: base.colorScheme.copyWith(
        surface: face.panel,
        onSurface: face.ink,
        onSurfaceVariant: face.gold,
      ),
      iconTheme: IconThemeData(color: face.gold),
      textTheme: base.textTheme.apply(bodyColor: face.ink, displayColor: face.ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: face.field,
        labelStyle: TextStyle(color: face.gold, fontWeight: FontWeight.w700),
        floatingLabelStyle: TextStyle(color: face.gold, fontWeight: FontWeight.w800),
        hintStyle: TextStyle(color: face.muted),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: face.gold, width: 1.6),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        side: BorderSide(color: face.gold, width: 1.6),
        checkColor: WidgetStatePropertyAll(face.onGold),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return face.gold;
          return face.field;
        }),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: face.ink, fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final hi = s.isHi;
    final showGoogle = screenPack.on('login', 'showGoogle', true) &&
        featureControls.on('googleLogin');
    final busy = authService.busy || _submitting;
    final face = Face.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([authService, screenPack, featureControls]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: face.pageBg,
          body: Container(
            decoration: BoxDecoration(gradient: face.page),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  Row(
                    children: [
                      if (!widget.embedded)
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: face.ink,
                          ),
                        ),
                      const BrandLogo(size: 42, radius: 13),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AG FARMER',
                              style: TextStyle(
                                color: face.ink,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'MEMBER CLUB',
                              style: TextStyle(
                                color: face.gold,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.2,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    _create
                        ? (hi ? 'नया मेंबर अकाउंट' : 'New member account')
                        : (hi ? 'मेंबर लॉगिन' : 'Member login'),
                    style: TextStyle(
                      color: face.ink,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _create
                        ? (hi
                            ? 'Google से एक टैप में, या नीचे अपना नाम भरकर।'
                            : 'One tap with Google, or fill your name below.')
                        : (hi
                            ? 'ईमेल और पासवर्ड से अंदर आएँ।'
                            : 'Come in with email and password.'),
                    style: TextStyle(
                      color: face.ink.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: face.field,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: face.line),
                    ),
                    child: Row(
                      children: [
                        _tab(hi ? 'नया अकाउंट' : 'New account', _create, () {
                          setState(() => _create = true);
                        }),
                        _tab(hi ? 'लॉगिन' : 'Login', !_create, () {
                          setState(() => _create = false);
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    decoration: BoxDecoration(
                      color: face.panel,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: face.line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: face.dark ? 0.28 : 0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Theme(
                      data: _formTheme(context),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_create && showGoogle) ...[
                          _googleButton(
                            hi ? 'Google से अकाउंट बनाएँ' : 'Create account with Google',
                            hi ? 'बनाया जा रहा है' : 'Creating your account',
                            _wait == _Wait.google,
                            busy,
                          ),
                          const SizedBox(height: 16),
                          _orDivider(hi ? 'या' : 'OR', face),
                          const SizedBox(height: 14),
                          Text(
                            hi ? 'अपना विवरण भरें' : 'Fill your details',
                            style: TextStyle(
                              color: face.ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (_create) ...[
                          TextField(
                            controller: _name,
                            style: TextStyle(color: face.ink, fontWeight: FontWeight.w700),
                            cursorColor: face.gold,
                            textCapitalization: TextCapitalization.words,
                            decoration: _box(s.farmerName, Icons.person_outline_rounded),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _email,
                          style: TextStyle(color: face.ink, fontWeight: FontWeight.w700),
                          cursorColor: face.gold,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _box(s.emailLabel, Icons.mail_outline_rounded),
                        ),
                        if (_create) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _phone,
                            style: TextStyle(color: face.ink, fontWeight: FontWeight.w700),
                            cursorColor: face.gold,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: _box(s.phoneNumber, Icons.phone_outlined)
                                .copyWith(prefixText: '+91 '),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _address,
                            style: TextStyle(color: face.ink, fontWeight: FontWeight.w700),
                            cursorColor: face.gold,
                            maxLines: 2,
                            decoration: _box(s.addressLabel, Icons.home_outlined),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          style: TextStyle(color: face.ink, fontWeight: FontWeight.w700),
                          cursorColor: face.gold,
                          obscureText: _obscure,
                          onSubmitted: (_) {
                            if (!_create && !busy) _login();
                          },
                          decoration: _box(s.passwordLabel, Icons.lock_outline_rounded)
                              .copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: face.gold,
                              ),
                            ),
                          ),
                        ),
                        if (_create) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _confirm,
                            style: TextStyle(color: face.ink, fontWeight: FontWeight.w700),
                            cursorColor: face.gold,
                            obscureText: _obscure2,
                            decoration: _box(
                              s.confirmPasswordLabel,
                              Icons.lock_person_outlined,
                            ).copyWith(
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure2 = !_obscure2),
                                icon: Icon(
                                  _obscure2
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  color: face.gold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          AgeDropdown(
                            value: _age,
                            onChanged: (v) => setState(() => _age = v),
                          ),
                          PolicyCheckbox(
                            value: _policy,
                            onChanged: (v) => setState(() => _policy = v),
                          ),
                        ],
                        if (!_create)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: busy
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ForgotPasswordScreen(
                                            initialEmail: _email.text.trim(),
                                          ),
                                        ),
                                      );
                                    },
                              child: Text(
                                hi ? 'पासवर्ड भूल गए?' : 'Forgot password?',
                                style: TextStyle(
                                  color: face.gold,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        _goldButton(
                          busy: _wait == _Wait.login || _wait == _Wait.create,
                          locked: busy || _wait != _Wait.idle,
                          label: _create
                              ? (hi ? 'अकाउंट बनाएँ' : 'Create account')
                              : (hi ? 'लॉगिन करें' : 'Log in'),
                          wait: _create
                              ? (hi ? 'बनाया जा रहा है' : 'Creating your account')
                              : (hi ? 'अकाउंट खुल रहा है' : 'Opening your account'),
                          onTap: _create ? _register : _login,
                        ),
                        if (!_create && showGoogle) ...[
                          const SizedBox(height: 12),
                          _googleButton(
                            hi ? 'Google से जारी रखें' : 'Continue with Google',
                            hi ? 'अकाउंट खुल रहा है' : 'Opening your account',
                            _wait == _Wait.google,
                            busy,
                          ),
                        ],
                      ],
                    ),
                    ),
                  ),
                  if (widget.belowForm != null) ...[
                    const SizedBox(height: 14),
                    widget.belowForm!,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _orDivider(String label, Face face) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: face.line)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: face.field,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: face.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: face.muted,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: face.line)),
      ],
    );
  }

  Widget _googleButton(String label, String wait, bool showWait, bool busy) {
    final face = Face.of(context);
    final fill = face.dark ? const Color(0xFF10283C) : Colors.white;
    final ink = face.dark ? const Color(0xFFF8F9FA) : const Color(0xFF3C4043);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : _google,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: showWait ? 74 : 56,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: face.dark ? const Color(0xFF5F6368) : const Color(0xFFDADCE0),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4285F4).withValues(alpha: face.dark ? 0.18 : 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: showWait
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      wait,
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _GoogleMark(),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _tab(String label, bool on, VoidCallback tap) {
    final face = Face.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: tap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: on ? face.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: on ? face.onGold : face.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _goldButton({
    required bool busy,
    required bool locked,
    required String label,
    required String wait,
    required VoidCallback onTap,
    bool filled = true,
  }) {
    final face = Face.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: busy ? 74 : 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: filled ? face.sheen : null,
            border: filled ? null : Border.all(color: face.gold, width: 1.4),
            color: filled ? null : face.field,
          ),
          child: Center(
            child: busy
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: filled ? face.onGold : face.gold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        wait,
                        style: TextStyle(
                          color: filled ? face.onGold : face.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: filled ? face.onGold : face.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

enum _Wait { idle, login, create, google }

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.36;
    final stroke = size.width * 0.18;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -0.55, -1.55, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 1.05, 1.05, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 2.15, 1.15, false, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -1.15, 1.15, false, paint);

    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4285F4);
    final bar = stroke * 0.92;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 0.2, center.dy - bar / 2, radius + stroke * 0.15, bar),
        const Radius.circular(1),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
