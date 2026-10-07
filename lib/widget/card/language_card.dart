import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../helper/global.dart';
import '../../helper/pref.dart';
import '../../model/language.dart';
import '../../screen/intro/onboarding_screen.dart';

class LanguageCard extends StatelessWidget {
  final Language language;

  const LanguageCard({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.symmetric(
          vertical: mq.height * .01, horizontal: mq.width * .04),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(15))),
      child: InkWell(
        onTap: () {
          Pref.langFlag = language.flag;
          Get.updateLocale(language.locale);
          Get.to(() => const OnboardingScreen());
        },
        borderRadius: const BorderRadius.all(Radius.circular(15)),
        child: ListTile(
          contentPadding:
              EdgeInsets.symmetric(horizontal: mq.width * .05, vertical: 5),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(15))),

          //flag
          leading: Container(
            padding: const EdgeInsets.all(0.5),
            decoration: const BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.all(Radius.circular(5))),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(5)),
              child: Image.asset('assets/flags/${language.flag}.webp',
                  height: 30, width: 43, fit: BoxFit.cover),
            ),
          ),

          title: Text(language.title, textAlign: TextAlign.center),

          //arrow
          trailing: const Icon(CupertinoIcons.right_chevron),
        ),
      ),
    );
  }
}
