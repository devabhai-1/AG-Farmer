import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Result after a successful Razorpay checkout.
class RazorpayPayment {
  const RazorpayPayment({
    required this.paymentId,
    required this.signature,
    this.orderId = '',
    this.subscriptionId = '',
  });

  final String paymentId;
  final String signature;
  final String orderId;
  final String subscriptionId;
}

class PaymentCancelled implements Exception {
  const PaymentCancelled([this.message = 'payment_cancelled']);
  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper around `razorpay_flutter`.
class RazorpayCheckout {
  RazorpayCheckout._();
  static final RazorpayCheckout instance = RazorpayCheckout._();

  Future<RazorpayPayment> open({
    required String keyId,
    required String orderId,
    required String subscriptionId,
    required int amountPaise,
    required String description,
    required String email,
    required String phone,
    required String name,
  }) async {
    if (kIsWeb) {
      throw Exception('payment_failed');
    }
    final razorpay = Razorpay();
    final done = Completer<RazorpayPayment>();

    void clear() {
      try {
        razorpay.clear();
      } catch (_) {}
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse res) {
      if (done.isCompleted) return;
      done.complete(
        RazorpayPayment(
          paymentId: '${res.paymentId ?? ''}',
          signature: '${res.signature ?? ''}',
          orderId: '${res.orderId ?? orderId}',
          subscriptionId: subscriptionId,
        ),
      );
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse res) {
      if (done.isCompleted) return;
      final code = res.code;
      if (code == Razorpay.PAYMENT_CANCELLED) {
        done.completeError(const PaymentCancelled());
      } else {
        done.completeError(Exception('payment_failed'));
      }
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});

    final options = <String, dynamic>{
      'key': keyId,
      'amount': amountPaise,
      'name': 'AG Farmer',
      'description': description,
      'prefill': {
        'contact': phone,
        'email': email,
        'name': name,
      },
      'theme': {'color': '#0284C7'},
    };
    if (subscriptionId.isNotEmpty) {
      options['subscription_id'] = subscriptionId;
    } else if (orderId.isNotEmpty) {
      options['order_id'] = orderId;
    }

    try {
      razorpay.open(options);
      return await done.future.timeout(const Duration(minutes: 8));
    } on TimeoutException {
      throw Exception('payment_failed');
    } finally {
      clear();
    }
  }
}
