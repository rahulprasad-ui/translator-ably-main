import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../helper/global.dart';
import '../../utils/strings.dart';
import '../button/image_btn.dart';

class ExitDialog extends StatelessWidget {
  const ExitDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(15))),
      //title
      title: SizedBox(
        width: mq.width,
        height: mq.height * .09,
        child: Stack(
          children: [
            //
            Align(
              child: Padding(
                padding: EdgeInsets.only(top: mq.height * .02),
                child: Text('${Strings.rateUs.tr}!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, color: Colors.white)),
              ),
            ),

            //
            Align(
                alignment: Alignment.topRight,
                child: IconButton(
                    onPressed: Get.back,
                    icon: const CircleAvatar(
                        radius: 13,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.clear_rounded,
                            color: Colors.white, size: 20))))
          ],
        ),
      ),
      titlePadding: EdgeInsets.zero,

      backgroundColor: pColor,

      contentPadding: EdgeInsets.zero,

      //content
      content: DecoratedBox(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          //rate us
          Padding(
            padding: EdgeInsets.symmetric(vertical: mq.height * .03),
            child: Semantics(
              button: true,
              child: InkWell(
                  onTap: () {
                    launchUrl(
                        Uri.parse(
                            'https://play.google.com/store/apps/details?id=$packageName'),
                        mode: LaunchMode.externalApplication);
                  },
                  child: Image.asset('assets/images/rate_us.webp', height: 30)),
            ),
          ),

          Text(
            Strings.exitNote.tr,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),

          //exit
          Padding(
            padding:
                EdgeInsets.only(top: mq.height * .02, bottom: mq.height * .03),
            child: ImageBtn(
                height: 50, onTap: SystemNavigator.pop, text: Strings.exit.tr),
          ),
        ]),
      ),
    );
  }
}
