import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../ads/ad_helper.dart';
import '../helper/global.dart';
import '../helper/pref.dart';
import '../widget/loading/custom_loading.dart';
import 'home_screen.dart';
import 'intro/onboarding_screen.dart';

//splash screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 1), () {
      //show app open ad
      AdHelper.showAppOpenAd(onComplete: () {
        Get.off(() =>
            Pref.skipIntro ? const HomeScreen() : const OnboardingScreen());
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    //initializing media query (for getting device screen size)
    mq = MediaQuery.sizeOf(context);

    return Scaffold(
      //body
      body: SizedBox(
        width: double.maxFinite,
        height: double.maxFinite,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            //app logo
            SizedBox(
              width: mq.width * .5,
              height: mq.width * .5,
              child: Card(
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(30))),
                  child: Padding(
                    padding: EdgeInsets.all(mq.width * .05),
                    child: Image.asset('assets/images/logo.webp'),
                  )),
            ),

            const Spacer(),

            const CustomLoading(),

            const Spacer(),
          ].animate().fadeIn(duration: const Duration(milliseconds: 300)),
        ),
      ),
    );
  }
}
