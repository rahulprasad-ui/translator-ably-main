import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../controllers/pdf_controller.dart';
import '../../helper/global.dart';
import '../../model/home.dart';
import '../../utils/strings.dart';
import '../../widget/button/home_btn.dart';
import '../../widget/button/image_btn.dart';
import '../../widget/loading/custom_loading.dart';

class PdfTab extends StatefulWidget {
  const PdfTab({super.key});

  @override
  State<PdfTab> createState() => _PdfTabState();
}

class _PdfTabState extends State<PdfTab> {
  final _c = PdfController();
  final _hType = HomeType.pdf_translator;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
          // physics: const BouncingScrollPhysics(),
          // padding: EdgeInsets.only(bottom: mq.height * .1),
          children: [
            //app bar
            DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors(_hType))),
              child: AppBar(
                elevation: 0,
                centerTitle: false,
                backgroundColor: Colors.transparent,

                //home
                leading: const HomeBtn(),

                //label
                title: Text(Strings.pdfTranslator.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, letterSpacing: .25)),
              ),
            ),

            SizedBox(height: mq.height * .02),

            //btn
            ...[
              _c.status.value != Loading.loading
                  ? Align(
                      child: ImageBtn(
                      onTap: () => _c.uploadPdf(),
                      text: Strings.uploadPdf.tr,
                      color: gradientColors(_hType)[1],
                    ))
                  : const SizedBox(height: 70, child: CustomLoading()),

              //how to instruction
              Padding(
                padding: EdgeInsets.only(
                  left: mq.width * .1,
                  right: mq.width * .1,
                  top: mq.height * .03,
                ),
                child: Text(Strings.howToPdf.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: gradientColors(_hType)[1],
                        fontSize: 15,
                        letterSpacing: .5)),
              ),

              const Spacer(),

              // Padding(
              //   padding: EdgeInsets.only(
              //       left: mq.width * .03,
              //       right: mq.width * .03,
              //       bottom: mq.height * .01),
              //   child: CustomAd(
              //       adController: adController, border: true, safeArea: false),
              // ),
            ].animate().fade(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeIn)
          ]),
    );
  }
}
