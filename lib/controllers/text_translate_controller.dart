import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:translator_plus/translator_plus.dart';

import '../helper/global.dart';
import '../model/language.dart';
import '../utils/strings.dart';

class TextTranslateController extends GetxController {
  final _translator = GoogleTranslator();

  Rx<TLanguage> from = TLanguage(code: 'auto', name: 'Automatic').obs,
      to = TLanguage(code: 'en', name: 'English').obs;

  final textC = TextEditingController(), resultC = TextEditingController();
  final enable = true.obs;
  final status = Loading.pending.obs;

  Future<void> translate() async {
    try {
      status.value = Loading.loading;

      //
      final temp = await _translator.translate(textC.text,
          from: from.value.code, to: to.value.code);

      from.value = TLanguage(
          code: temp.sourceLanguage.code, name: temp.sourceLanguage.name);
      status.value = Loading.done;
      resultC.text = '${temp.text}\n\n';

      log('result: ${temp.text}\nFrom: ${temp.sourceLanguage} - To: ${temp.targetLanguage}');
    } catch (e) {
      status.value = Loading.done;
      resultC.text = Strings.somethingWentWrong.tr;
    }
  }
}
