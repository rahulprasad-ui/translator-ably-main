import 'package:flutter/material.dart';
import 'package:get/get.dart';


class HomeBtn extends StatelessWidget {
  const HomeBtn({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
        padding: const EdgeInsets.only(left: 8),
        onPressed: Get.back,
        icon: Image.asset('assets/icons/home.webp', width: 22));
  }
}
