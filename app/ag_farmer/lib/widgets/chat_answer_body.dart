import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Renders GPT-style farming answers: headers, numbered points, bullets, bold.
class ChatAnswerBody extends StatelessWidget {
  const ChatAnswerBody({
    super.key,
    required this.text,
    this.onDark = false,
    this.compact = false,
  });

  final String text;
  final bool onDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final split = splitUseCaption(text);
    final blocks = parseChatAnswer(split.body);
    if (blocks.isEmpty && split.caption == null) {
      return const SizedBox.shrink();
    }
    final ink = onDark ? Colors.white : context.agroText;
    final head = onDark
        ? const Color(0xFF7DD3FC)
        : (context.isDark ? AgroColors.nightGold : AgroColors.skyDeep);
    final bodySize = compact ? 15.0 : 15.0;
    final pointSize = compact ? 17.0 : 18.5;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++)
          _block(
            context,
            blocks[i],
            first: i == 0,
            ink: ink,
            head: head,
            bodySize: bodySize,
            pointSize: pointSize,
          ),
        if (split.caption != null) ...[
          SizedBox(height: compact ? 10 : 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: onDark
                  ? const Color(0xFF3D3214)
                  : AgroColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: onDark
                    ? const Color(0xFFE8C56A)
                    : AgroColors.gold.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              split.caption!,
              style: TextStyle(
                color: onDark
                    ? const Color(0xFFF6D98A)
                    : (context.isDark
                        ? AgroColors.softGold
                        : const Color(0xFF5B3E00)),
                fontSize: compact ? 13 : 13.5,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _block(
    BuildContext context,
    ChatAnswerBlock block, {
    required bool first,
    required Color ink,
    required Color head,
    required double bodySize,
    required double pointSize,
  }) {
    final top = first
        ? 0.0
        : switch (block.kind) {
            ChatAnswerBlockKind.heading => compact ? 12.0 : 14.0,
            ChatAnswerBlockKind.numbered ||
            ChatAnswerBlockKind.bullet => compact ? 7.0 : 8.0,
            ChatAnswerBlockKind.paragraph => compact ? 6.0 : 8.0,
          };
    switch (block.kind) {
      case ChatAnswerBlockKind.heading:
        return Padding(
          padding: EdgeInsets.only(top: top, bottom: compact ? 4 : 6),
          child: Text.rich(
            TextSpan(children: _inlineSpans(block.text, head, 15.5, FontWeight.w900, 1.25)),
          ),
        );
      case ChatAnswerBlockKind.numbered:
        return Padding(
          padding: EdgeInsets.only(top: top),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 28 : 32,
                height: compact ? 28 : 32,
                margin: const EdgeInsets.only(top: 1, right: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: onDark
                      ? const Color(0xFF0369A1)
                      : AgroColors.skyPrimary.withValues(alpha: context.isDark ? 0.35 : 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: onDark
                        ? const Color(0xFF38BDF8)
                        : AgroColors.skyPrimary.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  '${block.number ?? 1}',
                  style: TextStyle(
                    color: onDark ? Colors.white : head,
                    fontSize: compact ? 13 : 15,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: _inlineSpans(block.text, ink, pointSize, FontWeight.w700, 1.35),
                  ),
                ),
              ),
            ],
          ),
        );
      case ChatAnswerBlockKind.bullet:
        return Padding(
          padding: EdgeInsets.only(top: top),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 14 : 16,
                height: compact ? 14 : 16,
                margin: EdgeInsets.only(top: compact ? 4 : 5, right: 10),
                decoration: BoxDecoration(
                  color: onDark ? const Color(0xFF38BDF8) : AgroColors.skyVibrant,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: _inlineSpans(block.text, ink, pointSize, FontWeight.w700, 1.35),
                  ),
                ),
              ),
            ],
          ),
        );
      case ChatAnswerBlockKind.paragraph:
        return Padding(
          padding: EdgeInsets.only(top: top),
          child: Text.rich(
            TextSpan(
              children: _inlineSpans(block.text, ink, bodySize, FontWeight.w500, 1.45),
            ),
          ),
        );
    }
  }

  List<InlineSpan> _inlineSpans(
    String raw,
    Color color,
    double size,
    FontWeight weight,
    double height,
  ) {
    final base = TextStyle(
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: height,
    );
    final bold = base.copyWith(fontWeight: FontWeight.w900);
    final spans = <InlineSpan>[];
    final source = _leadLabelMarkdown(raw);
    final re = RegExp(r'(\*\*[^*]+?\*\*|__[^_]+?__|`[^`]+?`)');
    var last = 0;
    for (final m in re.allMatches(source)) {
      if (m.start > last) {
        spans.add(TextSpan(text: source.substring(last, m.start), style: base));
      }
      final token = m.group(0)!;
      if (token.startsWith('`')) {
        spans.add(TextSpan(
          text: token.substring(1, token.length - 1),
          style: bold.copyWith(
            color: onDark ? const Color(0xFFBAE6FD) : AgroColors.skyDeepNavy,
            fontSize: size - 0.5,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: token.substring(2, token.length - 2),
          style: bold,
        ));
      }
      last = m.end;
    }
    if (last < source.length) {
      spans.add(TextSpan(text: source.substring(last), style: base));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: source, style: base));
    }
    return spans;
  }
}

enum ChatAnswerBlockKind { heading, numbered, bullet, paragraph }

class ChatAnswerBlock {
  const ChatAnswerBlock({
    required this.kind,
    required this.text,
    this.number,
  });

  final ChatAnswerBlockKind kind;
  final String text;
  final int? number;
}

final _headingNames = {
  'समस्या',
  'बीमारी',
  'कारण',
  'दवा',
  'दवाई',
  'मात्रा',
  'खुराक',
  'सावधानी',
  'फायदे',
  'लाभ',
  'पोषक तत्व',
  'तत्व',
  'खाद',
  'रोग',
  'इलाज',
  'लक्षण',
  'रोकथाम',
  'पहचान',
  'नुकसान',
  'उपाय',
  'सलाह',
  'ध्यान',
  'नोट',
  'कब',
  'कैसे',
  'कैसे दें',
  'कब दें',
  '10 आरी के हिसाब से',
  '10 आरी',
  'for 10 aari',
  'problem',
  'cause',
  'medicine',
  'dose',
  'caution',
  'benefit',
  'benefits',
  'harm',
  'harms',
  'treatment',
  'symptoms',
  'prevention',
  'nutrient',
  'fertilizer',
  'disease',
  'note',
  'advice',
  'how',
  'when',
};

const _useCaptions = {
  'यह एक बार डिस्ट्रीब्यूटर या खाद-बीज भंडार से पूछकर ही उपयोग करें।',
  'Use this only after asking your distributor or a fertilizer-seed store.',
};

({String body, String? caption}) splitUseCaption(String raw) {
  var body = raw.trim();
  String? caption;
  for (final line in _useCaptions) {
    if (body.contains(line)) {
      caption = line;
      body = body
          .replaceAll(line, '')
          .replaceAll('**उपयोग से पहले**', '')
          .replaceAll('**Before use**', '')
          .trim();
      break;
    }
  }
  return (body: body, caption: caption);
}

String _expandPointLines(String raw) {
  var t = raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(r'\n', '\n')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  t = t.replaceAllMapped(
    RegExp(r'(?<!^)(?<!\n)\s*(\*\*[^*]{1,40}\*\*)'),
    (m) => '\n${m[1]}',
  );
  t = t.replaceAllMapped(
    RegExp(r'(?<!^)(?<!\n)\s+(?=(\d{1,2}|[१-९])[.)]\s+\S)'),
    (_) => '\n',
  );
  t = t.replaceAllMapped(
    RegExp(r'(?<!^)(?<!\n)\s+(?=\(\d{1,2}\)\s+\S)'),
    (_) => '\n',
  );
  t = t.replaceAllMapped(
    RegExp(r'(?<!^)(?<!\n)\s+(?=[-•–]\s+\S)'),
    (_) => '\n',
  );
  return t;
}

List<ChatAnswerBlock> parseChatAnswer(String raw) {
  final cleaned = _expandPointLines(raw).trim();
  if (cleaned.isEmpty) return const [];
  final out = <ChatAnswerBlock>[];
  for (final original in cleaned.split('\n')) {
    var line = original.trim();
    if (line.isEmpty || line == '---' || line == '***' || line == '___') {
      continue;
    }
    if (line.startsWith('```')) continue;
    final hash = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
    if (hash != null) {
      out.add(ChatAnswerBlock(
        kind: ChatAnswerBlockKind.heading,
        text: hash.group(2)!.trim(),
      ));
      continue;
    }
    final numbered = RegExp(r'^(\d{1,2}|[१-९])[.)]\s+(.+)$').firstMatch(line) ??
        RegExp(r'^\((\d{1,2})\)\s+(.+)$').firstMatch(line);
    if (numbered != null) {
      out.add(ChatAnswerBlock(
        kind: ChatAnswerBlockKind.numbered,
        text: numbered.group(2)!.trim(),
        number: int.tryParse(numbered.group(1)!) ?? 0,
      ));
      continue;
    }
    final bullet = RegExp(r'^[-•–]\s+(.+)$').firstMatch(line) ??
        RegExp(r'^\*\s+(.+)$').firstMatch(line);
    if (bullet != null) {
      out.add(ChatAnswerBlock(
        kind: ChatAnswerBlockKind.bullet,
        text: bullet.group(1)!.trim(),
      ));
      continue;
    }
    final boldHead = RegExp(r'^\*{2}([^*]+?)\*{2}\s*:?\s*$').firstMatch(line);
    if (boldHead != null) {
      out.add(ChatAnswerBlock(
        kind: ChatAnswerBlockKind.heading,
        text: boldHead.group(1)!.replaceAll(RegExp(r'[:：]+$'), '').trim(),
      ));
      continue;
    }
    final labeledBody =
        RegExp(r'^\*{0,2}([^*:：]{1,28})\*{0,2}\s*[:：]\s+(.+)$').firstMatch(line);
    if (labeledBody != null && _isHeadingName(labeledBody.group(1)!)) {
      final label = labeledBody.group(1)!.trim();
      out.add(ChatAnswerBlock(
        kind: ChatAnswerBlockKind.numbered,
        text: '**$label:** ${labeledBody.group(2)!.trim()}',
      ));
      continue;
    }
    final labeled = RegExp(r'^\*{0,2}([^*:：]{1,28})\*{0,2}\s*[:：]\s*$').firstMatch(line);
    if (labeled != null && _isHeadingName(labeled.group(1)!)) {
      out.add(ChatAnswerBlock(
        kind: ChatAnswerBlockKind.heading,
        text: labeled.group(1)!.trim(),
      ));
      continue;
    }
    out.add(ChatAnswerBlock(kind: ChatAnswerBlockKind.paragraph, text: line));
  }
  var n = 0;
  final numbered = <ChatAnswerBlock>[];
  for (final block in out) {
    if (block.kind == ChatAnswerBlockKind.heading) {
      n = 0;
      numbered.add(block);
    } else if (block.kind == ChatAnswerBlockKind.numbered) {
      n += 1;
      numbered.add(ChatAnswerBlock(
        kind: ChatAnswerBlockKind.numbered,
        text: block.text,
        number: n,
      ));
    } else {
      numbered.add(block);
    }
  }
  return numbered;
}

bool _isHeadingName(String raw) {
  final name = raw.trim().toLowerCase();
  return _headingNames.contains(name) || _headingNames.contains(raw.trim());
}

String _leadLabelMarkdown(String raw) {
  if (raw.contains('**')) return raw;
  final m = RegExp(r'^([^:*]{1,28})[:：]\s+(.+)$').firstMatch(raw);
  if (m == null) return raw;
  final label = m.group(1)!.trim();
  if (!_isHeadingName(label) && label.split(RegExp(r'\s+')).length > 3) {
    return raw;
  }
  return '**$label:** ${m.group(2)!.trim()}';
}

/// Compact animated “thinking” bars used in chat / course typing rows.
class WorkMoment extends StatefulWidget {
  const WorkMoment({
    super.key,
    this.label = '',
    this.barsOnly = false,
    this.color,
  });

  final String label;
  final bool barsOnly;
  final Color? color;

  @override
  State<WorkMoment> createState() => _WorkMomentState();
}

class _WorkMomentState extends State<WorkMoment>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = widget.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? AgroColors.nightGold
            : AgroColors.deepGreen);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        final bars = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
                child: Container(
                  width: 3.5,
                  height: 8 + ((t + i * 0.22) % 1.0) * 10,
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: 0.55 + t * 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
          ],
        );
        if (widget.barsOnly || widget.label.trim().isEmpty) return bars;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            bars,
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ],
        );
      },
    );
  }
}
