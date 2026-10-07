import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../helper/global.dart';

class ImageBtn extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final double? width, height, fontSize;
  final bool greyBtn, showArrow;
  final Color? color;

  const ImageBtn(
      {super.key,
      this.height,
      this.width,
      this.fontSize = 17,
      required this.onTap,
      required this.text,
      this.showArrow = false,
      this.greyBtn = false,
      this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? mq.width * .5,
      height: height ?? 70,
      child: Semantics(
        button: true,
        child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            splashColor: Colors.white,
            child: Stack(
              children: [
                //bg
                Align(
                    alignment: Alignment.center,
                    child: Image.asset('assets/images/btn_bg.webp',
                        color: greyBtn ? Colors.grey : color)),

                //text
                Align(
                    alignment: Alignment.center,
                    child: Text(
                      text,
                      style: TextStyle(
                          fontSize: fontSize,
                          color: Colors.white,
                          letterSpacing: .5),
                    )),

                if (showArrow)
                  Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                          padding: EdgeInsets.only(
                              right: (width ?? mq.width * .5) * .1),
                          child: Lottie.asset('assets/lottie/arrow.json',
                              width: 40))),
              ],
            )),
      ),
    );
  }
}
