import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';
import '../controller/banner_controller.dart';

class CustomBannerAd extends StatelessWidget {
  final BannerAdController adController;

  const CustomBannerAd({super.key, required this.adController});

  @override
  Widget build(BuildContext context) {
    return Config.hideAds
        ? const SizedBox()
        : Obx(() => adController.adLoaded.value && adController.ad != null

            //admob, adx
            ? SafeArea(
                child: SizedBox(
                    height: adController.ad?.size.height.toDouble(),
                    child: AdWidget(ad: adController.ad!)),
              )

            //
            : const SizedBox());
  }
}
