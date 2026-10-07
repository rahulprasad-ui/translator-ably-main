import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BackBtn extends StatelessWidget {
  const BackBtn({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
        padding: const EdgeInsets.only(left: 8),
        onPressed: Get.back,
        icon: const Icon(CupertinoIcons.chevron_left_circle_fill, size: 30));
  }
}
