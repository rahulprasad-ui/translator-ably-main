import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../helper/global.dart';
import '../../../utils/strings.dart';
import '../../ads/widget/bottom_native_ad.dart';
import '../../widget/card/language_card.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        bottomNavigationBar: const BottomNativeAd(),
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.white,

          automaticallyImplyLeading: false,

          //label
          title: Text(Strings.selectLanguage.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18, letterSpacing: .25, color: Colors.black87)),
        ),

        //body
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
              left: mq.width * .04,
              right: mq.width * .04,
              bottom: mq.height * .1),
          //language list
          children: Strings.languageList
              .map((e) => LanguageCard(language: e))
              .toList()
              .animate()
              .fade(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeIn),
        ));
  }
}
