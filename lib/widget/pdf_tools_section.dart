import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../helper/global.dart';
import '../model/pdf_tool.dart';
import '../helper/my_dialogs.dart';
import '../screen/pdf_editor_screen.dart';
import '../screen/pdf_compress_screen.dart';
import '../screen/pdf_merge_screen.dart';
import '../screen/pdf_split_screen.dart';
import '../screen/merge_images_screen.dart';
import '../screen/pdf_to_word_screen.dart';
import '../screen/pdf_ocr_screen.dart';
import '../screen/pdf_fill_screen.dart';
import '../screen/pdf_sign_screen.dart';
import '../screen/pdf_remove_watermark_screen.dart';
import '../screen/pdf_unlock_screen.dart';
import '../screen/compress_image_screen.dart';
import '../screen/enhance_image_screen.dart';
import '../screen/pdf_to_png_screen.dart';
import '../screen/pdf_to_jpg_screen.dart';
import '../screen/pdf_to_epub_screen.dart';
import '../screen/pdf_to_pptx_screen.dart';
import '../screen/pdf_to_excel_screen.dart';
import '../screen/pdf_to_html_screen.dart';
import '../screen/qr_generator_screen.dart';
import '../screen/word_to_pdf_screen.dart';
import '../screen/png_to_pdf_screen.dart';
import '../screen/epub_to_pdf_screen.dart';
import '../screen/jpg_to_pdf_screen.dart';
import '../screen/pptx_to_pdf_screen.dart';
import '../screen/excel_to_pdf_screen.dart';
import '../screen/html_to_pdf_screen.dart';
import '../utils/strings.dart';

//color tints for icon tiles (like ilovepdf style pastel chips)
const _tileColors = [
  Color(0xFFFFE3E3), // pink tint
  Color(0xFFFFF3D6), // orange tint
  Color(0xFFE7F9E9), // green tint
  Color(0xFFE3F2FF), // blue tint
  Color(0xFFF3E8FF), // purple tint
  Color(0xFFE0FBFB), // cyan tint
];

class PdfToolsSection extends StatelessWidget {
  const PdfToolsSection({super.key});

  @override
  Widget build(BuildContext context) {
    //2 columns layout: categories are paired like screenshot
    final categories = _categories;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: mq.width * .03),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10, top: 6),
            child: Text(Strings.pdfTools.tr,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
          ),

          //rows of two categories (staggered like screenshot)
          for (var i = 0; i < categories.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: _CategoryColumn(category: categories[i])),
                  const SizedBox(width: 12),
                  Expanded(
                    child: i + 1 < categories.length
                        ? _CategoryColumn(category: categories[i + 1])
                        : const SizedBox(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<PdfToolCategory> get _categories => [
        //Edit & Compress
        PdfToolCategory(title: Strings.editCompress.tr, tools: [
          _tool(Strings.editPdf, _tileColors[0]),
          _tool(Strings.compressPdf, _tileColors[1]),
          _tool(Strings.ocrPdf, _tileColors[1]),
          _tool(Strings.fillPdf, _tileColors[0]),
          _tool(Strings.compressImages, _tileColors[1]),
          _tool(Strings.enhanceImage, _tileColors[0]),
        ]),

        //Split & Merge
        PdfToolCategory(title: Strings.splitMerge.tr, tools: [
          _tool(Strings.mergePdf, _tileColors[0]),
          _tool(Strings.mergeImages, _tileColors[1]),
          _tool(Strings.splitPdf, _tileColors[0]),
        ]),

        //Conversion from PDF
        PdfToolCategory(title: Strings.convFromPdf.tr, tools: [
          _tool(Strings.pdfToWord, _tileColors[3]),
          _tool(Strings.pdfToPng, _tileColors[1]),
          _tool(Strings.pdfToEpub, _tileColors[2]),
          _tool(Strings.pdfToJpg, _tileColors[0]),
          _tool(Strings.pdfToPptx, _tileColors[1]),
          _tool(Strings.pdfToExcel, _tileColors[2]),
          _tool(Strings.pdfToHtml, _tileColors[3]),
        ]),

        //Conversion to PDF
        PdfToolCategory(title: Strings.convToPdf.tr, tools: [
          _tool(Strings.wordToPdf, _tileColors[3]),
          _tool(Strings.pngToPdf, _tileColors[1]),
          _tool(Strings.epubToPdf, _tileColors[2]),
          _tool(Strings.jpgToPdf, _tileColors[0]),
          _tool(Strings.pptxToPdf, _tileColors[1]),
          _tool(Strings.excelToPdf, _tileColors[2]),
          _tool(Strings.htmlToPdf, _tileColors[3]),
        ]),

        //Sign & Security
        PdfToolCategory(title: Strings.signSecurity.tr, tools: [
          _tool(Strings.signPdf, _tileColors[5]),
          _tool(Strings.removeWatermark, _tileColors[5]),
          _tool(Strings.unlockPdf, _tileColors[5]),
          _tool(Strings.generateQr, _tileColors[5]),
        ]),

        //Forms
        PdfToolCategory(title: Strings.forms.tr, tools: [
          _tool(Strings.formW9, _tileColors[3]),
          _tool(Strings.formDs11, _tileColors[3]),
          _tool(Strings.form1099, _tileColors[3]),
          _tool(Strings.form941, _tileColors[3]),
          _tool(Strings.formW2, _tileColors[3]),
        ]),
      ];

  //tool tile builder (icon chip + label)
  PdfTool _tool(String name, Color color) => PdfTool(
        name: name,
        icon: 'assets/icons/ic_tool_placeholder.webp',
        color: color,
        onTap: () {
          if (name == Strings.editPdf) {
            Get.to(
              () => const PdfEditorScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.compressPdf || name == Strings.compressPdf.tr) {
            Get.to(
              () => const PdfCompressScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.mergePdf) {
            Get.to(
              () => const PdfMergeScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.mergeImages) {
            Get.to(
              () => const MergeImagesScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.splitPdf) {
            Get.to(
              () => const PdfSplitScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.pdfToWord || name == Strings.pdfToWord.tr) {
            Get.to(
              () => const PdfToWordScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.ocrPdf || name == Strings.ocrPdf.tr) {
            Get.to(
              () => const PdfOcrScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.signPdf || name == Strings.signPdf.tr) {
            Get.to(
              () => const PdfSignScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.removeWatermark ||
              name == Strings.removeWatermark.tr) {
            Get.to(
              () => const PdfRemoveWatermarkScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.unlockPdf ||
              name == Strings.unlockPdf.tr) {
            Get.to(
              () => const PdfUnlockScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.fillPdf ||
              name == Strings.fillPdf.tr ||
              name == Strings.formW9 ||
              name == Strings.formDs11 ||
              name == Strings.form1099 ||
              name == Strings.form941 ||
              name == Strings.formW2) {
            Get.to(
              () => const PdfFillScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.compressImages ||
              name == Strings.compressImages.tr) {
            Get.to(
              () => const CompressImageScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.enhanceImage ||
              name == Strings.enhanceImage.tr) {
            Get.to(
              () => const EnhanceImageScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.pdfToPng ||
              name == Strings.pdfToPng.tr) {
            Get.to(
              () => const PdfToPngScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.pdfToJpg ||
              name == Strings.pdfToJpg.tr) {
            Get.to(
              () => const PdfToJpgScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.pdfToEpub ||
              name == Strings.pdfToEpub.tr) {
            Get.to(
              () => const PdfToEpubScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.pdfToPptx ||
              name == Strings.pdfToPptx.tr) {
            Get.to(
              () => const PdfToPptxScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.pdfToExcel ||
              name == Strings.pdfToExcel.tr) {
            Get.to(
              () => const PdfToExcelScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.pdfToHtml ||
              name == Strings.pdfToHtml.tr) {
            Get.to(
              () => const PdfToHtmlScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.generateQr ||
              name == Strings.generateQr.tr) {
            Get.to(
              () => const QrGeneratorScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.wordToPdf ||
              name == Strings.wordToPdf.tr ||
              name.trim().toLowerCase() == 'word to pdf' ||
              name.toLowerCase().contains('word to pdf') ||
              name.toLowerCase().contains('word')) {
            Get.to(
              () => const WordToPdfScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.pngToPdf ||
              name == Strings.pngToPdf.tr ||
              name.trim().toLowerCase() == 'png to pdf' ||
              name.toLowerCase().contains('png to pdf')) {
            Get.to(
              () => const PngToPdfScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.epubToPdf ||
              name == Strings.epubToPdf.tr ||
              name.trim().toLowerCase() == 'epub to pdf' ||
              name.toLowerCase().contains('epub to pdf') ||
              (name.toLowerCase().contains('epub') && name.toLowerCase().contains('pdf'))) {
            Get.to(
              () => const EpubToPdfScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.jpgToPdf ||
              name == Strings.jpgToPdf.tr ||
              name.trim().toLowerCase() == 'jpg to pdf' ||
              name.toLowerCase().contains('jpg to pdf') ||
              (name.toLowerCase().contains('jpg') && name.toLowerCase().contains('pdf')) ||
              (name.toLowerCase().contains('jpeg') && name.toLowerCase().contains('pdf'))) {
            Get.to(
              () => const JpgToPdfScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.pptxToPdf ||
              name == Strings.pptxToPdf.tr ||
              name.trim().toLowerCase() == 'pptx to pdf' ||
              name.toLowerCase().contains('pptx to pdf') ||
              (name.toLowerCase().contains('pptx') && name.toLowerCase().contains('pdf')) ||
              (name.toLowerCase().contains('ppt') && name.toLowerCase().contains('pdf'))) {
            Get.to(
              () => const PptxToPdfScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.excelToPdf ||
              name == Strings.excelToPdf.tr ||
              name.trim().toLowerCase() == 'excel to pdf' ||
              name.toLowerCase().contains('excel to pdf') ||
              (name.toLowerCase().contains('excel') && name.toLowerCase().contains('pdf')) ||
              (name.toLowerCase().contains('xlsx') && name.toLowerCase().contains('pdf')) ||
              (name.toLowerCase().contains('xls') && name.toLowerCase().contains('pdf'))) {
            Get.to(
              () => const ExcelToPdfScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else if (name == Strings.htmlToPdf ||
              name == Strings.htmlToPdf.tr ||
              name.trim().toLowerCase() == 'html to pdf' ||
              name.toLowerCase().contains('html to pdf') ||
              (name.toLowerCase().contains('html') && name.toLowerCase().contains('pdf')) ||
              (name.toLowerCase().contains('htm') && name.toLowerCase().contains('pdf'))) {
            Get.to(
              () => const HtmlToPdfScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 280),
            );
          } else {
            MyDialogs.info(msg: todo);
          }
        },
      );
}

//single category column: bold title + vertical list of tool tiles
class _CategoryColumn extends StatelessWidget {
  final PdfToolCategory category;

  const _CategoryColumn({required this.category});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(category.title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
        ),
        ...category.tools.map((t) => _ToolTile(tool: t)),
      ],
    );
  }
}

//single tool tile
class _ToolTile extends StatelessWidget {
  final PdfTool tool;

  const _ToolTile({required this.tool});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        onTap: tool.onTap,
        child: Row(
          children: [
            //icon chip
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: tool.color,
                  borderRadius: const BorderRadius.all(Radius.circular(9))),
              child: const Icon(Icons.picture_as_pdf_rounded,
                  size: 18, color: Colors.black54),
            ),

            const SizedBox(width: 10),

            //label
            Expanded(
              child: Text(tool.name,
                  style: const TextStyle(
                      fontSize: 14,
                      letterSpacing: .25,
                      color: Colors.black87)),
            ),
          ],
        ),
      ),
    );
  }
}
