import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'api_client.dart';
import 'app_services.dart';

const _channelId = 'ag_course_summary';
const _localId = 1200;
const _seenPrefs = 'ag_course_opened_day_v1';

/// Shown by the OS when a course status push arrives in the foreground.
/// Background/killed delivery uses the FCM notification payload.
@pragma('vm:entry-point')
Future<void> courseSummaryBackground(RemoteMessage message) async {}

class CourseSummaryNotify {
  CourseSummaryNotify._();
  static final CourseSummaryNotify instance = CourseSummaryNotify._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _localReady = false;
  bool _listening = false;
  bool _fcmReady = false;
  Timer? _debounce;
  final Map<String, String> _openedDay = {};

  Future<void> start() async {
    if (kIsWeb) return;
    await _initLocal();
    await _loadOpened();
    if (!_listening) {
      try {
        FirebaseMessaging.onMessage.listen((message) async {
          await showRemote(message);
          await cropCourseService.refreshOpenFromServer();
        });
        FirebaseMessaging.onMessageOpenedApp.listen((_) {
          cropCourseService.refreshOpenFromServer();
        });
        FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
        _listening = true;
      } catch (e) {
        if (kDebugMode) debugPrint('FCM listeners skipped: $e');
      }
    }
    await _syncTokenOrSchedule();
  }

  void onCoursesChanged() {
    if (_fcmReady) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      unawaited(_scheduleLocalNoon());
    });
  }

  Future<void> showRemote(RemoteMessage message) async {
    final n = message.notification;
    final title = n?.title ?? 'आज का सारांश';
    final body = n?.body ?? message.data['body']?.toString() ?? '';
    if (body.trim().isEmpty) return;
    await _show(title, body, id: _localId + 1);
  }

  Future<void> _initLocal() async {
    if (_localReady) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(const InitializationSettings(android: android));
    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'कोर्स स्टेटस',
        description: 'हर दिन 12 बजे सक्रिय फसल का हाल',
        importance: Importance.high,
      ),
    );
    try {
      await androidPlugin?.requestNotificationsPermission();
    } catch (e) {
      if (kDebugMode) debugPrint('Notification permission skipped: $e');
    }
    _localReady = true;
  }

  Future<void> _syncTokenOrSchedule() async {
    if (!ApiClient.instance.hasSession) {
      _fcmReady = false;
      await _cancelLocals();
      return;
    }
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.length >= 20) {
        await _saveToken(token);
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Course summary token skipped: $e');
    }
    _fcmReady = false;
    await _scheduleLocalNoon();
  }

  Future<void> _saveToken(String token) async {
    if (!ApiClient.instance.hasSession || token.length < 20) return;
    try {
      await ApiClient.instance.call(
        'notify.token',
        auth: true,
        data: {'token': token},
        timeout: const Duration(seconds: 12),
      );
      _fcmReady = true;
      await _cancelLocals();
    } catch (e) {
      _fcmReady = false;
      if (kDebugMode) debugPrint('Course summary token save skipped: $e');
      await _scheduleLocalNoon();
    }
  }

  String visitKey(String cropId) => '$cropId|${_istDay()}';

  /// Opening the course does not stop the daily crop-health question.
  void noteOpened(String? cropId) {
    final id = (cropId ?? '').trim();
    if (id.isEmpty) return;
    final day = _istDay();
    if (_openedDay[id] == day) return;
    _openedDay[id] = day;
    unawaited(_saveOpened());
    unawaited(_postSeen(id));
  }

  Future<void> _loadOpened() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_seenPrefs);
      if (raw == null || raw.isEmpty) return;
      for (final part in raw.split(';')) {
        final i = part.indexOf('=');
        if (i <= 0) continue;
        _openedDay[part.substring(0, i)] = part.substring(i + 1);
      }
    } catch (_) {}
  }

  Future<void> _saveOpened() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _openedDay.entries.map((e) => '${e.key}=${e.value}').join(';');
    await prefs.setString(_seenPrefs, raw);
  }

  Future<void> _postSeen(String cropId) async {
    if (!ApiClient.instance.hasSession) return;
    try {
      await ApiClient.instance.call(
        'courses.seen',
        auth: true,
        data: {'cropId': cropId},
        timeout: const Duration(seconds: 12),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Course seen skipped: $e');
    }
  }

  String _istDay() {
    final shifted =
        DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${shifted.year}-${two(shifted.month)}-${two(shifted.day)}';
  }

  int _idForDay(String cropId, int offset) {
    var hash = 0;
    for (final c in cropId.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return 3000 + (hash % 400) * 15 + offset;
  }

  Future<void> _cancelLocals() async {
    await _local.cancel(_localId);
    await _local.cancel(_localId + 1);
    for (final e in cropCourseService.myCourses) {
      for (var i = 0; i < 15; i++) {
        await _local.cancel(_idForDay(e.cropId, i));
      }
    }
  }

  String _statusBody(String name) {
    if (!languageService.isHindi) {
      return 'How is your $name today? Tell us how the field is.';
    }
    return 'आज आपकी $name कैसी है? खेत का हाल बताएँ।';
  }

  tz.TZDateTime _nextNoon() {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, 12);
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }
    return when;
  }

  Future<void> _scheduleLocalNoon() async {
    if (!_localReady || _fcmReady) return;
    if (!ApiClient.instance.hasSession) return;
    await _cancelLocals();
    final start = _nextNoon();
    final details = _details();
    for (final e in cropCourseService.myCourses) {
      if (!e.isOngoing) continue;
      final name = languageService.isHindi
          ? (e.nameHi.trim().isEmpty ? e.nameEn : e.nameHi)
          : (e.nameEn.trim().isEmpty ? e.nameHi : e.nameEn);
      for (var i = 0; i < 15; i++) {
        final when = start.add(Duration(days: i));
        final extra = cropCourseService.aheadLine(
          e.cropId,
          DateTime(when.year, when.month, when.day),
          hi: languageService.isHindi,
        );
        final body =
            extra.isEmpty ? _statusBody(name) : '${_statusBody(name)}\n$extra';
        final id = _idForDay(e.cropId, i);
        try {
          await _local.zonedSchedule(
            id,
            name,
            body,
            when,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: 'course_status:${e.cropId}',
          );
        } catch (_) {
          try {
            await _local.zonedSchedule(
              id,
              name,
              body,
              when,
              details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              payload: 'course_status:${e.cropId}',
            );
          } catch (err) {
            if (kDebugMode) debugPrint('Course status schedule skipped: $err');
          }
        }
      }
    }
  }

  Future<void> _show(String title, String body, {required int id}) async {
    await _initLocal();
    await _local.show(id, title, body, _details());
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'कोर्स स्टेटस',
        channelDescription: 'हर दिन 12 बजे सक्रिय फसल का हाल',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
  }
}
