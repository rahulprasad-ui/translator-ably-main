import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ads/widget/bottom_native_ad.dart';
import '../controllers/main_controller.dart';
import '../helper/global.dart';
import '../model/home.dart';
import '../utils/strings.dart';

class BottomNav extends StatelessWidget {
  final MainController controller;

  const BottomNav({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BottomNativeAd(),
        Obx(
          () => SafeArea(
            top: false,
            child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: controller.index.value,
            onTap: (i) {
              controller.index.value = i;
            },

            //
            selectedItemColor: gradientColors([
              HomeType.text_translator,
              HomeType.voice_translator,
              HomeType.pdf_translator,
              HomeType.advance_dictionary,
              HomeType.word_pronouncer
            ][controller.index.value])[1],

            //
            selectedFontSize: 13,
            items: [
              Strings.translate,
              Strings.voice,
              Strings.pdf,
              Strings.dictionary,
              Strings.pronouncer
            ]
                .mapIndexed((i, e) => BottomNavigationBarItem(
                    activeIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Image.asset('assets/icons/a_$e.webp', height: 30),
                    ),
                    icon: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Image.asset('assets/icons/$e.webp', height: 25),
                    ),
                    label: e.toLowerCase().contains('pdf') ||
                            e.toLowerCase().contains('pro')
                        ? '${e.tr} '
                        : e.tr))
                .toList()),
        ),
      ),
    ],
  );
  }
}
