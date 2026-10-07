import 'dart:ui';

import '../model/home.dart';
import '../model/language.dart';

class Strings {
  static const String selectLanguage = 'selectLanguage';
  static const String effortlessCommunication = 'effortlessCommunication';
  static const String advanceVocabulary = 'advanceVocabulary';
  static const String funWordPlay = 'funWordPlay';

  static const String onboard1Desc = 'onboard1Desc';
  static const String onboard2Desc = 'onboard2Desc';
  static const String onboard3Desc = 'onboard3Desc';

  static const String next = 'next';
  static const String letsGetStarted = 'letsGetStarted';
  static const String translate = 'translate';
  static const String voice = 'voice';
  static const String pdf = 'pdf';
  static const String dictionary = 'dictionary';
  static const String pronouncer = 'pronouncer';

  static const String okay = 'okay';
  static const String start = 'start';
  static const String rateUs = 'rate_us';
  static const String exitNote = 'exitNote';
  static const String goBack = 'goBack';
  static const String exit = 'exit';

  static const String checkOutAmazingApp = 'checkOutAmazingApp';
  static const String yes = 'yes';
  static const String no = 'no';
  static const String deleteNote = 'deleteNote';
  static const String share = 'share';
  static const String play = 'play';
  static const String pause = 'pause';

  static const String startTypingText = 'startTypingText';
  static const String howToTranslate = 'howToTranslate';
  static const String from = 'from';
  static const String to = 'to';
  static const String fromLanguage = 'fromLanguage';
  static const String toLanguage = 'toLanguage';
  static const String searchLanguage = 'searchLanguage';
  static const String somethingWentWrong = 'somethingWentWrong';
  static const String pleaseSelectLanguage = 'pleaseSelectLanguage';
  static const String searchWord = 'searchWord';
  static const String typeSearchWord = 'typeSearchWord';
  static const String useDictionary = 'useDictionary';
  static const String wordPronHint = 'wordPronHint';
  static const String tapOnMic = 'tapOnMic';
  static const String howToVoiceT = 'howToVoiceT';
  static const String retake = 'retake';
  static const String uploadPdf = 'uploadPdf';
  static const String howToPdf = 'howToPdf';
  static const String notAbleToReadPdf = 'notAbleToReadPdf';
  static const String topFeatures = 'topFeatures';
  static const String more = 'more';

  //pdf tools section
  static const String pdfTools = 'pdfTools';
  static const String editCompress = 'editCompress';
  static const String splitMerge = 'splitMerge';
  static const String convFromPdf = 'convFromPdf';
  static const String convToPdf = 'convToPdf';
  static const String signSecurity = 'signSecurity';
  static const String forms = 'forms';

  static const String editPdf = 'editPdf';
  static const String compressPdf = 'compressPdf';
  static const String translatePdf = 'translatePdf';
  static const String ocrPdf = 'ocrPdf';
  static const String fillPdf = 'fillPdf';
  static const String compressImages = 'compressImages';
  static const String enhanceImage = 'enhanceImage';
  static const String mergePdf = 'mergePdf';
  static const String mergeImages = 'mergeImages';
  static const String splitPdf = 'splitPdf';
  static const String pdfToWord = 'pdfToWord';
  static const String pdfToPng = 'pdfToPng';
  static const String pdfToEpub = 'pdfToEpub';
  static const String pdfToJpg = 'pdfToJpg';
  static const String pdfToPptx = 'pdfToPptx';
  static const String pdfToExcel = 'pdfToExcel';
  static const String pdfToHtml = 'pdfToHtml';
  static const String wordToPdf = 'wordToPdf';
  static const String pngToPdf = 'pngToPdf';
  static const String epubToPdf = 'epubToPdf';
  static const String jpgToPdf = 'jpgToPdf';
  static const String pptxToPdf = 'pptxToPdf';
  static const String excelToPdf = 'excelToPdf';
  static const String htmlToPdf = 'htmlToPdf';
  static const String signPdf = 'signPdf';
  static const String removeWatermark = 'removeWatermark';
  static const String unlockPdf = 'unlockPdf';
  static const String generateQr = 'generateQr';
  static const String formW9 = 'formW9';
  static const String formDs11 = 'formDs11';
  static const String form1099 = 'form1099';
  static const String form941 = 'form941';
  static const String formW2 = 'formW2';
  static const String privacyPolicy = 'privacy_policy';

  //enum
  static String textTranslator = HomeType.text_translator.name;
  static String voiceTranslator = HomeType.voice_translator.name;
  static String advanceDictionary = HomeType.advance_dictionary.name;
  static String pdfTranslator = HomeType.pdf_translator.name;
  static String wordPronouncer = HomeType.word_pronouncer.name;
  static String classicWordGame = HomeType.classic_word_game.name;
  static String termsConditions = HomeType.terms_condition.name;
  static String appLanguage = HomeType.app_language.name;
  static String pdfToolsCard = HomeType.pdf_tools.name;

  // supported language list
  static List<Language> get languageList => [
        Language(
            title: 'English', flag: 'us', locale: const Locale('en', 'US')),
        Language(
            title: 'Español', flag: 'es', locale: const Locale('sp', 'SP')),
        Language(
            title: 'Português', flag: 'pt', locale: const Locale('pt', 'PT')),
        Language(title: 'हिंदी', flag: 'in', locale: const Locale('hi', 'IN')),
        Language(
            title: 'Français', flag: 'fr', locale: const Locale('fr', 'FR')),
        Language(
            title: 'Deutsch', flag: 'de', locale: const Locale('de', 'DE')),
        Language(title: '日本', flag: 'jp', locale: const Locale('ja', 'JP')),
        Language(
            title: 'English (AU)',
            flag: 'au',
            locale: const Locale('en', 'US')),
        Language(
            title: 'Русский', flag: 'ru', locale: const Locale('ru', 'RU')),
        Language(title: 'عربي', flag: 'eg', locale: const Locale('ar', 'AR')),
        Language(
            title: 'English (CA)',
            flag: 'ca',
            locale: const Locale('en', 'US')),
        Language(title: '中国人', flag: 'cn', locale: const Locale('zh', 'CN')),
      ];
}
