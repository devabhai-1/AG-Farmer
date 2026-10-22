import 'package:flutter/material.dart';
import '../models/crop_item.dart';
import '../models/subscription_plan.dart';
import '../services/agro_scope.dart';
import '../services/app_services.dart';
import '../services/page_analytics.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/soft_card.dart';
import '../widgets/plan_unlock_sheet.dart';
import '../widgets/crop_glyph.dart';

class CropSelectScreen extends StatefulWidget {
  final ProfileService profileService;

  const CropSelectScreen({super.key, required this.profileService});

  @override
  State<CropSelectScreen> createState() => _CropSelectScreenState();
}

class _CropSelectScreenState extends State<CropSelectScreen> with PageHit {
  @override
  String get analyticsPage => 'crop_select';
  final _search = TextEditingController();
  late Set<String> _draft;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _draft = {...widget.profileService.selectedCropIds};
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _minPlanLabel(CropItem crop, dynamic s) {
    switch (crop.minPlan) {
      case PlanTier.local:
        return s.planName('local') as String;
      case PlanTier.advanced:
        return s.planName('advanced') as String;
      case PlanTier.allCrops:
        return s.planName('all') as String;
      case PlanTier.superPro:
        return s.planName('super') as String;
      case PlanTier.distributor:
        return s.planName('distributor') as String;
      case PlanTier.free:
        return s.freePlan as String;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final profile = widget.profileService;
    final hi = s.isHi;

    return ListenableBuilder(
      listenable: Listenable.merge([profile, catalogService]),
      builder: (context, _) {
        final all = catalogService.crops;
        final filtered = all.where((c) {
          if (_query.isEmpty) return true;
          final q = _query.toLowerCase();
          return c.nameEn.toLowerCase().contains(q) ||
              c.nameHi.contains(_query) ||
              c.id.contains(q);
        }).toList();

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
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                s.cropCatalogTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            Text(
                              '${filtered.length}',
                              style: TextStyle(
                                color: context.isDark
                                    ? AgroColors.nightGold
                                    : AgroColors.softGold,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: TextField(
                            controller: _search,
                            onChanged: (v) => setState(() => _query = v.trim()),
                            style: const TextStyle(color: Colors.white),
                            cursorColor: Colors.white,
                            decoration: InputDecoration(
                              hintText: s.searchCrops,
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: Colors.white70,
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SoftCard(
                  color: context.agroSoftGoldFill,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    s.afimFocusNote,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      height: 1.3,
                      color: context.agroText,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final crop = filtered[index];
                    final unlocked = profile.canAccess(crop);
                    final selected = _draft.contains(crop.id);
                    final isTarget = crop.priority <= 2;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SoftCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        color: isTarget ? context.agroSoftGoldFill : null,
                        onTap: () {
                          if (!unlocked) {
                            showPlanUnlockSheet(context, crop: crop);
                            return;
                          }
                          setState(() {
                            if (selected) {
                              _draft.remove(crop.id);
                            } else {
                              _draft.add(crop.id);
                            }
                          });
                        },
                        child: Row(
                          children: [
                            CropGlyph.item(crop, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          crop.name(hi),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: unlocked
                                                ? context.agroText
                                                : context.agroMuted,
                                          ),
                                        ),
                                      ),
                                      if (isTarget) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: context.isDark
                                                ? AgroColors.nightGold
                                                : AgroColors.gold,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            s.targetBadge,
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                              color: context.isDark
                                                  ? AgroColors.night
                                                  : AgroColors.forest,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (crop.hasLiveAnalysis) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.podcasts_rounded,
                                          size: 16,
                                          color: unlocked
                                              ? context.agroGold
                                              : context.agroMuted,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${s.unlockWith} ${_minPlanLabel(crop, s)}'
                                    '${crop.hasLiveAnalysis ? ' • ${s.liveAnalysis}' : ''}',
                                    style: TextStyle(
                                      color: context.agroMuted,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!unlocked)
                              Icon(Icons.lock_rounded, color: context.agroMuted)
                            else
                              Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                color: selected
                                    ? context.agroGold
                                    : context.agroMuted,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: ColoredBox(
            color: context.agroNavBg,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await profile.setSelectedCrops(_draft);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.cropsSaved)),
                      );
                      Navigator.pop(context);
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.loginRequired)),
                      );
                    }
                  },
                  child: Text('${s.saveCropSelection} (${_draft.length})'),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
