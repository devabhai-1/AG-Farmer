import '../platform/local_file.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chat_message.dart';
import '../models/crop_item.dart';
import '../models/subscription_plan.dart';
import '../services/agro_scope.dart';
import '../services/app_services.dart';
import '../services/page_analytics.dart';
import '../services/crop_course_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_answer_body.dart';
import '../widgets/crop_glyph.dart';
import '../widgets/soft_card.dart';

/// One calendar, two options: what already happened, and the next 15 days.
class CourseCalendarScreen extends StatefulWidget {
  const CourseCalendarScreen({super.key, required this.cropId});

  final String cropId;

  @override
  State<CourseCalendarScreen> createState() => _CourseCalendarScreenState();
}

enum _CalSide { done, ahead }

class _CourseCalendarScreenState extends State<CourseCalendarScreen> with PageHit {
  @override
  String get analyticsPage => 'course_calendar';
  @override
  String? get analyticsExtra => widget.cropId;
  /// Done: page 0 = this month, higher = older. Ahead: page 0 = this month, 1 = next.
  late final PageController _pageCtrl;
  late DateTime _month;
  DateTime? _selected;
  _CalSide _side = _CalSide.ahead;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime _calendarDay(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dayLine(DateTime day, bool hi) {
    const hiMonths = [
      'जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
      'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर',
    ];
    const enMonths = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final month = hi ? hiMonths[day.month - 1] : enMonths[day.month - 1];
    return '${day.day} $month ${day.year}';
  }

  DateTime get _thisMonth {
    final n = DateTime.now();
    return DateTime(n.year, n.month);
  }

  @override
  void initState() {
    super.initState();
    _month = _thisMonth;
    _selected = _today;
    _pageCtrl = PageController();
    cropCourseService.loadAhead(widget.cropId);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  CropItem? get _crop {
    try {
      return catalogService.crops.firstWhere((c) => c.id == widget.cropId);
    } catch (_) {
      final e = cropCourseService.enrollmentFor(widget.cropId);
      if (e == null) return null;
      return CropItem(
        id: e.cropId,
        nameEn: e.nameEn,
        nameHi: e.nameHi,
        emoji: e.emoji,
        minPlan: PlanTier.advanced,
        priority: 500,
      );
    }
  }

  DateTime get _aheadEnd => _today.add(const Duration(days: 14));

  bool get _aheadHasNext {
    final end = _aheadEnd;
    return end.year != _today.year || end.month != _today.month;
  }

  /// Done walks backward. Ahead walks one month forward when the 15 days cross.
  DateTime _monthForPage(int page) {
    if (_side == _CalSide.ahead) {
      return DateTime(_thisMonth.year, _thisMonth.month + page);
    }
    return DateTime(_thisMonth.year, _thisMonth.month - page);
  }

  void _setSide(_CalSide side) {
    if (_side == side) return;
    if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(0);
    setState(() {
      _side = side;
      _month = _thisMonth;
      _selected = _today;
    });
    if (side == _CalSide.ahead) cropCourseService.loadAhead(widget.cropId);
  }

  int get _currentPage => _pageCtrl.hasClients
      ? (_pageCtrl.page?.round() ?? 0)
      : 0;

  void _goOlder() {
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _goNewer() {
    if (_currentPage <= 0) return;
    _pageCtrl.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _addNote() async {
    final s = AgroScope.of(context).s;
    if (_side != _CalSide.done) return;
    final day = _selected ?? _today;
    if (day.isAfter(_today)) return;
    final titleCtrl = TextEditingController();
    final detailCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.courseCalAddNote),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(labelText: s.courseCalNoteTitle),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detailCtrl,
                maxLines: 3,
                decoration: InputDecoration(labelText: s.courseCalNoteDetail),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.deleteAccountCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.ok),
          ),
        ],
      ),
    );
    final title = titleCtrl.text;
    final detail = detailCtrl.text;
    titleCtrl.dispose();
    detailCtrl.dispose();
    if (ok != true || title.trim().isEmpty) return;
    await cropCourseService.addManualNote(
      cropId: widget.cropId,
      day: day,
      title: title,
      detail: detail,
    );
  }

  String _monthTitle(DateTime m, bool hi) {
    const en = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const hiM = [
      'जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
      'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर'
    ];
    return '${hi ? hiM[m.month - 1] : en[m.month - 1]} ${m.year}';
  }

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final crop = _crop;
    final enroll = cropCourseService.enrollmentFor(widget.cropId);
    final ahead = _side == _CalSide.ahead;
    final canGoBack = ahead ? _currentPage > 0 : true;
    final canGoForward = ahead ? (_aheadHasNext && _currentPage == 0) : _currentPage > 0;

    return Scaffold(
      backgroundColor: context.agroScaffold,
      appBar: AppBar(
        title: Text(
          s.courseCalendarTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: s.courseCalAddNote,
            onPressed: _addNote,
            icon: const Icon(Icons.note_add_rounded),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: cropCourseService,
        builder: (context, _) {
          final dayChats = _selected == null
              ? const <ChatMessage>[]
              : cropCourseService
                  .messagesOnDay(widget.cropId, _selected!)
                  .where((m) => !m.id.startsWith('summary_'))
                  .toList();
          final dayPoints = _selected == null || ahead
              ? const <CourseDayPoint>[]
              : cropCourseService.pointsForDay(
                  widget.cropId,
                  _selected!,
                  hi: s.isHi,
                );
          final aheadTasks = !ahead || _selected == null
              ? const <CourseAheadTask>[]
              : cropCourseService.aheadOn(widget.cropId, _selected!);
          final loadingAhead =
              ahead && cropCourseService.aheadLoading(widget.cropId);
          final aheadReady = cropCourseService.aheadReady(widget.cropId);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SoftCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      CropGlyph(
                        cropId: widget.cropId,
                        emoji: crop?.emoji ?? enroll?.emoji ?? '🌾',
                        size: 36,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              crop?.name(s.isHi) ??
                                  enroll?.name(s.isHi) ??
                                  widget.cropId,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                color: context.agroText,
                              ),
                            ),
                            if (enroll != null)
                              Text(
                                enroll.dateRangeLabel(s.isHi),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.agroMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).asSliver(),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: Row(
                  children: [
                    Expanded(
                      child: _SideChip(
                        label: s.courseCalAhead,
                        selected: ahead,
                        onTap: () => _setSide(_CalSide.ahead),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SideChip(
                        label: s.courseCalDone,
                        selected: !ahead,
                        onTap: () => _setSide(_CalSide.done),
                      ),
                    ),
                  ],
                ).asSliver(),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SoftCard(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Older months (past) ← left chevron goes older
                          IconButton(
                            tooltip: s.isHi ? 'पिछला महीना' : 'Older month',
                            onPressed: canGoBack
                                ? (ahead ? _goNewer : _goOlder)
                                : null,
                            icon: Icon(
                              Icons.chevron_left_rounded,
                              color: canGoBack
                                  ? null
                                  : context.agroMuted.withValues(alpha: 0.35),
                            ),
                          ),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                _monthTitle(_month, s.isHi),
                                key: ValueKey(
                                    '${_month.year}-${_month.month}'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          // Newer months — disabled on current month
                          IconButton(
                            tooltip: s.isHi ? 'अगला महीना' : 'Newer month',
                            onPressed: canGoForward
                                ? (ahead ? _goOlder : _goNewer)
                                : null,
                            icon: Icon(
                              Icons.chevron_right_rounded,
                              color: canGoForward
                                  ? null
                                  : context.agroMuted.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: (s.isHi
                                ? const [
                                    // Grid starts on Monday (lead = weekday - 1),
                                    // so labels must start at सोमवार too.
                                    'सो', 'मं', 'बु', 'गु', 'शु', 'श', 'र'
                                  ]
                                : const [
                                    'M', 'T', 'W', 'T', 'F', 'S', 'S'
                                  ])
                            .map(
                              (d) => Expanded(
                                child: Center(
                                  child: Text(
                                    d,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      color: context.agroMuted,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          // Always size grid by width so cells stay square
                          // and layout never overflows.
                          return SizedBox(
                            height: _gridHeightFor(w, _month),
                            child: PageView.builder(
                              controller: _pageCtrl,
                              itemCount: ahead ? (_aheadHasNext ? 2 : 1) : 240,
                              physics: const BouncingScrollPhysics(),
                              onPageChanged: (page) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _month = _monthForPage(page);
                                  _selected = _clampSelected(_month);
                                });
                              },
                              itemBuilder: (context, page) {
                                final m = _monthForPage(page);
                                final marks = ahead
                                    ? cropCourseService
                                        .aheadFor(widget.cropId)
                                        .where((t) =>
                                            t.day.year == m.year &&
                                            t.day.month == m.month)
                                        .map((t) => t.day)
                                        .toSet()
                                    : cropCourseService.daysWithActivity(
                                        widget.cropId,
                                        m.year,
                                        m.month,
                                      );
                                return _MonthGrid(
                                  month: m,
                                  today: _today,
                                  selected: _selected,
                                  activityDays: marks,
                                  ahead: ahead,
                                  windowEnd: _aheadEnd,
                                  onSelect: (day) {
                                    HapticFeedback.lightImpact();
                                    setState(() => _selected = day);
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ahead
                            ? (aheadReady
                                ? s.courseCalAheadHint
                                : s.courseCalAheadWait(
                                    cropCourseService.aheadAnalyzed(widget.cropId),
                                    cropCourseService.aheadNeed(widget.cropId),
                                  ))
                            : (s.isHi
                                ? 'सिर्फ आज और पिछली तारीखें'
                                : 'Today and past dates only'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.agroMuted,
                        ),
                      ),
                    ],
                  ),
                ).asSliver(),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? const Color(0xFF3D3214)
                        : const Color(0xFFFFF4D6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.isDark
                          ? const Color(0xFFE8C56A)
                          : const Color(0xFFE0A82A),
                    ),
                  ),
                  child: Text(
                    s.courseCalAdvisorNote,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w800,
                      color: context.isDark
                          ? const Color(0xFFF6D98A)
                          : const Color(0xFF6B4200),
                    ),
                  ),
                ).asSliver(),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selected == null
                              ? s.courseCalPickDay
                              : ahead
                                  ? _dayLine(_selected!, s.isHi)
                                  : s.courseCalDayChatTitle(
                                      '${_selected!.day}/${_selected!.month}/${_selected!.year}',
                                    ),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: context.agroText,
                          ),
                        ),
                      ),
                      if (!ahead && dayChats.isNotEmpty)
                        Text(
                          s.courseCalMsgCount(dayChats.length),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: context.agroMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (ahead && loadingAhead && aheadTasks.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  sliver: SoftCard(
                    child: Text(
                      s.courseCalAheadLoading,
                      style: TextStyle(color: context.agroMuted),
                    ),
                  ).asSliver(),
                )
              else if (ahead && !aheadReady)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  sliver: SoftCard(
                    child: Text(
                      s.courseCalAheadWait(
                        cropCourseService.aheadAnalyzed(widget.cropId),
                        cropCourseService.aheadNeed(widget.cropId),
                      ),
                      style: TextStyle(
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: context.agroText,
                      ),
                    ),
                  ).asSliver(),
                )
              else if (ahead && aheadTasks.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  sliver: SoftCard(
                    child: Text(
                      s.courseCalAheadEmpty,
                      style: TextStyle(color: context.agroMuted),
                    ),
                  ).asSliver(),
                )
              else if (ahead)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AheadTile(task: aheadTasks[i], hi: s.isHi),
                      ),
                      childCount: aheadTasks.length,
                    ),
                  ),
                )
              else if (dayPoints.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    decoration: BoxDecoration(
                      color: context.isDark
                          ? const Color(0xFF3D3214)
                          : const Color(0xFFFFF4D6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.isDark
                            ? const Color(0xFFE8C56A)
                            : const Color(0xFFE0A82A),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.isHi ? 'सारांश' : 'Summary',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: context.isDark
                                ? const Color(0xFFF6D98A)
                                : const Color(0xFF8A5A00),
                          ),
                        ),
                        if (_selected != null &&
                            _calendarDay(_selected!).isBefore(_today)) ...[
                          const SizedBox(height: 8),
                          _CalendarDateLine(
                            label: _dayLine(_selected!, s.isHi),
                          ),
                        ],
                        const SizedBox(height: 10),
                        for (var i = 0; i < dayPoints.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _DayPointTile(
                            index: i + 1,
                            point: dayPoints[i],
                            hi: s.isHi,
                          ),
                        ],
                      ],
                    ),
                  ).asSliver(),
                ),
              if (!ahead && dayChats.isEmpty && dayPoints.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  sliver: SoftCard(
                    child: Text(
                      s.courseCalEmptyDay,
                      style: TextStyle(color: context.agroMuted),
                    ),
                  ).asSliver(),
                )
              else if (dayChats.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DayChatBubble(message: dayChats[i]),
                      ),
                      childCount: dayChats.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  DateTime _clampSelected(DateTime month) {
    final today = _today;
    if (_side == _CalSide.ahead) {
      final end = _aheadEnd;
      if (month.year == today.year && month.month == today.month) {
        return today;
      }
      final first = DateTime(month.year, month.month, 1);
      if (first.isAfter(end)) return end;
      return first;
    }
    if (month.year == today.year && month.month == today.month) {
      return today;
    }
    // Last day of that past month
    final last = DateTime(month.year, month.month + 1, 0);
    return DateTime(last.year, last.month, last.day);
  }

  /// Exact height for N rows of square cells + gaps.
  double _gridHeightFor(double width, DateTime month) {
    const gap = 4.0;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = firstWeekday - 1;
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil().clamp(4, 6);
    final cell = (width - gap * 6) / 7;
    return rows * cell + (rows - 1) * gap;
  }
}

extension on Widget {
  Widget asSliver() => SliverToBoxAdapter(child: this);
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.selected,
    required this.activityDays,
    required this.ahead,
    required this.windowEnd,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime today;
  final DateTime? selected;
  final Set<DateTime> activityDays;
  final bool ahead;
  final DateTime windowEnd;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = firstWeekday - 1;
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();

    return LayoutBuilder(
      builder: (context, c) {
        final gap = 4.0;
        final cell = (c.maxWidth - gap * 6) / 7;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: 1,
            mainAxisExtent: cell,
          ),
          itemCount: rows * 7,
          itemBuilder: (context, i) {
            if (i < lead || i >= lead + daysInMonth) {
              return const SizedBox.shrink();
            }
            final dayNum = i - lead + 1;
            final day = DateTime(month.year, month.month, dayNum);
            final open = ahead
                ? !day.isBefore(today) && !day.isAfter(windowEnd)
                : !day.isAfter(today);
            final has = open &&
                activityDays.any((d) =>
                    d.year == day.year &&
                    d.month == day.month &&
                    d.day == day.day);
            final isSelected = selected != null &&
                selected!.year == day.year &&
                selected!.month == day.month &&
                selected!.day == day.day;
            final isToday = today.year == day.year &&
                today.month == day.month &&
                today.day == day.day;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: open ? () => onSelect(day) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: !open
                        ? null
                        : isSelected
                            ? (context.isDark
                                ? AgroColors.mint
                                : AgroColors.forest)
                            : (has
                                ? (context.isDark
                                    ? AgroColors.mint.withValues(alpha: 0.2)
                                    : AgroColors.forest
                                        .withValues(alpha: 0.12))
                                : null),
                    borderRadius: BorderRadius.circular(10),
                    border: isToday && !isSelected && open
                        ? Border.all(
                            color: context.isDark
                                ? AgroColors.mint
                                : AgroColors.forest,
                            width: 1.3,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: math.min(14, cell * 0.38),
                          color: !open
                              ? context.agroMuted.withValues(alpha: 0.28)
                              : isSelected
                                  ? (context.isDark
                                      ? AgroColors.night
                                      : Colors.white)
                                  : context.agroText,
                        ),
                      ),
                      if (has)
                        Positioned(
                          bottom: 3,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (context.isDark
                                      ? AgroColors.night
                                      : Colors.white)
                                  : (context.isDark
                                      ? AgroColors.mint
                                      : AgroColors.forest),
                              shape: BoxShape.circle,
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
      },
    );
  }
}

class _CalendarDateLine extends StatelessWidget {
  const _CalendarDateLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final line = context.isDark
        ? const Color(0xFFE8C56A)
        : const Color(0xFFE0A82A);
    final ink = context.isDark
        ? const Color(0xFFF6D98A)
        : const Color(0xFF8A5A00);
    return Row(
      children: [
        Expanded(child: Divider(color: line, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ),
        Expanded(child: Divider(color: line, thickness: 1)),
      ],
    );
  }
}

class _DayPointTile extends StatelessWidget {
  const _DayPointTile({
    required this.index,
    required this.point,
    required this.hi,
  });

  final int index;
  final CourseDayPoint point;
  final bool hi;

  @override
  Widget build(BuildContext context) {
    final inputColor =
        context.isDark ? AgroColors.mint : AgroColors.forest;
    final outputColor = context.agroGold;
    final missing = hi ? 'जवाब नहीं आया' : 'No answer yet';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$index',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: context.agroMuted,
          ),
        ),
        const SizedBox(height: 4),
        if (point.input.isNotEmpty) ...[
          Text(
            hi ? 'इनपुट' : 'Input',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: inputColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            point.input,
            style: TextStyle(
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: context.agroText,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          hi ? 'आउटपुट' : 'Output',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: outputColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          point.output.isEmpty ? missing : point.output,
          style: TextStyle(
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: point.output.isEmpty ? context.agroMuted : context.agroText,
          ),
        ),
      ],
    );
  }
}

class _DayChatBubble extends StatelessWidget {
  const _DayChatBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final s = AgroScope.of(context).s;
    final mine = message.role == MessageRole.user;
    final t = message.createdAt;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.88,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: mine
                ? (context.isDark ? AgroColors.mint : AgroColors.forest)
                : context.agroCard,
            borderRadius: BorderRadius.circular(16),
            border: mine ? null : Border.all(color: context.agroBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      mine
                          ? (s.isHi ? 'आप' : 'You')
                          : (message.aiLabel.isNotEmpty
                              ? message.aiLabel
                              : 'AG Farmer'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: mine
                            ? (context.isDark
                                ? AgroColors.night.withValues(alpha: 0.7)
                                : Colors.white70)
                            : context.agroGold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: mine
                          ? (context.isDark
                              ? AgroColors.night.withValues(alpha: 0.55)
                              : Colors.white60)
                          : context.agroMuted,
                    ),
                  ),
                ],
              ),
              if (message.hasMedia) ...[
                const SizedBox(height: 8),
                _DayMedia(message: message, onAccent: mine),
              ],
              if (message.text.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                mine
                    ? Text(
                        message.text,
                        style: TextStyle(
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: context.isDark
                              ? AgroColors.night
                              : Colors.white,
                        ),
                      )
                    : ChatAnswerBody(text: message.text, compact: true),
              ],
              if (message.dosageHighlight != null &&
                  message.dosageHighlight!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message.dosageHighlight!,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: mine ? Colors.white70 : context.agroGold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DayMedia extends StatelessWidget {
  const _DayMedia({required this.message, required this.onAccent});
  final ChatMessage message;
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final path = message.displayMediaPath;
    if (path == null) return const SizedBox.shrink();

    if (message.mediaType == ChatMediaType.image) {
      if (localFileExists(path)) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: localFileImage(
            path,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      }
    }

    IconData icon;
    switch (message.mediaType) {
      case ChatMediaType.video:
        icon = Icons.videocam_rounded;
        break;
      case ChatMediaType.audio:
        icon = Icons.mic_rounded;
        break;
      case ChatMediaType.file:
        icon = Icons.insert_drive_file_rounded;
        break;
      case ChatMediaType.image:
        icon = Icons.image_rounded;
        break;
      default:
        icon = Icons.attachment_rounded;
    }

    final fg = onAccent
        ? (context.isDark ? AgroColors.night : Colors.white)
        : context.agroText;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: onAccent
            ? Colors.white.withValues(alpha: context.isDark ? 0.28 : 0.15)
            : context.agroSoftFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: onAccent ? fg : context.agroGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.mediaName ?? message.mediaType.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideChip extends StatelessWidget {
  const _SideChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = selected
        ? (context.isDark ? AgroColors.mint : AgroColors.forest)
        : (context.isDark ? const Color(0xFF0B2942) : Colors.white);
    final ink = selected
        ? (context.isDark ? AgroColors.night : Colors.white)
        : context.agroText;
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? fill
                  : context.agroMuted.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              height: 1.15,
              color: ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _AheadTile extends StatelessWidget {
  const _AheadTile({required this.task, required this.hi});

  final CourseAheadTask task;
  final bool hi;

  String get _kind {
    switch (task.kind) {
      case 'sinchai':
        return hi ? 'सिंचाई' : 'Irrigation';
      case 'dawai':
        return hi ? 'दवाई' : 'Medicine';
      case 'keet':
        return hi ? 'कीट' : 'Insects';
      case 'poshak':
        return hi ? 'पोषक तत्व' : 'Nutrients';
      case 'khad':
        return hi ? 'खाद' : 'Manure';
      case 'bimari':
        return hi ? 'बीमारी' : 'Disease';
      default:
        return hi ? 'देखभाल' : 'Care';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _kind,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: context.isDark ? AgroColors.mint : AgroColors.forest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            task.title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: context.agroText,
            ),
          ),
          if (task.detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              task.detail,
              style: TextStyle(
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: context.agroMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
