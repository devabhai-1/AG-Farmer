import 'package:facebook_app_events/facebook_app_events.dart';

/// Meta (Facebook) App Events bridge.
/// Supports standard Meta events:
///  - Complete Registration (fb_mobile_complete_registration)
///  - Initiate Checkout (fb_mobile_initiated_checkout)
///  - Purchase (fb_mobile_purchase)
///  - Subscribe (Subscribe)
///  - View Content (fb_mobile_content_view)
///  - Search (fb_mobile_search)
///  - Contact (Contact)
///  - Rate (fb_mobile_rate)
///  - Add Payment Info (fb_mobile_add_payment_info)
class MetaEvents {
  MetaEvents._();
  static final MetaEvents instance = MetaEvents._();

  final FacebookAppEvents _fb = FacebookAppEvents();
  bool _ready = false;

  /// Initialize the Meta SDK and enable Advertiser Tracking (iOS 14+ & Android).
  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _fb.initializeSdk();
      await _fb.setAdvertiserTracking(enabled: true, collectId: true);
      await _fb.setAdvertiserIdCollectionEnabled(true);
      await _fb.setAutoLogAppEventsEnabled(true);
    } catch (_) {
      // Best effort
    }
  }

  /// Log a custom event
  Future<void> logEvent(
    String name, {
    Map<String, Object?>? parameters,
    double? valueToSum,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (parameters != null) {
        parameters.forEach((k, v) {
          if (v != null) params[k] = v;
        });
      }
      await _fb.logEvent(name: name, parameters: params, valueToSum: valueToSum);
    } catch (_) {}
  }

  /// 1. App Open
  Future<void> logAppOpen() => logEvent('AppOpen');

  /// 2. Complete Registration
  Future<void> logCompletedRegistration({String method = 'email'}) async {
    try {
      await _fb.logCompletedRegistration(registrationMethod: method);
    } catch (_) {}
  }

  /// 3. Initiate Checkout
  Future<void> logInitiatedCheckout({
    required double amount,
    String currency = 'INR',
    String? contentId,
    String? contentType,
  }) async {
    try {
      await _fb.logInitiatedCheckout(
        totalPrice: amount,
        currency: currency,
        contentId: contentId,
        contentType: contentType,
        paymentInfoAvailable: true,
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
    try {
      await _fb.logPurchase(
        amount: amount,
        currency: currency,
        parameters: {
          if (contentId != null) FacebookAppEvents.paramNameContentId: contentId,
          if (contentType != null)
            FacebookAppEvents.paramNameContentType: contentType,
          if (orderId != null) FacebookAppEvents.paramNameOrderId: orderId,
        },
      );
    } catch (_) {}
  }

  /// 5. Subscribe
  Future<void> logSubscribe({
    required double price,
    String currency = 'INR',
    String? orderId,
  }) async {
    try {
      await _fb.logSubscribe(
        price: price,
        currency: currency,
        orderId: orderId ?? 'sub_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (_) {}
  }

  /// 6. View Content
  Future<void> logViewContent({
    required String contentId,
    required String contentType,
    double? price,
    String currency = 'INR',
  }) async {
    try {
      await _fb.logViewContent(
        id: contentId,
        type: contentType,
        price: price,
        currency: currency,
      );
    } catch (_) {}
  }

  /// 7. Search
  Future<void> logSearched({
    required String searchString,
    String? contentType,
  }) async {
    try {
      await _fb.logSearched(
        searchString: searchString,
        contentType: contentType,
      );
    } catch (_) {}
  }

  /// 8. Contact
  Future<void> logContact({String? method}) async {
    try {
      await _fb.logContact(
        parameters: {
          if (method != null) 'contact_method': method,
        },
      );
    } catch (_) {}
  }

  /// 9. Rate
  Future<void> logRated({
    required double rating,
    double maxRating = 5.0,
    String? contentId,
    String? contentType,
  }) async {
    try {
      await _fb.logRated(
        valueToSum: rating,
        parameters: {
          'fb_max_rating_value': maxRating,
          if (contentId != null) FacebookAppEvents.paramNameContentId: contentId,
          if (contentType != null)
            FacebookAppEvents.paramNameContentType: contentType,
        },
      );
    } catch (_) {}
  }

  /// 10. Add Payment Info
  Future<void> logAddedPaymentInfo({bool success = true}) async {
    try {
      await _fb.logAddedPaymentInfo(
        parameters: {
          'success': success ? '1' : '0',
        },
      );
    } catch (_) {}
  }

  /// 11. Start Trial
  Future<void> logStartTrial({
    required String orderId,
    double? price,
    String currency = 'INR',
  }) async {
    try {
      await _fb.logStartTrial(
        orderId: orderId,
        price: price,
        currency: currency,
      );
    } catch (_) {}
  }
}
