import 'dart:developer';
import 'package:get/get.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../ads/config.dart';
import 'iap.dart';
import 'my_dialogs.dart';
import 'pref.dart';

class RazorpayHelper {
  static Razorpay? _razorpay;

  static void init() {
    dispose();
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  static void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }

  static void _handlePaymentSuccess(PaymentSuccessResponse response) {
    log('Razorpay Success: ${response.paymentId} - ${response.orderId}');
    IAP.isPurchased.value = true;
    Pref.isPurchased = true;
    MyDialogs.success(msg: 'Payment Successful!\nYou are a Premium User now.');
    Get.back(); // close premium screen on success
  }

  static void _handlePaymentError(PaymentFailureResponse response) {
    log('Razorpay Error: ${response.code} - ${response.message}');
    if (response.code != Razorpay.PAYMENT_CANCELLED) {
      MyDialogs.error(msg: response.message ?? 'Payment Failed. Please try again.');
    }
  }

  static void _handleExternalWallet(ExternalWalletResponse response) {
    log('Razorpay External Wallet: ${response.walletName}');
  }

  static void openCheckout({
    int amountInPaise = 10000, // ₹100.00
    String name = 'Ably PDF',
    String description = 'Lifetime Premium Access (No Ads)',
  }) {
    try {
      init();
      var options = {
        'key': Config.razorpayKey,
        'amount': amountInPaise,
        'name': name,
        'description': description,
        'currency': 'INR',
        'theme': {
          'color': '#245AE4',
        },
        'retry': {'enabled': true, 'max_count': 1},
        'send_sms_hash': true,
        'prefill': {
          'contact': '',
          'email': '',
        },
        'external': {
          'wallets': ['paytm', 'phonepe', 'gpay']
        }
      };

      _razorpay!.open(options);
    } catch (e) {
      log('Razorpay open error: $e');
      MyDialogs.error(msg: 'Failed to initiate Razorpay: $e');
    }
  }
}
