// ─────────────────────────────────────────────
//  Polyticks V4.0 – Razorpay Checkout Bridge (B13)
// ─────────────────────────────────────────────
//
//  Opens the native Razorpay payment sheet for a subscription created by
//  `create-subscription-checkout`. Activation itself always arrives via the
//  `payment-webhook` edge function — this bridge only collects payment.
//
//  Platform guard: razorpay_flutter is Android/iOS only. On web and in
//  simulation mode this returns false and callers fall back to messaging.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayCheckoutService {
  RazorpayCheckoutService._();

  /// Opens the payment sheet for [checkoutId]. Resolves true on successful
  /// payment capture (webhook does the actual tier activation), false on
  /// error/dismiss/unsupported platform.
  static Future<bool> openSubscriptionSheet({
    required String checkoutId,
    required String razorpayKeyId,
    String orgName = 'Organization',
    String description = 'Polyticks paid organization plan',
  }) async {
    if (kIsWeb || razorpayKeyId.isEmpty || checkoutId.startsWith('mock-')) {
      debugPrint('RazorpayCheckout: skipped (web/mock/unconfigured).');
      return false;
    }

    final rzp = Razorpay();
    final completer = Completer<bool>();

    void finish(bool ok) {
      if (!completer.isCompleted) completer.complete(ok);
      rzp.clear();
    }

    rzp.on(Razorpay.EVENT_PAYMENT_SUCCESS,
        (PaymentSuccessResponse _) => finish(true));
    rzp.on(Razorpay.EVENT_PAYMENT_ERROR,
        (PaymentFailureResponse res) {
      debugPrint('Razorpay error ${res.code}: ${res.message}');
      finish(false);
    });
    rzp.on(Razorpay.EVENT_EXTERNAL_WALLET,
        (ExternalWalletResponse _) => finish(true));

    rzp.open({
      'key': razorpayKeyId,
      // Subscription checkout: id from create-subscription-checkout.
      'subscription_id': checkoutId,
      'name': 'Polyticks',
      'description': '$description — $orgName',
      'theme': {'color': '#FF9933'}, // saffron
    });

    return completer.future;
  }
}
