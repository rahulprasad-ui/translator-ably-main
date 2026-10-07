import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';
import '../controller/banner_controller.dart';
import '../../helper/global.dart';

class CustomBannerAd extends StatelessWidget {
  final BannerAdController adController;
  final bool safeArea;
  final bool border;
  final EdgeInsetsGeometry margin;

  const CustomBannerAd({
    super.key,
    required this.adController,
    this.safeArea = true,
    this.border = false,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    if (Config.hideAds) return const SizedBox.shrink();

    return Obx(() {
      final ad = adController.ad;
      if (!adController.adLoaded.value || ad == null) {
        return const SizedBox.shrink();
      }

      final w = ad.size.width.toDouble();
      final h = ad.size.height.toDouble();

      Widget adContent = Container(
        margin: margin,
        padding: border ? const EdgeInsets.symmetric(vertical: 4) : null,
        decoration: border
            ? BoxDecoration(
                border: Border.all(color: pColor.withValues(alpha: 0.3), width: 0.8),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        width: w > 0 ? w : double.infinity,
        height: h > 0 ? h : 50,
        alignment: Alignment.center,
        child: AdWidget(ad: ad),
      );

      return safeArea ? SafeArea(top: false, child: adContent) : adContent;
    });
  }
}
