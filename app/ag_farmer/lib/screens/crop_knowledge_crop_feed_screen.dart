import 'dart:math';

import 'package:flutter/material.dart';

import '../data/crop_knowledge.dart';
import '../models/crop_item.dart';
import '../services/agro_scope.dart';
import '../services/app_services.dart';
import '../services/page_analytics.dart';
import '../theme/app_theme.dart';
import '../widgets/crop_glyph.dart';
import '../widgets/premium_login_gate.dart';
import 'auth/login_screen.dart';
import 'crop_knowledge_article_screen.dart';

/// Full list of posts for one crop — opened from "सभी देखें".
class CropKnowledgeCropFeedScreen extends StatelessWidget {
  const CropKnowledgeCropFeedScreen({
    super.key,
    required this.cropId,
    this.crop,
  });

  final String cropId;
  final CropItem? crop;

  @override
  Widget build(BuildContext context) {
    PageAnalytics.instance.hit('jankari_feed', extra: cropId);
    final s = AgroScope.of(context).s;
    final hi = s.isHi;
    final item = crop ?? catalogService.cropById(cropId);
    final name = item?.name(hi) ?? cropId;
    final posts = CropKnowledge.forCrop(cropId)
        .where(
          (p) =>
              p.id != '${p.cropId}_about' &&
              p.id != '${p.cropId}_stages' &&
              p.id != '${p.cropId}_diseases' &&
              p.id != '${p.cropId}_tips',
        )
        .toList();

    return Scaffold(
      backgroundColor: context.agroScaffold,
      appBar: AppBar(
        title: Row(
          children: [
            CropGlyph(
              cropId: cropId,
              emoji: item?.emoji ?? '🌾',
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.relatedCropTitle(name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: posts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  s.noJankariPosts,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.agroMuted),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: posts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final post = posts[i];
                return _RelatedTile(
                  post: post,
                  crop: item,
                  hindi: hi,
                  onOpen: () => _open(context, post, item),
                );
              },
            ),
    );
  }

  Future<void> _open(
    BuildContext context,
    CropKnowledgePost post,
    CropItem? crop,
  ) async {
    final s = AgroScope.of(context).s;
    if (!authService.isLoggedIn) {
      final go = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: PremiumLoginGate(
            compact: true,
            emoji: '📖',
            badge: s.jankariLoginBadge,
            title: s.jankariLoginTitle,
            subtitle: s.jankariLoginBody,
            benefits: s.jankariLoginBenefits,
            ctaLabel: s.jankariLoginCta,
            onCta: () => Navigator.pop(ctx, true),
            secondaryLabel: s.deleteAccountCancel,
            onSecondary: () => Navigator.pop(ctx, false),
          ),
        ),
      );
      if (go != true || !context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (!context.mounted || !authService.isLoggedIn) return;
    }
    // Jankari is login-only: no plan gate for any crop.
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CropKnowledgeArticleScreen(post: post, crop: crop),
      ),
    );
  }
}

class _RelatedTile extends StatelessWidget {
  const _RelatedTile({
    required this.post,
    required this.crop,
    required this.hindi,
    required this.onOpen,
  });

  final CropKnowledgePost post;
  final CropItem? crop;
  final bool hindi;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.agroCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              CropGlyph(
                cropId: crop?.id ?? post.cropId,
                emoji: crop?.emoji ?? '🌾',
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title(hindi),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: context.agroText,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CropKnowledge.categoryLabel(post.category, hindi),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: context.agroMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.agroMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picks a fresh shuffled set of related posts for one open.
List<CropKnowledgePost> relatedPostsFor(
  CropKnowledgePost post, {
  int limit = 5,
}) {
  final pool = CropKnowledge.forCrop(post.cropId)
      .where((p) {
        if (p.id == post.id) return false;
        if (p.id == '${p.cropId}_about' ||
            p.id == '${p.cropId}_stages' ||
            p.id == '${p.cropId}_diseases' ||
            p.id == '${p.cropId}_tips') {
          return false;
        }
        return true;
      })
      .toList();
  pool.shuffle(Random());
  return pool.take(limit).toList();
}
