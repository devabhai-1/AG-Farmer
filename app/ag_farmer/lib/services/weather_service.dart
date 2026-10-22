import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class RainSlot {
  final DateTime time;
  final int probability;
  const RainSlot({required this.time, required this.probability});

  factory RainSlot.fromMap(Map<dynamic, dynamic> map) {
    return RainSlot(
      time: DateTime.tryParse('${map['time']}')?.toLocal() ?? DateTime.now(),
      probability: int.tryParse('${map['probability']}') ?? 0,
    );
  }
}

class WeatherHour {
  final DateTime time;
  final int? temp;
  final int probability;
  final double mm;
  final String icon;
  const WeatherHour({
    required this.time,
    required this.temp,
    required this.probability,
    required this.mm,
    required this.icon,
  });
}

class WeatherDay {
  final DateTime date;
  final int probability;
  final double rainMm;
  final int? tempMax;
  final int? tempMin;
  final String icon;
  final bool bad;
  final List<WeatherHour> hours;
  const WeatherDay({
    required this.date,
    required this.probability,
    required this.rainMm,
    required this.tempMax,
    required this.tempMin,
    required this.icon,
    required this.bad,
    required this.hours,
  });
}

class FarmWeather {
  final String place;
  final double? lat;
  final double? lon;
  final int? temp;
  final int? humidity;
  final int? wind;
  final String conditionHi;
  final String conditionEn;
  final String icon;
  final bool precise;
  final RainSlot? nextRain;
  final int maxPop;
  final List<WeatherHour> hours;
  final List<WeatherDay> days;

  const FarmWeather({
    required this.place,
    required this.lat,
    required this.lon,
    required this.temp,
    required this.humidity,
    required this.wind,
    required this.conditionHi,
    required this.conditionEn,
    required this.icon,
    required this.precise,
    required this.nextRain,
    required this.maxPop,
    required this.hours,
    required this.days,
  });

  String condition(bool hi) => hi ? conditionHi : conditionEn;

  FarmWeather copy({bool? precise}) {
    return FarmWeather(
      place: place,
      lat: lat,
      lon: lon,
      temp: temp,
      humidity: humidity,
      wind: wind,
      conditionHi: conditionHi,
      conditionEn: conditionEn,
      icon: icon,
      precise: precise ?? this.precise,
      nextRain: nextRain,
      maxPop: maxPop,
      hours: hours,
      days: days,
    );
  }

  factory FarmWeather.fromMap(Map<dynamic, dynamic> map) {
    int? n(dynamic v) => v == null ? null : (v is num ? v.round() : int.tryParse('$v'));
    double mmOf(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    WeatherHour hourOf(Map row) {
      return WeatherHour(
        time: DateTime.tryParse('${row['time']}') ?? DateTime.now(),
        temp: n(row['temp']),
        probability: n(row['probability']) ?? 0,
        mm: mmOf(row['mm']),
        icon: '${row['icon'] ?? '🌡️'}',
      );
    }

    final rain = map['nextRain'];
    final hours = map['hours'];
    final days = map['days'];
    return FarmWeather(
      place: '${map['place'] ?? ''}',
      lat: map['lat'] is num ? (map['lat'] as num).toDouble() : double.tryParse('${map['lat']}'),
      lon: map['lon'] is num ? (map['lon'] as num).toDouble() : double.tryParse('${map['lon']}'),
      temp: n(map['temp']),
      humidity: n(map['humidity']),
      wind: n(map['wind']),
      conditionHi: '${map['conditionHi'] ?? 'मौसम'}',
      conditionEn: '${map['conditionEn'] ?? 'Weather'}',
      icon: '${map['icon'] ?? '🌡️'}',
      precise: map['precise'] != false,
      nextRain: rain is Map ? RainSlot.fromMap(rain) : null,
      maxPop: n(map['maxPop']) ?? 0,
      hours: hours is List ? hours.whereType<Map>().map(hourOf).toList() : const [],
      days: days is List
          ? days.whereType<Map>().map((row) {
              final probability = n(row['probability']) ?? 0;
              final rawHours = row['hours'];
              return WeatherDay(
                date: DateTime.tryParse('${row['date']}') ?? DateTime.now(),
                probability: probability,
                rainMm: mmOf(row['rainMm']),
                tempMax: n(row['tempMax']),
                tempMin: n(row['tempMin']),
                icon: '${row['icon'] ?? '🌡️'}',
                bad: row['bad'] == true || probability >= 50,
                hours: rawHours is List ? rawHours.whereType<Map>().map(hourOf).toList() : const [],
              );
            }).toList()
          : const [],
    );
  }
}

class PlaceHit {
  final String label;
  final double lat;
  final double lon;
  const PlaceHit({required this.label, required this.lat, required this.lon});
}

class WeatherService {
  static const _savedKey = 'ag_precise_place';
  static const _gps = LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 0,
    timeLimit: Duration(seconds: 20),
  );

  static bool _fresh(Position pos) {
    if (pos.accuracy <= 0 || pos.accuracy > 100) return false;
    final age = DateTime.now().difference(pos.timestamp);
    return !age.isNegative && age.inMinutes <= 2;
  }

  static Future<({double? lat, double? lon})> _position() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return (lat: null, lon: null);
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return (lat: null, lon: null);
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(locationSettings: _gps);
        if (!_fresh(pos)) {
          pos = await Geolocator.getCurrentPosition(locationSettings: _gps);
        }
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null || !_fresh(pos)) return (lat: null, lon: null);
      return (lat: pos.latitude, lon: pos.longitude);
    } catch (_) {
      return (lat: null, lon: null);
    }
  }

  /// GPS for a photo/video shot. Last-known or saved farm if live fix is slow.
  static Future<({double lat, double lon})?> fixNow() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final denied = perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever;
      if (enabled && !denied) {
        Position? pos;
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 8),
            ),
          );
        } catch (_) {
          pos = await Geolocator.getLastKnownPosition();
        }
        if (pos != null && pos.latitude.abs() + pos.longitude.abs() > 0.001) {
          return (lat: pos.latitude, lon: pos.longitude);
        }
      }
      final saved = await _readSaved();
      if (saved != null) return (lat: saved.lat, lon: saved.lon);
      return null;
    } catch (_) {
      final saved = await _readSaved();
      if (saved != null) return (lat: saved.lat, lon: saved.lon);
      return null;
    }
  }

  static Future<List<PlaceHit>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final res = await ApiClient.instance.call(
      'weather.search',
      data: {'query': q},
      timeout: const Duration(seconds: 12),
    );
    final rows = res['places'];
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map && row['lat'] != null && row['lon'] != null)
          PlaceHit(
            label: '${row['label'] ?? ''}'.trim(),
            lat: row['lat'] is num ? (row['lat'] as num).toDouble() : double.parse('${row['lat']}'),
            lon: row['lon'] is num ? (row['lon'] as num).toDouble() : double.parse('${row['lon']}'),
          ),
    ].where((hit) => hit.label.isNotEmpty).toList();
  }

  static Future<({double lat, double lon, String place})?> savedFarm() =>
      _readSaved();

  static Future<({double lat, double lon, String place})?> _readSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedKey);
      if (raw == null || raw.isEmpty) return null;
      final body = jsonDecode(raw);
      if (body is! Map) return null;
      final lat = body['lat'];
      final lon = body['lon'];
      if (lat is! num || lon is! num) return null;
      return (lat: lat.toDouble(), lon: lon.toDouble(), place: '${body['place'] ?? ''}'.trim());
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeSaved(double lat, double lon, String place) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _savedKey,
        jsonEncode({'lat': lat, 'lon': lon, 'place': place}),
      );
    } catch (_) {}
  }

  /// City from the phone's public IP when GPS is off. Not a street address.
  static Future<({double lat, double lon, String place})?> _approxFromIp() async {
    try {
      final res = await http.get(Uri.parse('https://ipwho.is/')).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body is! Map || body['success'] != true) return null;
      final lat = body['latitude'];
      final lon = body['longitude'];
      if (lat is! num || lon is! num) return null;
      final city = '${body['city'] ?? ''}'.trim();
      final region = '${body['region'] ?? ''}'.trim();
      final place = [city, region].where((part) => part.isNotEmpty).join(', ');
      return (lat: lat.toDouble(), lon: lon.toDouble(), place: place);
    } catch (_) {
      return null;
    }
  }

  static Future<FarmWeather> load({double? lat, double? lon, String? place}) async {
    var useLat = lat;
    var useLon = lon;
    var usePlace = place;
    var approximate = false;
    if (useLat == null || useLon == null) {
      final pos = await _position();
      useLat = pos.lat;
      useLon = pos.lon;
    }
    if (useLat != null && useLon != null) {
      await _writeSaved(useLat, useLon, usePlace ?? '');
    } else {
      final saved = await _readSaved();
      if (saved != null) {
        useLat = saved.lat;
        useLon = saved.lon;
        if (usePlace == null || usePlace.trim().isEmpty) usePlace = saved.place;
      } else {
        final ip = await _approxFromIp();
        if (ip != null) {
          useLat = ip.lat;
          useLon = ip.lon;
          if (usePlace == null || usePlace.trim().isEmpty) usePlace = ip.place;
          approximate = true;
        }
      }
    }
    final res = await ApiClient.instance.call(
      'weather.forecast',
      data: {
        if (useLat != null) 'lat': useLat,
        if (useLon != null) 'lon': useLon,
        if (usePlace != null && usePlace.trim().isNotEmpty) 'place': usePlace.trim(),
        if (approximate) 'approximate': true,
      },
      timeout: const Duration(seconds: 18),
    );
    final weather = res['weather'];
    if (weather is! Map) throw Exception('weather_missing');
    final parsed = FarmWeather.fromMap(weather);
    final shown = approximate && parsed.precise ? parsed : (approximate ? parsed.copy(precise: false) : parsed);
    if (shown.precise && shown.lat != null && shown.lon != null) {
      await _writeSaved(shown.lat!, shown.lon!, shown.place);
    }
    return shown;
  }
}
