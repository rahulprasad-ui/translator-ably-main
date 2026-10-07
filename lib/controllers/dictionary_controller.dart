import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart';

import '../helper/global.dart';
import '../model/dictionary.dart';

class DictionaryController extends GetxController {
  final textC = TextEditingController();
  final status = Loading.pending.obs;
  Rx<Dictionary> dictionary = Dictionary.fromJson({}).obs;

  Future<void> findMeaning() async {
    try {
      status.value = Loading.loading;

      //
      final res = await get(Uri.parse(
          'https://api.dictionaryapi.dev/api/v2/entries/en/${textC.text}'));

      log('Dictionary: ${res.body}');

      dictionary.value = Dictionary.fromJson(jsonDecode(res.body)[0]);
      status.value = Loading.done;
    } catch (e) {
      status.value = Loading.error;
      log('DictionaryE: $e');
      // resultC.text = Strings.somethingWentWrong.tr;
    }
  }
}
