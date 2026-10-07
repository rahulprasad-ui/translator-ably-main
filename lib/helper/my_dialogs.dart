import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../widget/loading/custom_loading.dart';
import 'global.dart';

class MyDialogs {
  static void error({required String msg}) {
    Get.snackbar('Error', msg,
        backgroundColor: Colors.redAccent.withOpacity(.8),
        colorText: Colors.white);
  }

  static void success({required String msg}) {
    Get.snackbar('Success', msg,
        backgroundColor: Colors.green.withOpacity(.8), colorText: Colors.white);
  }

  static void info({required String msg, bool bottom = false}) {
    Get.snackbar('Info', msg,
        backgroundColor: pColor.withOpacity(.8),
        colorText: Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        snackPosition: bottom ? SnackPosition.BOTTOM : null);
  }

  static void showProgress() {
    Get.dialog(const Center(child: CustomLoading()));
  }
}
