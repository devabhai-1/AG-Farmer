import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../models/subscription_plan.dart';
import '../services/agro_scope.dart';
import '../services/app_services.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_header.dart';
import '../widgets/soft_card.dart';
import '../widgets/theme_toggle.dart';
import 'auth/google_complete_screen.dart';
import 'auth/login_screen.dart';
import 'crop_select_screen.dart';
import 'live_support_screen.dart';
import 'subscription_screen.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/crop_glyph.dart';

class ProfileScreen extends StatefulWidget {
  final ProfileService profileService;

  const ProfileScreen({super.key, required this.profileService});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profileService.name);
    _phoneCtrl = TextEditingController(text: widget.profileService.phone);
    widget.profileService.addListener(_syncFields);
    authService.addListener(_syncFromAuth);
    _syncFromAuth();
  }

  void _syncFields() {
    if (_nameCtrl.text != widget.profileService.name) {
      _nameCtrl.text = widget.profileService.name;
    }
    if (_phoneCtrl.text != widget.profileService.phone) {
      _phoneCtrl.text = widget.profileService.phone;
    }
  }

  void _syncFromAuth() {
    final p = authService.profile;
    if (p == null) return;
    if (p.name.isNotEmpty && _nameCtrl.text != p.name) {
      _nameCtrl.text = p.name;
    }
    if (p.phone.isNotEmpty && _phoneCtrl.text != p.phone) {
      _phoneCtrl.text = p.phone;
    }
  }

  @override
  void dispose() {
    widget.profileService.removeListener(_syncFields);
    authService.removeListener(_syncFromAuth);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _planLabel(S s, PlanTier plan) {
    switch (plan) {
      case PlanTier.local:
        return s.planName('local');
      case PlanTier.advanced:
        return s.planName('advanced');
      case PlanTier.allCrops:
        return s.planName('all');
      case PlanTier.superPro:
        return s.planName('super');
      case PlanTier.distributor:
        return s.planName('distributor');
      case PlanTier.free:
        return s.freePlan;
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, S s) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: ctx.agroCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AgroColors.danger.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_forever_rounded, color: AgroColors.danger, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.deleteAccountTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: ctx.agroText,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            s.deleteAccountWarning,
            style: TextStyle(color: ctx.agroMuted, fontSize: 13.5, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.deleteAccountCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AgroColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(s.deleteAccountConfirm),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(s.deletingAccount),
          ],
        ),
        duration: const Duration(seconds: 5),
      ),
    );

    final success = await authService.deleteAccount();
    if (!mounted) return;

    messenger.hideCurrentSnackBar();
    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(s.deleteAccountSuccess),
          backgroundColor: AgroColors.leaf,
        ),
      );
    } else {
      final error = authService.error;
      final msg = error == 'requires-recent-login'
          ? s.deleteAccountReauth
          : (error ?? s.errGeneric);
      messenger.showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AgroColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final profile = widget.profileService;

    return ListenableBuilder(
      listenable: Listenable.merge([profile, authService]),
      builder: (context, _) {
        if (authService.isLoggedIn && authService.needsProfileCompletion) {
          return const GoogleCompleteScreen();
        }

        if (!authService.isLoggedIn) {
          return _LoggedOutProfile(s: s);
        }

        final selected = profile.selectedCrops;
        final authProfile = authService.profile;
        final displayName = (authProfile?.name.isNotEmpty ?? false)
            ? authProfile!.name
            : (profile.name.isEmpty ? s.myProfile : profile.name);
        final displayPhone = (authProfile?.phone.isNotEmpty ?? false)
            ? authProfile!.phone
            : (profile.phone.isEmpty ? (authProfile?.email ?? '') : profile.phone);

        return Column(
          children: [
            PremiumHeader(
              title: s.profileTitle,
              subtitle: s.profileSubtitle,
              showBrand: true,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                children: [
                  SoftCard(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF032B43), Color(0xFF0284C7), Color(0xFF38BDF8)],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AgroColors.gold),
                          ),
                          child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                displayPhone,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (authProfile?.email.isNotEmpty ?? false) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${s.signedInAs} ${authProfile!.email}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AgroColors.gold,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${s.currentPlan}: ${_planLabel(s, profile.plan)}',
                                  style: const TextStyle(
                                    color: AgroColors.forest,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SoftCard(
                    color: context.agroSoftGoldFill,
                    child: Text(
                      s.afimFocusNote,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.isDark ? AgroColors.nightGold : AgroColors.forest,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.themeSettings,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: context.agroText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.themeSettingsSub,
                          style: TextStyle(color: context.agroMuted, fontSize: 12.5),
                        ),
                        const SizedBox(height: 12),
                        const ThemeModeSegment(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.editProfile,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: context.agroText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: s.farmerName,
                            hintText: s.nameHint,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: s.phoneNumber,
                            hintText: s.phoneHint,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              await profile.updateProfile(
                                name: _nameCtrl.text,
                                phone: _phoneCtrl.text,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(s.profileSaved)),
                              );
                            },
                            child: Text(s.saveProfile),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SoftCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SubscriptionScreen(profileService: profile),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: context.agroSoftFill,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.workspace_premium_rounded, color: context.agroGold),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.manageSubscription,
                                style: TextStyle(fontWeight: FontWeight.w900, color: context.agroText),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${s.currentPlan}: ${_planLabel(s, profile.plan)}',
                                style: TextStyle(color: context.agroMuted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: context.agroMuted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SoftCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LiveSupportScreen()),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: context.agroSoftFill,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.support_agent_rounded, color: context.agroGold),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.liveSupportMenu,
                                style: TextStyle(fontWeight: FontWeight.w900, color: context.agroText),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s.liveSupportMenuSub,
                                style: TextStyle(color: context.agroMuted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: context.agroMuted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SoftCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CropSelectScreen(profileService: profile),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: context.agroSoftFill,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.eco_rounded,
                            color: context.isDark ? AgroColors.mint : AgroColors.deepGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.selectCrops,
                                style: TextStyle(fontWeight: FontWeight.w900, color: context.agroText),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selected.isEmpty
                                    ? s.noCropsSelected
                                    : s.cropsCount(selected.length),
                                style: TextStyle(color: context.agroMuted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: context.agroMuted),
                      ],
                    ),
                  ),
                  if (selected.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      s.selectedCrops,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: context.agroText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selected.map((c) {
                        return Chip(
                          avatar: CropGlyph.item(c, size: 18),
                          label: Text(c.name(s.isHi)),
                          backgroundColor:
                              c.priority <= 2 ? context.agroSoftGoldFill : context.agroSoftFill,
                        );
                      }).toList(),
                    ),
                  ],
                  if (profile.hasAfimLive) ...[
                    const SizedBox(height: 16),
                    SoftCard(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF032B43), Color(0xFF0284C7), Color(0xFF38BDF8)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.liveAnalysis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.isHi
                                ? 'सुपर प्रो में अफीम लाइव एनालिसिस कोर्स सक्रिय है।'
                                : 'Afim Live Analysis course is active on Super Pro.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Legal & Privacy Policy
                  SoftCard(
                    onTap: () => showPolicyDialog(context, terms: false),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: context.agroSoftFill,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            color: context.isDark ? AgroColors.mint : AgroColors.deepGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.legalAndPrivacyTitle,
                                style: TextStyle(fontWeight: FontWeight.w900, color: context.agroText),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s.legalAndPrivacySubtitle,
                                style: TextStyle(color: context.agroMuted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: context.agroMuted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  // Danger Zone (Logout & Delete Account)
                  Text(
                    s.dangerZoneTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: context.agroTextMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await authService.logout();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.agroText,
                            side: BorderSide(color: context.agroBorder),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: Text(s.logoutBtn),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmDeleteAccount(context, s),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AgroColors.danger,
                            side: const BorderSide(color: AgroColors.danger),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.delete_forever_rounded, size: 18),
                          label: Text(s.deleteAccountBtn),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'AG Farmer v1.0.0 • AI Agriculture Assistant',
                      style: TextStyle(fontSize: 11, color: context.agroMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LoggedOutProfile extends StatelessWidget {
  final S s;

  const _LoggedOutProfile({required this.s});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PremiumHeader(
          title: s.profileTitle,
          subtitle: s.loginRequired,
          showBrand: true,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              SoftCard(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF03446E), Color(0xFF0284C7), Color(0xFF38BDF8)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.welcomeBack,
                      style: const TextStyle(
                        color: AgroColors.softGold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.loginRequired,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                        icon: const Icon(Icons.login_rounded),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AgroColors.forest,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        label: Text(
                          s.loginBtn,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.themeSettings,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: context.agroText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.themeSettingsSub,
                      style: TextStyle(color: context.agroMuted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 12),
                    const ThemeModeSegment(),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SoftCard(
                onTap: () => showPolicyDialog(context, terms: false),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.agroSoftFill,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        color: context.isDark ? AgroColors.mint : AgroColors.deepGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.legalAndPrivacyTitle,
                            style: TextStyle(fontWeight: FontWeight.w900, color: context.agroText),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.legalAndPrivacySubtitle,
                            style: TextStyle(color: context.agroMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: context.agroMuted),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'AG Farmer v1.0.0 • AI Agriculture Assistant',
                  style: TextStyle(fontSize: 11, color: context.agroMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
