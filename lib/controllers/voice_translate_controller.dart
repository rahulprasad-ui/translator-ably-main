import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:translator_plus/translator_plus.dart';

import '../helper/global.dart';
import '../model/language.dart';
import '../utils/strings.dart';

class VoiceTranslateController extends GetxController {
  final _translator = GoogleTranslator();
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  final isListening = false.obs;

  Rx<TLanguage> from = TLanguage(code: 'auto', name: 'Automatic').obs,
      to = TLanguage(code: 'en', name: 'English').obs;

  final textC = TextEditingController(), resultC = TextEditingController();
  final showRecord = true.obs;
  final status = Loading.pending.obs;

  void initSpeech() async {
    await _speechToText.initialize();
    _speechToText.statusListener = (s) {
      if (s == 'done' && textC.text.isNotEmpty) {
        showRecord.value = false;
      }
      isListening.value = _speechToText.isListening;

      log('Status: $s - isListening: ${isListening.value}');
    };
    _flutterTts.setSpeechRate(0.4);
    await _flutterTts.speak('');
  }

  void startListening() async {
    String oldText = textC.text;
    await _speechToText.listen(onResult: (r) => _onSpeechResult(r, oldText));
  }

  void stopListening() async => await _speechToText.stop();

  Future<void> release() async {
    _speechToText.cancel();
    await _flutterTts.stop();
  }

  void _onSpeechResult(SpeechRecognitionResult result, String oldText) {
    textC.text = textC.text.isEmpty
        ? oldText + result.recognizedWords
        : '$oldText ${result.recognizedWords}';
  }

  Future<void> translate() async {
    try {
      status.value = Loading.loading;

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

  Future<void> audioResult() async {
    try {
      if (status.value == Loading.loading) return;

      status.value = Loading.loading;

      await _flutterTts.speak(resultC.text);

      _flutterTts.setCompletionHandler(() {
        status.value = Loading.done;
      });
    } catch (e) {
      status.value = Loading.error;
      log('DictionaryE: $e');
    }
  }
}
