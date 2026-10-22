import 'package:flutter/material.dart';
import '../models/billing_cycle.dart';
import '../models/subscription_plan.dart';
import '../services/admin_live_sync.dart';
import '../services/agro_scope.dart';
import '../services/app_services.dart';
import '../services/page_analytics.dart';
import '../services/profile_service.dart';
import '../services/razorpay_checkout.dart';
import '../theme/app_theme.dart';
import '../widgets/soft_card.dart';
import '../widgets/crop_glyph.dart';

class SubscriptionScreen extends StatefulWidget {
  final ProfileService profileService;
  /// Prefer scrolling/highlighting this plan id (`all` = ₹599 Afim, `advanced` = ₹299).
  final String? highlightPlanId;

  const SubscriptionScreen({
    super.key,
    required this.profileService,
    this.highlightPlanId,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> with PageHit {
  @override
  String get analyticsPage => 'subscription';
  BillingCycle _cycle = BillingCycle.monthly;

  @override
  void initState() {
    super.initState();
    AdminLiveSync.instance.pull();
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: context.agroScaffold,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: context.agroHeaderGradient,
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.subscriptionTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.subscriptionSubtitle,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([widget.profileService, catalogService]),
              builder: (context, _) {
                final plans = catalogService.paidPlans.isNotEmpty
                    ? catalogService.paidPlans
                    : const [
                        SubscriptionPlan(tier: PlanTier.advanced, priceInr: 299, id: 'advanced'),
                        SubscriptionPlan(tier: PlanTier.allCrops, priceInr: 599, id: 'all'),
                        SubscriptionPlan(tier: PlanTier.superPro, priceInr: 2650, id: 'super'),
                        SubscriptionPlan(tier: PlanTier.distributor, priceInr: 13500, id: 'distributor'),
                      ];
                // Explicit padding disables ListView's automatic MediaQuery
                // inset handling, so add the system nav-bar inset ourselves.
                final bottomInset = MediaQuery.paddingOf(context).bottom;
                return ListView(
                  padding: EdgeInsets.fromLTRB(16, 18, 16, 24 + bottomInset),
                  children: [
                    SoftCard(
                      color: context.agroSoftGoldFill,
                      child: Text(
                        s.afimFocusNote,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                          color: context.agroText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Three equal cells; labels scale down (never wrap /
                    // overflow) so the selector fits a 320dp-wide phone.
                    // IntrinsicHeight gives the Row a bounded height inside
                    // the ListView so `stretch` can equalise the cells —
                    // without it the Row gets infinite height and the whole
                    // list below it fails to lay out.
                    IntrinsicHeight(
                      child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final cycle in BillingCycle.values)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Material(
                                color: _cycle == cycle
                                    ? (isDark ? AgroColors.sky : AgroColors.skyPrimary)
                                    : (isDark ? const Color(0xFF0B2942) : Colors.white),
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => setState(() => _cycle = cycle),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            cycle == BillingCycle.monthly
                                                ? s.cycleMonthly
                                                : cycle == BillingCycle.fourMonth
                                                    ? s.cycleFour
                                                    : s.cycleYear,
                                            maxLines: 1,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: _cycle == cycle
                                                  ? Colors.white
                                                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            cycle == BillingCycle.monthly
                                                ? s.monthlyAutopay
                                                : cycle == BillingCycle.yearly
                                                    ? s.off25
                                                    : s.off10,
                                            maxLines: 1,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: _cycle == cycle
                                                  ? Colors.white70
                                                  : context.agroMuted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (plans.isEmpty)
                      SoftCard(
                        child: Text(
                          s.isHi
                              ? 'प्लान अभी लोड नहीं हुए। थोड़ी देर बाद फिर कोशिश करें।'
                              : 'Plans are not available yet. Please try again shortly.',
                          style: TextStyle(color: context.agroMuted, height: 1.35),
                        ),
                      ),
                    ...plans.map((plan) {
                      // The user's current plan is active regardless of cycle:
                      // monthly autopay OR a one-time four-month / yearly plan.
                      final active =
                          widget.profileService.plan == plan.tier &&
                          plan.tier != PlanTier.free;
                      final isChatOnly = plan.tier == PlanTier.local;
                      final isLasun = plan.tier == PlanTier.advanced;
                      final isAfim = plan.tier == PlanTier.allCrops ||
                          plan.tier == PlanTier.superPro;
                      final highlighted = widget.highlightPlanId != null &&
                          (plan.id == widget.highlightPlanId ||
                              (widget.highlightPlanId == 'all' && isAfim) ||
                              (widget.highlightPlanId == 'advanced' && isLasun));

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: highlighted && !active
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(
                                    color: context.agroGold,
                                    width: 2,
                                  ),
                                )
                              : null,
                          child: SoftCard(
                          color: active ? null : context.agroCard,
                          premiumBorder: highlighted && !active,
                          gradient: active
                              ? (isDark
                                  ? AgroColors.premiumHeroDark
                                  : const LinearGradient(
                                      colors: [
                                        Color(0xFF032B43),
                                        Color(0xFF0284C7),
                                        Color(0xFF38BDF8),
                                      ],
                                    ))
                              : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.planName(plan.id),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        color: active ? Colors.white : context.agroText,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isAfim
                                          ? (isDark ? AgroColors.nightGold : AgroColors.gold)
                                          : isLasun
                                              ? (isDark
                                                  ? AgroColors.nightElevated
                                                  : AgroColors.mint)
                                              : (isDark
                                                  ? AgroColors.nightElevated
                                                  : AgroColors.skyIce),
                                      borderRadius: BorderRadius.circular(20),
                                      border: isDark
                                          ? Border.all(
                                              color: AgroColors.nightBorder.withValues(alpha: 0.8),
                                            )
                                          : null,
                                    ),
                                    child: Text(
                                      isAfim
                                          ? s.afimSpecialBadge
                                          : isLasun
                                              ? s.lasunSpecialBadge
                                              : s.chatOnlyBadge,
                                      style: TextStyle(
                                        color: isDark ? AgroColors.nightText : AgroColors.forest,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                s.planDesc(plan.id),
                                style: TextStyle(
                                  color: active
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : context.agroMuted,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _MiniTag(
                                    label: s.isHi ? '💬 चैट' : '💬 Chat',
                                    dark: active,
                                  ),
                                  if (!isChatOnly)
                                    _MiniTag(
                                      label: s.isHi ? '📚 कोर्स' : '📚 Courses',
                                      dark: active,
                                    ),
                                  if (isLasun || isAfim)
                                    _MiniTag(
                                      label: s.isHi ? '🧄 लहसुन' : '🧄 Garlic',
                                      dark: active,
                                    ),
                                  if (isAfim)
                                    _MiniTag(
                                      label: s.isHi ? 'अफीम' : 'Afim',
                                      leading: const CropGlyph(
                                        cropId: 'afim',
                                        size: 14,
                                      ),
                                      dark: active,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  // Price + strike-through + cycle label live in
                                  // a flexible Wrap so long amounts (e.g. ₹13500 /
                                  // ₹162000 yearly) wrap under the price instead
                                  // of overflowing the Row on narrow phones.
                                  Expanded(
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 2,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          s.priceLabel(_cycle.priceInr(plan.payInr)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            color: active
                                                ? AgroColors.skyIce
                                                : context.agroGold,
                                          ),
                                        ),
                                        if (_cycle.priceInr(plan.payInr) !=
                                            _cycle.compareAtInr(plan.priceInr))
                                          Text(
                                            '₹${_cycle.compareAtInr(plan.priceInr)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              decoration: TextDecoration.lineThrough,
                                              color: active
                                                  ? Colors.white70
                                                  : context.agroMuted,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        Text(
                                          _cycle == BillingCycle.monthly
                                              ? s.monthlyAutopay
                                              : s.payOnce,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: active
                                                ? Colors.white.withValues(alpha: 0.8)
                                                : context.agroMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: active || widget.profileService.paying
                                        ? null
                                        : () async {
                                            try {
                                              await widget.profileService.subscribe(
                                                plan,
                                                cycle: _cycle.apiValue,
                                              );
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  backgroundColor: AgroColors.deepGreen,
                                                  content: Text(
                                                    '${s.activePlan}: ${s.planName(plan.id)}',
                                                  ),
                                                ),
                                              );
                                            } on PaymentCancelled {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(s.paymentCancelled)),
                                              );
                                            } catch (e) {
                                              if (!context.mounted) return;
                                              final msg = e.toString();
                                              final text = msg.contains('login')
                                                  ? s.loginRequired
                                                  : s.paymentFailed;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(text)),
                                              );
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: active
                                          ? Colors.white24
                                          : (isDark ? AgroColors.nightGold : AgroColors.gold),
                                      foregroundColor: isDark && !active
                                          ? AgroColors.night
                                          : AgroColors.forest,
                                      disabledBackgroundColor: Colors.white24,
                                      disabledForegroundColor: Colors.white70,
                                    ),
                                    child: widget.profileService.paying && !active
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : Text(active ? s.activePlan : s.subscribeNow),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    }),
                    if (widget.profileService.plan != PlanTier.free)
                      TextButton(
                        onPressed: () async {
                          await widget.profileService.clearSubscription();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(s.cancelPlan)),
                          );
                        },
                        child: Text(
                          s.cancelPlan,
                          style: TextStyle(color: context.agroMuted),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final bool dark;
  final Widget? leading;

  const _MiniTag({required this.label, required this.dark, this.leading});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.15)
            : context.agroSoftFill,
        borderRadius: BorderRadius.circular(20),
        border: !dark && isDark
            ? Border.all(color: context.agroBorder.withValues(alpha: 0.7))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: dark ? Colors.white : context.agroText,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
