import 'package:flutter/material.dart';
import '../models/crop_item.dart';
import '../models/billing_cycle.dart';
import '../models/subscription_plan.dart';
import '../services/agro_scope.dart';
import '../services/app_services.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../screens/subscription_screen.dart';
import '../screens/auth/login_screen.dart';
import '../services/api_client.dart';
import 'soft_card.dart';
import 'crop_glyph.dart';

/// Lowest plan that unlocks this crop's course (mirrors the server's
/// `requiredRankForCrop`): Afim needs ₹599, every other crop needs ₹299.
PlanTier _minTierForCrop(CropItem? crop) {
  final id = crop?.id ?? '';
  if (id == 'afim' || id.startsWith('afim')) return PlanTier.allCrops;
  return PlanTier.advanced;
}

/// Fallback ladder when the catalog has not loaded yet.
const List<SubscriptionPlan> _fallbackPlans = [
  SubscriptionPlan(tier: PlanTier.advanced, priceInr: 299, id: 'advanced'),
  SubscriptionPlan(tier: PlanTier.allCrops, priceInr: 599, id: 'all'),
  SubscriptionPlan(tier: PlanTier.superPro, priceInr: 2650, id: 'super'),
  SubscriptionPlan(tier: PlanTier.distributor, priceInr: 13500, id: 'distributor'),
];

/// Plans to offer: the minimum plan for this content and every plan above
/// it, minus anything the user already has. Lower plans are never shown
/// (they would not unlock the content).
List<SubscriptionPlan> _plansFrom(PlanTier minTier) {
  final source = catalogService.paidPlans.isNotEmpty
      ? catalogService.paidPlans
      : _fallbackPlans;
  final current = profileService.plan.rank;
  final seen = <PlanTier>{};
  final out = <SubscriptionPlan>[];
  for (final p in source) {
    if (p.priceInr <= 0) continue;
    if (p.rank < minTier.rank || p.rank <= current) continue;
    if (!seen.add(p.tier)) continue;
    out.add(p);
  }
  out.sort((a, b) => a.rank.compareTo(b.rank));
  return out;
}

String _emojiFor(PlanTier tier) {
  switch (tier) {
    case PlanTier.advanced:
      return '🧄';
    case PlanTier.allCrops:
      return '🟢';
    case PlanTier.superPro:
      return '⭐';
    case PlanTier.distributor:
      return '🏪';
    default:
      return '🌾';
  }
}

/// Plan suggestions when creating a course / opening locked content.
/// - Afim → ₹599 and every plan above (₹2650, ₹13500)
/// - Lasun / other crops → ₹299 and every plan above
/// - AG Live (`forLiveVoice`) → ₹299 and above
/// - Treatment video (`forVideo`) → ₹299 and above; free gets 2/email/day on the server
Future<bool> showPlanUnlockSheet(
  BuildContext context, {
  CropItem? crop,
  PlanTier? requiredPlan,
  String? cropLabel,
  bool forLiveVoice = false,
  bool forVideo = false,
}) async {
  final s = AgroScope.of(context).s;
  final minTier = forVideo
      ? PlanTier.advanced
      : forLiveVoice
          ? PlanTier.advanced
          : crop != null
              ? _minTierForCrop(crop)
              : (requiredPlan ?? PlanTier.advanced);
  final options = _plansFrom(minTier);
  final isAfim = minTier == PlanTier.allCrops && !forVideo && !forLiveVoice;

  final name = forVideo
      ? (s.isHi ? 'इलाज वीडियो' : 'Treatment video')
      : forLiveVoice
      ? (s.isHi ? 'AG Live' : 'AG Live')
      : cropLabel ??
          (crop != null
              ? crop.name(s.isHi)
              : (isAfim ? (s.isHi ? 'अफीम' : 'Afim') : ''));

  String subtitleFor(SubscriptionPlan p) {
    if (forVideo) {
      return s.isHi
          ? 'इलाज वीडियो कॉल + ${s.planDesc(p.id)}'
          : 'Treatment video call + ${s.planDesc(p.id)}';
    }
    if (forLiveVoice) {
      return s.isHi ? 'AG Live + ${s.planDesc(p.id)}' : 'AG Live + ${s.planDesc(p.id)}';
    }
    return s.planDesc(p.id);
  }

  final chosen = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final media = MediaQuery.of(ctx);
      // Cap the sheet below the status bar and scroll its content so it
      // never overflows on short screens / landscape / with the keyboard
      // (the keyboard inset is absorbed by the Container's bottom padding).
      final maxHeight = media.size.height - media.padding.top - 24;
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 16,
          bottom: 16 + media.viewInsets.bottom,
        ),
        constraints: BoxConstraints(maxHeight: maxHeight > 0 ? maxHeight : 0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF082236) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF1B4E74) : const Color(0xFFBAE6FD),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                forVideo
                    ? (s.isHi ? 'वीडियो कॉल के लिए प्लान' : 'Plan for video call')
                    : forLiveVoice
                    ? (s.isHi ? 'AG Live के लिए प्लान' : 'Plan for AG Live')
                    : (s.isHi ? 'प्लान चुनें' : 'Choose a plan'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: isDark ? Colors.white : const Color(0xFF032B43),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                forVideo
                    ? (s.isHi
                        ? 'इलाज वीडियो कॉल ₹2650 और ₹13500 प्लान में है।'
                        : 'The treatment video call is on the ₹2650 and ₹13500 plans.')
                    : forLiveVoice
                    ? (s.isHi
                        ? 'लाइव आवाज़ सहायक के लिए कोई एक सब्सक्रिप्शन लें:'
                        : 'Pick a subscription to use the live voice assistant:')
                    : name.isEmpty
                        ? (s.isHi
                            ? 'कोर्स शुरू करने के लिए सही प्लान लें।'
                            : 'Pick the right plan to start this course.')
                        : (s.isHi
                            ? '$name कोर्स के लिए सुझाए गए प्लान:'
                            : 'Suggested plans for $name course:'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF4A728F),
                ),
              ),
              const SizedBox(height: 14),
              if (options.isEmpty)
                Text(
                  s.isHi
                      ? 'आपका मौजूदा प्लान इसे पहले से खोलता है।'
                      : 'Your current plan already unlocks this.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xFF4A728F),
                  ),
                ),
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _PlanOptionTile(
                  cropId: options[i].tier == PlanTier.allCrops ? 'afim' : null,
                  emoji: _emojiFor(options[i].tier),
                  title: options[i].hasSale
                      ? '₹${options[i].payInr} ${s.planName(options[i].id)}'
                      : '₹${options[i].priceInr} ${s.planName(options[i].id)}',
                  subtitle: subtitleFor(options[i]),
                  // The cheapest plan that unlocks the content is the
                  // suggestion; the rest are upgrades with more limits.
                  recommended: i == 0,
                  onTap: () => Navigator.pop(ctx, options[i].id),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  s.deleteAccountCancel,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF4A728F),
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      );
    },
  );

  if (chosen == null || !context.mounted) return false;

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SubscriptionScreen(
        profileService: profileService,
        highlightPlanId: chosen,
      ),
    ),
  );
  return true;
}

/// Shown when a logged-in chat or deep-research limit is finished.
Future<void> showLimitUpgradeSheet(BuildContext context) async {
  final s = AgroScope.of(context).s;
  final current = profileService.plan;
  final next = catalogService.paidPlans
      .where((p) => p.rank > current.rank && p.priceInr > 0)
      .toList()
    ..sort((a, b) => a.rank.compareTo(b.rank));
  if (next.isEmpty || !context.mounted) return;

  final chosen = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final media = MediaQuery.of(ctx);
      // `next` can hold several plans; cap height and scroll instead of
      // letting the Column overflow the screen.
      final maxHeight = media.size.height - media.padding.top - 24;
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + media.viewInsets.bottom),
        constraints: BoxConstraints(maxHeight: maxHeight > 0 ? maxHeight : 0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF082236) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF1B4E74) : const Color(0xFFBAE6FD),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.isHi ? 'लिमिट पूरी हो गई' : 'Limit used up',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.isHi
                    ? 'बड़ा प्लान लो, चैट और डीप रिसर्च की सीमा बढ़ जाएगी।'
                    : 'Upgrade your plan to raise chat and deep research limits.',
                style: TextStyle(
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 14),
              ...next.map(
                (plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PlanOptionTile(
                    emoji: '₹',
                    title: s.isHi
                        ? '₹${BillingCycle.monthly.priceInr(plan.payInr)} से ${plan.nameHi}'
                        : 'From ₹${BillingCycle.monthly.priceInr(plan.payInr)} ${plan.nameEn}',
                    subtitle: s.isHi
                        ? 'चैट ${plan.tier.chatDailyLimit}/दिन'
                        : 'Chat ${plan.tier.chatDailyLimit}/day',
                    recommended: plan.rank == next.first.rank,
                    onTap: () => Navigator.pop(ctx, plan.id),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  s.isHi ? 'अभी नहीं' : 'Not now',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
            ),
          ),
        ),
      );
    },
  );

  if (chosen == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SubscriptionScreen(
        profileService: profileService,
        highlightPlanId: chosen,
      ),
    ),
  );
}

/// AG Live: login first if needed, then both High plans if not subscribed.
Future<bool> ensureLiveVoiceAccess(BuildContext context) async {
  return true;
}

/// Video call: login + server quota. Free = 2/email/day. ₹299+ uses plan cap.
Future<bool> ensureVideoCallAccess(BuildContext context) async {
  if (!ApiClient.instance.hasSession) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    await profileService.syncSession();
    if (!context.mounted || !ApiClient.instance.hasSession) return false;
  }
  try {
    await ApiClient.instance.call('video.start', auth: true);
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    final msg = e.toString();
    final needsPlan = msg.contains('voice_upgrade') ||
        msg.contains('voice_credit') ||
        msg.contains('login_required');
    if (needsPlan) {
      await showPlanUnlockSheet(context, forVideo: true);
      return false;
    }
    final s = AgroScope.of(context).s;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.isHi
              ? 'वीडियो कॉल अभी नहीं खुली। एक बार फिर कोशिश करें।'
              : 'Video call did not open. Try once more.',
        ),
      ),
    );
    return false;
  }
}

Future<bool> ensureCropAccess(
  BuildContext context,
  ProfileService profile,
  CropItem crop,
) async {
  if (profile.canAccess(crop)) return true;
  await showPlanUnlockSheet(context, crop: crop);
  return profile.canAccess(crop);
}

class _PlanOptionTile extends StatelessWidget {
  const _PlanOptionTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.cropId,
    this.recommended = false,
  });

  final String? cropId;
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return SoftCard(
      onTap: onTap,
      remapSoftFills: false,
      premiumBorder: recommended,
      color: recommended
          ? (isDark ? const Color(0xFF0E314D) : const Color(0xFFE0F2FE))
          : (isDark ? const Color(0xFF0A2740) : Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          CropGlyph(cropId: cropId, emoji: emoji, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recommended)
                  Text(
                    AgroScope.of(context).s.isHi ? 'सुझाव' : 'Suggested',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: context.agroGold,
                    ),
                  ),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: context.agroText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: context.agroMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 16, color: context.agroGold),
        ],
      ),
    );
  }
}
