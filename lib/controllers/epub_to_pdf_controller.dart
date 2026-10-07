// lib/controllers/epub_to_pdf_controller.dart
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

enum EpubPdfPageSize {
  a4('A4 Document', 'Standard document format (210 × 297 mm)', pw_pdf.PdfPageFormat.a4),
  letter('US Letter', 'Standard US document (8.5 × 11 in)', pw_pdf.PdfPageFormat.letter),
  bookA5('Book / Digest (A5)', 'Authentic paperback novel format (148 × 210 mm)', pw_pdf.PdfPageFormat.a5);

  final String title;
  final String subtitle;
  final pw_pdf.PdfPageFormat format;
  const EpubPdfPageSize(this.title, this.subtitle, this.format);
}

enum EpubPdfMargin {
  normal('Normal', '20 mm balanced margins', 54.0),
  narrow('Narrow', '12 mm compact margins', 34.0),
  bookSpaced('Book Spaced', '28 mm editorial book margins', 72.0);

  final String title;
  final String subtitle;
  final double marginPoints;
  const EpubPdfMargin(this.title, this.subtitle, this.marginPoints);
}

enum EpubPdfFontTheme {
  classicSerif('Classic Book Serif', 'Traditional Times / Georgia literary typography'),
  cleanSans('Clean Modern Sans', 'Crisp Helvetica / Arial readable typography'),
  monospace('Typewriter Monospace', 'Courier technical font typography');

  final String title;
  final String subtitle;
  const EpubPdfFontTheme(this.title, this.subtitle);
}

enum EpubBlockType {
  chapterTitle,
  heading1,
  heading2,
  paragraph,
  bullet,
  blockquote,
}

class EpubRun {
  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;

  EpubRun({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
  });
}

class EpubBlock {
  final EpubBlockType type;
  final List<EpubRun> runs;
  final String? chapterName;

  EpubBlock({
    required this.type,
    required this.runs,
    this.chapterName,
  });

  String get fullText => runs.map((r) => r.text).join();
}

class EpubChapter {
  final String title;
  final List<EpubBlock> blocks;

  EpubChapter({
    required this.title,
    required this.blocks,
  });
}

// ── Controller Implementation ───────────────────────────────────────────────

class EpubToPdfController extends GetxController {
  // Selected EPUB file
  final selectedEpubPath = RxnString();
  final selectedEpubName = RxnString();
  final fileSizeInBytes = 0.obs;

  // Book Metadata extracted from EPUB
  final bookTitle = ''.obs;
  final bookAuthor = ''.obs;
  final bookLanguage = ''.obs;
  final coverImageBytes = Rxn<Uint8List>();
  final chapters = <EpubChapter>[].obs;
  final totalWords = 0.obs;
  final extractedSampleText = RxnString();

  // Settings
  final selectedPageSize = EpubPdfPageSize.a4.obs;
  final selectedMargin = EpubPdfMargin.normal.obs;
  final selectedFontTheme = EpubPdfFontTheme.classicSerif.obs;
  final includeCoverPage = true.obs;
  final includeHeader = true.obs;
  final includeFooter = true.obs;
  final fontSizeDelta = 0.0.obs; // 0 = default (10pt), -1.5 = compact, +2 = large print

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

  // ── 1. Pick EPUB File ─────────────────────────────────────────────────────
  Future<void> pickEpubFile() async {
    try {
      isPicking.value = true;
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub', 'EPUB'],
      );

      if (result.isEmpty) return;
      final path = result.first.path;
      if (path == null) return;

      await loadEpubFile(path, fileName: result.first.name);
    } catch (e) {
      log('[EpubToPdf] pickEpubFile error: $e');
      MyDialogs.info(msg: 'Failed to pick EPUB file: $e');
    } finally {
      isPicking.value = false;
    }
  }

  // ── 2. Load and Parse EPUB Archive ────────────────────────────────────────
  Future<void> loadEpubFile(String path, {String? fileName}) async {
    try {
      isParsing.value = true;
      statusMessage.value = 'Opening EPUB e-book...';
      final file = File(path);
      if (!await file.exists()) {
        MyDialogs.info(msg: 'Selected file does not exist');
        return;
      }

      selectedEpubPath.value = path;
      selectedEpubName.value =
          fileName ?? path.split(Platform.pathSeparator).last;
      fileSizeInBytes.value = await file.length();

      // Reset previous conversion
      convertedPdfPath.value = null;
      convertedPdfSize.value = 0;
      convertedPageCount.value = 0;
      previewThumbnailBytes.value = null;
      coverImageBytes.value = null;
      chapters.clear();

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      statusMessage.value = 'Reading e-book metadata & spine...';

      // 1. Locate OPF file path via META-INF/container.xml
      String opfPath = '';
      final containerFile = archive.findFile('META-INF/container.xml');
      if (containerFile != null) {
        final containerXml =
            utf8.decode(containerFile.content as List<int>, allowMalformed: true);
        final fullPathMatch =
            RegExp(r'full-path="([^"]+)"').firstMatch(containerXml);
        if (fullPathMatch != null) {
          opfPath = fullPathMatch.group(1)!;
        }
      }

      if (opfPath.isEmpty) {
        // Fallback: look for any .opf file in archive
        for (final f in archive.files) {
          if (f.name.toLowerCase().endsWith('.opf')) {
            opfPath = f.name;
            break;
          }
        }
      }

      String title = selectedEpubName.value!.replaceAll(RegExp(r'\.epub$', caseSensitive: false), '');
      String author = 'Unknown Author';
      String lang = 'en';
      final manifestItems = <String, String>{}; // id -> href
      final manifestTypes = <String, String>{}; // id -> media-type
      final spineItemRefs = <String>[];
      String? coverHref;

      String opfDir = '';
      if (opfPath.contains('/')) {
        opfDir = opfPath.substring(0, opfPath.lastIndexOf('/') + 1);
      }

      if (opfPath.isNotEmpty) {
        final opfFile = archive.findFile(opfPath);
        if (opfFile != null) {
          final opfXml = utf8.decode(opfFile.content as List<int>, allowMalformed: true);

          // Parse Metadata
          final titleMatch = RegExp(r'<dc:title[^>]*>(.*?)<\/dc:title>', dotAll: true).firstMatch(opfXml);
          if (titleMatch != null) {
            final t = _cleanHtml(titleMatch.group(1)!);
            if (t.isNotEmpty) title = t;
          }

          final authorMatch = RegExp(r'<dc:creator[^>]*>(.*?)<\/dc:creator>', dotAll: true).firstMatch(opfXml);
          if (authorMatch != null) {
            final a = _cleanHtml(authorMatch.group(1)!);
            if (a.isNotEmpty) author = a;
          }

          final langMatch = RegExp(r'<dc:language[^>]*>(.*?)<\/dc:language>', dotAll: true).firstMatch(opfXml);
          if (langMatch != null) {
            final l = _cleanHtml(langMatch.group(1)!);
            if (l.isNotEmpty) lang = l;
          }

          // Parse Manifest
          final itemRegex = RegExp(r'<item\s+[^>]*id="([^"]+)"[^>]*href="([^"]+)"[^>]*media-type="([^"]+)"', dotAll: true);
          for (final m in itemRegex.allMatches(opfXml)) {
            final id = m.group(1)!;
            final href = m.group(2)!;
            final mType = m.group(3)!;
            manifestItems[id] = href;
            manifestTypes[id] = mType;

            if (mType.startsWith('image/') && (id.toLowerCase().contains('cover') || href.toLowerCase().contains('cover'))) {
              coverHref = href;
            }
          }

          // Parse Spine
          final spineRegex = RegExp(r'<itemref\s+[^>]*idref="([^"]+)"', dotAll: true);
          for (final m in spineRegex.allMatches(opfXml)) {
            spineItemRefs.add(m.group(1)!);
          }
        }
      }

      bookTitle.value = title;
      bookAuthor.value = author;
      bookLanguage.value = lang;

      // Extract Cover Image if found
      if (coverHref != null) {
        final fullCoverPath = opfDir.isNotEmpty ? '$opfDir$coverHref' : coverHref;
        final cFile = archive.findFile(fullCoverPath) ?? archive.findFile(coverHref);
        if (cFile != null) {
          coverImageBytes.value = Uint8List.fromList(cFile.content as List<int>);
        }
      } else {
        // Fallback search for cover image
        for (final f in archive.files) {
          final n = f.name.toLowerCase();
          if ((n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png')) && n.contains('cover')) {
            coverImageBytes.value = Uint8List.fromList(f.content as List<int>);
            break;
          }
        }
      }

      statusMessage.value = 'Parsing chapters & paragraphs...';

      // 2. Parse Chapters according to Spine
      final parsedChapters = <EpubChapter>[];
      final chapterHrefs = <String>[];

      for (final ref in spineItemRefs) {
        final href = manifestItems[ref];
        if (href != null) chapterHrefs.add(href);
      }

      // If spine was empty, grab all html/xhtml files
      if (chapterHrefs.isEmpty) {
        for (final f in archive.files) {
          final n = f.name.toLowerCase();
          if (n.endsWith('.html') || n.endsWith('.xhtml') || n.endsWith('.htm')) {
            if (!n.contains('toc') && !n.contains('nav')) {
              chapterHrefs.add(f.name);
            }
          }
        }
      }

      int words = 0;
      final previewBuffer = StringBuffer();

      for (int i = 0; i < chapterHrefs.length; i++) {
        final rawHref = chapterHrefs[i];
        final fullHref = opfDir.isNotEmpty && !rawHref.startsWith(opfDir)
            ? '$opfDir$rawHref'
            : rawHref;

        final chFile = archive.findFile(fullHref) ?? archive.findFile(rawHref);
        if (chFile == null) continue;

        final htmlContent = utf8.decode(chFile.content as List<int>, allowMalformed: true);
        final ch = _parseChapterHtml(htmlContent, defaultTitle: 'Chapter ${parsedChapters.length + 1}');

        if (ch.blocks.isNotEmpty) {
          parsedChapters.add(ch);
          for (final b in ch.blocks) {
            final t = b.fullText;
            words += t.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
            if (previewBuffer.length < 800) {
              previewBuffer.writeln(t);
            }
          }
        }
      }

      chapters.value = parsedChapters;
      totalWords.value = words;
      extractedSampleText.value = previewBuffer.toString().trim();
      statusMessage.value = 'Ready to convert';
    } catch (e) {
      log('[EpubToPdf] loadEpubFile error: $e');
      MyDialogs.info(msg: 'Failed to read EPUB file: $e');
    } finally {
      isParsing.value = false;
    }
  }

  EpubChapter _parseChapterHtml(String html, {required String defaultTitle}) {
    // Strip <head>, <script>, <style>
    String cleanHtml = html
        .replaceAll(RegExp(r'<head.*?>.*?<\/head>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<script.*?>.*?<\/script>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<style.*?>.*?<\/style>', dotAll: true, caseSensitive: false), '');

    // Extract title from <h1> or <title>
    String chapterTitle = defaultTitle;
    final h1Match = RegExp(r'<h1[^>]*>(.*?)<\/h1>', dotAll: true, caseSensitive: false).firstMatch(cleanHtml);
    if (h1Match != null) {
      final t = _cleanHtml(h1Match.group(1)!);
      if (t.isNotEmpty && t.length < 80) chapterTitle = t;
    }

    final blocks = <EpubBlock>[];

    // Regex to match structural HTML elements
    final tagRegex = RegExp(
        r'<(h[1-6]|p|blockquote|li)[^>]*>(.*?)<\/\1>',
        dotAll: true,
        caseSensitive: false);

    final matches = tagRegex.allMatches(cleanHtml);
    for (final match in matches) {
      final tag = match.group(1)!.toLowerCase();
      final innerHtml = match.group(2)!;
      final runs = _parseInlineRuns(innerHtml);

      if (runs.isEmpty) continue;
      final text = runs.map((r) => r.text).join().trim();
      if (text.isEmpty) continue;

      EpubBlockType type = EpubBlockType.paragraph;
      if (tag == 'h1') {
        type = EpubBlockType.heading1;
      } else if (tag == 'h2') {
        type = EpubBlockType.heading2;
      } else if (tag.startsWith('h')) {
        type = EpubBlockType.heading2;
      } else if (tag == 'li') {
        type = EpubBlockType.bullet;
      } else if (tag == 'blockquote') {
        type = EpubBlockType.blockquote;
      }

      blocks.add(EpubBlock(type: type, runs: runs));
    }

    // Fallback if no tags matched: split by line breaks or double newlines
    if (blocks.isEmpty) {
      final textLines = cleanHtml
          .replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .split(RegExp(r'\r?\n\s*\n'));

      for (final l in textLines) {
        final trimmed = l.trim();
        if (trimmed.length > 2) {
          blocks.add(
            EpubBlock(
              type: EpubBlockType.paragraph,
              runs: [EpubRun(text: trimmed)],
            ),
          );
        }
      }
    }

    return EpubChapter(title: chapterTitle, blocks: blocks);
  }

  List<EpubRun> _parseInlineRuns(String html) {
    final runs = <EpubRun>[];

    // Replace line breaks with newline
    final normalized = html.replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n');

    // Split on tags while preserving styling
    final tokenRegex = RegExp(r'(<[^>]+>|[^<]+)');
    final tokens = tokenRegex.allMatches(normalized);

    bool isBold = false;
    bool isItalic = false;
    bool isUnderline = false;

    for (final tMatch in tokens) {
      final token = tMatch.group(0)!;
      if (token.startsWith('<')) {
        final lower = token.toLowerCase();
        if (lower.startsWith('<b') || lower.startsWith('<strong')) {
          isBold = true;
        } else if (lower.startsWith('</b') || lower.startsWith('</strong')) {
          isBold = false;
        } else if (lower.startsWith('<i') || lower.startsWith('<em')) {
          isItalic = true;
        } else if (lower.startsWith('</i') || lower.startsWith('</em')) {
          isItalic = false;
        } else if (lower.startsWith('<u')) {
          isUnderline = true;
        } else if (lower.startsWith('</u')) {
          isUnderline = false;
        }
      } else {
        final text = _cleanHtml(token);
        if (text.isNotEmpty) {
          runs.add(
            EpubRun(
              text: text,
              isBold: isBold,
              isItalic: isItalic,
              isUnderline: isUnderline,
            ),
          );
        }
      }
    }

    return runs;
  }

  String _cleanHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#8220;', '"')
        .replaceAll('&#8221;', '"')
        .replaceAll('&#8216;', "'")
        .replaceAll('&#8217;', "'")
        .replaceAll('&#8211;', '–')
        .replaceAll('&#8212;', '—')
        .replaceAll(RegExp(r'[ \t]+'), ' ');
  }

  // ── 3. Convert EPUB to PDF ────────────────────────────────────────────────
  Future<String?> convertToPdf() async {
    if (selectedEpubPath.value == null || chapters.isEmpty) {
      MyDialogs.info(msg: 'Please select a valid EPUB file first');
      return null;
    }

    try {
      isConverting.value = true;
      conversionProgress.value = 0.15;
      statusMessage.value = 'Preparing PDF layout & book typography...';

      final pdfDoc = pw.Document(
        title: bookTitle.value,
        author: bookAuthor.value,
        creator: 'Translator Ably EPUB to PDF',
      );

      final format = selectedPageSize.value.format;
      final marginPts = selectedMargin.value.marginPoints;

      // Select Font
      pw.Font bodyFont;
      pw.Font boldFont;
      pw.Font italicFont;
      pw.Font boldItalicFont;

      switch (selectedFontTheme.value) {
        case EpubPdfFontTheme.classicSerif:
          bodyFont = pw.Font.times();
          boldFont = pw.Font.timesBold();
          italicFont = pw.Font.timesItalic();
          boldItalicFont = pw.Font.timesBoldItalic();
          break;
        case EpubPdfFontTheme.cleanSans:
          bodyFont = pw.Font.helvetica();
          boldFont = pw.Font.helveticaBold();
          italicFont = pw.Font.helveticaOblique();
          boldItalicFont = pw.Font.helveticaBoldOblique();
          break;
        case EpubPdfFontTheme.monospace:
          bodyFont = pw.Font.courier();
          boldFont = pw.Font.courierBold();
          italicFont = pw.Font.courierOblique();
          boldItalicFont = pw.Font.courierBoldOblique();
          break;
      }

      // Base font sizes
      final baseSize = 10.0 + fontSizeDelta.value;
      final h1Size = baseSize + 6.0;
      final h2Size = baseSize + 3.0;

      // ── Optional Book Cover Page ──────────────────────────────────────────
      if (includeCoverPage.value) {
        if (coverImageBytes.value != null) {
          final coverImg = pw.MemoryImage(coverImageBytes.value!);
          pdfDoc.addPage(
            pw.Page(
              pageFormat: format,
              margin: pw.EdgeInsets.zero,
              build: (pw.Context ctx) {
                return pw.Center(
                  child: pw.Image(coverImg, fit: pw.BoxFit.contain),
                );
              },
            ),
          );
        } else {
          // Elegant Typographic Title Page
          pdfDoc.addPage(
            pw.Page(
              pageFormat: format,
              margin: const pw.EdgeInsets.all(48),
              build: (pw.Context ctx) {
                return pw.Center(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 60,
                        height: 3,
                        color: pw_pdf.PdfColors.grey800,
                      ),
                      pw.SizedBox(height: 24),
                      pw.Text(
                        bookTitle.value,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 26,
                          color: pw_pdf.PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 14),
                      pw.Text(
                        'By ${bookAuthor.value}',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          font: italicFont,
                          fontSize: 14,
                          color: pw_pdf.PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 24),
                      pw.Container(
                        width: 60,
                        height: 3,
                        color: pw_pdf.PdfColors.grey800,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }
      }

      conversionProgress.value = 0.40;
      statusMessage.value = 'Rendering book chapters & pages...';

      final totalCh = chapters.length;

      for (int c = 0; c < totalCh; c++) {
        final ch = chapters[c];
        final chProgress = 0.40 + (0.45 * ((c + 1) / totalCh));
        conversionProgress.value = chProgress;
        statusMessage.value = 'Rendering chapter ${c + 1} of $totalCh...';

        final widgetsList = <pw.Widget>[];

        // Chapter Header
        widgetsList.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 8, bottom: 16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  ch.title,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: h1Size + 2,
                    color: pw_pdf.PdfColors.black,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  height: 1.5,
                  color: pw_pdf.PdfColors.grey400,
                ),
              ],
            ),
          ),
        );

        for (final block in ch.blocks) {
          switch (block.type) {
            case EpubBlockType.chapterTitle:
            case EpubBlockType.heading1:
              final spans = _buildSpans(block.runs, bodyFont, boldFont, italicFont, boldItalicFont, h1Size, defaultBold: true);
              widgetsList.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
                  child: pw.RichText(text: pw.TextSpan(children: spans)),
                ),
              );
              break;

            case EpubBlockType.heading2:
              final spans = _buildSpans(block.runs, bodyFont, boldFont, italicFont, boldItalicFont, h2Size, defaultBold: true);
              widgetsList.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
                  child: pw.RichText(text: pw.TextSpan(children: spans)),
                ),
              );
              break;

            case EpubBlockType.bullet:
              final spans = _buildSpans(block.runs, bodyFont, boldFont, italicFont, boldItalicFont, baseSize);
              widgetsList.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 14, bottom: 4),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('• ', style: pw.TextStyle(font: boldFont, fontSize: baseSize)),
                      pw.Expanded(child: pw.RichText(text: pw.TextSpan(children: spans))),
                    ],
                  ),
                ),
              );
              break;

            case EpubBlockType.blockquote:
              final spans = _buildSpans(block.runs, bodyFont, boldFont, italicFont, boldItalicFont, baseSize);
              widgetsList.add(
                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 6),
                  padding: const pw.EdgeInsets.only(left: 10, top: 4, bottom: 4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(left: pw.BorderSide(color: pw_pdf.PdfColors.grey500, width: 2.5)),
                  ),
                  child: pw.RichText(text: pw.TextSpan(children: spans)),
                ),
              );
              break;

            case EpubBlockType.paragraph:
              final spans = _buildSpans(block.runs, bodyFont, boldFont, italicFont, boldItalicFont, baseSize);
              widgetsList.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6.5),
                  child: pw.RichText(
                    textAlign: pw.TextAlign.justify,
                    text: pw.TextSpan(children: spans),
                  ),
                ),
              );
              break;
          }
        }

        // Add Chapter MultiPage
        pdfDoc.addPage(
          pw.MultiPage(
            pageFormat: format,
            margin: pw.EdgeInsets.all(marginPts),
            header: (pw.Context ctx) {
              if (!includeHeader.value || ctx.pageNumber == 1) {
                return pw.SizedBox.shrink();
              }
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.only(bottom: 4),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: pw_pdf.PdfColors.grey300, width: 0.6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      bookTitle.value,
                      style: pw.TextStyle(font: bodyFont, fontSize: 8.0, color: pw_pdf.PdfColors.grey600),
                    ),
                    pw.Text(
                      ch.title,
                      style: pw.TextStyle(font: italicFont, fontSize: 7.5, color: pw_pdf.PdfColors.grey500),
                    ),
                  ],
                ),
              );
            },
            footer: (pw.Context ctx) {
              if (!includeFooter.value) return pw.SizedBox.shrink();
              return pw.Container(
                margin: const pw.EdgeInsets.only(top: 12),
                padding: const pw.EdgeInsets.only(top: 4),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: pw_pdf.PdfColors.grey300, width: 0.6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                      style: pw.TextStyle(font: bodyFont, fontSize: 8.0, color: pw_pdf.PdfColors.grey600),
                    ),
                    pw.Text(
                      bookAuthor.value,
                      style: pw.TextStyle(font: bodyFont, fontSize: 7.5, color: pw_pdf.PdfColors.grey400),
                    ),
                  ],
                ),
              );
            },
            build: (pw.Context ctx) => widgetsList,
          ),
        );
      }

      conversionProgress.value = 0.90;
      statusMessage.value = 'Writing PDF document...';

      final outputBytes = await pdfDoc.save();
      final tempDir = await getTemporaryDirectory();
      final baseName = selectedEpubName.value!.replaceAll(RegExp(r'\.[^.]+$'), '');
      final outputPath = '${tempDir.path}/${baseName}_converted.pdf';
      final outFile = File(outputPath);
      await outFile.writeAsBytes(outputBytes, flush: true);

      convertedPdfPath.value = outputPath;
      convertedPdfSize.value = outputBytes.length;

      // Render Page 1 preview thumbnail
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
        log('[EpubToPdf] thumbnail render error: $e');
        convertedPageCount.value = chapters.length;
      }

      conversionProgress.value = 1.0;
      statusMessage.value = 'Book Converted!';
      MyDialogs.success(msg: 'EPUB converted to PDF successfully!');
      AdHelper.showInterstitialAd(onComplete: () {});
      return outputPath;
    } catch (e) {
      log('[EpubToPdf] convertToPdf error: $e');
      MyDialogs.info(msg: 'Conversion failed: $e');
      return null;
    } finally {
      isConverting.value = false;
    }
  }

  List<pw.InlineSpan> _buildSpans(
    List<EpubRun> runs,
    pw.Font bodyFont,
    pw.Font boldFont,
    pw.Font italicFont,
    pw.Font boldItalicFont,
    double fontSize, {
    bool defaultBold = false,
  }) {
    return runs.map((run) {
      pw.Font fontToUse;
      final isBold = defaultBold || run.isBold;
      final isItalic = run.isItalic;

      if (isBold && isItalic) {
        fontToUse = boldItalicFont;
      } else if (isBold) {
        fontToUse = boldFont;
      } else if (isItalic) {
        fontToUse = italicFont;
      } else {
        fontToUse = bodyFont;
      }

      return pw.TextSpan(
        text: run.text,
        style: pw.TextStyle(
          font: fontToUse,
          fontSize: fontSize,
          color: pw_pdf.PdfColors.black,
          decoration: run.isUnderline ? pw.TextDecoration.underline : pw.TextDecoration.none,
        ),
      );
    }).toList();
  }

  // ── 4. Share and Reset ────────────────────────────────────────────────────
  Future<void> shareConvertedPdf() async {
    final path = convertedPdfPath.value;
    if (path == null) return;
    try {
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'PDF Book: ${bookTitle.value}',
        text: 'Converted from EPUB e-book "${bookTitle.value}" by ${bookAuthor.value}',
      );
    } catch (e) {
      log('[EpubToPdf] share error: $e');
      MyDialogs.info(msg: 'Failed to share PDF: $e');
    }
  }

  void reset() {
    selectedEpubPath.value = null;
    selectedEpubName.value = null;
    fileSizeInBytes.value = 0;
    bookTitle.value = '';
    bookAuthor.value = '';
    bookLanguage.value = '';
    coverImageBytes.value = null;
    chapters.clear();
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
