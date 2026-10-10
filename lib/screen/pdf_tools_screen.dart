import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../ads/widget/bottom_native_ad.dart';
import '../helper/global.dart';
import '../helper/my_dialogs.dart';
import '../utils/strings.dart';
import 'pdf_editor_screen.dart';
import 'pdf_compress_screen.dart';
import 'pdf_merge_screen.dart';
import 'pdf_split_screen.dart';
import 'merge_images_screen.dart';
import 'pdf_to_word_screen.dart';
import 'pdf_ocr_screen.dart';
import 'pdf_fill_screen.dart';
import 'pdf_sign_screen.dart';
import 'pdf_remove_watermark_screen.dart';
import 'pdf_unlock_screen.dart';
import 'compress_image_screen.dart';
import 'enhance_image_screen.dart';
import 'pdf_to_png_screen.dart';
import 'pdf_to_jpg_screen.dart';
import 'pdf_to_epub_screen.dart';
import 'pdf_to_pptx_screen.dart';
import 'pdf_to_excel_screen.dart';
import 'pdf_to_html_screen.dart';
import 'qr_generator_screen.dart';
import 'word_to_pdf_screen.dart';
import 'png_to_pdf_screen.dart';
import 'epub_to_pdf_screen.dart';
import 'jpg_to_pdf_screen.dart';
import 'pptx_to_pdf_screen.dart';
import 'excel_to_pdf_screen.dart';
import 'html_to_pdf_screen.dart';

// ── Tool model ───────────────────────────────────────────────────────────────
class _Tool {
  final String name;
  final IconData icon;
  final Color color;
  const _Tool(this.name, this.icon, this.color);
}

// ── Category model ───────────────────────────────────────────────────────────
class _Category {
  final String title;
  final IconData tabIcon;
  final Color color;
  final List<_Tool> tools;
  const _Category(this.title, this.tabIcon, this.color, this.tools);
}

// ── Screen ───────────────────────────────────────────────────────────────────
class PdfToolsScreen extends StatefulWidget {
  const PdfToolsScreen({super.key});

  @override
  State<PdfToolsScreen> createState() => _PdfToolsScreenState();
}

class _PdfToolsScreenState extends State<PdfToolsScreen> {
  int _selectedCat = 0;

  List<_Category> get _categories => [
        _Category(Strings.editCompress.tr, Icons.edit_rounded,
            const Color(0xFFFF6B6B), [
          _Tool(Strings.editPdf.tr, Icons.edit_document, const Color(0xFFFF6B6B)),
          _Tool(Strings.compressPdf.tr, Icons.compress, const Color(0xFFFF8C42)),
          _Tool(Strings.ocrPdf.tr, Icons.document_scanner, const Color(0xFFFF8C42)),
          _Tool(Strings.fillPdf.tr, Icons.edit_note, const Color(0xFFFF6B6B)),
          _Tool(Strings.compressImages.tr, Icons.photo_size_select_small, const Color(0xFFFF8C42)),
          _Tool(Strings.enhanceImage.tr, Icons.auto_fix_high, const Color(0xFFFF6B6B)),
        ]),
        _Category(Strings.splitMerge.tr, Icons.call_split_rounded,
            const Color(0xFF5E89FC), [
          _Tool(Strings.mergePdf.tr, Icons.merge, const Color(0xFF5E89FC)),
          _Tool(Strings.mergeImages.tr, Icons.collections, const Color(0xFF245AE4)),
          _Tool(Strings.splitPdf.tr, Icons.call_split, const Color(0xFF5E89FC)),
        ]),
        _Category(Strings.convFromPdf.tr, Icons.upload_file_rounded,
            const Color(0xFFFFAB6C), [
          _Tool(Strings.pdfToWord.tr, Icons.description, const Color(0xFFFFAB6C)),
          _Tool(Strings.pdfToPng.tr, Icons.image, const Color(0xFFFD8838)),
          _Tool(Strings.pdfToEpub.tr, Icons.menu_book, const Color(0xFFFFAB6C)),
          _Tool(Strings.pdfToJpg.tr, Icons.photo, const Color(0xFFFD8838)),
          _Tool(Strings.pdfToPptx.tr, Icons.slideshow, const Color(0xFFFFAB6C)),
          _Tool(Strings.pdfToExcel.tr, Icons.table_chart, const Color(0xFFFD8838)),
          _Tool(Strings.pdfToHtml.tr, Icons.html, const Color(0xFFFFAB6C)),
        ]),
        _Category(Strings.convToPdf.tr, Icons.download_rounded,
            const Color(0xFF4FEE13), [
          _Tool(Strings.wordToPdf.tr, Icons.description, const Color(0xFF36C404)),
          _Tool(Strings.pngToPdf.tr, Icons.image, const Color(0xFF4FEE13)),
          _Tool(Strings.epubToPdf.tr, Icons.menu_book, const Color(0xFF36C404)),
          _Tool(Strings.jpgToPdf.tr, Icons.photo, const Color(0xFF4FEE13)),
          _Tool(Strings.pptxToPdf.tr, Icons.slideshow, const Color(0xFF36C404)),
          _Tool(Strings.excelToPdf.tr, Icons.table_chart, const Color(0xFF4FEE13)),
          _Tool(Strings.htmlToPdf.tr, Icons.html, const Color(0xFF36C404)),
        ]),
        _Category(Strings.signSecurity.tr, Icons.lock_rounded,
            const Color(0xFFA392FA), [
          _Tool(Strings.signPdf.tr, Icons.draw, const Color(0xFFA392FA)),
          _Tool(Strings.removeWatermark.tr, Icons.water_drop, const Color(0xFF8772FD)),
          _Tool(Strings.unlockPdf.tr, Icons.lock_open, const Color(0xFFA392FA)),
          _Tool(Strings.generateQr.tr, Icons.qr_code, const Color(0xFF8772FD)),
        ]),
        _Category(Strings.forms.tr, Icons.assignment_rounded,
            const Color(0xFF2DEBE9), [
          _Tool(Strings.formW9.tr, Icons.assignment, const Color(0xFF02D3D7)),
          _Tool(Strings.formDs11.tr, Icons.assignment, const Color(0xFF2DEBE9)),
          _Tool(Strings.form1099.tr, Icons.assignment, const Color(0xFF02D3D7)),
          _Tool(Strings.form941.tr, Icons.assignment, const Color(0xFF2DEBE9)),
          _Tool(Strings.formW2.tr, Icons.assignment, const Color(0xFF02D3D7)),
        ]),
      ];

  @override
  Widget build(BuildContext context) {
    final cats = _categories;
    final selected = cats[_selectedCat];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      bottomNavigationBar: const BottomNativeAd(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Top bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.black87, size: 20),
                    onPressed: () => Get.back(),
                  ),
                  const Text('PDF Tools',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          letterSpacing: .3)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${selected.tools.length} tools',
                      style: TextStyle(
                          color: selected.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Category tabs (horizontal scroll) ─────────────────────────
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemCount: cats.length,
                itemBuilder: (_, i) {
                  final cat = cats[i];
                  final isSelected = _selectedCat == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCat = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      width: 78,
                      decoration: BoxDecoration(
                        color: isSelected ? cat.color : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? cat.color.withValues(alpha: 0.35)
                                : Colors.black.withValues(alpha: 0.06),
                            blurRadius: isSelected ? 14 : 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(cat.tabIcon,
                              color: isSelected ? Colors.white : cat.color,
                              size: 26),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              cat.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black54,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 18),

            // ── Section label ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 4, height: 18,
                    decoration: BoxDecoration(
                      color: selected.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(selected.title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87)),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Tool grid ─────────────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.05), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: GridView.builder(
                  key: ValueKey(_selectedCat),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.7,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: selected.tools.length,
                  itemBuilder: (_, i) {
                    return _ToolCard(
                      tool: selected.tools[i],
                      index: i,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tool card ────────────────────────────────────────────────────────────────
class _ToolCard extends StatelessWidget {
  final _Tool tool;
  final int index;
  const _ToolCard({required this.tool, required this.index});

  void _onToolTap(BuildContext context, String name) {
    if (name == Strings.editPdf.tr || name == Strings.editPdf) {
      Get.to(() => const PdfEditorScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.compressPdf.tr || name == Strings.compressPdf) {
      Get.to(() => const PdfCompressScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.mergePdf.tr) {
      Get.to(() => const PdfMergeScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.mergeImages.tr || name == Strings.mergeImages) {
      Get.to(() => const MergeImagesScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.splitPdf.tr || name == Strings.splitPdf) {
      Get.to(() => const PdfSplitScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.pdfToWord.tr || name == Strings.pdfToWord) {
      Get.to(() => const PdfToWordScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.ocrPdf.tr || name == Strings.ocrPdf) {
      Get.to(() => const PdfOcrScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.signPdf.tr || name == Strings.signPdf) {
      Get.to(() => const PdfSignScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.removeWatermark.tr ||
        name == Strings.removeWatermark) {
      Get.to(() => const PdfRemoveWatermarkScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.unlockPdf.tr || name == Strings.unlockPdf) {
      Get.to(() => const PdfUnlockScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.fillPdf.tr ||
        name == Strings.fillPdf ||
        name == Strings.formW9.tr ||
        name == Strings.formDs11.tr ||
        name == Strings.form1099.tr ||
        name == Strings.form941.tr ||
        name == Strings.formW2.tr) {
      Get.to(() => const PdfFillScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.compressImages.tr ||
        name == Strings.compressImages) {
      Get.to(() => const CompressImageScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.enhanceImage.tr ||
        name == Strings.enhanceImage) {
      Get.to(() => const EnhanceImageScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.pdfToPng.tr ||
        name == Strings.pdfToPng) {
      Get.to(() => const PdfToPngScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.pdfToJpg.tr ||
        name == Strings.pdfToJpg) {
      Get.to(() => const PdfToJpgScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.pdfToEpub.tr ||
        name == Strings.pdfToEpub) {
      Get.to(() => const PdfToEpubScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.pdfToPptx.tr ||
        name == Strings.pdfToPptx) {
      Get.to(() => const PdfToPptxScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.pdfToExcel.tr ||
        name == Strings.pdfToExcel) {
      Get.to(() => const PdfToExcelScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.pdfToHtml.tr ||
        name == Strings.pdfToHtml) {
      Get.to(() => const PdfToHtmlScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.generateQr.tr ||
        name == Strings.generateQr) {
      Get.to(() => const QrGeneratorScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.wordToPdf.tr ||
        name == Strings.wordToPdf ||
        name.trim().toLowerCase() == 'word to pdf' ||
        name.toLowerCase().contains('word to pdf') ||
        name.toLowerCase().contains('word')) {
      Get.to(() => const WordToPdfScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.pngToPdf.tr ||
        name == Strings.pngToPdf ||
        name.trim().toLowerCase() == 'png to pdf' ||
        name.toLowerCase().contains('png to pdf') ||
        (name.toLowerCase().contains('png') && name.toLowerCase().contains('pdf'))) {
      Get.to(() => const PngToPdfScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.epubToPdf.tr ||
        name == Strings.epubToPdf ||
        name.trim().toLowerCase() == 'epub to pdf' ||
        name.toLowerCase().contains('epub to pdf') ||
        (name.toLowerCase().contains('epub') && name.toLowerCase().contains('pdf'))) {
      Get.to(() => const EpubToPdfScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.jpgToPdf.tr ||
        name == Strings.jpgToPdf ||
        name.trim().toLowerCase() == 'jpg to pdf' ||
        name.toLowerCase().contains('jpg to pdf') ||
        (name.toLowerCase().contains('jpg') && name.toLowerCase().contains('pdf')) ||
        (name.toLowerCase().contains('jpeg') && name.toLowerCase().contains('pdf'))) {
      Get.to(() => const JpgToPdfScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.pptxToPdf.tr ||
        name == Strings.pptxToPdf ||
        name.trim().toLowerCase() == 'pptx to pdf' ||
        name.toLowerCase().contains('pptx to pdf') ||
        (name.toLowerCase().contains('pptx') && name.toLowerCase().contains('pdf')) ||
        (name.toLowerCase().contains('ppt') && name.toLowerCase().contains('pdf'))) {
      Get.to(() => const PptxToPdfScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.excelToPdf.tr ||
        name == Strings.excelToPdf ||
        name.trim().toLowerCase() == 'excel to pdf' ||
        name.toLowerCase().contains('excel to pdf') ||
        (name.toLowerCase().contains('excel') && name.toLowerCase().contains('pdf')) ||
        (name.toLowerCase().contains('xlsx') && name.toLowerCase().contains('pdf')) ||
        (name.toLowerCase().contains('xls') && name.toLowerCase().contains('pdf'))) {
      Get.to(() => const ExcelToPdfScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else if (name == Strings.htmlToPdf.tr ||
        name == Strings.htmlToPdf ||
        name.trim().toLowerCase() == 'html to pdf' ||
        name.toLowerCase().contains('html to pdf') ||
        (name.toLowerCase().contains('html') && name.toLowerCase().contains('pdf')) ||
        (name.toLowerCase().contains('htm') && name.toLowerCase().contains('pdf'))) {
      Get.to(() => const HtmlToPdfScreen(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 280));
    } else {
      MyDialogs.info(msg: todo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: tool.color.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: () => _onToolTap(context, tool.name),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // icon pill
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          tool.color.withValues(alpha: 0.15),
                          tool.color.withValues(alpha: 0.28),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(tool.icon, color: tool.color, size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tool.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text('Tap to use',
                          style: TextStyle(
                              fontSize: 10,
                              color: tool.color,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded,
                          size: 10, color: tool.color),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 50))
        .fadeIn(duration: 280.ms, curve: Curves.easeOut)
        .scale(
            begin: const Offset(0.92, 0.92),
            end: const Offset(1, 1),
            duration: 280.ms,
            curve: Curves.easeOut);
  }
}
