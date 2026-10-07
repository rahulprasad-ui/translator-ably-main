import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../../helper/global.dart';
import '../../model/onboard.dart';
import '../../utils/strings.dart';
import '../../widget/button/image_btn.dart';
import '../home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    final c = PageController();

    final List<Onboard> list = [
      Onboard(
        title: Strings.effortlessCommunication.tr,
        img: 'onboard_1',
        subtitle: Strings.onboard1Desc.tr,
      ),
      Onboard(
          title: Strings.advanceVocabulary.tr,
          img: 'onboard_2',
          subtitle: Strings.onboard2Desc.tr),
      Onboard(
          title: Strings.funWordPlay.tr,
          img: 'onboard_3',
          subtitle: Strings.onboard3Desc.tr)
    ];

    return PageView.builder(
      controller: c,
      itemCount: list.length,
      // physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (BuildContext ctx, int i) {
        return Scaffold(
          //body
          body: Column(
            children: [
              const Spacer(flex: 2),

              //lottie
              Lottie.asset('assets/lottie/${list[i].img}.json',
                  width: i == 2 ? mq.width * .7 : null, height: mq.height * .5),

              //title text
              Text(list[i].title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18,
                      letterSpacing: .5,
                      fontWeight: FontWeight.w900)),

              //title text
              Padding(
                padding: EdgeInsets.only(
                    left: mq.width * .125,
                    right: mq.width * .125,
                    bottom: mq.height * .05,
                    top: mq.height * .015),
                child: Text(list[i].subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13.5,
                        letterSpacing: .5,
                        color: Colors.black54)),
              ),

              //loading
              Image.asset('assets/images/onboard_load_${i + 1}.webp',
                  width: mq.width * .3),

              //for adding some space
              SizedBox(height: mq.height * .03),

              ImageBtn(
                  onTap: () {
                    list.length - 1 == i
                        ? Get.to(() => const HomeScreen())
                        : c.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeIn);
                  },
                  text: i == list.length - 1
                      ? Strings.letsGetStarted.tr
                      : Strings.next.tr),

              //for adding some space
              const Spacer(flex: 2)
            ],
          ).animate().fade(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeIn),
        );
      },
    );
  }
}
