import 'package:flutter/material.dart';

import '../models/crop_item.dart';
import '../services/api_client.dart';
import '../services/agro_scope.dart';
import '../theme/app_theme.dart';

/// Thin strip of admin announcements (`announcement.list`).
class AnnouncementStrip extends StatefulWidget {
  const AnnouncementStrip({
    super.key,
    required this.filterCropId,
    required this.crops,
  });

  final String filterCropId;
  final List<CropItem> crops;

  @override
  State<AnnouncementStrip> createState() => _AnnouncementStripState();
}

class _AnnouncementStripState extends State<AnnouncementStrip> {
  List<_Ann> _posts = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AnnouncementStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterCropId != widget.filterCropId) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.call(
        'announcement.list',
        timeout: const Duration(seconds: 10),
      );
      final raw = res['posts'];
      final list = <_Ann>[];
      if (raw is List) {
        for (final row in raw) {
          if (row is! Map) continue;
          final m = Map<String, dynamic>.from(row);
          if (m['active'] == false) continue;
          final title = '${m['titleHi'] ?? m['title'] ?? ''}'.trim();
          final body = '${m['bodyHi'] ?? m['body'] ?? ''}'.trim();
          if (title.isEmpty && body.isEmpty) continue;
          list.add(
            _Ann(
              id: '${m['id'] ?? ''}',
              cropId: '${m['cropId'] ?? 'all'}',
              title: title,
              body: body,
            ),
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _posts = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<_Ann> get _visible {
    final id = widget.filterCropId;
    return _posts
        .where(
          (p) =>
              p.cropId == 'all' ||
              id == 'all' ||
              p.cropId == id ||
              (id == 'afim' && p.cropId.startsWith('afim')),
        )
        .take(8)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _visible.isEmpty) return const SizedBox.shrink();
    final s = AgroScope.of(context).s;
    final posts = _visible;

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        itemCount: posts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final p = posts[i];
          CropItem? crop;
          for (final c in widget.crops) {
            if (c.id == p.cropId) {
              crop = c;
              break;
            }
          }
          final tag = crop?.name(s.isHi) ??
              (p.cropId == 'all'
                  ? (s.isHi ? 'सभी' : 'All')
                  : p.cropId);
          return Material(
            color: context.agroSoftGoldFill,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(p.title.isEmpty ? tag : p.title),
                    content: Text(p.body.isEmpty ? p.title : p.body),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(s.isHi ? 'ठीक' : 'OK'),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                width: 220,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.agroBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: context.agroGold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.title.isNotEmpty ? p.title : p.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: context.agroText,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Ann {
  const _Ann({
    required this.id,
    required this.cropId,
    required this.title,
    required this.body,
  });

  final String id;
  final String cropId;
  final String title;
  final String body;
}
