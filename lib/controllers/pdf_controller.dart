import 'dart:developer';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:read_pdf_text/read_pdf_text.dart';

import '../helper/global.dart';
import '../helper/pref.dart';
import '../model/home.dart';
import '../screen/tab/text_translate_tab.dart';
import '../utils/strings.dart';

class PdfController extends GetxController {
  final status = Loading.pending.obs;

  Future<void> uploadPdf() async {
    try {
      final files = await FilePicker.pickFiles(
          type: FileType.custom, allowedExtensions: ['pdf']);

      if (files.isNotEmpty && files.first.path != null) {
        status.value = Loading.loading;

        final pdfPath = files.first.path!;
        log('pdf path: $pdfPath');
        Pref.pdfText = await ReadPdfText.getPDFtext(pdfPath);

        if (Pref.pdfText.trim().isEmpty) {
          Pref.pdfText = Strings.notAbleToReadPdf.tr;
        }

        log('Pdf Text: ${Pref.pdfText}');

        status.value = Loading.done;
        Get.to(() => const TextTranslateTab(hType: HomeType.pdf_translator));
      }
    } catch (e) {
      status.value = Loading.error;
      log('pickPdf: $e');
    }
  }
}
