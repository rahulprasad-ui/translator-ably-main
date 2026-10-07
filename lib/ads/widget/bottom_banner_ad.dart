import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_helper.dart';
import '../controller/banner_controller.dart';
import 'custom_banner_ad.dart';

class BottomBannerAd extends StatefulWidget {
  final AdSize adSize;
  final EdgeInsetsGeometry margin;
  final bool border;
  final bool safeArea;

  const BottomBannerAd({
    super.key,
    this.adSize = AdSize.banner,
    this.margin = EdgeInsets.zero,
    this.border = false,
    this.safeArea = true,
  });

  @override
  State<BottomBannerAd> createState() => _BottomBannerAdState();
}

class _BottomBannerAdState extends State<BottomBannerAd> {
  final _adController = BannerAdController();

  @override
  void initState() {
    super.initState();
    AdHelper.loadBannerAd(
      adController: _adController,
      adSize: widget.adSize,
    );
  }

  @override
  void dispose() {
    _adController.ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomBannerAd(
      adController: _adController,
      margin: widget.margin,
      border: widget.border,
      safeArea: widget.safeArea,
    );
  }
}
