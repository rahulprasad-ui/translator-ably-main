import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_helper.dart';
import '../controller/native_controller.dart';
import 'custom_native_ad.dart';

class BottomNativeAd extends StatefulWidget {
  final double height;
  final EdgeInsetsGeometry margin;
  final bool border;

  const BottomNativeAd({
    super.key,
    this.height = 100,
    this.margin = EdgeInsets.zero,
    this.border = false,
  });

  @override
  State<BottomNativeAd> createState() => _BottomNativeAdState();
}

class _BottomNativeAdState extends State<BottomNativeAd> {
  final _adController = NativeAdController();

  @override
  void initState() {
    super.initState();
    AdHelper.loadNativeAd(
      adController: _adController,
      templateType: TemplateType.small,
    );
  }

  @override
  void dispose() {
    _adController.ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomNativeAd(
      adController: _adController,
      height: widget.height,
      margin: widget.margin,
      border: widget.border,
      safeArea: true,
    );
  }
}
