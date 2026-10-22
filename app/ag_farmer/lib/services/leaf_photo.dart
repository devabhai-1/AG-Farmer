import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import 'weather_service.dart';

/// A real camera or gallery photo, ready to send as JPEG base64.
class LeafPhoto {
  const LeafPhoto({
    required this.path,
    required this.name,
    required this.base64,
    required this.bytes,
    this.lat,
    this.lon,
  });

  final String path;
  final String name;
  final String base64;
  final int bytes;
  final double? lat;
  final double? lon;
}

class LeafPhotoPicker {
  static const maxBytes = 4 * 1024 * 1024;
  static final ImagePicker _picker = ImagePicker();

  static Future<LeafPhoto?> pick(ImageSource source) async {
    final shot = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (shot == null) return null;
    final geoFuture = WeatherService.fixNow();
    final raw = await shot.readAsBytes();
    if (raw.isEmpty) {
      throw StateError('empty_file');
    }
    if (raw.length > maxBytes) {
      throw StateError('file_too_large');
    }
    final geo = await geoFuture;
    return LeafPhoto(
      path: shot.path,
      name: shot.name,
      base64: base64Encode(raw),
      bytes: raw.length,
      lat: geo?.lat,
      lon: geo?.lon,
    );
  }
}
