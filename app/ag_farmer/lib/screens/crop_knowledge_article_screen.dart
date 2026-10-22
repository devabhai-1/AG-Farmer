import 'package:flutter/material.dart';
import '../data/crop_knowledge.dart';
import '../models/crop_item.dart';
import '../services/agro_scope.dart';
import '../services/api_client.dart';
import '../services/page_analytics.dart';
import '../services/app_services.dart';
import '../services/speech_speak_service.dart';
import '../theme/app_theme.dart';
import '../widgets/crop_glyph.dart';
import '../widgets/premium_crop_style.dart';
import 'crop_knowledge_crop_feed_screen.dart';

/// Full article page — shown after login via See more.
class CropKnowledgeArticleScreen extends StatefulWidget {
  const CropKnowledgeArticleScreen({
    super.key,
    required this.post,
    this.crop,
  });

  final CropKnowledgePost post;
  final CropItem? crop;

  @override
  State<CropKnowledgeArticleScreen> createState() =>
      _CropKnowledgeArticleScreenState();
}

class _CropKnowledgeArticleScreenState extends State<CropKnowledgeArticleScreen>
    with PageHit {
  @override
  String get analyticsPage => 'jankari_article';
  @override
  String? get analyticsExtra => widget.post.cropId;
  final _photos = PageController();
  int _photo = 0;
  late final List<CropKnowledgePost> _related;

  @override
  void initState() {
    super.initState();
    _related = relatedPostsFor(widget.post, limit: 5);
  }

  @override
  void dispose() {
    _photos.dispose();
    if (speechSpeakService.activeId == widget.post.id) {
      speechSpeakService.stop();
    }
    super.dispose();
  }

  Future<void> _toggleRead() async {
    final hi = AgroScope.of(context).s.isHi;
    final post = widget.post;
    if (speechSpeakService.activeId == post.id && speechSpeakService.isSpeaking) {
      await speechSpeakService.stop();
      return;
    }
    try {
      final text = '${post.title(hi)}। ${post.body(hi)}';
      await speechSpeakService.speakArticle(
        text,
        hindi: hi,
        id: post.id,
        postId: post.id,
        cropId: widget.crop?.id ?? post.cropId,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hi ? 'अभी बोल नहीं पाए' : 'Could not speak now'),
        ),
      );
    }
  }

  Color get _accent {
    final style = PremiumCropStyle.of(widget.post.cropId);
    if (style != null) return style.accent;
    const palette = [
      Color(0xFF0F766E),
      Color(0xFFB45309),
      Color(0xFF0369A1),
      Color(0xFF4D7C0F),
      Color(0xFF9A3412),
      Color(0xFF6D28D9),
    ];
    return palette[widget.post.cropId.hashCode.abs() % palette.length];
  }

  List<String> get _photoNames => widget.post.images
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .take(3)
      .toList();

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final hi = s.isHi;
    final post = widget.post;
    final crop = widget.crop;
    final paragraphs = post.paragraphs(hi);
    final cropName = crop?.name(hi) ?? post.cropId;
    final emoji = crop?.emoji ?? '🌾';
    final cropId = crop?.id ?? post.cropId;
    final accent = _accent;
    final photos = _photoNames;
    final dark = context.isDark;
    final showPhotos = photos.isNotEmpty;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF071018) : const Color(0xFFF7FAFC),
      floatingActionButton: ListenableBuilder(
        listenable: speechSpeakService,
        builder: (context, _) {
          final reading = speechSpeakService.activeId == post.id &&
              speechSpeakService.isSpeaking;
          return FloatingActionButton.extended(
            onPressed: _toggleRead,
            elevation: 8,
            backgroundColor: reading ? const Color(0xFFB45309) : accent,
            foregroundColor: Colors.white,
            icon: Icon(reading ? Icons.stop_rounded : Icons.volume_up_rounded),
            label: Text(
              reading ? (hi ? 'रोकें' : 'Stop') : (hi ? 'बोलें' : 'Speak'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          );
        },
      ),
      body: SelectionArea(
        child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: showPhotos ? 248 : 220,
            pinned: true,
            backgroundColor: accent,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
              title: Text(
                CropKnowledge.categoryLabel(post.category, hi),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              background: showPhotos
                  ? _ArticlePhotos(
                      names: photos,
                      controller: _photos,
                      index: _photo,
                      accent: accent,
                      onChanged: (i) => setState(() => _photo = i),
                      fallback: _PremiumHeader(
                        emoji: emoji,
                        cropId: cropId,
                        cropName: cropName,
                        accent: accent,
                      ),
                    )
                  : _PremiumHeader(
                      emoji: emoji,
                      cropId: cropId,
                      cropName: cropName,
                      accent: accent,
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: dark ? 0.22 : 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      cropName,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    post.title(hi),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.22,
                      color: context.agroText,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaChip(
                        icon: Icons.schedule_rounded,
                        label: s.readMinutesLabel(post.readMinutes),
                      ),
                      _MetaChip(
                        icon: Icons.article_outlined,
                        label: CropKnowledge.categoryLabel(post.category, hi),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 3,
                    width: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, const Color(0xFFF59E0B)],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final block = paragraphs[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: _SmartBlock(
                    text: block,
                    isDark: dark,
                    accent: accent,
                  ),
                );
              },
              childCount: paragraphs.length,
            ),
          ),
          if (_related.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.relatedPostsTitle,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: context.agroText,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CropKnowledgeCropFeedScreen(
                                  cropId: post.cropId,
                                  crop: crop ?? catalogService.cropById(post.cropId),
                                ),
                              ),
                            );
                          },
                          child: Text(
                            s.seeAllRelated,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final related in _related)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: context.agroCard,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => CropKnowledgeArticleScreen(
                                    post: related,
                                    crop: crop ??
                                        catalogService.cropById(related.cropId),
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                              child: Row(
                                children: [
                                  CropGlyph(
                                    cropId: post.cropId,
                                    emoji: emoji,
                                    size: 26,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          related.title(hi),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: context.agroText,
                                            height: 1.25,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          CropKnowledge.categoryLabel(
                                            related.category,
                                            hi,
                                          ),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: context.agroMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: context.agroMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: dark
                        ? [
                            Color.lerp(accent, Colors.black, 0.65)!,
                            const Color(0xFF0B1220),
                          ]
                        : [
                            Color.lerp(accent, Colors.white, 0.9)!,
                            Colors.white,
                          ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.jankariArticleFooter,
                        style: TextStyle(
                          color: context.agroMuted,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.agroSoftFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.agroBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.agroMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: context.agroMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartBlock extends StatelessWidget {
  const _SmartBlock({
    required this.text,
    required this.isDark,
    required this.accent,
  });
  final String text;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final headingOnly = RegExp(r'^\*\*(.+)\*\*$').firstMatch(text.trim());
    if (headingOnly != null) {
      return Text(
        headingOnly.group(1)!,
        style: TextStyle(
          fontSize: 17.5,
          fontWeight: FontWeight.w900,
          color: accent,
        ),
      );
    }

    final withHead = RegExp(r'^\*\*(.+?)\*\*\s*\n([\s\S]+)$').firstMatch(text);
    if (withHead != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            withHead.group(1)!,
            style: TextStyle(
              fontSize: 17.5,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          _RichBody(
            text: withHead.group(2)!.trim(),
            isDark: isDark,
            accent: accent,
          ),
        ],
      );
    }

    return _RichBody(text: text, isDark: isDark, accent: accent);
  }
}

String _jankariImageUrl(String name) {
  if (name.startsWith('http')) return name;
  final origin = ApiClient.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  return '$origin/media/jankari/$name';
}

class _ArticlePhotos extends StatelessWidget {
  const _ArticlePhotos({
    required this.names,
    required this.controller,
    required this.index,
    required this.accent,
    required this.onChanged,
    required this.fallback,
  });

  final List<String> names;
  final PageController controller;
  final int index;
  final Color accent;
  final ValueChanged<int> onChanged;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: controller,
          itemCount: names.length,
          onPageChanged: onChanged,
          itemBuilder: (context, i) {
            return Image.network(
              _jankariImageUrl(names[i]),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => fallback,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return ColoredBox(
                  color: accent.withValues(alpha: 0.35),
                  child: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66011422),
                Color(0x00011422),
                Color(0xE603446E),
              ],
              stops: [0, 0.45, 1],
            ),
          ),
        ),
        if (names.length > 1)
          Positioned(
            right: 16,
            bottom: 40,
            child: Row(
              children: [
                for (var i = 0; i < names.length; i++)
                  Container(
                    width: i == index ? 16 : 7,
                    height: 7,
                    margin: const EdgeInsets.only(left: 5),
                    decoration: BoxDecoration(
                      color: i == index ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader({
    required this.emoji,
    required this.cropId,
    required this.cropName,
    required this.accent,
  });

  final String emoji;
  final String cropId;
  final String cropName;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 42),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
            ),
            child: CropGlyph(cropId: cropId, emoji: emoji, size: 42),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              cropName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, const Color(0xFF0B1220), 0.25)!,
            accent,
            Color.lerp(accent, const Color(0xFF0D9488), 0.35)!,
          ],
        ),
      ),
      child: SafeArea(child: content),
    );
  }
}

class _RichBody extends StatelessWidget {
  const _RichBody({
    required this.text,
    required this.isDark,
    required this.accent,
  });
  final String text;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final t = line.trim();
        if (t.isEmpty) return const SizedBox(height: 6);
        if (t.startsWith('•') || RegExp(r'^\d+\)').hasMatch(t)) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.startsWith('•') ? '•' : '·',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: accent,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t
                        .replaceFirst(RegExp(r'^[•·]\s*'), '')
                        .replaceFirst(RegExp(r'^\d+\)\s*'), ''),
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.55,
                      fontWeight: FontWeight.w600,
                      color: context.agroText,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            t.replaceAll('**', ''),
            style: TextStyle(
              fontSize: 15.5,
              height: 1.58,
              fontWeight: FontWeight.w600,
              color: context.agroText,
            ),
          ),
        );
      }).toList(),
    );
  }
}
