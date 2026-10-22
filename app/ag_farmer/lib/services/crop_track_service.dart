import 'package:flutter/foundation.dart';
import '../models/crop_item.dart';
import '../models/crop_track.dart';
import 'api_client.dart';

/// Crop tracks via backend API only.
class CropTrackService extends ChangeNotifier {
  final List<CropTrack> _tracks = [];
  bool _ready = false;
  String? _uid;

  List<CropTrack> get tracks => List.unmodifiable(_tracks);
  bool get ready => _ready;

  Future<void> load() async {
    await ApiClient.instance.loadSession();
    _uid = ApiClient.instance.uid;
    if (_uid != null) {
      await _pull();
    } else {
      _ready = true;
      notifyListeners();
    }
  }

  Future<void> syncSession() async {
    _uid = ApiClient.instance.uid;
    _tracks.clear();
    if (_uid == null) {
      _ready = true;
      notifyListeners();
      return;
    }
    await _pull();
  }

  Future<void> _pull() async {
    try {
      final res = await ApiClient.instance.call('tracks.list', auth: true);
      _applyMap(res['tracks']);
    } catch (e) {
      debugPrint('Tracks pull via API failed: $e');
      _tracks.clear();
    }
    _ready = true;
    notifyListeners();
  }

  void _applyMap(dynamic raw) {
    _tracks.clear();
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      final track = CropTrack.fromMap(
        Map<String, dynamic>.from(
          Map<dynamic, dynamic>.from(entry.value as Map).map(
            (k, v) => MapEntry(k.toString(), v),
          ),
        ),
        fallbackId: entry.key.toString(),
      );
      _tracks.add(track);
    }
    _tracks.sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  Future<void> _requireUid() async {
    _uid ??= ApiClient.instance.uid;
    if (_uid == null) throw Exception('login_required');
  }

  String _dateKey([DateTime? dt]) {
    final d = dt ?? DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  CropTrack? byId(String id) {
    try {
      return _tracks.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<CropTrack> startTrack(CropItem crop) async {
    await _requireUid();
    final existing = _tracks.where((e) => e.cropId == crop.id).toList();
    if (existing.isNotEmpty) return existing.first;

    final track = CropTrack(
      id: 'track_${crop.id}_${DateTime.now().millisecondsSinceEpoch}',
      cropId: crop.id,
      nameEn: crop.nameEn,
      nameHi: crop.nameHi,
      emoji: crop.emoji,
      startedAt: DateTime.now().toIso8601String(),
    );
    await ApiClient.instance.call(
      'tracks.save',
      auth: true,
      data: {'trackId': track.id, 'track': track.toMap()},
    );
    _tracks.insert(0, track);
    notifyListeners();
    return track;
  }

  Future<DailyFieldLog> saveDailyLog({
    required String trackId,
    required String fieldMood,
    required double moisture,
    required String pestLevel,
    required String weather,
    required String note,
    required bool isHindi,
  }) async {
    await _requireUid();
    final track = byId(trackId);
    if (track == null) throw Exception('Track not found');

    final dateKey = _dateKey();
    final suggestions = buildSuggestions(
      cropName: track.name(isHindi),
      fieldMood: fieldMood,
      moisture: moisture,
      pestLevel: pestLevel,
      weather: weather,
      note: note,
      isHindi: isHindi,
    );

    final log = DailyFieldLog(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      dateKey: dateKey,
      fieldMood: fieldMood,
      moisture: moisture,
      pestLevel: pestLevel,
      weather: weather,
      note: note.trim(),
      suggestions: suggestions,
      createdAt: DateTime.now().toIso8601String(),
    );

    await ApiClient.instance.call(
      'tracks.log',
      auth: true,
      data: {
        'trackId': trackId,
        'dateKey': dateKey,
        'log': log.toMap(),
      },
    );
    await _pull();
    return log;
  }

  static List<String> buildSuggestions({
    required String cropName,
    required String fieldMood,
    required double moisture,
    required String pestLevel,
    required String weather,
    required String note,
    required bool isHindi,
  }) {
    final out = <String>[];
    final mood = fieldMood.toLowerCase();
    final pest = pestLevel.toLowerCase();
    final w = weather.toLowerCase();

    if (moisture < 0.35) {
      out.add(isHindi
          ? '$cropName में नमी कम है — आज हल्की सिंचाई करें, जड़ क्षेत्र नम रखें।'
          : 'Moisture is low for $cropName — give light irrigation today, keep root zone moist.');
    } else if (moisture > 0.75) {
      out.add(isHindi
          ? 'नमी ज्यादा है — आज पानी रोकें, जलभराव से जड़ सड़न बचें।'
          : 'Moisture is high — skip irrigation today to avoid root rot.');
    } else {
      out.add(isHindi
          ? 'नमी संतुलित है — आज सिंचाई तभी करें जब पत्ते हल्के मुरझाएँ।'
          : 'Moisture is balanced — irrigate only if leaves look slightly wilted.');
    }

    if (pest == 'high' || pest == 'medium') {
      out.add(isHindi
          ? 'कीट स्तर $pestLevel है — प्रभावित पत्तियाँ अलग करें और शाम को निगरानी स्प्रे प्लान बनाएँ।'
          : 'Pest level is $pestLevel — remove affected leaves and plan an evening scouting spray.');
    } else if (pest == 'low') {
      out.add(isHindi
          ? 'हल्का कीट दबाव — रोज सुबह खेत चक्कर बढ़ाएँ, जरूरत पड़ने पर जैविक उपाय अपनाएँ।'
          : 'Low pest pressure — increase morning field walks; use organic control if needed.');
    }

    if (mood.contains('poor') ||
        mood.contains('खराब') ||
        mood.contains('average') ||
        mood.contains('सामान्य')) {
      out.add(isHindi
          ? 'खेत की स्थिति कमजोर लग रही है — पत्ती रंग, रोग धब्बे और मिट्टी जाँच रिपोर्ट में नोट करें।'
          : 'Field condition looks weak — note leaf color, disease spots and soil check in report.');
    }

    if (w.contains('rain') || w.contains('बारिश')) {
      out.add(isHindi
          ? 'बारिश वाले दिन — छिड़काव टालें, नालियाँ साफ रखें।'
          : 'Rainy day — avoid spraying and keep drains clear.');
    } else if (w.contains('hot') || w.contains('गर्म')) {
      out.add(isHindi
          ? 'गर्मी तेज है — सिंचाई सुबह/शाम करें, दोपहर में काम कम करें।'
          : 'Hot weather — irrigate morning/evening and reduce midday work.');
    }

    if (note.trim().isNotEmpty) {
      out.add(isHindi
          ? 'आपके नोट के आधार पर: कल दोबारा उसी बिंदु की तुलना करके ट्रेंड देखें।'
          : 'Based on your note: compare the same point tomorrow to spot the trend.');
    }

    if (out.length < 2) {
      out.add(isHindi
          ? 'आज का डेटा सेव हो गया — कल फिर लॉग भरें ताकि रिपोर्ट और सटीक बने।'
          : 'Today’s data is saved — log again tomorrow for a sharper report.');
    }

    return out.take(4).toList();
  }

  CropReport buildReport(CropTrack track, {required bool isHindi}) {
    if (track.logs.isEmpty) {
      return CropReport(
        totalDays: 0,
        avgMoisturePercent: 0,
        mostCommonMood: '-',
        mostCommonPest: '-',
        mostCommonWeather: '-',
        keySuggestions: const [],
        summaryHi: 'अभी कोई डेली डेटा नहीं है। पहले आज का लॉग भरें।',
        summaryEn: 'No daily data yet. Add today’s log first.',
      );
    }

    String topOf(Iterable<String> values) {
      final map = <String, int>{};
      for (final v in values) {
        map[v] = (map[v] ?? 0) + 1;
      }
      final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return sorted.first.key;
    }

    final mood = topOf(track.logs.map((e) => e.fieldMood));
    final pest = topOf(track.logs.map((e) => e.pestLevel));
    final weather = topOf(track.logs.map((e) => e.weather));
    final avg = track.avgMoisture * 100;

    final suggestionFreq = <String, int>{};
    for (final log in track.logs) {
      for (final s in log.suggestions) {
        suggestionFreq[s] = (suggestionFreq[s] ?? 0) + 1;
      }
    }
    final topSuggestions = suggestionFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final summaryHi =
        '${track.nameHi} पर ${track.logs.length} दिनों का डेटा मिला। औसत नमी ${avg.round()}%. सबसे आम मूड: $mood, कीट: $pest, मौसम: $weather।';
    final summaryEn =
        '${track.nameEn}: ${track.logs.length} day(s) logged. Avg moisture ${avg.round()}%. Mood: $mood, pest: $pest, weather: $weather.';

    return CropReport(
      totalDays: track.logs.length,
      avgMoisturePercent: avg,
      mostCommonMood: mood,
      mostCommonPest: pest,
      mostCommonWeather: weather,
      keySuggestions: topSuggestions.take(3).map((e) => e.key).toList(),
      summaryHi: summaryHi,
      summaryEn: summaryEn,
    );
  }

  Future<void> removeTrack(String id) async {
    await _requireUid();
    await ApiClient.instance.call(
      'tracks.delete',
      auth: true,
      data: {'trackId': id},
    );
    _tracks.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}
