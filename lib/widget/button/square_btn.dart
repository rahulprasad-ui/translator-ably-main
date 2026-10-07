import 'package:flutter/material.dart';

import '../../helper/global.dart';

class SquareBtn extends StatelessWidget {
  final Color color;
  final Widget icon;
  final VoidCallback? onTap;
  final double? size;

  const SquareBtn(
      {super.key,
      this.color = pColor,
      required this.icon,
      this.onTap,
      this.size});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          onTap: onTap,
          child: SizedBox(
            width: size ?? 70,
            height: size ?? 70,
            child: Stack(
              children: [
                Image.asset('assets/images/square_bg.webp', color: color),

                //icon
                Align(child: icon)
              ],
            ),
          )),
    );
  }
}
