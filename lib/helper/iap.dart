import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../helper/my_dialogs.dart';
import 'pref.dart';

class IAP {
  static final RxBool isPurchased = false.obs;
  static bool showDialog = true;

  static final InAppPurchase _iap = InAppPurchase.instance;

  // subscription that listens to a stream of updates to purchase details
  static StreamSubscription? _subscription;

  static void dispose() {
    _subscription?.cancel();
  }

  static Future<void> initialize({required bool showDialogs}) async {
    showDialog = showDialogs;
    final purchaseUpdated = _iap.purchaseStream;
    _subscription ??= purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () {
        log('purchase done');
      },
      onError: (e) {
        log('purchase error: $e');
        // MyDialogs.info(msg: 'purchase error: $e');
      },
    );
    restorePurchase();
  }

  static void restorePurchase() {
    _iap.restorePurchases();
  }

  static Future<void> _onPurchaseUpdate(
      List<PurchaseDetails> purchaseDetailsList) async {
    log('purchase update called');
    // MyDialogs.info(msg: 'purchase update called');

    for (var purchaseDetails in purchaseDetailsList) {
      await _handlePurchase(purchaseDetails);
    }
  }

  static Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    log('purchaseDetails: ${purchaseDetails.status} - ${purchaseDetails.pendingCompletePurchase} - ${purchaseDetails.purchaseID} - ${purchaseDetails.transactionDate} - ${purchaseDetails.verificationData.localVerificationData}');

    if (jsonDecode(purchaseDetails.verificationData.localVerificationData)[
            'acknowledged'] ==
        true) {
      IAP.isPurchased.value = true;
      Pref.isPurchased = IAP.isPurchased.value;

      _subscription?.cancel();
      log('isPurchased: ${IAP.isPurchased}');
    } else {
      IAP.isPurchased.value = false;
      Pref.isPurchased = IAP.isPurchased.value;

      log('isPurchased: ${IAP.isPurchased}');
    }

    if (showDialog) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          MyDialogs.info(msg: 'We\'re Processing Your Request.\nPlease wait.');
          break;

        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          MyDialogs.info(
              msg:
                  'Something went wrong.\nYour money will be refunded within 3 days if it was deducted.');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          break;
      }
    }

    if (purchaseDetails.pendingCompletePurchase) {
      await _iap.completePurchase(purchaseDetails);

      // Sirf genuine purchase/restore par hi premium mark karo.
      // Pehle yahan bina status check kiye hamesha true set ho raha tha,
      // jiski wajah se cancel/pending/error event par bhi ads hide ho jati thi.
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        IAP.isPurchased.value = true;
        Pref.isPurchased = IAP.isPurchased.value;

        log('isPurchased: ${IAP.isPurchased}');

        if (showDialog) {
          MyDialogs.info(
              msg: 'Payment Successful.\nYou\'re an Premium User now.');
        }
      }
    }
  }

  static Future<List<ProductDetails>> getProducts() async {
    try {
      final res = await _iap.queryProductDetails(
          {'product1'}); //Imp for fetching product from playstore
      log('\nproducts: ${res.productDetails.first.title} - ${res.productDetails.first.id} - ${res.productDetails.first.price}');
      return res.productDetails;
    } catch (e) {
      log('getProductsE: $e');
      return [];
    }
  }

  static Future<void> buyProduct(ProductDetails prod) async {
    try {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: prod);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      if (showDialog) MyDialogs.info(msg: '$e');
      log('buyProduct: $e');
    }
  }
}
