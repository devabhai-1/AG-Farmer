import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/crop_knowledge.dart';

const _allKey = 'ag_jankari_all_v1';
const _allStampKey = 'ag_jankari_all_stamp_v1';
String _cropKey(String id) => 'ag_jankari_crop_$id';
String _cropStampKey(String id) => 'ag_jankari_crop_stamp_$id';

/// Phone cache for Fasal Jankari posts (full list + per-crop).
class JankariCache {
  JankariCache._();

  static Future<List<CropKnowledgePost>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_allKey);
      if (raw == null || raw.isEmpty) return const [];
      return _decodeList(raw);
    } catch (e) {
      debugPrint('jankari cache loadAll: $e');
      return const [];
    }
  }

  static Future<String?> stampAll() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_allStampKey);
  }

  static Future<void> saveAll(
    List<CropKnowledgePost> posts,
    String stamp,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_allKey, jsonEncode(posts.map((p) => p.toJson()).toList()));
    if (stamp.isNotEmpty) {
      await prefs.setString(_allStampKey, stamp);
    }
  }

  static Future<List<CropKnowledgePost>> loadCrop(String cropId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cropKey(cropId));
      if (raw == null || raw.isEmpty) return const [];
      return _decodeList(raw);
    } catch (e) {
      debugPrint('jankari cache loadCrop: $e');
      return const [];
    }
  }

  static Future<String?> stampCrop(String cropId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cropStampKey(cropId));
  }

  static Future<void> saveCrop(
    String cropId,
    List<CropKnowledgePost> posts,
    String stamp,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cropKey(cropId),
      jsonEncode(posts.map((p) => p.toJson()).toList()),
    );
    if (stamp.isNotEmpty) {
      await prefs.setString(_cropStampKey(cropId), stamp);
    }
  }

  static List<CropKnowledgePost> _decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final out = <CropKnowledgePost>[];
    for (final row in decoded) {
      if (row is! Map) continue;
      final post = CropKnowledgePost.fromApi(Map<String, dynamic>.from(row));
      if (post.id.isNotEmpty) out.add(post);
    }
    return out;
  }
}
