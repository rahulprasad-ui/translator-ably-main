import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../helper/global.dart';
import '../../../utils/strings.dart';
import '../../ads/widget/bottom_native_ad.dart';
import '../../model/home.dart';
import '../../widget/button/back_btn.dart';
import '../../widget/card/language_card.dart';

class AppLanguageScreen extends StatefulWidget {
  const AppLanguageScreen({super.key});

  @override
  State<AppLanguageScreen> createState() => _AppLanguageScreenState();
}

class _AppLanguageScreenState extends State<AppLanguageScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        bottomNavigationBar: const BottomNativeAd(),

        //body
        body: ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(bottom: mq.height * .1),
      //language list
      children: [
        //app bar
        DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors(HomeType.app_language))),
          child: AppBar(
            elevation: 0,
            centerTitle: true,
            backgroundColor: Colors.transparent,

            leading: const BackBtn(),

            //label
            title: Text(Strings.selectLanguage.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, letterSpacing: .25)),
          ),
        ),

        SizedBox(height: mq.height * .01),

        ...Strings.languageList
            .map((e) => LanguageCard(language: e))
            .toList()
            .animate()
            .fade(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeIn)
      ],
    ));
  }
}
