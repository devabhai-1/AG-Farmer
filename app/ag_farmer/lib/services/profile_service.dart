import 'package:flutter/foundation.dart';
import '../models/crop_item.dart';
import '../models/subscription_plan.dart';
import 'api_client.dart';
import 'catalog_service.dart';
import 'razorpay_checkout.dart';

/// Profile via backend API only — no database paths in the app.
class ProfileService extends ChangeNotifier {
  ProfileService(this._catalog);

  final CatalogService _catalog;

  String? _uid;
  String _name = '';
  String _phone = '';
  PlanTier _plan = PlanTier.free;
  final Set<String> _selectedCropIds = {};
  bool _ready = false;
  bool _paying = false;
  bool _autoRenew = false;

  String get name => _name;
  String get phone => _phone;
  PlanTier get plan => _plan;
  /// Server plan key (`free` / `local` / `advanced` / `all` / `super`).
  String get planId => _plan.planKey;
  bool get ready => _ready;
  bool get paying => _paying;
  bool get autoRenew => _autoRenew;
  Set<String> get selectedCropIds => Set.unmodifiable(_selectedCropIds);

  SubscriptionPlan? get activePaidPlan =>
      _catalog.planById(_plan == PlanTier.free ? null : _plan.planKey);

  int get planRank => _plan.rank;

  bool canAccess(CropItem crop) => planRank >= crop.minPlan.rank;

  /// Courses from ₹299. Free has chat, not the fasal course system.
  bool get hasCourseAccess => planRank >= PlanTier.advanced.rank;

  /// ₹599 Afim Special (and above)
  bool get hasAfimCourse => planRank >= PlanTier.allCrops.rank;

  bool get hasAfimLive => hasAfimCourse;

  List<CropItem> get selectedCrops {
    return _catalog.crops.where((c) => _selectedCropIds.contains(c.id)).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  Future<void> load() async {
    await ApiClient.instance.loadSession();
    if (ApiClient.instance.hasSession) {
      _uid = ApiClient.instance.uid;
      await _pull();
    } else {
      _ready = true;
      notifyListeners();
    }
  }

  /// Call after login / logout
  Future<void> syncSession() async {
    _uid = ApiClient.instance.uid;
    if (_uid == null) {
      _name = '';
      _phone = '';
      _plan = PlanTier.free;
      _autoRenew = false;
      _selectedCropIds.clear();
      _ready = true;
      notifyListeners();
      return;
    }
    await _pull();
  }

  Future<void> _pull() async {
    try {
      final res = await ApiClient.instance.call('users.me', auth: true);
      final user = res['user'];
      if (user is Map) {
        _applyUserMap(Map<dynamic, dynamic>.from(user));
      } else {
        _name = '';
        _phone = '';
        _plan = PlanTier.free;
        _autoRenew = false;
        _selectedCropIds.clear();
      }
    } catch (e) {
      debugPrint('Profile pull via API failed: $e');
      // Don't keep stale fields if server says empty / offline
      _name = '';
      _phone = '';
      _plan = PlanTier.free;
      _autoRenew = false;
      _selectedCropIds.clear();
    }
    _ready = true;
    notifyListeners();
  }

  void _applyUserMap(Map<dynamic, dynamic> map) {
    _name = (map['name'] ?? '').toString();
    _phone = (map['phone'] ?? '').toString();

    final sub = map['subscription'];
    var planId = sub is Map
        ? (sub['planId'] ?? '').toString()
        : (map['planId'] ?? map['plan'] ?? '').toString();
    if (sub is Map && sub['expiresAt'] is num) {
      final exp = (sub['expiresAt'] as num).toInt();
      if (exp > 0 && exp < DateTime.now().millisecondsSinceEpoch) {
        planId = 'free';
      }
    }
    if (planId.isEmpty || planId == 'free') {
      _plan = PlanTier.free;
      _autoRenew = false;
    } else {
      _plan = _catalog.planById(planId)?.tier ?? PlanTierX.fromKey(planId);
      _autoRenew = sub is Map && sub['autoRenew'] == true;
    }

    _selectedCropIds.clear();
    final crops = map['selectedCropIds'];
    if (crops is List) {
      _selectedCropIds.addAll(crops.map((e) => e.toString()));
    } else if (crops is Map) {
      _selectedCropIds.addAll(crops.keys.map((e) => e.toString()));
    }
  }

  Future<void> _ensureUid() async {
    _uid ??= ApiClient.instance.uid;
    if (_uid == null) throw Exception('login_required');
  }

  Future<void> updateProfile({required String name, required String phone}) async {
    await _ensureUid();
    _name = name.trim();
    _phone = phone.trim();
    await ApiClient.instance.call(
      'users.me.update',
      auth: true,
      data: {'name': _name, 'phone': _phone},
    );
    notifyListeners();
  }

  Future<Map<String, dynamic>> _billing(
    String action,
    Map<String, dynamic> data,
  ) {
    return ApiClient.instance.call(
      action,
      auth: true,
      data: data,
      timeout: const Duration(seconds: 12),
    );
  }

  Future<void> subscribe(SubscriptionPlan plan, {String cycle = 'monthly'}) async {
    if (_paying) return;
    _paying = true;
    notifyListeners();
    try {
      await _subscribe(plan, cycle: cycle);
    } finally {
      _paying = false;
      notifyListeners();
    }
  }

  Future<void> _subscribe(SubscriptionPlan plan, {required String cycle}) async {
    await _ensureUid();
    if (plan.payInr <= 0) return;

    final created = await _billing(
      'billing.checkout.create',
      {'planId': plan.id, 'cycle': cycle},
    );
    final early = created['user'];
    if (created['alreadyPaid'] == true && early is Map) {
      _applyUserMap(Map<dynamic, dynamic>.from(early));
      notifyListeners();
      return;
    }
    final checkout = created['checkout'];
    if (checkout is! Map) throw Exception('payment_failed');

    final orderId = '${checkout['orderId'] ?? ''}';
    final subscriptionId = '${checkout['subscriptionId'] ?? ''}';
    final amountRaw = checkout['amount'];
    final amountPaise = amountRaw is int
        ? amountRaw
        : int.tryParse('$amountRaw') ?? 0;
    final paid = await RazorpayCheckout.instance.open(
      keyId: '${checkout['keyId']}',
      subscriptionId: subscriptionId,
      orderId: orderId,
      amountPaise: amountPaise,
      description: '${checkout['description'] ?? plan.id}',
      email: ApiClient.instance.email ?? '',
      phone: _phone,
      name: _name,
    );

    Map<String, dynamic> verified;
    try {
      verified = await _verifyPaid(paid);
    } catch (_) {
      await Future<void>.delayed(const Duration(seconds: 2));
      verified = await _verifyPaid(paid);
    }
    final user = verified['user'];
    if (user is Map) {
      _applyUserMap(Map<dynamic, dynamic>.from(user));
    } else {
      await _pull();
    }
    notifyListeners();
  }
  Future<Map<String, dynamic>> _verifyPaid(RazorpayPayment paid) {
    return _billing(
      'billing.checkout.verify',
      {
        if (paid.subscriptionId.isNotEmpty) 'subscriptionId': paid.subscriptionId,
        if (paid.orderId.isNotEmpty) 'orderId': paid.orderId,
        'paymentId': paid.paymentId,
        'signature': paid.signature,
      },
    );
  }


  Future<void> clearSubscription() async {
    await _ensureUid();
    final res = await _billing('billing.subscription.cancel', {});
    final user = res['user'];
    if (user is Map) {
      _applyUserMap(Map<dynamic, dynamic>.from(user));
    } else {
      _autoRenew = false;
      _plan = PlanTier.free;
      _selectedCropIds.clear();
    }
    notifyListeners();
  }

  Future<void> toggleCrop(CropItem crop) async {
    if (!canAccess(crop)) return;
    await _ensureUid();
    if (_selectedCropIds.contains(crop.id)) {
      _selectedCropIds.remove(crop.id);
    } else {
      _selectedCropIds.add(crop.id);
    }
    await ApiClient.instance.call(
      'users.me.update',
      auth: true,
      data: {'selectedCropIds': _selectedCropIds.toList()},
    );
    notifyListeners();
    // ignore: unawaited_futures
    ApiClient.instance.logActivity(
      'crop_toggle',
      detail: {
        'cropId': crop.id,
        'on': _selectedCropIds.contains(crop.id),
      },
      state: {'selectedCropIds': _selectedCropIds.toList()},
    );
  }

  Future<void> setSelectedCrops(Set<String> ids) async {
    await _ensureUid();
    final allowed = _catalog.crops.where(canAccess).map((e) => e.id).toSet();
    _selectedCropIds
      ..clear()
      ..addAll(ids.where(allowed.contains));
    await ApiClient.instance.call(
      'users.me.update',
      auth: true,
      data: {'selectedCropIds': _selectedCropIds.toList()},
    );
    notifyListeners();
  }
}
