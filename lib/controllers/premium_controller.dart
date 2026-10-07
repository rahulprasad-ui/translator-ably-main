import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../helper/iap.dart';

class PremiumController extends GetxController {
  final Rx<ProductDetails> product = ProductDetails(
          id: '',
          title: 'One Time Pay',
          description: 'Lifetime access to all Premium Features',
          price: '... ',
          rawPrice: 0,
          currencyCode: '')
      .obs;

  Future<void> initData() async {
    // IAP.initialize(showDialogs: true);
    IAP.showDialog = true;
    final list = await IAP.getProducts();
    if (list.isNotEmpty) product.value = list.first;
  }

  Future<void> purchase() async {
    if (product.value.id.isNotEmpty) {
      IAP.buyProduct(product.value);
    }
  }
}
