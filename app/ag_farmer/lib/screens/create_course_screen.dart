import 'package:flutter/material.dart';
import '../models/crop_item.dart';
import '../services/agro_scope.dart';
import '../services/app_services.dart';
import '../services/page_analytics.dart';
import '../theme/app_theme.dart';
import '../widgets/soft_card.dart';
import '../widgets/plan_unlock_sheet.dart';
import '../widgets/crop_glyph.dart';
import '../widgets/premium_crop_style.dart';
import '../widgets/create_custom_course_sheet.dart';
import 'crop_track_detail_screen.dart';

class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> with PageHit {
  @override
  String get analyticsPage => 'create_course';
  final _search = TextEditingController();
  String _query = '';
  bool _showAll = false;
  static const _previewCount = 12;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CropItem> get _crops {
    final all = catalogService.indiaCourseCrops();
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where(
          (c) =>
              c.nameEn.toLowerCase().contains(q) ||
              c.nameHi.contains(_query) ||
              c.id.contains(q),
        )
        .toList();
  }

  Future<void> _start(CropItem crop) async {
    final unlocked = await ensureCropAccess(context, profileService, crop);
    if (!unlocked || !mounted) return;
    try {
      final track = await cropTrackService.startTrack(crop);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => CropTrackDetailScreen(trackId: track.id)),
      );
    } catch (_) {
      if (!mounted) return;
      final s = AgroScope.of(context).s;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.loginRequired)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final hi = s.isHi;

    return ListenableBuilder(
      listenable: catalogService,
      builder: (context, _) {
        final crops = _crops;
        final featured = crops.where((c) => c.id == 'afim' || c.id == 'lasun').toList();
        final rest = crops.where((c) => c.id != 'afim' && c.id != 'lasun').toList();
        final searching = _query.isNotEmpty;
        final visibleRest = (searching || _showAll)
            ? rest
            : rest.take(_previewCount).toList();
        final hiddenCount = rest.length - visibleRest.length;

        return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: context.isDark
                    ? const [Color(0xFF031626), Color(0xFF082F49), Color(0xFF0369A1)]
                    : const [AgroColors.forest, AgroColors.deepGreen, AgroColors.mint],
              ),
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
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        ),
                        Expanded(
                          child: Text(
                            s.createCourseTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        Text(
                          '${crops.length}',
                          style: const TextStyle(
                            color: AgroColors.softGold,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        s.createCourseSubtitle,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.88), height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _search,
                        onChanged: (v) => setState(() => _query = v.trim()),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: s.searchCrops,
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                SoftCard(
                  onTap: () => showCreateNewCourseSheet(context),
                  color: context.agroSoftGoldFill,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AgroColors.gold.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: AgroColors.forest,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.createNewCourseTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: context.agroText,
                              ),
                            ),
                            Text(
                              s.createNewCourseSub,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.agroMuted,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: context.agroMuted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SoftCard(
                  color: context.agroSoftGoldFill,
                  child: Text(
                    s.createCoursePinNote,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: context.agroText,
                      height: 1.35,
                    ),
                  ),
                ),
                if (featured.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    s.topTargetCrops,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: context.agroText),
                  ),
                  const SizedBox(height: 10),
                  ...featured.map(
                    (c) => _CropPickTile(crop: c, hi: hi, featured: true, onTap: () => _start(c)),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  s.indiaCropsList,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: context.agroText),
                ),
                const SizedBox(height: 10),
                ...visibleRest.map(
                  (c) => _CropPickTile(crop: c, hi: hi, featured: false, onTap: () => _start(c)),
                ),
                if (!searching && (hiddenCount > 0 || _showAll)) ...[
                  const SizedBox(height: 6),
                  SoftCard(
                    onTap: () => setState(() => _showAll = !_showAll),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showAll ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          color: context.isDark ? AgroColors.mint : AgroColors.deepGreen,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _showAll ? s.seeLessCrops : s.seeMoreCrops(hiddenCount),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: context.isDark ? AgroColors.mint : AgroColors.deepGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

class _CropPickTile extends StatelessWidget {
  final CropItem crop;
  final bool hi;
  final bool featured;
  final VoidCallback onTap;

  const _CropPickTile({
    required this.crop,
    required this.hi,
    required this.featured,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final premium = PremiumCropStyle.of(crop.id);
    final card = SoftCard(
      onTap: onTap,
      color: premium?.fill(context) ??
          (featured ? context.agroSoftGoldFill : null),
      premiumBorder: premium != null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          CropGlyph.item(crop, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  crop.name(hi),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: premium?.accent ?? context.agroText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  premium != null
                      ? (crop.id == 'afim' || crop.id.startsWith('afim')
                          ? s.afimSpecialBadge
                          : s.lasunSpecialBadge)
                      : s.createCourseForCrop,
                  style: TextStyle(
                    color: premium != null
                        ? premium.badge.withValues(alpha: 0.9)
                        : context.agroMuted,
                    fontSize: 12,
                    fontWeight:
                        premium != null ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.play_circle_fill_rounded,
            color: premium?.badge ?? context.agroGold,
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: premium != null ? 8 : 0),
      child: PremiumCropFrame(
        cropId: crop.id,
        badgeLabel: s.premiumBadge,
        child: card,
      ),
    );
  }
}
