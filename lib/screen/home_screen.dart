import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../ads/ad_helper.dart';
import '../ads/controller/native_controller.dart';
import '../ads/widget/custom_native_ad.dart';
import '../helper/my_dialogs.dart';
import '../model/home.dart';
import '../helper/global.dart';
import '../helper/pref.dart';
import '../model/nav_item.dart';
import '../utils/strings.dart';
import '../widget/card/home_card.dart';
import '../widget/dialog/exit_dialog.dart';
import 'premium/premium_screen.dart';
import 'tab_screen.dart';

final _scaffoldKey = GlobalKey<ScaffoldState>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nativeAdController = NativeAdController();

  @override
  void initState() {
    super.initState();
    AdHelper.loadNativeAd(
      adController: _nativeAdController,
      templateType: TemplateType.medium,
    );

    // Fallback: agar pehla attempt fail ho jaye to dobara try karo
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && !_nativeAdController.adLoaded.value) {
        AdHelper.loadNativeAd(
          adController: _nativeAdController,
          templateType: TemplateType.medium,
        );
      }
    });
  }

  @override
  void dispose() {
    _nativeAdController.ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    mq = MediaQuery.sizeOf(context);
    Pref.skipIntro = true;

    //exit full-screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return PopScope(
      canPop: false,
      onPopInvoked: (b) {
        if (_scaffoldKey.currentState?.isDrawerOpen == true) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }

        Get.dialog(const ExitDialog(), barrierDismissible: true);
      },
      child: Scaffold(
          key: _scaffoldKey,
          //app bar
          appBar: AppBar(
            leading: IconButton(
                icon: Image.asset('assets/icons/menu.webp', width: 26),
                onPressed: () => _scaffoldKey.currentState?.openDrawer()),

            //
            title: const Text(
              appName,
              style: TextStyle(color: Colors.black87, fontSize: 18),
            ),
            backgroundColor: Colors.white,

            actions: [
              IconButton(
                  padding: const EdgeInsets.only(right: 4),
                  icon: Lottie.asset('assets/lottie/crown.json', width: 50),
                  onPressed: () => Get.dialog(const PremiumScreen()))
            ],
          ),

          //drawer
          drawer: const _NavDrawer(),

          //body
          body: ListView(
            physics: const BouncingScrollPhysics(),
            padding:
                EdgeInsets.only(top: mq.height * .02, bottom: mq.height * .1),
            children: [
              //
              SizedBox(
                width: double.maxFinite,
                child: Column(
                  children: [
                    // PDF at the top
                    const HomeCard(homeType: HomeType.pdf_tools),

                    const SizedBox(height: 6),

                    // Native Ad
                    CustomNativeAd(
                      adController: _nativeAdController,
                      height: 320,
                      safeArea: false,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),

                    const SizedBox(height: 6),

                    // Existing options at the bottom
                    const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          HomeCard(homeType: HomeType.text_translator),
                          HomeCard(homeType: HomeType.voice_translator)
                        ]),

                    const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          HomeCard(homeType: HomeType.advance_dictionary),
                          HomeCard(homeType: HomeType.pdf_translator),
                        ]),

                    //
                    const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          HomeCard(homeType: HomeType.word_pronouncer),
                          HomeCard(homeType: HomeType.classic_word_game),
                        ]),

                    // App Language & Terms and Conditions
                    const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          HomeCard(homeType: HomeType.app_language),
                          HomeCard(homeType: HomeType.terms_condition),
                        ]),
                  ],
                ).animate().fade(
                    duration: const Duration(milliseconds: 550),
                    curve: Curves.easeIn),
              )
            ],
          )),
    );
  }
}

//custom navigation drawer
class _NavDrawer extends StatelessWidget {
  const _NavDrawer();

  @override
  Widget build(BuildContext context) {
    final List<NavItem> list = [
      //text translator
      NavItem(
          homeType: HomeType.text_translator,
          onTap: () => Get.to(() => const TabScreen(i: 0))),

      //voice translator
      NavItem(
          homeType: HomeType.voice_translator,
          onTap: () => Get.to(() => const TabScreen(i: 1))),

      //dictionary
      NavItem(
          homeType: HomeType.advance_dictionary,
          onTap: () => Get.to(() => const TabScreen(i: 2))),

      //pdf translator
      NavItem(
          homeType: HomeType.pdf_translator,
          onTap: () => Get.to(() => const TabScreen(i: 3))),

      //word pronouncer
      NavItem(
          homeType: HomeType.word_pronouncer,
          onTap: () => Get.to(() => const TabScreen(i: 4))),
    ];

    final bottomList = [
      //rate us
      BottomNavItem(
          name: Strings.rateUs,
          onTap: () {
            launchUrlString(
                'https://play.google.com/store/apps/details?id=$packageName',
                mode: LaunchMode.externalApplication);
          }),

      //terms & conditions
      BottomNavItem(
          name: Strings.termsConditions,
          onTap: () => MyDialogs.info(msg: todo)),

      //privacy policy
      BottomNavItem(
          name: Strings.privacyPolicy,
          onTap: () {
            launchUrlString(
                'https://clipcraftcreations.blogspot.com/p/privacy-policy.html',
                mode: LaunchMode.externalApplication);
          }),

      //share
      BottomNavItem(
          name: Strings.share,
          onTap: () async {
            await Share.share(
              '${Strings.checkOutAmazingApp.tr}\n$appName: https://play.google.com/store/apps/details?id=$packageName',
            );
          }),
    ];

    return Drawer(
      width: mq.width,
      elevation: 0,

      //list view
      child: SafeArea(
        child: ListView(
            padding:
                EdgeInsets.only(left: mq.width * .02, right: mq.width * .02),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: mq.width * .045, top: 8),
                  child: IconButton(
                      onPressed: () => _scaffoldKey.currentState?.closeDrawer(),
                      icon: const Icon(Icons.cancel,
                          color: Colors.black54, size: 28)),
                ),
              ),

              Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(
                        left: mq.width * .01,
                        bottom: mq.height * .01,
                        top: mq.height * .02),
                    child: Text(Strings.topFeatures.tr,
                        style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                  )),

              //
              ...list.map((e) => _navItem(navItem: e)),

              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(
                      left: mq.width * .01,
                      bottom: mq.height * .01,
                      top: mq.height * .02),
                  child: Text(Strings.more.tr,
                      style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                ),
              ),

              ...bottomList.map((e) => _bottomNavItem(navItem: e))
            ].animate(interval: 200.ms).fade(duration: 200.ms)),
      ),
    );
  }

  //single item used in navigation drawer item
  Widget _navItem({required NavItem navItem}) {
    return InkWell(
      onTap: navItem.onTap,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.width * .015),
        child: Row(
          children: [
            //icon
            Image.asset('assets/images/h_${navItem.homeType.name}.webp',
                width: 55),

            const SizedBox(width: 8),

            //title
            Expanded(
              child: Text(navItem.homeType.name.tr,
                  style: const TextStyle(
                      fontSize: 15,
                      letterSpacing: .25,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54)),
            ),
          ],
        ),
      ),
    );
  }

  //single item used in navigation drawer item
  Widget _bottomNavItem({required BottomNavItem navItem}) {
    return InkWell(
      onTap: navItem.onTap,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: Padding(
        padding: EdgeInsets.only(
            top: mq.height * .01,
            bottom: mq.width * .03,
            left: mq.width * .02,
            right: mq.width * .02),
        child: Row(
          children: [
            //icon
            Image.asset('assets/icons/ic_${navItem.name}.webp', width: 30),

            const SizedBox(width: 8),

            //title
            Expanded(
              child: Text(navItem.name.tr,
                  style: const TextStyle(
                      letterSpacing: .25, color: Colors.black54)),
            ),
          ],
        ),
      ),
    );
  }
}
