import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../../ads/ad_helper.dart';
import '../../controllers/game_controller.dart';
import '../../helper/global.dart';
import '../../helper/iap.dart';
import '../../model/home.dart';
import '../button/image_btn.dart';

class HintDialog extends StatelessWidget {
  final GameController controller;

  const HintDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        contentPadding:
            const EdgeInsets.only(top: 20, left: 24, right: 24, bottom: 24),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20))),
        actionsAlignment: MainAxisAlignment.center,
        backgroundColor: Colors.white.withOpacity(.95),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Word Hint'),

            //
            GestureDetector(
                onTap: Get.back, child: const Icon(Icons.clear_rounded))
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              //image
              Lottie.asset('assets/lottie/hint.json', height: mq.height * .15),

              const Text('Feeling stuck!\nWould you like a hint?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87)),

              //
              SizedBox(height: mq.height * .02)
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.only(bottom: 20),

        // button
        actions: <Widget>[
          ImageBtn(
              height: 50,
              onTap: () {
                Get.back();
                if (IAP.isPurchased.isTrue) {
                  controller.showHint.value = true;
                  return;
                }
                AdHelper.showRewardedAd(onComplete: () {
                  controller.showHint.value = true;
                });
              },
              text: IAP.isPurchased.value ? 'Get Hint' : 'Watch Ad',
              color: gradientColors(HomeType.classic_word_game)[1])
        ]);
  }
}
