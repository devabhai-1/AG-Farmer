import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/agro_scope.dart';
import '../../services/app_services.dart';
import '../../services/page_analytics.dart';
import '../../services/screen_pack.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/soft_card.dart';

class GoogleCompleteScreen extends StatefulWidget {
  const GoogleCompleteScreen({super.key});

  @override
  State<GoogleCompleteScreen> createState() => _GoogleCompleteScreenState();
}

class _GoogleCompleteScreenState extends State<GoogleCompleteScreen> with PageHit {
  @override
  String get analyticsPage => 'google_complete';
  late final TextEditingController _name;
  late final TextEditingController _phone;
  int? _age;
  bool _policy = false;
  // Covers the whole submit flow (complete profile + local sync) so the button
  // can't be tapped again in the gap after authService.busy drops.
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final p = authService.profile;
    _name = TextEditingController(text: p?.name ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _age = p?.age;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool _validPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return true;
    if (digits.length == 12 && digits.startsWith('91')) return true;
    if (digits.length == 11 && digits.startsWith('0')) return true;
    return false;
  }

  Future<void> _continue() async {
    if (_submitting || authService.busy) return;
    final s = AgroScope.of(context).s;
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty || _age == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.fillAllFields)));
      return;
    }
    if (!_validPhone(_phone.text)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.errInvalidPhone)));
      return;
    }
    if (!_policy) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.acceptPolicyFirst)));
      return;
    }

    setState(() => _submitting = true);
    try {
      final ok = await authService.completeGoogleProfile(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        age: _age!,
        acceptedPolicy: _policy,
      );
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authService.error ?? s.errGeneric)),
        );
        return;
      }

      await profileService.updateProfile(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
      );
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final p = authService.profile;
    final canPop = Navigator.of(context).canPop();

    return PopScope(
      canPop: false,
      child: ListenableBuilder(
      listenable: authService,
      builder: (context, _) {
        return AuthScaffold(
          title: s.completeProfileTitle,
          subtitle: s.completeProfileSubtitle,
          showBack: canPop,
          child: SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (p?.email != null && p!.email.isNotEmpty)
                  SoftCard(
                    color: context.agroSoftFill,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.account_circle_rounded, color: AgroColors.gold),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.googleAccountInfo,
                                style: TextStyle(fontWeight: FontWeight.w800, color: context.agroText, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p.email,
                                style: TextStyle(color: context.agroMuted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: s.farmerName,
                    hintText: s.nameHint,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
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
                AgeDropdown(
                  value: _age,
                  onChanged: (v) => setState(() => _age = v),
                ),
                const SizedBox(height: 8),
                PolicyCheckbox(
                  value: _policy,
                  onChanged: (v) => setState(() => _policy = v),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: (authService.busy || _submitting)
                      ? ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(74),
                        )
                      : null,
                  onPressed:
                      (authService.busy || _submitting) ? null : _continue,
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
                            Text(
                              s.isHi ? 'बनाया जा रहा है' : 'Creating your account',
                            ),
                          ],
                        )
                      : Text(s.continueBtn),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: (authService.busy || _submitting)
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: ctx.agroCard,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                              title: Text(s.logoutConfirmTitle),
                              content: Text(s.logoutConfirmBody),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(s.deleteAccountCancel),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(s.logoutConfirmBtn),
                                ),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          await authService.logout();
                          if (context.mounted &&
                              Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: Text(s.logoutBtn),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.agroText,
                    side: BorderSide(color: context.agroBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      ),
    );
  }
}
