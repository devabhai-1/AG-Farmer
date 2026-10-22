class DailyFieldLog {
  final String id;
  final String dateKey; // yyyy-MM-dd
  final String fieldMood;
  final double moisture; // 0..1
  final String pestLevel; // none, low, medium, high
  final String weather; // sunny, cloudy, rainy, hot
  final String note;
  final List<String> suggestions;
  final String createdAt;

  const DailyFieldLog({
    required this.id,
    required this.dateKey,
    required this.fieldMood,
    required this.moisture,
    required this.pestLevel,
    required this.weather,
    required this.note,
    required this.suggestions,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'dateKey': dateKey,
        'fieldMood': fieldMood,
        'moisture': moisture,
        'pestLevel': pestLevel,
        'weather': weather,
        'note': note,
        'suggestions': suggestions,
        'createdAt': createdAt,
      };

  factory DailyFieldLog.fromMap(Map<String, dynamic> map) {
    return DailyFieldLog(
      id: map['id']?.toString() ?? '',
      dateKey: map['dateKey']?.toString() ?? '',
      fieldMood: map['fieldMood']?.toString() ?? '',
      moisture: (map['moisture'] is num) ? (map['moisture'] as num).toDouble() : 0.5,
      pestLevel: map['pestLevel']?.toString() ?? 'none',
      weather: map['weather']?.toString() ?? 'sunny',
      note: map['note']?.toString() ?? '',
      suggestions: (map['suggestions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      createdAt: map['createdAt']?.toString() ?? '',
    );
  }
}

class CropTrack {
  final String id;
  final String cropId;
  final String nameEn;
  final String nameHi;
  final String emoji;
  final String startedAt;
  final List<DailyFieldLog> logs;

  CropTrack({
    required this.id,
    required this.cropId,
    required this.nameEn,
    required this.nameHi,
    required this.emoji,
    required this.startedAt,
    List<DailyFieldLog>? logs,
  }) : logs = logs ?? [];

  String name(bool hi) => hi ? nameHi : nameEn;

  DailyFieldLog? logForDate(String dateKey) {
    try {
      return logs.firstWhere((e) => e.dateKey == dateKey);
    } catch (_) {
      return null;
    }
  }

  DailyFieldLog? get latestLog {
    if (logs.isEmpty) return null;
    final sorted = [...logs]..sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return sorted.first;
  }

  double get avgMoisture {
    if (logs.isEmpty) return 0;
    return logs.map((e) => e.moisture).reduce((a, b) => a + b) / logs.length;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'cropId': cropId,
        'nameEn': nameEn,
        'nameHi': nameHi,
        'emoji': emoji,
        'startedAt': startedAt,
        'logs': {
          for (final log in logs) log.dateKey: log.toMap(),
        },
      };

  factory CropTrack.fromMap(Map<String, dynamic> map, {String? fallbackId}) {
    final logs = <DailyFieldLog>[];
    final rawLogs = map['logs'];
    if (rawLogs is List) {
      for (final item in rawLogs) {
        if (item is Map) {
          logs.add(DailyFieldLog.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    } else if (rawLogs is Map) {
      for (final entry in rawLogs.entries) {
        if (entry.value is Map) {
          final m = Map<String, dynamic>.from(
            Map<dynamic, dynamic>.from(entry.value as Map).map(
              (k, v) => MapEntry(k.toString(), v),
            ),
          );
          m.putIfAbsent('dateKey', () => entry.key.toString());
          logs.add(DailyFieldLog.fromMap(m));
        }
      }
    }
    logs.sort((a, b) => b.dateKey.compareTo(a.dateKey));

    return CropTrack(
      id: map['id']?.toString() ?? fallbackId ?? '',
      cropId: map['cropId']?.toString() ?? '',
      nameEn: map['nameEn']?.toString() ?? '',
      nameHi: map['nameHi']?.toString() ?? '',
      emoji: map['emoji']?.toString() ?? '🌾',
      startedAt: map['startedAt']?.toString() ?? '',
      logs: logs,
    );
  }
}

class CropReport {
  final int totalDays;
  final double avgMoisturePercent;
  final String mostCommonMood;
  final String mostCommonPest;
  final String mostCommonWeather;
  final List<String> keySuggestions;
  final String summaryHi;
  final String summaryEn;

  const CropReport({
    required this.totalDays,
    required this.avgMoisturePercent,
    required this.mostCommonMood,
    required this.mostCommonPest,
    required this.mostCommonWeather,
    required this.keySuggestions,
    required this.summaryHi,
    required this.summaryEn,
  });

  String summary(bool hi) => hi ? summaryHi : summaryEn;
}
