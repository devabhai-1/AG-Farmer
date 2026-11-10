import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';

import 'meta_events.dart';

/// Unified app-analytics facade. Every call fans out to BOTH:
///  * Firebase Analytics (native google-services.json)
///  * Meta App Events (facebook_app_events)
class FBAnalytics {
  FBAnalytics._();
  static final FBAnalytics instance = FBAnalytics._();

  bool _ready = false;
  FirebaseAnalytics? _fa;
  String? _appId;

  /// Warm up the Meta bridge and Firebase instance.
  Future<bool> init() async {
    if (_ready) return _fa != null;
    _ready = true;
    unawaited(MetaEvents.instance.init());
    try {
      final fa = FirebaseAnalytics.instance;
      _fa = fa;
      _appId = fa.app.options.appId;
    } catch (_) {
      _fa = null;
      _appId = null;
    }
    return _fa != null;
  }

  /// Log a custom app event on BOTH Firebase and Meta.
  Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    if (parameters != null) {
      unawaited(MetaEvents.instance.logEvent(
        name,
        parameters: parameters.map((k, v) => MapEntry(k, v as Object?)),
      ));
    } else {
      unawaited(MetaEvents.instance.logEvent(name));
    }

    final fa = _fa;
    if (fa == null) return;
    try {
      await fa.logEvent(name: name, parameters: parameters);
    } catch (_) {}
  }

  Future<String?> appId() async {
    if (_appId == null && _fa == null) await init();
    return _appId;
  }

  /// 1. App Open
  Future<void> logAppOpen() async {
    unawaited(MetaEvents.instance.logAppOpen());
    final fa = _fa;
    if (fa == null) return;
    try {
      await fa.logAppOpen();
    } catch (_) {}
  }

  /// Screen View
  Future<void> logScreenView(String screenName, {String? screenClass}) async {
    unawaited(MetaEvents.instance.logEvent(
      'screen_view',
      parameters: {
        'screen_name': screenName,
        if (screenClass != null && screenClass.isNotEmpty)
          'screen_class': screenClass,
      },
    ));
    final fa = _fa;
    if (fa == null) return;
    try {
      await fa.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
    } catch (_) {}
  }

  /// 2. Complete Registration
  Future<void> logCompletedRegistration({String method = 'email'}) async {
    unawaited(MetaEvents.instance.logCompletedRegistration(method: method));
    final fa = _fa;
    if (fa == null) return;
    try {
      await fa.logSignUp(signUpMethod: method);
    } catch (_) {}
  }

  /// 3. Initiate Checkout
  Future<void> logInitiatedCheckout({
    required double amount,
    String currency = 'INR',
    String? contentId,
    String? contentType,
  }) async {
    unawaited(MetaEvents.instance.logInitiatedCheckout(
      amount: amount,
      currency: currency,
      contentId: contentId,
      contentType: contentType,
    ));
    final fa = _fa;
    if (fa == null) return;
    try {
      await fa.logBeginCheckout(
        value: amount,
        currency: currency,
        items: [
          AnalyticsEventItem(
            itemId: contentId ?? 'plan',
            itemName: contentId ?? 'Subscription',
            itemCategory: contentType ?? 'subscription',
            price: amount,
          ),
        ],
      );
    } catch (_) {}
  }

  /// 4. Purchase
  Future<void> logPurchase({
    required double amount,
    String currency = 'INR',
    String? contentId,
    String? contentType,
    String? orderId,
  }) async {
    unawaited(MetaEvents.instance.logPurchase(
      amount: amount,
      currency: currency,
      contentId: contentId,
      contentType: contentType,
      orderId: orderId,
    ));
    final fa = _fa;
    if (fa == null) return;
    try {
      await fa.logPurchase(
        currency: currency,
        value: amount,
        transactionId: orderId,
        items: [
          AnalyticsEventItem(
            itemId: contentId ?? 'plan',
            itemName: contentId ?? 'Subscription',
            itemCategory: contentType ?? 'subscription',
            price: amount,
          ),
        ],
      );
    } catch (_) {}
  }

  /// 5. Subscribe
  Future<void> logSubscribe({
    required double price,
    String currency = 'INR',
    String? orderId,
  }) async {
    unawaited(MetaEvents.instance.logSubscribe(
      price: price,
      currency: currency,
      orderId: orderId,
    ));
  }

  /// 6. View Content
  Future<void> logViewContent({
    required String contentId,
    required String contentType,
    double? price,
    String currency = 'INR',
  }) async {
    unawaited(MetaEvents.instance.logViewContent(
      contentId: contentId,
      contentType: contentType,
      price: price,
      currency: currency,
    ));
    final fa = _fa;
    if (fa == null) return;
    try {
      await fa.logViewItem(
        currency: currency,
        value: price,
        items: [
          AnalyticsEventItem(
            itemId: contentId,
            itemName: contentId,
            itemCategory: contentType,
            price: price,
          ),
        ],
      );
    } catch (_) {}
  }

  /// 7. Search
  Future<void> logSearched({
    required String searchString,
    String? contentType,
  }) async {
    unawaited(MetaEvents.instance.logSearched(
      searchString: searchString,
      contentType: contentType,
    ));
    final fa = _fa;
    if (fa == null) return;
    try {
      await fa.logSearch(searchTerm: searchString);
    } catch (_) {}
  }

  /// 8. Contact
  Future<void> logContact({String? method}) async {
    unawaited(MetaEvents.instance.logContact(method: method));
    final fa = _fa;
    if (fa == null) return;
    try {
      await fa.logEvent(name: 'contact', parameters: {
        if (method != null) 'method': method,
      });
    } catch (_) {}
  }

  /// 9. Rate
  Future<void> logRated({
    required double rating,
    double maxRating = 5.0,
    String? contentId,
    String? contentType,
  }) async {
    unawaited(MetaEvents.instance.logRated(
      rating: rating,
      maxRating: maxRating,
      contentId: contentId,
      contentType: contentType,
    ));
  }

  /// 10. Add Payment Info
  Future<void> logAddedPaymentInfo({bool success = true}) async {
    unawaited(MetaEvents.instance.logAddedPaymentInfo(success: success));
    final fa = _fa;
    if (fa == null) return;
    try {
      await fa.logAddPaymentInfo(
        parameters: {'success': success ? '1' : '0'},
      );
    } catch (_) {}
  }

  /// 11. Start Trial
  Future<void> logStartTrial({
    required String orderId,
    double? price,
    String currency = 'INR',
  }) async {
    unawaited(MetaEvents.instance.logStartTrial(
      orderId: orderId,
      price: price,
      currency: currency,
    ));
  }
}
