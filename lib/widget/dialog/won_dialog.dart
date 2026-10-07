import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../../controllers/game_controller.dart';
import '../../helper/global.dart';
import '../../model/home.dart';
import '../button/square_btn.dart';

class WonDialog extends StatelessWidget {
  final GameController controller;

  const WonDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          //content
          Align(
            child: Container(
              width: mq.width * .75,
              margin: EdgeInsets.only(top: mq.height * .05),
              padding:
                  EdgeInsets.only(top: mq.height * .1, bottom: mq.height * .05),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.9),
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                  border: Border.all(color: Colors.green, width: 3)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                //
                Container(
                  width: double.maxFinite,
                  margin: EdgeInsets.only(
                      bottom: mq.height * .02,
                      left: mq.width * .04,
                      right: mq.width * .04),
                  padding: EdgeInsets.symmetric(vertical: mq.height * .025),
                  decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius:
                          const BorderRadius.all(Radius.circular(10))),
                  child: Column(
                    children: [
                      //label
                      const Text('LEVEL\nCOMPLETE!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .5,
                              color: Colors.blue)),

                      SizedBox(height: mq.height * .04),

                      //level
                      Text(
                          'Level ${controller.level.value.toString().padLeft(2, '0')}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: .5)),
                    ],
                  ),
                ),

                //
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  //close
                  SquareBtn(
                    onTap: Get.back,
                    color: gradientColors(HomeType.pdf_translator)[1],
                    icon: const Icon(CupertinoIcons.clear, color: Colors.white),
                  ),

                  //restart
                  SquareBtn(
                    onTap: () {
                      controller.initGame();
                      Get.back();
                    },
                    icon:
                        const Icon(CupertinoIcons.refresh, color: Colors.white),
                  ),

                  //next
                  SquareBtn(
                    onTap: () {
                      controller.nextLevel();
                      Get.back();
                    },
                    color: gradientColors(HomeType.classic_word_game)[1],
                    icon: const Icon(Icons.fast_forward_rounded,
                        size: 30, color: Colors.white),
                  ),
                ]),
              ]),
            ),
          ),

          //smile
          Align(
              child: Padding(
            padding: EdgeInsets.only(bottom: mq.height * .425),
            child:
                Lottie.asset('assets/lottie/star.json', width: mq.width * .75),
          )),
        ],
      ),
    );
  }
}
