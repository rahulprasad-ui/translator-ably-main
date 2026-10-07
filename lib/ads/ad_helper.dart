import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'controller/banner_controller.dart';
import 'controller/native_controller.dart';
import 'config.dart';
import '../helper/my_dialogs.dart';

class AdHelper {
  static InterstitialAd? _interstitialAd;
  static bool _interstitialAdLoaded = false;


  //*****************App Open Ad******************

  static Future<void> showAppOpenAd({required VoidCallback onComplete}) async {
    log('AppOpen Ad Id: ${Config.appOpenAd}');

    if (Config.hideAds) {
      onComplete();
      return;
    }

    try {
      await AppOpenAd.load(
        adUnitId: Config.appOpenAd,
        request: const AdRequest(httpTimeoutMillis: 5000),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback =
                FullScreenContentCallback(onAdShowedFullScreenContent: (ad) {
              onComplete();
            }, onAdFailedToShowFullScreenContent: (ad, error) {
              log('$ad onAdFailedToShowFullScreenContent: $error');
              onComplete();

              ad.dispose();
            });
            //show ad
            ad.show();
          },
          onAdFailedToLoad: (error) {
            onComplete();
            log('AppOpenAd failed to load: $error');
          },
        ),
      );
    } catch (e) {
      onComplete();
      log('$e');
    }
  }

  //*****************Interstitial Ad******************

  static Timer? _periodicInterstitialTimer;
  static DateTime? _lastInterstitialShownTime;
  static bool _isLoadingInterstitial = false;

  static void _resetInterstitialAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _interstitialAdLoaded = false;
    _isLoadingInterstitial = false;
  }

  // Cooldown between full-screen interstitial ads to prevent spamming
  static const int _minCooldownSeconds = 40;

  /// Preloads an Interstitial Ad in the background so it is ready instantly
  static void preloadInterstitialAd() {
    if (Config.hideAds || _interstitialAdLoaded || _isLoadingInterstitial) return;

    _isLoadingInterstitial = true;
    log('Preloading Interstitial Ad: ${Config.interstitialAd}');

    InterstitialAd.load(
      adUnitId: Config.interstitialAd,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          log('Interstitial Ad preloaded successfully.');
          _interstitialAd = ad;
          _interstitialAdLoaded = true;
          _isLoadingInterstitial = false;
        },
        onAdFailedToLoad: (err) {
          log('Failed to preload Interstitial Ad: ${err.message}');
          _resetInterstitialAd();
        },
      ),
    );
  }

  /// Safe backward-compatible method: preloads ad instead of intrusive timer
  static void startPeriodicInterstitial() {
    _periodicInterstitialTimer?.cancel();
    preloadInterstitialAd();
  }

  /// Shows an interstitial ad with callback upon completion (with policy cooldown protection)
  static void showInterstitialAd({
    required VoidCallback onComplete,
    bool ignoreCooldown = false,
  }) {
    log('Interstitial Ad Id: ${Config.interstitialAd}');

    if (Config.hideAds) {
      onComplete();
      return;
    }

    // Cooldown protection to prevent violating AdMob Frequency / Interruption policies
    if (!ignoreCooldown && _lastInterstitialShownTime != null) {
      final elapsed = DateTime.now().difference(_lastInterstitialShownTime!).inSeconds;
      if (elapsed < _minCooldownSeconds) {
        log('Interstitial Ad skipped due to cooldown ($elapsed / $_minCooldownSeconds s)');
        onComplete();
        return;
      }
    }

    if (_interstitialAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback =
          FullScreenContentCallback(onAdDismissedFullScreenContent: (ad) {
        onComplete();
        _lastInterstitialShownTime = DateTime.now();
        _resetInterstitialAd();
        preloadInterstitialAd();
      }, onAdFailedToShowFullScreenContent: (ad, error) {
        onComplete();
        _resetInterstitialAd();
        preloadInterstitialAd();
      });

      _interstitialAd!.show();
      _lastInterstitialShownTime = DateTime.now();
      return;
    }

    MyDialogs.showProgress();

    InterstitialAd.load(
      adUnitId: Config.interstitialAd,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback =
              FullScreenContentCallback(onAdDismissedFullScreenContent: (ad) {
            onComplete();
            _lastInterstitialShownTime = DateTime.now();
            _resetInterstitialAd();
            preloadInterstitialAd();
          }, onAdFailedToShowFullScreenContent: (ad, error) {
            onComplete();
            _resetInterstitialAd();
            preloadInterstitialAd();
          });
          Get.back();
          ad.show();
          _lastInterstitialShownTime = DateTime.now();
        },
        onAdFailedToLoad: (err) {
          Get.back();
          log('Failed to load an interstitial ad: ${err.message}');
          onComplete();
          _resetInterstitialAd();
        },
      ),
    );
  }

  //*****************Native Ad******************

  static void loadNativeAd({
    required NativeAdController adController,
    TemplateType templateType = TemplateType.small,
    int retryAttempt = 0,
  }) {
    if (Config.hideAds) {
      debugPrint('[AdHelper] Native Ad skipped - hideAds is true '
          '(premium user ya remote config show_ads = false)');
      return;
    }

    debugPrint('[AdHelper] Native Ad loading (attempt ${retryAttempt + 1}): '
        '${Config.nativeAd}');

    NativeAd(
      adUnitId: Config.nativeAd,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('[AdHelper] Native Ad loaded successfully.');
          adController.adLoaded.value = true;
          adController.ad = ad as NativeAd;
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('[AdHelper] Native Ad failed to load: $error');

          // Slow network par pehla attempt fail ho sakta hai, retry karo
          if (retryAttempt < 3 && !adController.adLoaded.value) {
            Future.delayed(const Duration(seconds: 3), () {
              loadNativeAd(
                adController: adController,
                templateType: templateType,
                retryAttempt: retryAttempt + 1,
              );
            });
          }
        },
      ),
      request: const AdRequest(),
      // Styling
      nativeTemplateStyle: NativeTemplateStyle(templateType: templateType),
    ).load();
  }

  //*****************Banner Ad******************

  static void loadBannerAd({required BannerAdController adController}) {
    log('Native Ad Id: ${Config.nativeAd}');

    //
    // if (Config.hideAds) return;

    BannerAd(
      adUnitId: Config.bannerAd,
      size: AdSize.banner, // Change according to your needs
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          log('Banner Ad loaded.');
          adController.adLoaded.value = true;
          adController.ad = ad as BannerAd;
        },
        onAdFailedToLoad: (ad, error) {
          log('Banner Ad failed to load: $error');
        },
      ),
      request: const AdRequest(),
    ).load();
  }

  //*****************Rewarded Ad******************

  static void showRewardedAd({required VoidCallback onComplete}) {
    log('Rewarded Ad Id: ${Config.rewardedAd}');

    if (Config.hideAds) {
      onComplete();
      return;
    }

    MyDialogs.showProgress();

    RewardedAd.load(
      adUnitId: Config.rewardedAd,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          Get.back();

          //reward listener
          ad.show(
              onUserEarnedReward: (AdWithoutView ad, RewardItem rewardItem) {
            onComplete();
          });
        },
        onAdFailedToLoad: (err) {
          Get.back();
          log('Failed to load an interstitial ad: ${err.message}');
          // onComplete();
        },
      ),
    );
  }
}
