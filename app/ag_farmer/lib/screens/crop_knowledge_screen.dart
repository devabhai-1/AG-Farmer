import 'dart:async';

import 'package:flutter/material.dart';
import '../data/crop_knowledge.dart';
import '../models/crop_item.dart';
import '../services/agro_scope.dart';
import '../services/api_client.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../theme/front_style.dart';
import '../services/jankari_cache.dart';
import '../widgets/crop_glyph.dart';
import '../widgets/premium_crop_style.dart';
import '../widgets/announcement_strip.dart';
import 'crop_knowledge_article_screen.dart';

/// Fasal Jankari feed. Open without login.
class CropKnowledgeScreen extends StatefulWidget {
  const CropKnowledgeScreen({super.key});

  @override
  State<CropKnowledgeScreen> createState() => CropKnowledgeScreenState();
}

class CropKnowledgeScreenState extends State<CropKnowledgeScreen> {
  String _filterCropId = 'all';
  String _afimStage = 'all';
  String _lasunStage = 'all';
  static const _afimStageIds = ['all', 'sowing', 'day10', 'day30', 'day60'];
  static const _lasunStageIds = ['all', 'day1', 'day45', 'day60', 'end'];
  final _search = TextEditingController();
  String _query = '';
  Timer? _searchTimer;
  int _searchGen = 0;
  List<CropKnowledgePost>? _hits;
  bool _searching = false;
  bool _searchFailed = false;
  bool _loading = false;
  bool _ready = false;
  bool _loadFailed = false;
  String _cropLoading = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// Called again when the Jankari tab is opened.
  /// Cache already on screen stays; only a failed first load retries hard.
  void reload() {
    if (_loading) return;
    if (!_ready) {
      _bootstrap();
      return;
    }
    _syncIfNeeded();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _searchTimer?.cancel();
    final q = _query.trim();
    if (q.length < 2) {
      setState(() {
        _hits = null;
        _searching = false;
        _searchFailed = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchTimer = Timer(
      const Duration(milliseconds: 350),
      () => _runSearch(q),
    );
  }

  Future<void> _runSearch(String q) async {
    final gen = ++_searchGen;
    try {
      final res = await ApiClient.instance.call(
        'jankari.search',
        data: {'q': q, 'cropId': _filterCropId},
        timeout: const Duration(seconds: 20),
      );
      if (!mounted || gen != _searchGen || _query.trim() != q) return;
      final raw = res['posts'];
      final posts = <CropKnowledgePost>[];
      if (raw is List) {
        for (final row in raw) {
          if (row is! Map) continue;
          final post = CropKnowledgePost.fromApi(
            Map<String, dynamic>.from(row),
          );
          if (post.id.isNotEmpty && post.bodyHi.isNotEmpty) posts.add(post);
        }
      }
      setState(() {
        _hits = posts;
        _searching = false;
        _searchFailed = false;
      });
    } catch (_) {
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _hits = const [];
        _searching = false;
        _searchFailed = true;
      });
    }
  }

  List<CropKnowledgePost> _parsePosts(Object? raw) {
    if (raw is! List) return const [];
    final posts = <CropKnowledgePost>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final post = CropKnowledgePost.fromApi(Map<String, dynamic>.from(row));
      if (post.id.isNotEmpty && post.bodyHi.isNotEmpty) posts.add(post);
    }
    return posts;
  }

  Future<void> _bootstrap() async {
    if (_loading) return;
    _loading = true;
    if (mounted) setState(() => _loadFailed = false);

    final cached = await JankariCache.loadAll();
    if (cached.isNotEmpty) {
      CropKnowledge.replaceRemote(cached);
      _ready = true;
      _loading = false;
      if (mounted) setState(() => _loadFailed = false);
      await _syncIfNeeded();
      return;
    }

    final ok = await _downloadAll();
    _loading = false;
    if (ok) {
      _ready = true;
      if (mounted) setState(() => _loadFailed = false);
    } else if (mounted) {
      setState(() => _loadFailed = true);
    }
  }

  Future<void> _syncIfNeeded() async {
    try {
      final meta = await ApiClient.instance.call(
        'jankari.meta',
        timeout: const Duration(seconds: 12),
      );
      final stamp = '${meta['stamp'] ?? ''}';
      if (stamp.isEmpty) return;
      final local = await JankariCache.stampAll();
      if (local == stamp) return;
      await _downloadAll(stampHint: stamp);
      if (mounted) setState(() {});
    } catch (_) {
      // Keep the phone cache. Update waits for the next open.
    }
  }

  Future<bool> _downloadAll({String? stampHint}) async {
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        final res = await ApiClient.instance.call(
          'jankari.list',
          data: const {'cropId': 'all'},
          timeout: const Duration(seconds: 40),
        );
        final posts = _parsePosts(res['posts']);
        if (posts.isEmpty) throw Exception('empty');
        final stamp = stampHint ?? '${res['stamp'] ?? ''}';
        CropKnowledge.replaceRemote(posts);
        if (stamp.isNotEmpty) {
          await JankariCache.saveAll(posts, stamp);
        }
        return true;
      } catch (_) {
        if (attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 700 * (attempt + 1)),
          );
        }
      }
    }
    return false;
  }

  Future<void> _ensureCrop(String cropId) async {
    if (cropId == 'all' || cropId == 'afim' || cropId == 'lasun') {
      return;
    }
    if (_cropLoading == cropId) return;
    _cropLoading = cropId;
    if (mounted) setState(() {});
    try {
      final cached = await JankariCache.loadCrop(cropId);
      final localStamp = await JankariCache.stampCrop(cropId);
      if (cached.isNotEmpty) {
        CropKnowledge.upsertCrop(cropId, cached);
        if (mounted) setState(() {});
        try {
          final meta = await ApiClient.instance.call(
            'jankari.meta',
            data: {'cropId': cropId},
            timeout: const Duration(seconds: 12),
          );
          final remoteStamp = '${meta['stamp'] ?? ''}';
          if (remoteStamp.isNotEmpty && remoteStamp == localStamp) return;
        } catch (_) {
          return;
        }
      }

      final res = await ApiClient.instance.call(
        'jankari.list',
        data: {'cropId': cropId},
        timeout: const Duration(seconds: 40),
      );
      final posts = _parsePosts(res['posts']);
      if (posts.isEmpty) return;
      final stamp = '${res['stamp'] ?? ''}';
      CropKnowledge.upsertCrop(cropId, posts);
      if (stamp.isNotEmpty) {
        await JankariCache.saveCrop(cropId, posts, stamp);
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Keep whatever is already on screen.
    } finally {
      if (_cropLoading == cropId) _cropLoading = '';
      if (mounted) setState(() {});
    }
  }

  void _selectCrop(String cropId) {
    setState(() => _filterCropId = cropId);
    _scheduleSearch();
    _ensureCrop(cropId);
  }

  Future<void> _openFull(CropKnowledgePost post, CropItem? crop) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CropKnowledgeArticleScreen(post: post, crop: crop),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final crops = _orderedCrops(catalogService.indiaCourseCrops());
    final searching = _query.trim().length >= 2;
    final posts = _postsForStage(
      searching ? (_hits ?? const <CropKnowledgePost>[]) : _feed(),
    );

    return ListenableBuilder(
      listenable: authService,
      builder: (context, _) {
        return FrontScope(
          child: Column(
          children: [
            FrontBar(subtitle: s.jankariSubtitle),
            AnnouncementStrip(filterCropId: _filterCropId, crops: crops),
            ListenableBuilder(
              listenable: catalogService,
              builder: (context, _) {
                final liveCrops = _orderedCrops(
                  catalogService.indiaCourseCrops(),
                );
                return SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    children: [
                      _CropFilterChip(
                        label: s.allCropsFilter,
                        selected: _filterCropId == 'all',
                        onTap: () => _selectCrop('all'),
                      ),
                      for (final c in liveCrops)
                        _CropFilterChip(
                          label: c.name(s.isHi),
                          cropId: c.id,
                          selected: _filterCropId == c.id,
                          featured: c.id == 'afim' || c.id == 'lasun',
                          leading: CropGlyph.item(c, size: 22),
                          onTap: () => _selectCrop(c.id),
                        ),
                    ],
                  ),
                );
              },
            ),
            if (_filterCropId == 'afim')
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  children: [
                    for (final id in _afimStageIds)
                      _StageChip(
                        label: s.afimStageLabel(id),
                        selected: _afimStage == id,
                        onTap: () => setState(() => _afimStage = id),
                      ),
                  ],
                ),
              ),
            if (_filterCropId == 'lasun')
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  children: [
                    for (final id in _lasunStageIds)
                      _StageChip(
                        label: s.lasunStageLabel(id),
                        selected: _lasunStage == id,
                        onTap: () => setState(() => _lasunStage = id),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (value) {
                  setState(() => _query = value.trim());
                  _scheduleSearch();
                },
                textInputAction: TextInputAction.search,
                style: TextStyle(color: Face.of(context).ink, fontWeight: FontWeight.w700),
                cursorColor: Face.of(context).gold,
                decoration: InputDecoration(
                  hintText: s.searchJankari,
                  hintStyle: TextStyle(color: Face.of(context).muted),
                  prefixIcon: Icon(Icons.search_rounded, color: Face.of(context).gold),
                  filled: true,
                  fillColor: Face.of(context).field,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Face.of(context).line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Face.of(context).gold, width: 1.6),
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                            _scheduleSearch();
                          },
                          icon: Icon(Icons.close_rounded, color: Face.of(context).gold),
                        ),
                  isDense: true,
                ),
              ),
            ),
            if (_cropLoading.isNotEmpty)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: !_ready && _loading
                  ? const Center(child: CircularProgressIndicator())
                  : !_ready && _loadFailed && !searching
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              s.isHi
                                  ? 'पोस्ट लोड नहीं हुईं'
                                  : 'Posts did not load',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.agroMuted),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _bootstrap,
                            child: Text(
                              s.isHi ? 'फिर कोशिश करें' : 'Try again',
                            ),
                          ),
                        ],
                      ),
                    )
                  : searching && _searching && _hits == null
                  ? const Center(child: CircularProgressIndicator())
                  : posts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _searchFailed
                              ? s.searchJankariFail
                              : s.noJankariPosts,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.agroMuted),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: posts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final p = posts[i];
                        final crop = _cropById(crops, p.cropId);
                        return _PremiumArticleCard(
                          post: p,
                          crop: crop,
                          hindi: s.isHi,
                          minutes: s.readMinutesLabel(p.readMinutes),
                          openLabel: s.seeMoreArticle,
                          featuredLabel: s.isHi ? 'खास' : 'Special',
                          locked: false,
                          onOpen: () => _openFull(p, crop),
                        );
                      },
                    ),
            ),
          ],
        ),
        );
      },
    );
  }

  bool get _inSowingSeason {
    final now = DateTime.now();
    if (now.month == 9 && now.day >= 15) return true;
    return now.month == 10 || now.month == 11;
  }

  bool get _inDay10Season {
    final now = DateTime.now();
    return now.month == 11 && now.day >= 11;
  }

  bool get _inDay30Season {
    final now = DateTime.now();
    if (now.month == 12) return true;
    return now.month == 1 && now.day <= 20;
  }

  bool get _inDay60Season {
    final now = DateTime.now();
    if (now.month == 1 && now.day >= 21) return true;
    return now.month == 2 || now.month == 3 || now.month == 4;
  }

  String _phaseOf(CropKnowledgePost post) {
    if (post.phase == 'sowing' ||
        post.phase == 'day10' ||
        post.phase == 'day30' ||
        post.phase == 'day60' ||
        post.phase == 'day1' ||
        post.phase == 'day45' ||
        post.phase == 'end') {
      return post.phase;
    }
    if (post.id.startsWith('afim_s')) return 'day60';
    if (post.id.startsWith('afim_r')) return 'day30';
    if (post.id.startsWith('afim_q')) return 'day10';
    if (post.cropId == 'afim') return 'sowing';
    if (post.id.startsWith('lasun_a')) return 'day1';
    if (post.id.startsWith('lasun_b')) return 'day45';
    if (post.id.startsWith('lasun_c')) return 'day60';
    if (post.id.startsWith('lasun_d')) return 'end';
    return '';
  }

  List<CropKnowledgePost> _afimPhase(String phase) {
    final posts = CropKnowledge.forCrop(
      'afim',
    ).where((post) => !_genericPost(post) && _phaseOf(post) == phase).toList();
    posts.sort((a, b) => a.id.compareTo(b.id));
    return posts;
  }

  List<CropKnowledgePost> _postsForStage(List<CropKnowledgePost> posts) {
    if (_filterCropId == 'afim' && _afimStage != 'all') {
      return posts.where((post) => _phaseOf(post) == _afimStage).toList();
    }
    if (_filterCropId == 'lasun' && _lasunStage != 'all') {
      return posts.where((post) => _phaseOf(post) == _lasunStage).toList();
    }
    return posts;
  }

  List<CropKnowledgePost> _feed() {
    if (_filterCropId != 'all') {
      if (_filterCropId == 'afim') return _afimOrdered();
      return CropKnowledge.forCrop(
        _filterCropId,
      ).where((p) => !_genericPost(p)).toList();
    }
    // Always interleave afim + lasun + other crops. Season only changes
    // which afim phase comes first inside the afim slots — never hides mix.
    return _mixedAll();
  }

  List<CropKnowledgePost> _afimOrdered() {
    final sowing = _afimPhase('sowing');
    final young = _afimPhase('day10');
    final mid = _afimPhase('day30');
    final late = _afimPhase('day60');
    if (_inDay60Season) return [...late, ...mid, ...young, ...sowing];
    if (_inDay30Season) return [...mid, ...young, ...sowing, ...late];
    if (_inDay10Season) return [...young, ...sowing, ...mid, ...late];
    if (_inSowingSeason) return [...sowing, ...young, ...mid, ...late];
    return [...sowing, ...young, ...mid, ...late];
  }

  /// All Crops: afim, lasun and every other crop appear together.
  /// Roughly 2 afim : 1 lasun : 2 other, so the mix is visible from the first screen.
  List<CropKnowledgePost> _mixedAll() {
    final buckets = <String, List<CropKnowledgePost>>{
      'a': _afimOrdered(),
      'l': CropKnowledge.forCrop(
        'lasun',
      ).where((p) => !_genericPost(p)).toList(),
      'o': _otherCropsMixed(),
    };
    const pattern = [
      'a',
      'o',
      'l',
      'o',
      'a',
      'o',
      'a',
      'l',
      'o',
      'a',
      'o',
      'l',
      'o',
      'a',
      'o',
    ];
    final total = buckets.values.fold<int>(
      0,
      (sum, queue) => sum + queue.length,
    );
    final out = <CropKnowledgePost>[];
    final used = <String>{};
    var guard = 0;
    while (buckets.values.any((queue) => queue.isNotEmpty) &&
        guard < total + 2) {
      guard++;
      var placed = false;
      for (final key in pattern) {
        final queue = buckets[key]!;
        while (queue.isNotEmpty && used.contains(queue.first.id)) {
          queue.removeAt(0);
        }
        if (queue.isEmpty) continue;
        final post = queue.removeAt(0);
        used.add(post.id);
        out.add(post);
        placed = true;
      }
      if (!placed) break;
    }
    return out;
  }

  /// Round-robin across crops. Cap each crop so opening one crop's full
  /// 400 posts does not flood the All feed.
  List<CropKnowledgePost> _otherCropsMixed() {
    const perCrop = 12;
    final byCrop = <String, List<CropKnowledgePost>>{};
    for (final post in CropKnowledge.allPosts()) {
      if (post.cropId == 'afim' || post.cropId == 'lasun') {
        continue;
      }
      if (_genericPost(post)) continue;
      final bucket = byCrop.putIfAbsent(post.cropId, () => []);
      if (bucket.length >= perCrop) continue;
      bucket.add(post);
    }
    final mixed = <CropKnowledgePost>[];
    var pending = true;
    while (pending) {
      pending = false;
      for (final posts in byCrop.values) {
        if (posts.isEmpty) continue;
        mixed.add(posts.removeAt(0));
        pending = true;
      }
    }
    return mixed;
  }

  bool _genericPost(CropKnowledgePost post) {
    return post.id == '${post.cropId}_about' ||
        post.id == '${post.cropId}_stages' ||
        post.id == '${post.cropId}_diseases' ||
        post.id == '${post.cropId}_tips';
  }

  List<CropItem> _orderedCrops(List<CropItem> crops) {
    final afim = crops.where((c) => c.id == 'afim');
    final lasun = crops.where((c) => c.id == 'lasun');
    final rest = crops.where((c) => c.id != 'afim' && c.id != 'lasun');
    return [...afim, ...lasun, ...rest];
  }

  CropItem? _cropById(List<CropItem> crops, String id) {
    try {
      return crops.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}

class _PremiumArticleCard extends StatelessWidget {
  const _PremiumArticleCard({
    required this.post,
    required this.crop,
    required this.hindi,
    required this.minutes,
    required this.openLabel,
    required this.featuredLabel,
    required this.locked,
    required this.onOpen,
  });

  final CropKnowledgePost post;
  final CropItem? crop;
  final bool hindi;
  final String minutes;
  final String openLabel;
  final String featuredLabel;
  final bool locked;
  final VoidCallback onOpen;

  static const _palette = [
    Color(0xFF0F766E),
    Color(0xFFB45309),
    Color(0xFF0369A1),
    Color(0xFF4D7C0F),
    Color(0xFF9A3412),
    Color(0xFF6D28D9),
    Color(0xFFBE185D),
    Color(0xFF0E7490),
  ];

  Color get _accent {
    final style = PremiumCropStyle.of(post.cropId);
    if (style != null) return style.accent;
    return _palette[post.cropId.hashCode.abs() % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final style = PremiumCropStyle.of(post.cropId);
    final accent = _accent;
    final dark = context.isDark;
    final topA =
        style?.fillLight ??
        Color.lerp(accent, Colors.white, dark ? 0.12 : 0.88)!;
    final topB = style == null
        ? Color.lerp(
            accent,
            dark ? const Color(0xFF0B1220) : Colors.white,
            dark ? 0.55 : 0.72,
          )!
        : (dark
              ? style.fillDark
              : Color.lerp(style.fillLight, Colors.white, 0.35)!);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Color.lerp(accent, Colors.white, dark ? 0.55 : 0.35)!,
              width: style == null ? 1.1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: dark ? 0.28 : 0.16),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [
                      Color.lerp(const Color(0xFF0B1220), accent, 0.22)!,
                      const Color(0xFF0B1220),
                    ]
                  : [Colors.white, Color.lerp(Colors.white, accent, 0.06)!],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(23),
                ),
                child: SizedBox(
                  // Header holds crop name + pills; grow with font scale so
                  // large-text settings do not overflow the fixed band.
                  height: 108 *
                      MediaQuery.textScalerOf(context)
                          .scale(1.0)
                          .clamp(1.0, 1.4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: dark
                                ? [
                                    Color.lerp(accent, Colors.black, 0.35)!,
                                    accent,
                                    Color.lerp(accent, Colors.teal, 0.35)!,
                                  ]
                                : [topA, topB, Color.lerp(topB, accent, 0.28)!],
                          ),
                        ),
                      ),
                      Positioned(
                        right: -18,
                        top: -24,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(
                              alpha: dark ? 0.06 : 0.18,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -30,
                        bottom: -40,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(
                              alpha: dark ? 0.18 : 0.05,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: dark ? 0.14 : 0.92,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.55),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: CropGlyph(
                                cropId: crop?.id ?? post.cropId,
                                emoji: crop?.emoji ?? '🌾',
                                size: 34,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    crop?.name(hindi) ?? post.cropId,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: dark ? Colors.white : accent,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      if (style != null)
                                        _Pill(
                                          label: featuredLabel,
                                          color: style.badge,
                                          onDark: true,
                                        ),
                                      _Pill(
                                        label: CropKnowledge.categoryLabel(
                                          post.category,
                                          hindi,
                                        ),
                                        color: Colors.white.withValues(
                                          alpha: dark ? 0.16 : 0.88,
                                        ),
                                        foreground: dark
                                            ? Colors.white
                                            : accent,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 3,
                      width: 42,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            accent,
                            Color.lerp(accent, Colors.amber, 0.45)!,
                          ],
                        ),
                      ),
                    ),
                    Text(
                      post.title(hindi),
                      style: TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w900,
                        height: 1.28,
                        color: context.agroText,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      post.preview(hindi),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.agroMuted,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 15,
                          color: context.agroMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          minutes,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: context.agroMuted,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: dark ? 0.22 : 0.1),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                locked
                                    ? Icons.lock_outline_rounded
                                    : Icons.auto_stories_rounded,
                                size: 15,
                                color: accent,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                openLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : const Color(0xFF5B21B6),
          ),
        ),
        selected: selected,
        showCheckmark: false,
        selectedColor: const Color(0xFF6D28D9),
        backgroundColor: const Color(0xFFEDE9FE),
        side: const BorderSide(color: Color(0xFFC4B5FD)),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _CropFilterChip extends StatelessWidget {
  const _CropFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.featured = false,
    this.cropId,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final bool featured;
  final String? cropId;

  @override
  Widget build(BuildContext context) {
    final accent = cropId == 'afim'
        ? const Color(0xFF6D28D9)
        : cropId == 'lasun'
            ? const Color(0xFF047857)
            : (context.isDark ? AgroColors.mint : AgroColors.forest);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
            decoration: BoxDecoration(
              color: selected
                  ? accent
                  : (context.isDark ? const Color(0xFF122033) : Colors.white),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? accent
                    : (featured ? const Color(0xFFD4A017) : context.agroBorder),
                width: featured || selected ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (selected ? accent : Colors.black).withValues(
                    alpha: selected ? 0.28 : 0.06,
                  ),
                  blurRadius: selected ? 12 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 7)],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: featured || selected
                        ? FontWeight.w900
                        : FontWeight.w700,
                    color: selected ? Colors.white : context.agroText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    this.foreground,
    this.onDark = false,
  });

  final String label;
  final Color color;
  final Color? foreground;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: foreground ?? (onDark ? Colors.white : context.agroText),
        ),
      ),
    );
  }
}
