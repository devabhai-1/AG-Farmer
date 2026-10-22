import 'dart:async';
import 'dart:convert';
import '../platform/local_file.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/crop_knowledge.dart';
import '../models/chat_message.dart';
import '../models/crop_item.dart';
import '../models/subscription_plan.dart';
import 'agro_ai_backend.dart';
import 'app_services.dart' show catalogService, languageService, profileService;
import 'chat_sync_service.dart';
import 'api_client.dart';

/// One main exchange on a course day: what the farmer sent, and the answer.
class CourseDayPoint {
  final String input;
  final String output;

  const CourseDayPoint({required this.input, required this.output});
}

class CourseAheadTask {
  final DateTime day;
  final String kind;
  final String title;
  final String detail;

  const CourseAheadTask({
    required this.day,
    required this.kind,
    required this.title,
    this.detail = '',
  });
}

class CourseCalendarEntry {
  final String id;
  final String cropId;
  final DateTime at;
  final String kind; // chat | image | video | audio | file | note
  final String title;
  final String detail;

  const CourseCalendarEntry({
    required this.id,
    required this.cropId,
    required this.at,
    required this.kind,
    required this.title,
    this.detail = '',
  });

  DateTime get day => DateTime(at.year, at.month, at.day);

  Map<String, dynamic> toJson() => {
        'id': id,
        'cropId': cropId,
        'at': at.toIso8601String(),
        'kind': kind,
        'title': title,
        'detail': detail,
      };

  factory CourseCalendarEntry.fromJson(Map<String, dynamic> m) =>
      CourseCalendarEntry(
        id: '${m['id']}',
        cropId: '${m['cropId']}',
        at: DateTime.tryParse('${m['at']}') ?? DateTime.now(),
        kind: '${m['kind'] ?? 'chat'}',
        title: '${m['title'] ?? ''}',
        detail: '${m['detail'] ?? ''}',
      );
}

/// One enrolled fasal course — starts on enroll day; ends only when closed
/// (user / admin). No fixed duration.
class CourseEnrollment {
  final String cropId;
  final String nameEn;
  final String nameHi;
  final String emoji;
  final DateTime startedAt;
  /// Set only when course is closed. Null = still running.
  final DateTime? endedAt;
  /// Admin asked farmer to close or continue.
  final bool pendingAdminClose;

  const CourseEnrollment({
    required this.cropId,
    required this.nameEn,
    required this.nameHi,
    required this.emoji,
    required this.startedAt,
    this.endedAt,
    this.pendingAdminClose = false,
  });

  String name(bool hi) => hi ? nameHi : nameEn;

  bool get isClosed => endedAt != null;

  bool get isOngoing => !isClosed;

  /// Days since start (1 = start day). No fixed total.
  int get dayNumber {
    final today = DateTime.now();
    final start = DateTime(startedAt.year, startedAt.month, startedAt.day);
    final endCap = endedAt != null
        ? DateTime(endedAt!.year, endedAt!.month, endedAt!.day)
        : DateTime(today.year, today.month, today.day);
    final d = endCap.difference(start).inDays + 1;
    return d < 1 ? 1 : d;
  }

  String _fmt(DateTime d, bool hi) {
    const monthsEn = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const monthsHi = [
      'जन', 'फर', 'मार', 'अप्रै', 'मई', 'जून',
      'जुला', 'अग', 'सित', 'अक्टू', 'नव', 'दिस',
    ];
    final m = hi ? monthsHi[d.month - 1] : monthsEn[d.month - 1];
    return '${d.day} $m ${d.year}';
  }

  /// Start only while open; start – end after close.
  String dateRangeLabel(bool hi) {
    final start = _fmt(startedAt, hi);
    if (endedAt == null) {
      return hi ? 'शुरुआत: $start' : 'Started: $start';
    }
    return '$start – ${_fmt(endedAt!, hi)}';
  }

  String startOnlyLabel(bool hi) =>
      hi ? 'शुरुआत: ${_fmt(startedAt, hi)}' : 'Started: ${_fmt(startedAt, hi)}';

  CourseEnrollment copyWith({
    DateTime? endedAt,
    bool clearEndedAt = false,
    bool? pendingAdminClose,
  }) {
    return CourseEnrollment(
      cropId: cropId,
      nameEn: nameEn,
      nameHi: nameHi,
      emoji: emoji,
      startedAt: startedAt,
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      pendingAdminClose: pendingAdminClose ?? this.pendingAdminClose,
    );
  }

  Map<String, dynamic> toJson() => {
        'cropId': cropId,
        'nameEn': nameEn,
        'nameHi': nameHi,
        'emoji': emoji,
        'startedAt': startedAt.toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
        'pendingAdminClose': pendingAdminClose,
      };

  factory CourseEnrollment.fromJson(Map<String, dynamic> m) {
    final start =
        DateTime.tryParse('${m['startedAt']}') ?? DateTime.now();
    DateTime? ended;
    if (m['endedAt'] != null) {
      ended = DateTime.tryParse('${m['endedAt']}');
    } else if (m['endsAt'] != null) {
      // Legacy auto +90 day end was never a real close — drop it.
      final legacy = DateTime.tryParse('${m['endsAt']}');
      if (legacy != null) {
        final auto = start.add(const Duration(days: 90));
        final sameDay = legacy.year == auto.year &&
            legacy.month == auto.month &&
            legacy.day == auto.day;
        if (!sameDay) ended = legacy;
      }
    }
    return CourseEnrollment(
      cropId: '${m['cropId']}',
      nameEn: '${m['nameEn'] ?? m['cropId']}',
      nameHi: '${m['nameHi'] ?? m['nameEn'] ?? m['cropId']}',
      emoji: '${m['emoji'] ?? '🌾'}',
      startedAt: DateTime(start.year, start.month, start.day),
      endedAt: ended == null
          ? null
          : DateTime(ended.year, ended.month, ended.day),
      pendingAdminClose: m['pendingAdminClose'] == true,
    );
  }

  factory CourseEnrollment.fromCrop(CropItem crop, {DateTime? start}) {
    final s = start ?? DateTime.now();
    final dayStart = DateTime(s.year, s.month, s.day);
    return CourseEnrollment(
      cropId: crop.id,
      nameEn: crop.nameEn,
      nameHi: crop.nameHi,
      emoji: crop.emoji,
      startedAt: dayStart,
    );
  }
}

/// Multi-crop course chats: each crop = one tab/chat. Media attach max 20MB.
class CropCourseService extends ChangeNotifier {
  static const _activeKey = 'ag_course_active_crop';
  static const _orderKey = 'ag_course_open_order';
  static const _chatsKey = 'ag_course_chats_v2';
  static const _calKey = 'ag_course_calendar_v1';
  static const _enrollKey = 'ag_course_enroll_v1';
  static const _ownerKey = 'ag_course_owner_uid';
  static const maxUploadBytes = 20 * 1024 * 1024; // 20MB

  String? _activeCropId;
  final List<String> _openOrder = [];
  final Map<String, List<ChatMessage>> _chats = {};
  final List<CourseCalendarEntry> _calendar = [];
  final Map<String, CourseEnrollment> _enrollments = {};
  final Map<String, List<CourseAheadTask>> _ahead = {};
  final Map<String, bool> _aheadReady = {};
  final Map<String, int> _aheadAnalyzed = {};
  final Map<String, int> _aheadNeed = {};
  final Set<String> _aheadLoading = {};
  bool _ready = false;
  int _loadEpoch = 0;

  String? get activeCropId => _activeCropId;
  bool get ready => _ready;
  bool get hasOpenChats => _openOrder.isNotEmpty;
  bool get hasMyCourses => _enrollments.isNotEmpty;
  List<String> get openCropIds => List.unmodifiable(_openOrder);

  /// My Courses — permanently enrolled until user removes.
  List<CourseEnrollment> get myCourses {
    final list = _enrollments.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  CourseEnrollment? enrollmentFor(String cropId) => _enrollments[cropId];

  CropItem? get activeCrop => _cropById(_activeCropId);

  CropItem? _cropById(String? id) {
    if (id == null) return null;
    try {
      return catalogService.crops.firstWhere((c) => c.id == id);
    } catch (_) {
      final e = _enrollments[id];
      if (e == null) return null;
      return CropItem(
        id: e.cropId,
        nameEn: e.nameEn,
        nameHi: e.nameHi,
        emoji: e.emoji,
        minPlan: PlanTierX.fromKey('advanced'),
        priority: 500,
      );
    }
  }

  List<ChatMessage> messagesFor(String cropId) =>
      List.unmodifiable(_chats[cropId] ?? const []);

  List<ChatMessage> get activeMessages =>
      _activeCropId == null ? const [] : messagesFor(_activeCropId!);

  /// Full chat for one calendar day (user + AI, with images).
  List<ChatMessage> messagesOnDay(String cropId, DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final list = messagesFor(cropId).where((m) {
      if (m.id.startsWith('welcome_')) return false;
      final t = m.createdAt;
      return t.year == d.year && t.month == d.month && t.day == d.day;
    }).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// Main input/output pairs for one calendar day, above that day's chats.
  List<CourseDayPoint> pointsForDay(
    String cropId,
    DateTime day, {
    required bool hi,
  }) {
    final msgs = messagesOnDay(cropId, day)
        .where((m) => !m.id.startsWith('summary_'))
        .toList();
    final points = <CourseDayPoint>[];
    String? input;
    var output = '';

    String clipLine(String raw, int max) {
      final s = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (s.isEmpty || s == 'फोटो') return '';
      final sentence = s.split(RegExp(r'(?<=[।.!?])\s')).first;
      if (sentence.length <= max) return sentence;
      return '${sentence.substring(0, max)}…';
    }

    void flush() {
      if (input == null) return;
      if (input!.isNotEmpty || output.isNotEmpty) {
        points.add(CourseDayPoint(input: input!, output: output));
      }
      input = null;
      output = '';
    }

    for (final m in msgs) {
      if (m.role == MessageRole.user) {
        flush();
        final said = clipLine(m.text, 120);
        final photo = m.hasMedia && m.mediaType == ChatMediaType.image;
        final photoLabel = hi ? 'फोटो भेजी' : 'Photo sent';
        input = said.isNotEmpty
            ? (photo ? '$said · $photoLabel' : said)
            : (photo ? photoLabel : '');
        continue;
      }
      if (input == null || output.isNotEmpty) continue;
      output = clipLine(m.text, 180);
    }
    flush();
    if (points.length <= 5) return points;
    return points.sublist(0, 5);
  }

  List<CourseCalendarEntry> calendarForCrop(String cropId) {
    final list = _calendar.where((e) => e.cropId == cropId).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  List<CourseCalendarEntry> entriesOnDay(String cropId, DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return calendarForCrop(cropId)
        .where((e) =>
            e.day.year == d.year &&
            e.day.month == d.month &&
            e.day.day == d.day)
        .toList();
  }

  Set<DateTime> daysWithActivity(String cropId, int year, int month) {
    final fromCal = calendarForCrop(cropId)
        .where((e) => e.at.year == year && e.at.month == month)
        .map((e) => e.day);
    final fromChat = messagesFor(cropId)
        .where((m) {
          if (m.id.startsWith('welcome_')) return false;
          return m.createdAt.year == year && m.createdAt.month == month;
        })
        .map((m) =>
            DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day));
    return {...fromCal, ...fromChat};
  }

  void _clearMemory() {
    _chats.clear();
    _calendar.clear();
    _openOrder.clear();
    _enrollments.clear();
    _activeCropId = null;
  }

  Future<void> _wipePhoneCache(SharedPreferences prefs) async {
    await prefs.remove(_chatsKey);
    await prefs.remove('ag_course_chats_v1');
    await prefs.remove(_calKey);
    await prefs.remove(_orderKey);
    await prefs.remove(_activeKey);
    await prefs.remove(_enrollKey);
  }

  /// Courses that already exist on this account's server, even on a new phone.
  Future<void> _adoptServerCourses(bool Function() stale) async {
    final sessions = await chatSyncService.listSessions(mode: 'course');
    if (stale()) return;
    for (final s in sessions) {
      var cropId = '${s['cropId'] ?? ''}'.trim();
      if (cropId.isEmpty) {
        final thread = '${s['threadId'] ?? s['id'] ?? ''}';
        if (thread.startsWith('course_')) cropId = thread.substring(7);
      }
      if (cropId.isEmpty || _enrollments.containsKey(cropId)) {
        if (cropId.isNotEmpty && !_openOrder.contains(cropId)) {
          _openOrder.add(cropId);
        }
        continue;
      }
      final crop = _cropById(cropId);
      final ts = s['updatedAt'] ?? s['lastMessageAt'];
      final started = ts is num
          ? DateTime.fromMillisecondsSinceEpoch(ts.toInt())
          : DateTime.now();
      if (crop != null) {
        _enrollments[cropId] = CourseEnrollment.fromCrop(crop, start: started);
      } else {
        final name = '${s['name'] ?? cropId}'.trim();
        _enrollments[cropId] = CourseEnrollment(
          cropId: cropId,
          nameEn: name.isEmpty ? cropId : name,
          nameHi: name.isEmpty ? cropId : name,
          emoji: '🌾',
          startedAt: DateTime(started.year, started.month, started.day),
        );
      }
      if (!_openOrder.contains(cropId)) _openOrder.add(cropId);
    }
  }

  Future<void> load() async {
    final epoch = ++_loadEpoch;
    bool stale() => epoch != _loadEpoch;
    final prefs = await SharedPreferences.getInstance();
    if (stale()) return;
    final uid = ApiClient.instance.hasSession ? ApiClient.instance.uid : null;
    if (uid == null || uid.isEmpty) {
      // Hide the previous account on this screen. Keep its saved courses
      // on the phone and on the server so the next login brings them back.
      _clearMemory();
      _ready = true;
      if (!stale()) notifyListeners();
      return;
    }
    final owner = prefs.getString(_ownerKey);
    if (owner != null && owner != uid) {
      _clearMemory();
      await _wipePhoneCache(prefs);
      if (stale()) return;
    }
    await prefs.setString(_ownerKey, uid);
    if (stale()) return;
    _activeCropId = prefs.getString(_activeKey);
    _openOrder
      ..clear()
      ..addAll(prefs.getStringList(_orderKey) ?? const []);
    _chats.clear();
    _calendar.clear();
    _enrollments.clear();

    final enrollRaw = prefs.getString(_enrollKey);
    if (enrollRaw != null && enrollRaw.isNotEmpty) {
      try {
        final list = jsonDecode(enrollRaw) as List;
        for (final item in list) {
          final e = CourseEnrollment.fromJson(
            Map<String, dynamic>.from(item as Map),
          );
          _enrollments[e.cropId] = e;
          if (!_openOrder.contains(e.cropId)) _openOrder.add(e.cropId);
        }
      } catch (_) {}
    }

    _readCachedChats(prefs);
    final calRaw = prefs.getString(_calKey);
    if (calRaw != null && calRaw.isNotEmpty) {
      try {
        final list = jsonDecode(calRaw) as List;
        for (final item in list) {
          _calendar.add(
            CourseCalendarEntry.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          );
        }
      } catch (_) {}
    }

    final loggedIn = ApiClient.instance.hasSession;

    if (loggedIn) {
      await _pullServerEnrollments(stale);
      if (stale()) return;
      await _adoptServerCourses(stale);
      if (stale()) return;
      // Keep enrolled courses forever; restore chats from RTDB when present.
      final order = List<String>.from(_openOrder);
      for (final cropId in order) {
        final remote = await chatSyncService.restore(
          mode: 'course',
          cropId: cropId,
          limit: 2000,
        );
        if (stale()) return;
        // Empty server reply must not wipe the copy already on this phone.
        _chats[cropId] = _mergeThread(_chats[cropId] ?? const [], remote);
      }
      if (stale()) return;
      await prefs.setStringList(_orderKey, _openOrder);
      if (_activeCropId != null) {
        await prefs.setString(_activeKey, _activeCropId!);
      }
      if (stale()) return;
      await _persistEnrollments(prefs);
    }

    // Backfill enrollments for any open tabs that lack meta (legacy)
    for (final id in List<String>.from(_openOrder)) {
      if (_enrollments.containsKey(id)) continue;
      final crop = _cropById(id);
      if (crop != null) {
        _enrollments[id] = CourseEnrollment.fromCrop(crop);
      }
    }

    if (stale()) return;
    if (loggedIn) {
      _backfillFromChats();
      if (stale()) return;
      await _persist();
      if (!stale()) await _pushEnrollments();
    } else {
      if (stale()) return;
      final beforeBackfill = _calendar.length;
      _backfillFromChats();
      if (_calendar.length > beforeBackfill) {
        await prefs.setString(
          _calKey,
          jsonEncode(_calendar.map((e) => e.toJson()).toList()),
        );
      }
      await _persistEnrollments(prefs);
    }

    if (_activeCropId != null && !_openOrder.contains(_activeCropId)) {
      _activeCropId = null;
    }
    if (_activeCropId == null && _openOrder.isNotEmpty) {
      _activeCropId = _openOrder.first;
    }
    if (stale()) return;
    _ready = true;
    notifyListeners();
    if (loggedIn) unawaited(_warmAhead());
  }

  bool aheadLoading(String cropId) => _aheadLoading.contains(cropId);
  bool aheadReady(String cropId) => _aheadReady[cropId] == true;
  int aheadAnalyzed(String cropId) => _aheadAnalyzed[cropId] ?? 0;
  int aheadNeed(String cropId) => _aheadNeed[cropId] ?? 4;

  List<CourseAheadTask> aheadFor(String cropId) =>
      List.unmodifiable(_ahead[cropId] ?? const []);

  List<CourseAheadTask> aheadOn(String cropId, DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return aheadFor(cropId)
        .where((t) =>
            t.day.year == d.year && t.day.month == d.month && t.day.day == d.day)
        .toList();
  }

  String aheadLine(String cropId, DateTime day, {required bool hi}) {
    final titles = aheadOn(cropId, day)
        .map((t) => t.title.trim())
        .where((t) => t.isNotEmpty)
        .take(3)
        .join(' · ');
    if (titles.isEmpty) return '';
    return hi ? 'आज का काम: $titles' : 'Today: $titles';
  }

  Future<void> loadAhead(String cropId) async {
    final id = cropId.trim();
    if (id.isEmpty || !ApiClient.instance.hasSession) return;
    if (_aheadLoading.contains(id)) return;
    _aheadLoading.add(id);
    notifyListeners();
    try {
      final res = await ApiClient.instance.call(
        'courses.ahead',
        auth: true,
        data: {
          'cropId': id,
          'lang': languageService.isHindi ? 'hi' : 'en',
        },
        timeout: const Duration(seconds: 22),
      );
      final ready = res['ready'] == true;
      _aheadReady[id] = ready;
      _aheadAnalyzed[id] = res['analyzedDays'] is num
          ? (res['analyzedDays'] as num).toInt()
          : int.tryParse('${res['analyzedDays']}') ?? 0;
      _aheadNeed[id] = res['need'] is num
          ? (res['need'] as num).toInt()
          : int.tryParse('${res['need']}') ?? 4;
      final raw = res['items'];
      final items = <CourseAheadTask>[];
      if (raw is List) {
        for (final row in raw) {
          if (row is! Map) continue;
          final day = DateTime.tryParse('${row['day']}');
          if (day == null) continue;
          final title = '${row['title'] ?? ''}'.trim();
          if (title.isEmpty) continue;
          items.add(
            CourseAheadTask(
              day: DateTime(day.year, day.month, day.day),
              kind: '${row['kind'] ?? ''}',
              title: title,
              detail: '${row['detail'] ?? ''}'.trim(),
            ),
          );
        }
      }
      _ahead[id] = ready ? items : const [];
      if (!ready || items.isEmpty) _aheadReady[id] = false;
    } catch (err) {
      debugPrint('Course ahead skipped: $err');
    } finally {
      _aheadLoading.remove(id);
      notifyListeners();
    }
  }

  Future<void> _warmAhead() async {
    for (final e in myCourses) {
      if (!e.isOngoing) continue;
      await loadAhead(e.cropId);
    }
  }

  /// Pull new server messages (daily summary) into open course chats.
  Future<void> refreshOpenFromServer() async {
    if (!ApiClient.instance.hasSession) return;
    final ids = <String>{..._openOrder, ..._enrollments.keys};
    if (ids.isEmpty) return;
    var changed = false;
    for (final cropId in ids) {
      final remote = await chatSyncService.restore(
        mode: 'course',
        cropId: cropId,
        limit: 2000,
      );
      if (remote.isEmpty) continue;
      final local = _chats[cropId] ?? const <ChatMessage>[];
      final merged = _mergeThread(local, remote);
      if (merged.length == local.length) continue;
      _chats[cropId] = merged;
      changed = true;
    }
    if (changed) {
      await _persist();
      notifyListeners();
    }
  }

  Future<void> _persistEnrollments(SharedPreferences prefs) async {
    final list = _enrollments.values.map((e) => e.toJson()).toList();
    await prefs.setString(_enrollKey, jsonEncode(list));
  }

  Future<void> _pushEnrollments() async {
    if (!ApiClient.instance.hasSession) return;
    for (final e in _enrollments.values) {
      try {
        await ApiClient.instance.call('courses.save', auth: true, data: e.toJson());
      } catch (err) {
        debugPrint('Course save skipped: $err');
      }
    }
  }

  Future<void> _pullServerEnrollments(bool Function() stale) async {
    if (!ApiClient.instance.hasSession) return;
    try {
      final res = await ApiClient.instance.call('courses.list', auth: true);
      if (stale()) return;
      final raw = res['courses'];
      if (raw is! Map) return;
      for (final item in raw.values) {
        if (item is! Map) continue;
        final e = CourseEnrollment.fromJson(Map<String, dynamic>.from(item));
        if (e.cropId.isEmpty) continue;
        final local = _enrollments[e.cropId];
        if (local == null) {
          _enrollments[e.cropId] = e;
        } else if (e.startedAt.isBefore(local.startedAt)) {
          _enrollments[e.cropId] = e;
        } else if (e.isClosed && !local.isClosed) {
          _enrollments[e.cropId] = local.copyWith(
            endedAt: e.endedAt,
            pendingAdminClose: e.pendingAdminClose,
          );
        }
        if (!_openOrder.contains(e.cropId)) _openOrder.add(e.cropId);
      }
    } catch (err) {
      debugPrint('Course list skipped: $err');
    }
  }

  /// Drop all phone-cached course chats (e.g. after logout or DB wipe).
  Future<void> clearLocalCache() async {
    _chats.clear();
    _calendar.clear();
    _openOrder.clear();
    _enrollments.clear();
    _ahead.clear();
    _aheadReady.clear();
    _aheadAnalyzed.clear();
    _aheadNeed.clear();
    _activeCropId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatsKey);
    await prefs.remove('ag_course_chats_v1');
    await prefs.remove(_calKey);
    await prefs.remove(_orderKey);
    await prefs.remove(_activeKey);
    await prefs.remove(_enrollKey);
    await prefs.remove(_ownerKey);
    notifyListeners();
  }

  void _backfillFromChats() {
    for (final e in _chats.entries) {
      final cropId = e.key;
      final has = _calendar.any((c) => c.cropId == cropId);
      if (has) continue;
      for (final m in e.value) {
        if (m.role != MessageRole.user) continue;
        if (m.id.startsWith('welcome_')) continue;
        _calendar.add(
          CourseCalendarEntry(
            id: 'bf_${m.id}',
            cropId: cropId,
            at: m.createdAt,
            kind: m.mediaType == ChatMediaType.none ? 'chat' : m.mediaType.name,
            title: m.text.length > 80 ? '${m.text.substring(0, 80)}…' : m.text,
            detail: m.mediaName ?? '',
          ),
        );
      }
    }
  }

  bool _onlyWelcome(List<ChatMessage>? list) {
    if (list == null || list.isEmpty) return true;
    return list.every((m) => m.id.startsWith('welcome_'));
  }

  /// One course is one server thread. Phone memory can be empty right after
  /// an update, so pull that crop's saved chat before showing a new welcome.
  Future<void> _fillFromServer(String cropId) async {
    if (!_onlyWelcome(_chats[cropId])) return;
    final remote = await chatSyncService.restore(
      mode: 'course',
      cropId: cropId,
      limit: 2000,
    );
    if (remote.isEmpty) return;
    _chats[cropId] = _mergeThread(_chats[cropId] ?? const [], remote);
  }

  List<ChatMessage> _mergeThread(
    List<ChatMessage> local,
    List<ChatMessage> remote,
  ) {
    final byId = <String, ChatMessage>{};
    for (final m in local) {
      if (m.id.startsWith('welcome_')) continue;
      byId[m.id] = m;
    }
    for (final m in remote) {
      if (m.id.startsWith('welcome_')) continue;
      byId[m.id] = m;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  void _readCachedChats(SharedPreferences prefs) {
    final raw =
        prefs.getString(_chatsKey) ?? prefs.getString('ag_course_chats_v1');
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in map.entries) {
        final list = (e.value as List)
            .map((m) => _msgFromJson(Map<String, dynamic>.from(m as Map)))
            .toList();
        _chats[e.key] = list;
        if (!_openOrder.contains(e.key)) _openOrder.add(e.key);
      }
    } catch (_) {}
  }

  Future<void> selectCrop(CropItem crop, {required bool isHi}) async {
    // Enroll into My Courses — start today; no end until closed.
    _enrollments.putIfAbsent(
      crop.id,
      () => CourseEnrollment.fromCrop(crop),
    );
    if (!_openOrder.contains(crop.id)) {
      _openOrder.add(crop.id);
    }
    _activeCropId = crop.id;
    await _fillFromServer(crop.id);
    if (_onlyWelcome(_chats[crop.id])) {
      final welcome = CropKnowledge.courseWelcome(
        crop.id,
        crop.name(isHi),
        isHi,
      );
      final enroll = _enrollments[crop.id]!;
      _chats[crop.id] = [
        ChatMessage(
          id: 'welcome_${crop.id}',
          text: welcome,
          role: MessageRole.assistant,
          createdAt: DateTime.now(),
          quickReplies: const [],
          cropTag: crop.name(isHi),
        ),
      ];
      await _addCalendarEntry(
        cropId: crop.id,
        kind: 'note',
        title: isHi ? 'फसल कोर्स शुरू' : 'Crop course started',
        detail: '${crop.name(isHi)} · ${enroll.startOnlyLabel(isHi)}',
      );
    }
    await _persist();
    await _pushEnrollments();
    notifyListeners();
    // ignore: unawaited_futures
    ApiClient.instance.logActivity(
      'course_open',
      detail: {
        'cropId': crop.id,
        'startedAt': _enrollments[crop.id]!.startedAt.toIso8601String(),
      },
      state: {'activeCropId': crop.id},
    );
  }

  Future<void> switchToCrop(String cropId) async {
    if (!_openOrder.contains(cropId) && !_enrollments.containsKey(cropId)) {
      return;
    }
    if (!_openOrder.contains(cropId)) _openOrder.add(cropId);
    _activeCropId = cropId;
    await _fillFromServer(cropId);
    await _persist();
    notifyListeners();
    // ignore: unawaited_futures
    ApiClient.instance.logActivity(
      'course_switch',
      detail: {'cropId': cropId},
      state: {'activeCropId': cropId},
    );
  }

  /// Hide from open tabs only — My Course enrollment stays, chat stays saved.
  Future<void> closeCropTab(String cropId) async {
    _openOrder.remove(cropId);
    if (_activeCropId == cropId) {
      _activeCropId = _openOrder.isEmpty ? null : _openOrder.last;
    }
    await _persist();
    notifyListeners();
    // ignore: unawaited_futures
    ApiClient.instance.logActivity(
      'course_close',
      detail: {'cropId': cropId},
      state: {'activeCropId': _activeCropId},
    );
  }

  /// Remove from My Courses entirely (chat tab closed too).
  Future<void> removeMyCourse(String cropId) async {
    _enrollments.remove(cropId);
    _openOrder.remove(cropId);
    _chats.remove(cropId);
    _calendar.removeWhere((e) => e.cropId == cropId);
    if (_activeCropId == cropId) {
      _activeCropId = _openOrder.isEmpty ? null : _openOrder.last;
    }
    await _persist();
    if (ApiClient.instance.hasSession) {
      try {
        await ApiClient.instance.call(
          'courses.remove',
          auth: true,
          data: {'cropId': cropId},
        );
      } catch (err) {
        debugPrint('Course remove skipped: $err');
      }
    }
    notifyListeners();
  }

  /// Admin/user closes course — end date set today.
  Future<void> closeCourse(String cropId, {required bool isHi}) async {
    final e = _enrollments[cropId];
    if (e == null) return;
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    _enrollments[cropId] = e.copyWith(
      endedAt: end,
      pendingAdminClose: false,
    );
    await _addCalendarEntry(
      cropId: cropId,
      kind: 'note',
      title: isHi ? 'कोर्स बंद' : 'Course closed',
      detail: _enrollments[cropId]!.dateRangeLabel(isHi),
    );
    final list = List<ChatMessage>.from(_chats[cropId] ?? const []);
    list.add(
      ChatMessage(
        id: 'close_${DateTime.now().millisecondsSinceEpoch}',
        text: isHi
            ? 'यह कोर्स आज बंद कर दिया गया। चैट सेव रहेगा — कैलेंडर से पुराना देख सकते हैं।'
            : 'This course was closed today. Chat stays saved — you can review it in the calendar.',
        role: MessageRole.assistant,
        createdAt: DateTime.now(),
        cropTag: e.name(isHi),
      ),
    );
    _chats[cropId] = list;
    // ignore: unawaited_futures
    chatSyncService.sync(list, mode: 'course', cropId: cropId);
    await _persist();
    await _pushEnrollments();
    notifyListeners();
    // ignore: unawaited_futures
    ApiClient.instance.logActivity(
      'course_close_end',
      detail: {
        'cropId': cropId,
        'endedAt': end.toIso8601String(),
      },
    );
  }

  /// Farmer chooses to keep course running after admin prompt.
  Future<void> continueCourse(String cropId, {required bool isHi}) async {
    final e = _enrollments[cropId];
    if (e == null) return;
    _enrollments[cropId] = e.copyWith(
      clearEndedAt: true,
      pendingAdminClose: false,
    );
    final list = List<ChatMessage>.from(_chats[cropId] ?? const []);
    list.add(
      ChatMessage(
        id: 'continue_${DateTime.now().millisecondsSinceEpoch}',
        text: isHi
            ? 'कोर्स जारी रखा गया। जब चाहें चैट करते रहें।'
            : 'Course continued. Keep chatting whenever you need.',
        role: MessageRole.assistant,
        createdAt: DateTime.now(),
        cropTag: e.name(isHi),
      ),
    );
    _chats[cropId] = list;
    // ignore: unawaited_futures
    chatSyncService.sync(list, mode: 'course', cropId: cropId);
    await _persist();
    await _pushEnrollments();
    notifyListeners();
  }

  /// Admin panel later: mark that farmer should see close/continue choice.
  Future<void> setPendingAdminClose(String cropId, {required bool isHi}) async {
    final e = _enrollments[cropId];
    if (e == null || e.isClosed) return;
    _enrollments[cropId] = e.copyWith(pendingAdminClose: true);
    final list = List<ChatMessage>.from(_chats[cropId] ?? const []);
    list.add(
      ChatMessage(
        id: 'admin_close_${DateTime.now().millisecondsSinceEpoch}',
        text: isHi
            ? 'एडमिन संदेश: क्या आप यह कोर्स बंद करना चाहते हैं, या जारी रखना चाहते हैं?'
            : 'Admin message: Do you want to close this course, or keep it going?',
        role: MessageRole.assistant,
        createdAt: DateTime.now(),
        quickReplies: isHi
            ? ['कोर्स बंद करें', 'जारी रखें']
            : ['Close course', 'Continue'],
        cropTag: e.name(isHi),
      ),
    );
    _chats[cropId] = list;
    // ignore: unawaited_futures
    chatSyncService.sync(list, mode: 'course', cropId: cropId);
    await _persist();
    await _pushEnrollments();
    notifyListeners();
  }

  String? validateUploadSize(int bytes) {
    if (bytes <= 0) return 'empty_file';
    if (bytes > maxUploadBytes) return 'file_too_large';
    return null;
  }

  Future<void> addManualNote({
    required String cropId,
    required DateTime day,
    required String title,
    String detail = '',
  }) async {
    final at = DateTime(
      day.year,
      day.month,
      day.day,
      DateTime.now().hour,
      DateTime.now().minute,
    );
    await _addCalendarEntry(
      cropId: cropId,
      kind: 'note',
      title: title.trim(),
      detail: detail.trim(),
      at: at,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> _addCalendarEntry({
    required String cropId,
    required String kind,
    required String title,
    String detail = '',
    DateTime? at,
  }) async {
    _calendar.add(
      CourseCalendarEntry(
        id: 'cal_${DateTime.now().microsecondsSinceEpoch}',
        cropId: cropId,
        at: at ?? DateTime.now(),
        kind: kind,
        title: title,
        detail: detail,
      ),
    );
  }

  Future<({ChatMessage message, bool blocked, String? reason})> ask(
    String query, {
    required bool isHi,
    String provider = 'openai',
    String? mediaPath,
    ChatMediaType mediaType = ChatMediaType.none,
    String? mediaName,
    int? mediaBytes,
    String? imageBase64,
    double? lat,
    double? lon,
    bool deepResearch = false,
    bool voice = false,
  }) async {
    final cropId = _activeCropId;
    if (cropId == null) throw StateError('no_active_crop');
    final enroll = _enrollments[cropId];
    if (enroll != null && enroll.isClosed) {
      throw StateError('course_closed');
    }

    if (mediaPath != null && mediaType != ChatMediaType.none) {
      final size = mediaBytes ?? await localFileLength(mediaPath);
      final err = validateUploadSize(size);
      if (err != null) throw StateError(err);
    }

    final crop = activeCrop;
    final tag = crop?.name(isHi);
    final hasMedia = mediaPath != null && mediaType != ChatMediaType.none;
    final text = query.trim().isEmpty
        ? (hasMedia
            ? (isHi ? _mediaCaptionHi(mediaType) : _mediaCaptionEn(mediaType))
            : '')
        : query.trim();
    if (text.isEmpty && !hasMedia) {
      throw StateError('empty_message');
    }

    final userMsg = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      role: MessageRole.user,
      createdAt: DateTime.now(),
      imagePath: mediaType == ChatMediaType.image ? mediaPath : null,
      mediaPath: mediaPath,
      mediaType: mediaType,
      mediaName: mediaName,
      mediaBytes: mediaBytes,
      cropTag: tag,
    );
    _chats.putIfAbsent(cropId, () => []);
    _chats[cropId]!.add(userMsg);

    final kind = hasMedia ? mediaType.name : 'chat';
    await _addCalendarEntry(
      cropId: cropId,
      kind: kind,
      title: text.length > 90 ? '${text.substring(0, 90)}…' : text,
      detail: mediaName ?? '',
    );

    final aiQuery = hasMedia
        ? '$text\n[${mediaType.name} attached: ${mediaName ?? 'file'}]'
        : text;
    final chatList = _chats[cropId] ?? const <ChatMessage>[];
    final historyForAi =
        chatList.length > 1 ? chatList.sublist(0, chatList.length - 1) : const <ChatMessage>[];
    final photoBytes = imageBase64 != null && imageBase64.length > 40;
    final ai = await AgroAiBackend.ask(
      aiQuery,
      activeCropId: cropId,
      isHi: isHi,
      mode: 'course',
      provider: voice ? 'openai' : provider,
      planId: profileService.planId,
      hasImage: photoBytes,
      imageBase64: photoBytes ? imageBase64 : null,
      lat: lat,
      lon: lon,
      deepResearch: voice ? false : deepResearch,
      voice: voice,
      history: historyForAi,
    );
    if (ai.imageUrl != null && ai.imageUrl!.isNotEmpty) {
      final list = _chats[cropId]!;
      final photoIndex = list.lastIndexWhere((m) => m.role == MessageRole.user);
      if (photoIndex >= 0) {
        list[photoIndex] = list[photoIndex].copyWith(
          imagePath: ai.imageUrl,
          mediaPath: ai.imageUrl,
          mediaType: ChatMediaType.image,
        );
      }
    }
    final bot = ChatMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}_ai',
      text: ai.blocked ? '' : ai.text,
      role: MessageRole.assistant,
      createdAt: DateTime.now(),
      dosageHighlight: ai.dosageHighlight,
      quickReplies: ai.quickReplies,
      cropTag: tag,
      aiProvider: ai.provider,
      aiModel: ai.model,
      isDeepResearch: deepResearch,
      isStreaming: !ai.blocked && ai.text.trim().isNotEmpty,
    );
    if (!ai.blocked) _chats[cropId]!.add(bot);
    await _persist();
    // Source of truth: Realtime Database (per user + crop course thread)
    // ignore: unawaited_futures
    chatSyncService.sync(
      List<ChatMessage>.from(_chats[cropId]!),
      mode: 'course',
      cropId: cropId,
    );
    notifyListeners();
    return (
      message: bot,
      blocked: ai.blocked,
      reason: ai.blockReason,
    );
  }

  void finishStream(String id) {
    final cropId = _activeCropId;
    if (cropId == null) return;
    final list = _chats[cropId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == id);
    if (index < 0 || !list[index].isStreaming) return;
    list[index] = list[index].copyWith(isStreaming: false);
    notifyListeners();
  }

  Future<void> appendLiveLine({
    required String role,
    required String text,
    required bool isHi,
  }) async {
    final cropId = _activeCropId;
    final line = text.trim();
    if (cropId == null || line.isEmpty) return;
    final msg = ChatMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}_$role',
      text: line,
      role: role == 'user' ? MessageRole.user : MessageRole.assistant,
      createdAt: DateTime.now(),
      cropTag: activeCrop?.name(isHi),
      aiProvider: role == 'user' ? null : 'openai',
    );
    _chats.putIfAbsent(cropId, () => []);
    _chats[cropId]!.add(msg);
    await _persist();
    chatSyncService.sync(
      List<ChatMessage>.from(_chats[cropId]!),
      mode: 'course',
      cropId: cropId,
    );
    notifyListeners();
  }

  String _mediaCaptionHi(ChatMediaType t) {
    switch (t) {
      case ChatMediaType.image:
        return '🌱 पत्ती/खेत की फोटो जाँचें';
      case ChatMediaType.video:
        return '🎥 वीडियो देखकर सलाह दें';
      case ChatMediaType.audio:
        return '🎤 आवाज़ संदेश सुनकर सलाह दें';
      case ChatMediaType.file:
        return '📎 फाइल देखकर सलाह दें';
      case ChatMediaType.none:
        return '';
    }
  }

  String _mediaCaptionEn(ChatMediaType t) {
    switch (t) {
      case ChatMediaType.image:
        return '🌱 Please check this crop photo';
      case ChatMediaType.video:
        return '🎥 Please advise from this video';
      case ChatMediaType.audio:
        return '🎤 Please advise from this voice note';
      case ChatMediaType.file:
        return '📎 Please advise from this file';
      case ChatMediaType.none:
        return '';
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = ApiClient.instance.hasSession ? ApiClient.instance.uid : null;
    if (prefs.getString(_ownerKey) != uid) return;
    if (_activeCropId != null) {
      await prefs.setString(_activeKey, _activeCropId!);
    } else {
      await prefs.remove(_activeKey);
    }
    await prefs.setStringList(_orderKey, _openOrder);
    await _persistEnrollments(prefs);

    final encoded = <String, dynamic>{};
    for (final e in _chats.entries) {
      encoded[e.key] = e.value.map(_msgToJson).toList();
    }
    await prefs.setString(_chatsKey, jsonEncode(encoded));
    await prefs.setString(
      _calKey,
      jsonEncode(_calendar.map((e) => e.toJson()).toList()),
    );
  }

  Map<String, dynamic> _msgToJson(ChatMessage m) => {
        'id': m.id,
        'text': m.text,
        'role': m.role.name,
        'createdAt': m.createdAt.toIso8601String(),
        'imagePath': m.imagePath,
        'mediaPath': m.mediaPath,
        'mediaType': m.mediaType.name,
        'mediaName': m.mediaName,
        'mediaBytes': m.mediaBytes,
        'dosageHighlight': m.dosageHighlight,
        'quickReplies': m.quickReplies,
        'cropTag': m.cropTag,
        'aiProvider': m.aiProvider,
        'aiModel': m.aiModel,
      };

  ChatMessage _msgFromJson(Map<String, dynamic> m) {
    final typeName = '${m['mediaType'] ?? 'none'}';
    final mediaType = ChatMediaType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => (m['imagePath'] != null && '${m['imagePath']}'.isNotEmpty)
          ? ChatMediaType.image
          : ChatMediaType.none,
    );
    return ChatMessage(
      id: '${m['id']}',
      text: '${m['text']}',
      role: '${m['role']}' == 'user' ? MessageRole.user : MessageRole.assistant,
      createdAt: DateTime.tryParse('${m['createdAt']}') ?? DateTime.now(),
      imagePath: m['imagePath']?.toString(),
      mediaPath: m['mediaPath']?.toString(),
      mediaType: mediaType,
      mediaName: m['mediaName']?.toString(),
      mediaBytes: m['mediaBytes'] is int
          ? m['mediaBytes'] as int
          : int.tryParse('${m['mediaBytes'] ?? ''}'),
      dosageHighlight: m['dosageHighlight']?.toString(),
      quickReplies:
          (m['quickReplies'] as List?)?.map((e) => '$e').toList() ?? const [],
      cropTag: m['cropTag']?.toString(),
      aiProvider: m['aiProvider']?.toString(),
      aiModel: m['aiModel']?.toString(),
    );
  }
}

final cropCourseService = CropCourseService();
