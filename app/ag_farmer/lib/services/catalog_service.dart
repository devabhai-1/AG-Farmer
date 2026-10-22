import 'package:flutter/foundation.dart';
import '../models/crop_item.dart';
import '../models/subscription_plan.dart';
import 'api_client.dart';

/// Catalog via backend API only — app never touches database paths.
class CatalogService extends ChangeNotifier {
  List<CropItem> _crops = [];
  List<SubscriptionPlan> _plans = [];
  int _updatedAt = 0;
  bool _ready = false;
  String? _error;

  List<CropItem> get crops => List.unmodifiable(_crops);
  List<SubscriptionPlan> get plans => List.unmodifiable(_plans);
  List<SubscriptionPlan> get paidPlans =>
      _plans.where((p) =>
          p.tier != PlanTier.free &&
          p.tier != PlanTier.local &&
          p.active &&
          p.priceInr > 0 &&
          p.priceInr != 99).toList()
        ..sort((a, b) => a.rank.compareTo(b.rank));
  bool get ready => _ready;
  String? get error => _error;

  Future<void> load() async {
    try {
      final res = await ApiClient.instance.call('catalog.all');
      final stamp = res['updatedAt'];
      final nextAt = stamp is num ? stamp.toInt() : 0;
      if (_ready && nextAt > 0 && nextAt == _updatedAt) {
        _error = null;
        return;
      }
      _applyPayload(res);
      if (nextAt > 0) _updatedAt = nextAt;
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Catalog load failed: $e');
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> refresh() => load();

  void _applyPayload(Map<String, dynamic> res) {
    final cropMap = res['crops'];
    if (cropMap is Map) {
      _crops = cropMap.entries
          .where((e) => e.value is Map)
          .map((e) => CropItem.fromMap(
                e.key.toString(),
                Map<dynamic, dynamic>.from(e.value as Map),
              ))
          .where((c) => c.active)
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));
    } else {
      _crops = [];
    }

    final planMap = res['plans'];
    if (planMap is Map) {
      _plans = planMap.entries
          .where((e) => e.value is Map)
          .map(
            (e) => SubscriptionPlan.fromMap(
              e.key.toString(),
              Map<dynamic, dynamic>.from(e.value as Map),
            ),
          )
          .where((p) => p.active)
          .toList()
        ..sort((a, b) => a.rank.compareTo(b.rank));
    } else {
      _plans = [];
    }
  }

  CropItem? cropById(String id) {
    try {
      return _crops.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  SubscriptionPlan? planById(String? id) {
    if (id == null) return null;
    try {
      return _plans.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  List<CropItem> indiaCourseCrops() {
    const excluded = {
      'afim_live',
      'hydroponics',
      'protected_farming',
      'organic_mix',
      'seed_spice',
      'beekeeping_crop',
      'ai_scouting',
      'high_value_veg',
    };
    final list = _crops.where((c) => !excluded.contains(c.id)).toList();
    list.sort((a, b) {
      if (a.id == 'afim') return -1;
      if (b.id == 'afim') return 1;
      if (a.id == 'lasun') return -1;
      if (b.id == 'lasun') return 1;
      return a.priority.compareTo(b.priority);
    });
    return list;
  }
}
