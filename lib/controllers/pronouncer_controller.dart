import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';

import '../helper/global.dart';

class PronouncerController extends GetxController {
  final FlutterTts _flutterTts = FlutterTts();

  final textC = TextEditingController();
  final enable = true.obs;
  final status = Loading.pending.obs;

  Future<void> initFlutterTts() async {
    _flutterTts.setSpeechRate(0.4);
    await _flutterTts.speak('');
  }

  Future<void> wordPronounce() async {
    try {
      if (status.value == Loading.loading) return;

      status.value = Loading.loading;

      await _flutterTts.speak(textC.text);

      _flutterTts.setCompletionHandler(() {
        status.value = Loading.done;
      });

    } catch (e) {
      status.value = Loading.error;
      log('DictionaryE: $e');
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
