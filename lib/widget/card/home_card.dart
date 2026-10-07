import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../ads/ad_helper.dart';
import '../../helper/my_dialogs.dart';
import '../../model/home.dart';
import '../../helper/global.dart';
import '../../screen/all_pdf_reader_screen.dart';
import '../../screen/classic_word_game.dart';
import '../../screen/intro/app_language_screen.dart';
import '../../screen/tab_screen.dart';

class HomeCard extends StatelessWidget {
  final HomeType homeType;

  const HomeCard({super.key, required this.homeType});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10))),
      elevation: 0,
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        onTap: () {
          if (_getTabIndex != -1) {
            Get.to(() => TabScreen(i: _getTabIndex));
            return;
          }

          if (homeType == HomeType.pdf_tools) {
            Get.to(() => const AllPdfReaderScreen());
            return;
          }

          if (homeType == HomeType.classic_word_game) {
            AdHelper.showInterstitialAd(
                onComplete: () => Get.to(() => const ClassicWordGame()));
            return;
          }

          if (homeType == HomeType.app_language) {
            Get.to(() => const AppLanguageScreen());
            return;
          }

          if (homeType == HomeType.terms_condition) {
            MyDialogs.info(msg: todo);
          }
        },
        child: SizedBox(
          width: mq.width * .45,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                homeType == HomeType.pdf_tools
                    ? 'assets/images/h_pdf_tools.webp'
                    : 'assets/images/h_${homeType.name}.webp',
                width: mq.width * .3),

              //label
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
                child: Text(
                  homeType == HomeType.pdf_tools
                      ? 'PDF Tools'
                      : homeType.name.tr,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  int get _getTabIndex => switch (homeType) {
        HomeType.text_translator => 0,
        HomeType.voice_translator => 1,
        HomeType.pdf_translator => 2,
        HomeType.advance_dictionary => 3,
        HomeType.word_pronouncer => 4,
        HomeType.app_language ||
        HomeType.terms_condition ||
        HomeType.classic_word_game ||
        HomeType.pdf_tools =>
          -1,
      };
}
