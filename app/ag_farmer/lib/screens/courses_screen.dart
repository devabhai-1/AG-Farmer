import 'package:flutter/material.dart';
import '../models/crop_item.dart';
import '../models/crop_track.dart';
import '../services/agro_scope.dart';
import '../services/app_services.dart';
import '../services/page_analytics.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_header.dart';
import '../widgets/soft_card.dart';
import '../widgets/crop_glyph.dart';
import '../widgets/premium_crop_style.dart';
import '../widgets/plan_unlock_sheet.dart';
import '../widgets/create_custom_course_sheet.dart';
import 'crop_track_detail_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> with PageHit {
  @override
  String get analyticsPage => 'courses_old';
  static const _previewCount = 10;
  bool _showAllCrops = false;

  Future<void> _openAddNew() async {
    await showCreateNewCourseSheet(context);
  }

  Future<void> _startCrop(CropItem crop) async {
    final unlocked = await ensureCropAccess(context, profileService, crop);
    if (!unlocked || !mounted) return;
    try {
      final existing = cropTrackService.tracks
          .where((t) => t.cropId == crop.id)
          .toList();
      if (existing.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CropTrackDetailScreen(trackId: existing.first.id),
          ),
        );
        return;
      }
      final track = await cropTrackService.startTrack(crop);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CropTrackDetailScreen(trackId: track.id),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      final s = AgroScope.of(context).s;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.loginRequired)),
      );
    }
  }

  Widget _cropTile(CropItem crop, {required bool hi}) {
    final s = AgroScope.of(context).s;
    final premium = PremiumCropStyle.of(crop.id);
    final card = SoftCard(
      onTap: () => _startCrop(crop),
      color: premium?.fill(context),
      premiumBorder: premium != null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          CropGlyph.item(crop, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  crop.name(hi),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
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
                    fontSize: 11.5,
                    fontWeight:
                        premium != null ? FontWeight.w700 : FontWeight.w500,
                    color: premium != null
                        ? premium.badge.withValues(alpha: 0.9)
                        : context.agroMuted,
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
      padding: EdgeInsets.only(bottom: 10, top: premium != null ? 8 : 0),
      child: PremiumCropFrame(
        cropId: crop.id,
        badgeLabel: s.premiumBadge,
        child: card,
      ),
    );
  }

  Widget _trackTile(CropTrack track, {required bool hi}) {
    final s = AgroScope.of(context).s;
    final latest = track.latestLog;
    final premium = PremiumCropStyle.of(track.cropId);
    final card = SoftCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CropTrackDetailScreen(trackId: track.id),
          ),
        );
      },
      color: premium?.fill(context),
      premiumBorder: premium != null,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: premium != null
                    ? [
                        premium.badge.withValues(alpha: 0.85),
                        premium.accent,
                      ]
                    : const [AgroColors.softMint, AgroColors.softGold],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: CropGlyph(
                cropId: track.cropId,
                emoji: track.emoji,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.name(hi),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: premium?.accent ?? context.agroText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  latest == null
                      ? s.noDailyLogsYet
                      : s.lastLogLine(
                          latest.dateKey,
                          (latest.moisture * 100).round(),
                        ),
                  style: TextStyle(color: context.agroMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: premium?.badge ?? context.agroMuted,
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 10, top: premium != null ? 6 : 0),
      child: PremiumCropFrame(
        cropId: track.cropId,
        badgeLabel: s.premiumBadge,
        child: card,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final hi = s.isHi;

    return Column(
      children: [
        PremiumHeader(
          title: s.courseTitle,
          subtitle: s.courseSubtitle,
          showBrand: true,
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: Listenable.merge([cropTrackService, catalogService]),
            builder: (context, _) {
              final tracks = cropTrackService.tracks;
              final all = catalogService.indiaCourseCrops();
              final featured = all
                  .where((c) => c.id == 'afim' || c.id == 'lasun')
                  .toList();
              final rest = all
                  .where((c) => c.id != 'afim' && c.id != 'lasun')
                  .toList();
              final visibleRest = _showAllCrops
                  ? rest
                  : rest.take(_previewCount).toList();
              final hiddenCount = rest.length - visibleRest.length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  SoftCard(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF03446E),
                        Color(0xFF0284C7),
                        Color(0xFF38BDF8),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.cropTrackBadge,
                          style: const TextStyle(
                            color: AgroColors.softGold,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.courseHero,
                          style: const TextStyle(
                            color: AgroColors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.courseAllCropsNote(all.length),
                          style: TextStyle(
                            color: AgroColors.white.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (featured.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      s.topTargetCrops,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: context.agroText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...featured.map((c) => _cropTile(c, hi: hi)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.indiaCropsList,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: context.agroText,
                          ),
                        ),
                      ),
                      Text(
                        '${all.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: context.agroMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (all.isEmpty)
                    SoftCard(
                      child: Text(
                        s.noJankariPosts,
                        style: TextStyle(color: context.agroMuted),
                      ),
                    )
                  else ...[
                    ...visibleRest.map((c) => _cropTile(c, hi: hi)),
                    if (hiddenCount > 0 || _showAllCrops) ...[
                      const SizedBox(height: 4),
                      SoftCard(
                        onTap: () =>
                            setState(() => _showAllCrops = !_showAllCrops),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _showAllCrops
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: context.isDark
                                  ? AgroColors.mint
                                  : AgroColors.deepGreen,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _showAllCrops
                                    ? s.seeLessCrops
                                    : s.seeMoreCrops(hiddenCount),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: context.isDark
                                      ? AgroColors.mint
                                      : AgroColors.deepGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  SoftCard(
                    onTap: _openAddNew,
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
                  const SizedBox(height: 20),
                  Text(
                    s.myCropTracks,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: context.agroText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (tracks.isEmpty)
                    SoftCard(
                      child: Text(
                        s.noCropTracksYet,
                        style:
                            TextStyle(color: context.agroMuted, height: 1.4),
                      ),
                    )
                  else
                    ...tracks.map((t) => _trackTile(t, hi: hi)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
