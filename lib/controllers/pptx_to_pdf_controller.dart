// lib/controllers/pptx_to_pdf_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../ads/ad_helper.dart';
import '../helper/my_dialogs.dart';

// ── Models & Enums ──────────────────────────────────────────────────────────

enum PptxPdfPageFormat {
  widescreen16x9(
    'Widescreen (16:9)',
    'Modern slide presentation proportion (Standard for TV, monitor, laptop)',
    842.0,
    474.0,
  ),
  standardA4Landscape(
    'A4 Landscape',
    'Standard printable international landscape (297 × 210 mm)',
    841.89,
    595.28,
  ),
  standard4x3(
    'Standard (4:3)',
    'Classic projector & iPad presentation proportion',
    792.0,
    594.0,
  );

  final String title;
  final String subtitle;
  final double width;
  final double height;
  const PptxPdfPageFormat(this.title, this.subtitle, this.width, this.height);
}

enum PptxSlidesPerPage {
  one('1 Slide per Page', 'Full size presentation slides'),
  two('2 Slides per Page (Handout)', 'Two slides per page with separator'),
  threeWithNotes('3 Slides with Notes', 'Slides on left, blank note lines on right');

  final String title;
  final String subtitle;
  const PptxSlidesPerPage(this.title, this.subtitle);
}

enum PptxSlideTheme {
  cleanWhite('Clean Minimalist', 'White slide canvas with high-contrast text', 0xFFFFFFFF, 0xFF0F172A),
  corporateDark('Modern Slate Dark', 'Executive dark theme with light typography', 0xFF0F172A, 0xFFF8FAFC),
  warmIvory('Warm Paper / Editorial', 'Comfortable reading ivory background', 0xFFFDFBF7, 0xFF1C1917);

  final String title;
  final String subtitle;
  final int bgColor;
  final int textColor;
  const PptxSlideTheme(this.title, this.subtitle, this.bgColor, this.textColor);
}

class PptxTextRun {
  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final double? fontSize;
  final Color? color;

  PptxTextRun({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.fontSize,
    this.color,
  });
}

class PptxParagraph {
  final List<PptxTextRun> runs;
  final int level;
  final bool isBullet;
  final String alignment; // 'left', 'center', 'right', 'justify'

  PptxParagraph({
    required this.runs,
    this.level = 0,
    this.isBullet = false,
    this.alignment = 'left',
  });

  String get fullText => runs.map((r) => r.text).join();
}

class PptxSlideData {
  final int slideNumber;
  final String? title;
  final List<PptxParagraph> paragraphs;
  final List<List<String>>? tableData;

  PptxSlideData({
    required this.slideNumber,
    this.title,
    required this.paragraphs,
    this.tableData,
  });

  String get allText {
    final sb = StringBuffer();
    if (title != null && title!.isNotEmpty) sb.writeln(title);
    for (final p in paragraphs) {
      sb.writeln(p.fullText);
    }
    return sb.toString().trim();
  }
}

// ── Controller Implementation ───────────────────────────────────────────────

class PptxToPdfController extends GetxController {
  // Source presentation state
  final selectedPptxPath = RxnString();
  final selectedPptxName = RxnString();
  final fileSizeInBytes = 0.obs;
  final isPptxFormat = true.obs;

  // Extracted presentation data
  final presentationTitle = ''.obs;
  final slides = <PptxSlideData>[].obs;
  final totalWords = 0.obs;
  final extractedSampleText = RxnString();

  // Settings
  final selectedFormat = PptxPdfPageFormat.widescreen16x9.obs;
  final selectedSlidesPerPage = PptxSlidesPerPage.one.obs;
  final selectedTheme = PptxSlideTheme.cleanWhite.obs;
  final includeSlideNumbers = true.obs;
  final includePresentationTitle = true.obs;
  final accentColorValue = 0xFFD24726.obs; // Microsoft PowerPoint Orange/Red

  // UI state
  final isPicking = false.obs;
  final isParsing = false.obs;
  final isConverting = false.obs;
  final conversionProgress = 0.0.obs;
  final statusMessage = 'Ready'.obs;

  // Result state
  final convertedPdfPath = RxnString();
  final convertedPdfSize = 0.obs;
  final convertedPageCount = 0.obs;
  final previewThumbnailBytes = Rxn<Uint8List>();

  String get formattedFileSize {
    final bytes = fileSizeInBytes.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedConvertedSize {
    final bytes = convertedPdfSize.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  // ── 1. Pick Presentation File ─────────────────────────────────────────────
  Future<void> pickPptxFile() async {
    try {
      isPicking.value = true;
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pptx', 'ppt', 'PPTX', 'PPT'],
      );

      if (result.isEmpty) return;
      final path = result.first.path;
      if (path == null) return;

      await loadPptxFile(path, fileName: result.first.name);
    } catch (e) {
      log('[PptxToPdf] pickPptxFile error: $e');
      MyDialogs.info(msg: 'Failed to pick presentation: $e');
    } finally {
      isPicking.value = false;
    }
  }

  // ── 2. Load and Parse PPTX Presentation ───────────────────────────────────
  Future<void> loadPptxFile(String path, {String? fileName}) async {
    try {
      isParsing.value = true;
      statusMessage.value = 'Reading presentation...';
      final file = File(path);
      if (!await file.exists()) {
        MyDialogs.info(msg: 'Selected file does not exist');
        return;
      }

      selectedPptxPath.value = path;
      selectedPptxName.value =
          fileName ?? path.split(Platform.pathSeparator).last;
      fileSizeInBytes.value = await file.length();

      // Reset previous conversion
      convertedPdfPath.value = null;
      convertedPdfSize.value = 0;
      convertedPageCount.value = 0;
      previewThumbnailBytes.value = null;
      slides.clear();

      final isPptx = selectedPptxName.value!.toLowerCase().endsWith('.pptx');
      isPptxFormat.value = isPptx;

      final bytes = await file.readAsBytes();
      List<PptxSlideData> parsedSlides = [];

      if (isPptx) {
        parsedSlides = await _parsePptxBytes(bytes);
      } else {
        parsedSlides = await _parseLegacyPptBytes(bytes);
      }

      if (parsedSlides.isEmpty) {
        parsedSlides = [
          PptxSlideData(
            slideNumber: 1,
            title: selectedPptxName.value!.replaceAll(RegExp(r'\.[^.]+$'), ''),
            paragraphs: [
              PptxParagraph(runs: [PptxTextRun(text: 'Presentation Slide')])
            ],
          )
        ];
      }

      slides.value = parsedSlides;

      // Extract title and word counts
      String title = selectedPptxName.value!.replaceAll(RegExp(r'\.[^.]+$'), '');
      if (parsedSlides.isNotEmpty && parsedSlides.first.title != null) {
        title = parsedSlides.first.title!;
      }
      presentationTitle.value = title;

      int words = 0;
      final previewBuffer = StringBuffer();
      for (final s in parsedSlides) {
        final text = s.allText;
        if (text.isNotEmpty) {
          words += text.split(RegExp(r'\s+')).where((str) => str.isNotEmpty).length;
          if (previewBuffer.length < 800) {
            previewBuffer.writeln('Slide ${s.slideNumber}: ${s.title ?? "Untitled"}');
            previewBuffer.writeln(text);
            previewBuffer.writeln();
          }
        }
      }

      totalWords.value = words;
      extractedSampleText.value = previewBuffer.toString().trim();
      statusMessage.value = 'Ready to convert';
    } catch (e) {
      log('[PptxToPdf] loadPptxFile error: $e');
      MyDialogs.info(msg: 'Failed to read presentation: $e');
    } finally {
      isParsing.value = false;
    }
  }

  // ── 3. Parse .pptx OpenXML Archive ────────────────────────────────────────
  Future<List<PptxSlideData>> _parsePptxBytes(Uint8List bytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Check slide dimensions from ppt/presentation.xml if available
      final presFile = archive.findFile('ppt/presentation.xml');
      if (presFile != null) {
        final presXml = utf8.decode(presFile.content as List<int>, allowMalformed: true);
        final sldSzMatch = RegExp(r'<p:sldSz\s+[^>]*cx="(\d+)"\s+cy="(\d+)"').firstMatch(presXml);
        if (sldSzMatch != null) {
          final cx = int.tryParse(sldSzMatch.group(1)!);
          final cy = int.tryParse(sldSzMatch.group(2)!);
          if (cx != null && cy != null && cy > 0) {
            final ratio = cx / cy;
            if (ratio > 1.6) {
              selectedFormat.value = PptxPdfPageFormat.widescreen16x9;
            } else {
              selectedFormat.value = PptxPdfPageFormat.standard4x3;
            }
          }
        }
      }

      // 2. Discover slide files
      // Either through ppt/_rels/presentation.xml.rels or listing ppt/slides/slideX.xml
      final slideFiles = <ArchiveFile>[];
      for (final f in archive.files) {
        final name = f.name.toLowerCase();
        if (name.startsWith('ppt/slides/slide') && name.endsWith('.xml')) {
          slideFiles.add(f);
        }
      }

      // Sort slides by number natural order: slide1.xml, slide2.xml, slide10.xml
      slideFiles.sort((a, b) {
        final numA = _extractSlideNumber(a.name);
        final numB = _extractSlideNumber(b.name);
        return numA.compareTo(numB);
      });

      final resultSlides = <PptxSlideData>[];

      for (int i = 0; i < slideFiles.length; i++) {
        final sf = slideFiles[i];
        final xml = utf8.decode(sf.content as List<int>, allowMalformed: true);
        final slideData = _parseSlideXml(xml, i + 1);
        resultSlides.add(slideData);
      }

      return resultSlides;
    } catch (e) {
      log('[PptxToPdf] _parsePptxBytes error, falling back to legacy: $e');
      return _parseLegacyPptBytes(bytes);
    }
  }

  int _extractSlideNumber(String name) {
    final m = RegExp(r'slide(\d+)\.xml', caseSensitive: false).firstMatch(name);
    if (m != null) {
      return int.tryParse(m.group(1)!) ?? 0;
    }
    return 0;
  }

  PptxSlideData _parseSlideXml(String xml, int slideNum) {
    String? title;
    final paragraphs = <PptxParagraph>[];
    List<List<String>>? tableData;

    // Check for tables in slide
    final tblRegex = RegExp(r'<a:tbl[\s>].*?<\/a:tbl>', dotAll: true);
    final tblMatch = tblRegex.firstMatch(xml);
    if (tblMatch != null) {
      tableData = _parseSlideTable(tblMatch.group(0)!);
    }

    // Shapes containing text (<p:sp>)
    final spRegex = RegExp(r'<p:sp[\s>].*?<\/p:sp>', dotAll: true);
    final spMatches = spRegex.allMatches(xml);

    for (final spMatch in spMatches) {
      final spXml = spMatch.group(0)!;
      final isTitleShape = spXml.contains('type="title"') ||
          spXml.contains('type="ctrTitle"') ||
          spXml.contains('type="subTitle"');

      // Paragraphs within shape (<a:p>)
      final pRegex = RegExp(r'<a:p[\s>].*?<\/a:p>', dotAll: true);
      final pMatches = pRegex.allMatches(spXml);

      for (final pMatch in pMatches) {
        final pXml = pMatch.group(0)!;

        // Alignment
        String alignment = 'left';
        final algnMatch = RegExp(r'algn="([^"]+)"').firstMatch(pXml);
        if (algnMatch != null) {
          final val = algnMatch.group(1)!.toLowerCase();
          if (val == 'ctr') {
            alignment = 'center';
          } else if (val == 'r') {
            alignment = 'right';
          } else if (val == 'just') {
            alignment = 'justify';
          }
        }

        // Level / Bullet
        int level = 0;
        final lvlMatch = RegExp(r'lvl="(\d+)"').firstMatch(pXml);
        if (lvlMatch != null) {
          level = int.tryParse(lvlMatch.group(1)!) ?? 0;
        }
        final isBullet = pXml.contains('<a:buChar') || pXml.contains('<a:buAutoNum') || level > 0;

        // Runs within paragraph (<a:r>)
        final runs = <PptxTextRun>[];
        final rRegex = RegExp(r'<a:r[\s>].*?<\/a:r>', dotAll: true);
        final rMatches = rRegex.allMatches(pXml);

        for (final rMatch in rMatches) {
          final rXml = rMatch.group(0)!;
          final run = _parseRun(rXml);
          if (run != null && run.text.isNotEmpty) {
            runs.add(run);
          }
        }

        if (runs.isEmpty) continue;

        final fullText = runs.map((r) => r.text).join().trim();
        if (fullText.isEmpty) continue;

        if (isTitleShape && title == null && fullText.length < 120) {
          title = fullText;
        } else {
          paragraphs.add(
            PptxParagraph(
              runs: runs,
              level: level,
              isBullet: isBullet,
              alignment: alignment,
            ),
          );
        }
      }
    }

    return PptxSlideData(
      slideNumber: slideNum,
      title: title,
      paragraphs: paragraphs,
      tableData: tableData,
    );
  }

  PptxTextRun? _parseRun(String rXml) {
    final isBold = rXml.contains('b="1"') || rXml.contains('b="true"');
    final isItalic = rXml.contains('i="1"') || rXml.contains('i="true"');
    final isUnderline = rXml.contains('u="sng"') || rXml.contains('u="true"');

    // Font size in hundredths of a point (e.g. 2400 = 24pt)
    double? fontSize;
    final szMatch = RegExp(r'sz="(\d+)"').firstMatch(rXml);
    if (szMatch != null) {
      final hundredths = int.tryParse(szMatch.group(1)!);
      if (hundredths != null) {
        fontSize = hundredths / 100.0;
      }
    }

    // Text content (<a:t>)
    final tMatch = RegExp(r'<a:t[^>]*>(.*?)<\/a:t>', dotAll: true).firstMatch(rXml);
    if (tMatch == null) return null;

    final rawText = _xmlUnescape(tMatch.group(1)!);
    if (rawText.isEmpty) return null;

    return PptxTextRun(
      text: rawText,
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      fontSize: fontSize,
    );
  }

  List<List<String>>? _parseSlideTable(String tblXml) {
    final rows = <List<String>>[];
    final trRegex = RegExp(r'<a:tr[\s>].*?<\/a:tr>', dotAll: true);
    for (final trMatch in trRegex.allMatches(tblXml)) {
      final trXml = trMatch.group(0)!;
      final cells = <String>[];
      final tcRegex = RegExp(r'<a:tc[\s>].*?<\/a:tc>', dotAll: true);
      for (final tcMatch in tcRegex.allMatches(trXml)) {
        final tcXml = tcMatch.group(0)!;
        final cellBuffer = StringBuffer();
        final tRegex = RegExp(r'<a:t[^>]*>(.*?)<\/a:t>', dotAll: true);
        for (final tMatch in tRegex.allMatches(tcXml)) {
          cellBuffer.write(_xmlUnescape(tMatch.group(1)!));
          cellBuffer.write(' ');
        }
        cells.add(cellBuffer.toString().trim());
      }
      if (cells.isNotEmpty && cells.any((c) => c.isNotEmpty)) {
        rows.add(cells);
      }
    }
    return rows.isNotEmpty ? rows : null;
  }

  // ── 4. Fallback Parser for Legacy .ppt Binary Presentations ────────────────
  Future<List<PptxSlideData>> _parseLegacyPptBytes(Uint8List bytes) async {
    final slidesList = <PptxSlideData>[];
    try {
      final sb = StringBuffer();
      for (int i = 0; i < bytes.length; i++) {
        final b = bytes[i];
        if ((b >= 32 && b <= 126) || b == 10 || b == 13 || b == 9) {
          sb.writeCharCode(b);
        } else if (b == 0 && sb.isNotEmpty && !sb.toString().endsWith(' ')) {
          sb.write(' ');
        }
      }

      final raw = sb.toString();
      final chunks = raw.split(RegExp(r'\r?\n\s*\r?\n'));

      final currentParas = <PptxParagraph>[];
      int slideIndex = 1;

      for (final ch in chunks) {
        final trimmed = ch.trim();
        if (trimmed.length < 3) continue;
        if (!RegExp(r'[a-zA-Z0-9]').hasMatch(trimmed)) continue;

        final isBullet = trimmed.startsWith('•') || trimmed.startsWith('-') || RegExp(r'^\d+[\.\)]\s').hasMatch(trimmed);
        currentParas.add(
          PptxParagraph(
            runs: [PptxTextRun(text: trimmed)],
            isBullet: isBullet,
          ),
        );

        if (currentParas.length >= 4) {
          slidesList.add(
            PptxSlideData(
              slideNumber: slideIndex++,
              title: currentParas.first.fullText,
              paragraphs: currentParas.sublist(1),
            ),
          );
          currentParas.clear();
        }
      }

      if (currentParas.isNotEmpty) {
        slidesList.add(
          PptxSlideData(
            slideNumber: slideIndex,
            title: currentParas.first.fullText,
            paragraphs: currentParas.sublist(1),
          ),
        );
      }
    } catch (e) {
      log('[PptxToPdf] _parseLegacyPptBytes error: $e');
    }
    return slidesList;
  }

  String _xmlUnescape(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  // ── 5. Convert PPTX to PDF Document ───────────────────────────────────────
  Future<String?> convertToPdf() async {
    if (selectedPptxPath.value == null || slides.isEmpty) {
      MyDialogs.info(msg: 'Please select a valid presentation file first');
      return null;
    }

    try {
      isConverting.value = true;
      conversionProgress.value = 0.15;
      statusMessage.value = 'Preparing PDF slide layouts...';

      final pdfDoc = pw.Document(
        title: presentationTitle.value,
        author: 'Translator Ably',
        creator: 'PPTX to PDF Converter',
      );

      final format = selectedFormat.value;
      final pdfPageFormat = pw_pdf.PdfPageFormat(format.width, format.height);
      final theme = selectedTheme.value;
      final bgPdfColor = pw_pdf.PdfColor.fromInt(theme.bgColor);
      final textPdfColor = pw_pdf.PdfColor.fromInt(theme.textColor);
      final accentPdfColor = pw_pdf.PdfColor.fromInt(accentColorValue.value);

      final bodyFont = pw.Font.helvetica();
      final boldFont = pw.Font.helveticaBold();
      final italicFont = pw.Font.helveticaOblique();

      final total = slides.length;

      // ── Mode: 1 Slide per Page ────────────────────────────────────────────
      if (selectedSlidesPerPage.value == PptxSlidesPerPage.one) {
        for (int i = 0; i < total; i++) {
          final slide = slides[i];
          final progress = 0.20 + (0.65 * ((i + 1) / total));
          conversionProgress.value = progress;
          statusMessage.value = 'Rendering slide ${i + 1} of $total...';

          pdfDoc.addPage(
            pw.Page(
              pageFormat: pdfPageFormat,
              margin: const pw.EdgeInsets.all(32),
              build: (pw.Context ctx) {
                return pw.Container(
                  color: bgPdfColor,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Header (Optional Title)
                      if (includePresentationTitle.value)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 8),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                presentationTitle.value,
                                style: pw.TextStyle(
                                  font: bodyFont,
                                  fontSize: 8,
                                  color: textPdfColor.flatten(background: bgPdfColor),
                                ),
                              ),
                              pw.Text(
                                'Slide ${slide.slideNumber} of $total',
                                style: pw.TextStyle(
                                  font: bodyFont,
                                  fontSize: 8,
                                  color: textPdfColor.flatten(background: bgPdfColor),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Slide Title Banner
                      if (slide.title != null && slide.title!.isNotEmpty)
                        pw.Container(
                          margin: const pw.EdgeInsets.only(top: 6, bottom: 14),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                slide.title!,
                                style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 20,
                                  color: textPdfColor,
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Container(
                                height: 2.5,
                                width: 50,
                                color: accentPdfColor,
                              ),
                            ],
                          ),
                        ),

                      // Slide Content Area
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            // Paragraphs & Bullets
                            for (final p in slide.paragraphs)
                              pw.Padding(
                                padding: pw.EdgeInsets.only(
                                  left: p.level * 16.0 + (p.isBullet ? 12.0 : 0.0),
                                  bottom: 8,
                                ),
                                child: pw.Row(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    if (p.isBullet)
                                      pw.Container(
                                        margin: const pw.EdgeInsets.only(top: 4, right: 8),
                                        width: 4,
                                        height: 4,
                                        decoration: pw.BoxDecoration(
                                          color: accentPdfColor,
                                          shape: pw.BoxShape.circle,
                                        ),
                                      ),
                                    pw.Expanded(
                                      child: pw.RichText(
                                        textAlign: _getPwTextAlign(p.alignment),
                                        text: pw.TextSpan(
                                          children: p.runs.map((r) {
                                            final isB = r.isBold;
                                            final isI = r.isItalic;
                                            final font = isB ? boldFont : (isI ? italicFont : bodyFont);
                                            final sz = r.fontSize != null && r.fontSize! > 9.0
                                                ? (r.fontSize! * 0.75).clamp(10.0, 18.0)
                                                : 11.5;
                                            return pw.TextSpan(
                                              text: r.text,
                                              style: pw.TextStyle(
                                                font: font,
                                                fontSize: sz,
                                                color: textPdfColor,
                                                decoration: r.isUnderline
                                                    ? pw.TextDecoration.underline
                                                    : pw.TextDecoration.none,
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Table (if any)
                            if (slide.tableData != null && slide.tableData!.isNotEmpty)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 10),
                                child: pw.TableHelper.fromTextArray(
                                  headers: slide.tableData!.first,
                                  data: slide.tableData!.length > 1
                                      ? slide.tableData!.sublist(1)
                                      : <List<String>>[],
                                  headerStyle: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 9,
                                    color: pw_pdf.PdfColors.white,
                                  ),
                                  headerDecoration: pw.BoxDecoration(color: accentPdfColor),
                                  cellStyle: pw.TextStyle(
                                    font: bodyFont,
                                    fontSize: 8.5,
                                    color: textPdfColor,
                                  ),
                                  cellPadding: const pw.EdgeInsets.all(6),
                                  rowDecoration: const pw.BoxDecoration(
                                    border: pw.Border(
                                      bottom: pw.BorderSide(color: pw_pdf.PdfColors.grey300, width: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Footer (Slide Number)
                      if (includeSlideNumbers.value)
                        pw.Container(
                          padding: const pw.EdgeInsets.only(top: 8),
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(
                            '${slide.slideNumber}',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 9,
                              color: accentPdfColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        }
      } else {
        // ── Handout Mode (2 Slides per Page) ────────────────────────────────
        for (int i = 0; i < total; i += 2) {
          final slideA = slides[i];
          final slideB = (i + 1 < total) ? slides[i + 1] : null;

          pdfDoc.addPage(
            pw.Page(
              pageFormat: pw_pdf.PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(32),
              build: (pw.Context ctx) {
                return pw.Column(
                  children: [
                    pw.Expanded(child: _buildHandoutSlideBox(slideA, bodyFont, boldFont, accentPdfColor)),
                    pw.SizedBox(height: 16),
                    pw.Container(height: 1, color: pw_pdf.PdfColors.grey300),
                    pw.SizedBox(height: 16),
                    pw.Expanded(
                      child: slideB != null
                          ? _buildHandoutSlideBox(slideB, bodyFont, boldFont, accentPdfColor)
                          : pw.SizedBox.shrink(),
                    ),
                  ],
                );
              },
            ),
          );
        }
      }

      conversionProgress.value = 0.90;
      statusMessage.value = 'Writing PDF file...';

      final outputBytes = await pdfDoc.save();
      final tempDir = await getTemporaryDirectory();
      final baseName = selectedPptxName.value!.replaceAll(RegExp(r'\.[^.]+$'), '');
      final outputPath = '${tempDir.path}/${baseName}_converted.pdf';
      final outFile = File(outputPath);
      await outFile.writeAsBytes(outputBytes, flush: true);

      convertedPdfPath.value = outputPath;
      convertedPdfSize.value = outputBytes.length;

      // Render page 1 preview thumbnail
      try {
        final pdfViewDoc = await PdfDocument.openFile(outputPath);
        convertedPageCount.value = pdfViewDoc.pagesCount;
        final pageOne = await pdfViewDoc.getPage(1);
        final pageImg = await pageOne.render(
          width: pageOne.width * 1.2,
          height: pageOne.height * 1.2,
          format: PdfPageImageFormat.png,
        );
        previewThumbnailBytes.value = pageImg?.bytes;
        await pageOne.close();
        await pdfViewDoc.close();
      } catch (e) {
        log('[PptxToPdf] thumbnail render error: $e');
        convertedPageCount.value = slides.length;
      }

      conversionProgress.value = 1.0;
      statusMessage.value = 'Conversion Complete!';
      MyDialogs.success(msg: 'Presentation converted to PDF successfully!');
      AdHelper.showInterstitialAd(onComplete: () {});
      return outputPath;
    } catch (e) {
      log('[PptxToPdf] convertToPdf error: $e');
      MyDialogs.info(msg: 'Conversion failed: $e');
      return null;
    } finally {
      isConverting.value = false;
    }
  }

  pw.Widget _buildHandoutSlideBox(
    PptxSlideData slide,
    pw.Font bodyFont,
    pw.Font boldFont,
    pw_pdf.PdfColor accentColor,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: pw_pdf.PdfColors.grey400, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  slide.title ?? 'Slide ${slide.slideNumber}',
                  style: pw.TextStyle(font: boldFont, fontSize: 13, color: pw_pdf.PdfColors.black),
                ),
              ),
              pw.Text(
                'Slide ${slide.slideNumber}',
                style: pw.TextStyle(font: boldFont, fontSize: 9, color: accentColor),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Expanded(
            child: pw.ListView.builder(
              itemCount: slide.paragraphs.length,
              itemBuilder: (ctx, idx) {
                final p = slide.paragraphs[idx];
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(
                    '${p.isBullet ? "• " : ""}${p.fullText}',
                    maxLines: 2,
                    style: pw.TextStyle(font: bodyFont, fontSize: 8.5, color: pw_pdf.PdfColors.grey800),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  pw.TextAlign _getPwTextAlign(String alignment) {
    switch (alignment) {
      case 'center':
        return pw.TextAlign.center;
      case 'right':
        return pw.TextAlign.right;
      case 'justify':
        return pw.TextAlign.justify;
      case 'left':
      default:
        return pw.TextAlign.left;
    }
  }

  // ── 6. Share and Reset ────────────────────────────────────────────────────
  Future<void> shareConvertedPdf() async {
    final path = convertedPdfPath.value;
    if (path == null) return;
    try {
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'PDF Presentation: ${presentationTitle.value}',
        text: 'Converted from PowerPoint presentation "${presentationTitle.value}"',
      );
    } catch (e) {
      log('[PptxToPdf] share error: $e');
      MyDialogs.info(msg: 'Failed to share PDF: $e');
    }
  }

  void reset() {
    selectedPptxPath.value = null;
    selectedPptxName.value = null;
    fileSizeInBytes.value = 0;
    presentationTitle.value = '';
    slides.clear();
    totalWords.value = 0;
    extractedSampleText.value = null;
    convertedPdfPath.value = null;
    convertedPdfSize.value = 0;
    convertedPageCount.value = 0;
    previewThumbnailBytes.value = null;
    conversionProgress.value = 0.0;
    statusMessage.value = 'Ready';
  }
}
