import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../controller/native_controller.dart';
import '../config.dart';
import '../../helper/global.dart';

class CustomNativeAd extends StatelessWidget {
  final NativeAdController adController;
  final bool safeArea;
  final bool border;
  final EdgeInsetsGeometry margin;

  final double? height;
  final double? width;

  const CustomNativeAd(
      {super.key,
      required this.adController,
      this.safeArea = true,
      this.border = false,
      this.margin = EdgeInsets.zero,
      this.height,
      this.width});

  @override
  Widget build(BuildContext context) {
    return Config.hideAds
        ? const SizedBox()
        : Obx(() => adController.adLoaded.value && adController.ad != null

            //admob, adx
            ? safeArea
                ? SafeArea(top: false, child: _googleAd())
                : _googleAd()

            //
            : const SizedBox());
  }

  Widget _googleAd() {
    return Container(
        padding: border ? const EdgeInsets.only(top: 5, bottom: 5) : null,
        margin: margin,
        decoration: border
            ? BoxDecoration(
                border: Border.all(color: pColor, width: 0.5),
                borderRadius: const BorderRadius.all(Radius.circular(10)))
            : null,
        height: height ?? 90,
        width: width,
        child: AdWidget(ad: adController.ad!));
  }
}
