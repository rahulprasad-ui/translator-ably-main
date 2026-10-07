// lib/controllers/html_to_pdf_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../helper/my_dialogs.dart';

// ── Models & Enums ──────────────────────────────────────────────────────────

enum HtmlInputSource {
  file('HTML File', Icons.file_present_rounded, 'Pick .html or .htm document from storage'),
  code('Direct Code', Icons.code_rounded, 'Write or paste raw HTML markup'),
  url('Web URL', Icons.language_rounded, 'Fetch and convert live website page');

  final String title;
  final IconData icon;
  final String subtitle;
  const HtmlInputSource(this.title, this.icon, this.subtitle);
}

enum HtmlPdfPageSize {
  a4('A4 Document', 'Standard 210 × 297 mm', pw_pdf.PdfPageFormat.a4),
  letter('US Letter', 'Standard 8.5 × 11 in', pw_pdf.PdfPageFormat.letter),
  a3('A3 Sheet', 'Large format 297 × 420 mm', pw_pdf.PdfPageFormat.a3),
  legal('US Legal', 'Tall 8.5 × 14 in', pw_pdf.PdfPageFormat.legal),
  a5('A5 Compact', 'Compact 148 × 210 mm', pw_pdf.PdfPageFormat.a5);

  final String title;
  final String subtitle;
  final pw_pdf.PdfPageFormat format;
  const HtmlPdfPageSize(this.title, this.subtitle, this.format);
}

enum HtmlPdfOrientation {
  portrait('Portrait', 'Standard vertical page orientation'),
  landscape('Landscape', 'Wide horizontal page orientation');

  final String title;
  final String subtitle;
  const HtmlPdfOrientation(this.title, this.subtitle);
}

enum HtmlPdfMargin {
  normal('Normal (36 pt)', 36.0),
  compact('Compact (18 pt)', 18.0),
  wide('Spacious (54 pt)', 54.0),
  minimal('Minimal (10 pt)', 10.0);

  final String title;
  final double marginPoints;
  const HtmlPdfMargin(this.title, this.marginPoints);
}

enum HtmlPdfFontFamily {
  sansSerif('Clean Sans (Helvetica)', 'Modern & readable typography'),
  serif('Classic Serif (Times)', 'Traditional editorial typography'),
  monospace('Monospace (Courier)', 'Technical & code typography');

  final String title;
  final String subtitle;
  const HtmlPdfFontFamily(this.title, this.subtitle);
}

// ── Intermediate Parsed HTML Elements ───────────────────────────────────────

enum HtmlBlockType {
  h1,
  h2,
  h3,
  h4,
  h5,
  h6,
  paragraph,
  blockquote,
  codeBlock,
  unorderedList,
  orderedList,
  table,
  horizontalRule,
  image,
  pageBreak,
}

class HtmlInlineSpan {
  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrike;
  final bool isCode;
  final String? linkUrl;
  final pw_pdf.PdfColor? textColor;
  final pw_pdf.PdfColor? backgroundColor;
  final double? fontSize;

  HtmlInlineSpan({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrike = false,
    this.isCode = false,
    this.linkUrl,
    this.textColor,
    this.backgroundColor,
    this.fontSize,
  });
}

class HtmlBlock {
  final HtmlBlockType type;
  final List<HtmlInlineSpan> inlineSpans;
  final List<List<HtmlInlineSpan>>? listItems;
  final List<List<List<HtmlInlineSpan>>>? tableRows; // [row][col] -> inline spans
  final Uint8List? imageBytes;
  final String? imageAlt;
  final double? customPaddingTop;
  final double? customPaddingBottom;
  final pw.TextAlign? textAlign;

  HtmlBlock({
    required this.type,
    this.inlineSpans = const [],
    this.listItems,
    this.tableRows,
    this.imageBytes,
    this.imageAlt,
    this.customPaddingTop,
    this.customPaddingBottom,
    this.textAlign,
  });

  String get plainText {
    if (inlineSpans.isNotEmpty) {
      return inlineSpans.map((e) => e.text).join();
    }
    if (listItems != null) {
      return listItems!.map((it) => it.map((s) => s.text).join()).join('\n');
    }
    return '';
  }
}

// ── Controller Implementation ───────────────────────────────────────────────

class HtmlToPdfController extends GetxController {
  // Input Selection
  final activeSource = HtmlInputSource.file.obs;

  // File Input State
  final selectedFilePath = RxnString();
  final selectedFileName = RxnString();
  final selectedFileSize = 0.obs;

  // Code Input State
  final htmlCodeInput = ''.obs;

  // URL Input State
  final webUrlInput = ''.obs;
  final isFetchingUrl = false.obs;
  final fetchedUrlStatus = RxnString();

  // Document Parsed Info
  final documentTitle = 'Untitled Document'.obs;
  final rawHtmlContent = ''.obs;
  final parsedBlocks = <HtmlBlock>[].obs;
  final extractedTextSnippet = ''.obs;
  final wordCount = 0.obs;
  final headingCount = 0.obs;
  final tableCount = 0.obs;
  final imageCount = 0.obs;

  // Conversion Options
  final selectedPageSize = HtmlPdfPageSize.a4.obs;
  final selectedOrientation = HtmlPdfOrientation.portrait.obs;
  final selectedMargin = HtmlPdfMargin.normal.obs;
  final selectedFont = HtmlPdfFontFamily.sansSerif.obs;
  final baseFontSize = 11.0.obs;
  final showHeader = true.obs;
  final showFooter = true.obs;
  final enableTableBorders = true.obs;
  final renderImages = true.obs;

  // Conversion Progress & Output
  final isConverting = false.obs;
  final conversionProgress = 0.0.obs;
  final conversionStatusText = ''.obs;
  final convertedPdfPath = RxnString();
  final convertedPdfName = RxnString();
  final convertedPdfSize = 0.obs;
  final convertedPageCount = 0.obs;
  final previewThumbnailBytes = Rxn<Uint8List>();

  @override
  void onInit() {
    super.onInit();
    // Pre-populate with a clean sample invoice if code mode is opened empty
    if (htmlCodeInput.value.isEmpty) {
      loadSample(HtmlSampleTemplate.modernInvoice);
    }
  }

  // ── File Picking ──────────────────────────────────────────────────────────

  Future<void> pickHtmlFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['html', 'htm', 'xhtml', 'txt'],
      );

      if (result.isNotEmpty) {
        final path = result.first.path;
        if (path != null && File(path).existsSync()) {
          await loadHtmlFromFile(path, customName: result.first.name);
        }
      }
    } catch (e) {
      log('[HtmlToPdf] pickHtmlFile error: $e');
      MyDialogs.error(msg: 'Failed to select HTML file: $e');
    }
  }

  Future<void> loadHtmlFromFile(String filePath, {String? customName}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        MyDialogs.error(msg: 'File does not exist.');
        return;
      }

      final bytes = await file.readAsBytes();
      selectedFilePath.value = filePath;
      selectedFileName.value = customName ?? file.uri.pathSegments.last;
      selectedFileSize.value = bytes.length;

      // Try UTF-8 decode, fallback to Latin1
      String htmlStr;
      try {
        htmlStr = utf8.decode(bytes);
      } catch (_) {
        htmlStr = latin1.decode(bytes);
      }

      rawHtmlContent.value = htmlStr;
      htmlCodeInput.value = htmlStr;
      _parseHtmlMarkup(htmlStr, defaultTitle: selectedFileName.value);
    } catch (e) {
      log('[HtmlToPdf] loadHtmlFromFile error: $e');
      MyDialogs.error(msg: 'Could not read HTML file: $e');
    }
  }

  // ── Fetch Web URL ─────────────────────────────────────────────────────────

  Future<void> fetchHtmlFromUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      MyDialogs.info(msg: 'Please enter a valid website URL');
      return;
    }

    String normalizedUrl = trimmed;
    if (!normalizedUrl.startsWith('http://') && !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'https://$normalizedUrl';
    }

    try {
      isFetchingUrl.value = true;
      fetchedUrlStatus.value = 'Connecting to $normalizedUrl...';

      final uri = Uri.parse(normalizedUrl);
      final response = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String bodyText;
        try {
          bodyText = utf8.decode(response.bodyBytes);
        } catch (_) {
          bodyText = response.body;
        }

        selectedFilePath.value = null;
        selectedFileName.value = uri.host.isNotEmpty ? '${uri.host}.html' : 'webpage.html';
        selectedFileSize.value = response.bodyBytes.length;
        rawHtmlContent.value = bodyText;
        htmlCodeInput.value = bodyText;
        webUrlInput.value = normalizedUrl;
        fetchedUrlStatus.value = 'Successfully loaded (${(response.bodyBytes.length / 1024).toStringAsFixed(1)} KB)';

        _parseHtmlMarkup(bodyText, defaultTitle: uri.host);
      } else {
        fetchedUrlStatus.value = 'HTTP ${response.statusCode} error';
        MyDialogs.error(msg: 'Failed to load webpage: HTTP status ${response.statusCode}');
      }
    } catch (e) {
      log('[HtmlToPdf] fetchHtmlFromUrl error: $e');
      fetchedUrlStatus.value = 'Failed to connect: $e';
      MyDialogs.error(msg: 'Could not fetch webpage. Check your internet connection.');
    } finally {
      isFetchingUrl.value = false;
    }
  }

  // ── Code Input Changes ────────────────────────────────────────────────────

  void onCodeChanged(String value) {
    htmlCodeInput.value = value;
    rawHtmlContent.value = value;
    _parseHtmlMarkup(value, defaultTitle: 'Custom HTML');
  }

  void loadSample(HtmlSampleTemplate template) {
    final code = template.markup;
    htmlCodeInput.value = code;
    rawHtmlContent.value = code;
    selectedFileName.value = '${template.name.toLowerCase().replaceAll(' ', '_')}.html';
    selectedFilePath.value = null;
    _parseHtmlMarkup(code, defaultTitle: template.name);
  }

  // ── HTML Parsing Engine ───────────────────────────────────────────────────

  void _parseHtmlMarkup(String rawHtml, {String? defaultTitle}) {
    try {
      if (rawHtml.trim().isEmpty) {
        parsedBlocks.clear();
        documentTitle.value = defaultTitle ?? 'Untitled';
        extractedTextSnippet.value = '';
        wordCount.value = 0;
        headingCount.value = 0;
        tableCount.value = 0;
        imageCount.value = 0;
        return;
      }

      // 1. Extract <title> if present
      final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true)
          .firstMatch(rawHtml);
      if (titleMatch != null && titleMatch.group(1) != null) {
        final t = _decodeHtmlEntities(titleMatch.group(1)!).trim();
        if (t.isNotEmpty) {
          documentTitle.value = t;
        } else {
          documentTitle.value = defaultTitle ?? 'HTML Document';
        }
      } else {
        documentTitle.value = defaultTitle ?? 'HTML Document';
      }

      // 2. Pre-clean markup: strip scripts, styles, head, comments
      String sanitized = rawHtml
          .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
          .replaceAll(RegExp(r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<head\b[^<]*(?:(?!<\/head>)<[^<]*)*<\/head>', caseSensitive: false), '');

      // 3. Extract body content if <body> tag exists
      final bodyMatch = RegExp(r'<body[^>]*>([\s\S]*?)</body>', caseSensitive: false).firstMatch(sanitized);
      if (bodyMatch != null && bodyMatch.group(1) != null) {
        sanitized = bodyMatch.group(1)!;
      }

      // 4. Tokenize & build blocks
      final blocks = <HtmlBlock>[];
      int headings = 0;
      int tables = 0;
      int images = 0;

      // Match major block-level containers or top-level elements
      final blockRegex = RegExp(
        r'<(h[1-6]|p|blockquote|pre|table|ul|ol|hr|img|div|section|article)\b([^>]*)>([\s\S]*?)<\/\1>|<(hr|img)\b([^>]*)\/?>',
        caseSensitive: false,
      );

      final matches = blockRegex.allMatches(sanitized);

      if (matches.isEmpty) {
        // Fallback: If no standard block tags found, split by lines / breaks
        final textLines = sanitized
            .replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n')
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .split('\n');

        for (final line in textLines) {
          final trimmed = _decodeHtmlEntities(line).trim();
          if (trimmed.isNotEmpty) {
            blocks.add(HtmlBlock(
              type: HtmlBlockType.paragraph,
              inlineSpans: [HtmlInlineSpan(text: trimmed)],
            ));
          }
        }
      } else {
        for (final match in matches) {
          final tag = (match.group(1) ?? match.group(4) ?? '').toLowerCase();
          final attrs = match.group(2) ?? match.group(5) ?? '';
          final innerContent = match.group(3) ?? '';

          if (tag.startsWith('h') && tag.length == 2) {
            headings++;
            final level = int.tryParse(tag[1]) ?? 1;
            final spans = _parseInlineSpans(innerContent);
            HtmlBlockType hType;
            switch (level) {
              case 1:
                hType = HtmlBlockType.h1;
                break;
              case 2:
                hType = HtmlBlockType.h2;
                break;
              case 3:
                hType = HtmlBlockType.h3;
                break;
              case 4:
                hType = HtmlBlockType.h4;
                break;
              case 5:
                hType = HtmlBlockType.h5;
                break;
              default:
                hType = HtmlBlockType.h6;
            }
            blocks.add(HtmlBlock(
              type: hType,
              inlineSpans: spans,
              textAlign: _extractAlignment(attrs),
            ));
          } else if (tag == 'p' || tag == 'div' || tag == 'section' || tag == 'article') {
            final spans = _parseInlineSpans(innerContent);
            if (spans.isNotEmpty) {
              blocks.add(HtmlBlock(
                type: HtmlBlockType.paragraph,
                inlineSpans: spans,
                textAlign: _extractAlignment(attrs),
              ));
            }
          } else if (tag == 'blockquote') {
            final spans = _parseInlineSpans(innerContent);
            blocks.add(HtmlBlock(
              type: HtmlBlockType.blockquote,
              inlineSpans: spans,
            ));
          } else if (tag == 'pre') {
            final decoded = _decodeHtmlEntities(innerContent.replaceAll(RegExp(r'<[^>]+>'), ''));
            blocks.add(HtmlBlock(
              type: HtmlBlockType.codeBlock,
              inlineSpans: [HtmlInlineSpan(text: decoded, isCode: true)],
            ));
          } else if (tag == 'ul' || tag == 'ol') {
            final isOrdered = tag == 'ol';
            final liMatches = RegExp(r'<li\b[^>]*>([\s\S]*?)<\/li>', caseSensitive: false).allMatches(innerContent);
            final items = <List<HtmlInlineSpan>>[];
            for (final li in liMatches) {
              final liContent = li.group(1) ?? '';
              final spans = _parseInlineSpans(liContent);
              if (spans.isNotEmpty) {
                items.add(spans);
              }
            }
            if (items.isNotEmpty) {
              blocks.add(HtmlBlock(
                type: isOrdered ? HtmlBlockType.orderedList : HtmlBlockType.unorderedList,
                listItems: items,
              ));
            }
          } else if (tag == 'table') {
            tables++;
            final parsedRows = _parseTable(innerContent);
            if (parsedRows.isNotEmpty) {
              blocks.add(HtmlBlock(
                type: HtmlBlockType.table,
                tableRows: parsedRows,
              ));
            }
          } else if (tag == 'hr') {
            blocks.add(HtmlBlock(type: HtmlBlockType.horizontalRule));
          } else if (tag == 'img') {
            images++;
            final srcMatch = RegExp(r'src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(attrs);
            final altMatch = RegExp(r'alt=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(attrs);
            final src = srcMatch?.group(1);
            final alt = altMatch?.group(1);

            Uint8List? imgBytes;
            if (src != null && src.startsWith('data:image')) {
              try {
                final commaIdx = src.indexOf(',');
                if (commaIdx != -1) {
                  imgBytes = base64Decode(src.substring(commaIdx + 1));
                }
              } catch (e) {
                log('[HtmlToPdf] base64 image decode error: $e');
              }
            }
            blocks.add(HtmlBlock(
              type: HtmlBlockType.image,
              imageBytes: imgBytes,
              imageAlt: alt ?? 'Image',
            ));
          }
        }
      }

      parsedBlocks.value = blocks;
      headingCount.value = headings;
      tableCount.value = tables;
      imageCount.value = images;

      // Extract plain text snippet & word count
      final buffer = StringBuffer();
      for (final b in blocks) {
        final text = b.plainText;
        if (text.isNotEmpty) {
          buffer.writeln(text);
        }
      }

      final fullPlainText = buffer.toString();
      final words = fullPlainText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      wordCount.value = words;

      extractedTextSnippet.value = fullPlainText.length > 500
          ? '${fullPlainText.substring(0, 500)}...'
          : fullPlainText;
    } catch (e) {
      log('[HtmlToPdf] _parseHtmlMarkup error: $e');
    }
  }

  // ── Inline Spans Parser ───────────────────────────────────────────────────

  List<HtmlInlineSpan> _parseInlineSpans(String raw) {
    if (raw.trim().isEmpty) return [];

    final cleanRaw = raw
        .replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ');

    final spans = <HtmlInlineSpan>[];

    // Tokenize inline tags: <b>, <strong>, <i>, <em>, <u>, <s>, <code>, <a>, <span style=...>
    final tagRegex = RegExp(
      r'<(b|strong|i|em|u|ins|s|del|strike|code|a|span|mark)\b([^>]*)>([\s\S]*?)<\/\1>|([^<]+)',
      caseSensitive: false,
    );

    final matches = tagRegex.allMatches(cleanRaw);

    for (final match in matches) {
      final tag = match.group(1)?.toLowerCase();
      final attrs = match.group(2) ?? '';
      final inner = match.group(3);
      final plain = match.group(4);

      if (plain != null && plain.isNotEmpty) {
        final text = _decodeHtmlEntities(plain);
        if (text.isNotEmpty) {
          spans.add(HtmlInlineSpan(text: text));
        }
      } else if (inner != null) {
        final text = _decodeHtmlEntities(inner.replaceAll(RegExp(r'<[^>]+>'), ''));
        if (text.isEmpty) continue;

        bool isBold = false;
        bool isItalic = false;
        bool isUnderline = false;
        bool isStrike = false;
        bool isCode = false;
        String? linkUrl;
        pw_pdf.PdfColor? textColor;
        pw_pdf.PdfColor? bgColor;

        switch (tag) {
          case 'b':
          case 'strong':
            isBold = true;
            break;
          case 'i':
          case 'em':
            isItalic = true;
            break;
          case 'u':
          case 'ins':
            isUnderline = true;
            break;
          case 's':
          case 'del':
          case 'strike':
            isStrike = true;
            break;
          case 'code':
            isCode = true;
            break;
          case 'mark':
            bgColor = pw_pdf.PdfColors.yellow100;
            break;
          case 'a':
            isUnderline = true;
            textColor = pw_pdf.PdfColors.blue700;
            final hrefMatch = RegExp(r'href=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(attrs);
            linkUrl = hrefMatch?.group(1);
            break;
        }

        // Inline CSS parsing for style="..."
        if (attrs.contains('style')) {
          final styleMatch = RegExp(r'style=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(attrs);
          if (styleMatch != null) {
            final styleStr = styleMatch.group(1) ?? '';
            final parsedCss = _parseCssInline(styleStr);
            if (parsedCss['bold'] == true) isBold = true;
            if (parsedCss['italic'] == true) isItalic = true;
            if (parsedCss['underline'] == true) isUnderline = true;
            if (parsedCss['color'] is pw_pdf.PdfColor) {
              textColor = parsedCss['color'] as pw_pdf.PdfColor;
            }
            if (parsedCss['bg'] is pw_pdf.PdfColor) {
              bgColor = parsedCss['bg'] as pw_pdf.PdfColor;
            }
          }
        }

        spans.add(HtmlInlineSpan(
          text: text,
          isBold: isBold,
          isItalic: isItalic,
          isUnderline: isUnderline,
          isStrike: isStrike,
          isCode: isCode,
          linkUrl: linkUrl,
          textColor: textColor,
          backgroundColor: bgColor,
        ));
      }
    }

    return spans;
  }

  List<List<List<HtmlInlineSpan>>> _parseTable(String tableHtml) {
    final rows = <List<List<HtmlInlineSpan>>>[];
    final trMatches = RegExp(r'<tr\b[^>]*>([\s\S]*?)<\/tr>', caseSensitive: false).allMatches(tableHtml);

    for (final tr in trMatches) {
      final trInner = tr.group(1) ?? '';
      final cellMatches = RegExp(r'<(td|th)\b([^>]*)>([\s\S]*?)<\/\1>', caseSensitive: false).allMatches(trInner);
      final rowCells = <List<HtmlInlineSpan>>[];

      for (final cell in cellMatches) {
        final cellTag = cell.group(1)?.toLowerCase();
        final cellInner = cell.group(3) ?? '';
        var spans = _parseInlineSpans(cellInner);

        if (cellTag == 'th') {
          // Headers are automatically bold
          spans = spans.map((s) {
            return HtmlInlineSpan(
              text: s.text,
              isBold: true,
              isItalic: s.isItalic,
              isUnderline: s.isUnderline,
              isStrike: s.isStrike,
              isCode: s.isCode,
              textColor: s.textColor ?? pw_pdf.PdfColors.blueGrey900,
            );
          }).toList();
        }
        rowCells.add(spans);
      }

      if (rowCells.isNotEmpty) {
        rows.add(rowCells);
      }
    }

    return rows;
  }

  pw.TextAlign? _extractAlignment(String attrs) {
    if (attrs.toLowerCase().contains('center')) return pw.TextAlign.center;
    if (attrs.toLowerCase().contains('right')) return pw.TextAlign.right;
    if (attrs.toLowerCase().contains('justify')) return pw.TextAlign.justify;
    return pw.TextAlign.left;
  }

  Map<String, dynamic> _parseCssInline(String style) {
    final result = <String, dynamic>{};
    final parts = style.split(';');

    for (final part in parts) {
      final kv = part.split(':');
      if (kv.length == 2) {
        final key = kv[0].trim().toLowerCase();
        final val = kv[1].trim().toLowerCase();

        if (key == 'font-weight' && (val.contains('bold') || val.contains('700') || val.contains('800'))) {
          result['bold'] = true;
        } else if (key == 'font-style' && val.contains('italic')) {
          result['italic'] = true;
        } else if (key == 'text-decoration' && val.contains('underline')) {
          result['underline'] = true;
        } else if (key == 'color') {
          result['color'] = _colorFromCss(val);
        } else if (key == 'background-color' || key == 'background') {
          result['bg'] = _colorFromCss(val);
        }
      }
    }

    return result;
  }

  pw_pdf.PdfColor? _colorFromCss(String val) {
    if (val.startsWith('#')) {
      final hex = val.replaceFirst('#', '');
      if (hex.length == 6) {
        final r = int.tryParse(hex.substring(0, 2), radix: 16) ?? 0;
        final g = int.tryParse(hex.substring(2, 4), radix: 16) ?? 0;
        final b = int.tryParse(hex.substring(4, 6), radix: 16) ?? 0;
        return pw_pdf.PdfColor.fromInt(0xFF000000 | (r << 16) | (g << 8) | b);
      }
    } else if (val.startsWith('rgb')) {
      final rgbMatch = RegExp(r'rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)').firstMatch(val);
      if (rgbMatch != null) {
        final r = int.tryParse(rgbMatch.group(1)!) ?? 0;
        final g = int.tryParse(rgbMatch.group(2)!) ?? 0;
        final b = int.tryParse(rgbMatch.group(3)!) ?? 0;
        return pw_pdf.PdfColor.fromInt(0xFF000000 | (r << 16) | (g << 8) | b);
      }
    } else {
      switch (val) {
        case 'red':
          return pw_pdf.PdfColors.red;
        case 'blue':
          return pw_pdf.PdfColors.blue;
        case 'green':
          return pw_pdf.PdfColors.green;
        case 'orange':
          return pw_pdf.PdfColors.orange;
        case 'gray':
        case 'grey':
          return pw_pdf.PdfColors.grey;
        case 'black':
          return pw_pdf.PdfColors.black;
      }
    }
    return null;
  }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&bull;', '•')
        .replaceAll('&copy;', '©')
        .replaceAll('&reg;', '®')
        .replaceAll('&trade;', '™')
        .replaceAll('&euro;', '€')
        .replaceAll('&pound;', '£')
        .replaceAll('&yen;', '¥')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
          final code = int.tryParse(m.group(1)!);
          return code != null ? String.fromCharCode(code) : '';
        }).replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
          final code = int.tryParse(m.group(1)!, radix: 16);
          return code != null ? String.fromCharCode(code) : '';
        });
  }

  // ── Convert to PDF ────────────────────────────────────────────────────────

  Future<void> convertToPdf() async {
    if (parsedBlocks.isEmpty && htmlCodeInput.value.trim().isEmpty) {
      MyDialogs.info(msg: 'No HTML content to convert. Please pick a file, enter code, or fetch a URL.');
      return;
    }

    try {
      isConverting.value = true;
      conversionProgress.value = 0.1;
      conversionStatusText.value = 'Preparing PDF layout...';

      // 1. Configure page size & orientation
      pw_pdf.PdfPageFormat format = selectedPageSize.value.format;
      if (selectedOrientation.value == HtmlPdfOrientation.landscape) {
        format = pw_pdf.PdfPageFormat(format.height, format.width);
      }

      final marginVal = selectedMargin.value.marginPoints;
      final docTitle = documentTitle.value.isNotEmpty ? documentTitle.value : 'HTML Document';

      conversionProgress.value = 0.3;
      conversionStatusText.value = 'Rendering HTML elements...';

      // Select PDF font
      pw.Font baseFont;
      pw.Font boldFont;
      pw.Font italicFont;
      pw.Font boldItalicFont;

      switch (selectedFont.value) {
        case HtmlPdfFontFamily.serif:
          baseFont = pw.Font.times();
          boldFont = pw.Font.timesBold();
          italicFont = pw.Font.timesItalic();
          boldItalicFont = pw.Font.timesBoldItalic();
          break;
        case HtmlPdfFontFamily.monospace:
          baseFont = pw.Font.courier();
          boldFont = pw.Font.courierBold();
          italicFont = pw.Font.courierOblique();
          boldItalicFont = pw.Font.courierBoldOblique();
          break;
        default:
          baseFont = pw.Font.helvetica();
          boldFont = pw.Font.helveticaBold();
          italicFont = pw.Font.helveticaOblique();
          boldItalicFont = pw.Font.helveticaBoldOblique();
          break;
      }

      final theme = pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
        italic: italicFont,
        boldItalic: boldItalicFont,
      );

      final pdf = pw.Document(theme: theme);

      // 2. Build PDF MultiPage
      final widgets = <pw.Widget>[];

      for (int i = 0; i < parsedBlocks.length; i++) {
        final block = parsedBlocks[i];
        final pwWidget = _buildPdfWidgetFromBlock(block);
        if (pwWidget != null) {
          widgets.add(pwWidget);
        }
      }

      // If document is empty, add fallback paragraph
      if (widgets.isEmpty) {
        widgets.add(pw.Paragraph(
          text: rawHtmlContent.value.isNotEmpty
              ? rawHtmlContent.value
              : 'Empty HTML Document',
        ));
      }

      conversionProgress.value = 0.6;
      conversionStatusText.value = 'Assembling PDF pages...';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: format,
          margin: pw.EdgeInsets.all(marginVal),
          header: showHeader.value
              ? (context) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 12),
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: pw_pdf.PdfColors.grey300, width: 0.8),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          docTitle,
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: pw_pdf.PdfColors.blueGrey700,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Created with Translator Ably',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: pw_pdf.PdfColors.grey500,
                          ),
                        ),
                      ],
                    ),
                  )
              : null,
          footer: showFooter.value
              ? (context) => pw.Container(
                    margin: const pw.EdgeInsets.only(top: 12),
                    padding: const pw.EdgeInsets.only(top: 6),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: pw_pdf.PdfColors.grey300, width: 0.8),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'HTML to PDF',
                          style: const pw.TextStyle(
                            fontSize: 8.5,
                            color: pw_pdf.PdfColors.grey600,
                          ),
                        ),
                        pw.Text(
                          'Page ${context.pageNumber} of ${context.pagesCount}',
                          style: const pw.TextStyle(
                            fontSize: 8.5,
                            color: pw_pdf.PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  )
              : null,
          build: (context) => widgets,
        ),
      );

      conversionProgress.value = 0.8;
      conversionStatusText.value = 'Saving output PDF...';

      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = docTitle
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final outputName = '${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outputFile = File('${tempDir.path}/$outputName');

      final pdfBytes = await pdf.save();
      await outputFile.writeAsBytes(pdfBytes);

      convertedPdfPath.value = outputFile.path;
      convertedPdfName.value = outputName;
      convertedPdfSize.value = pdfBytes.length;

      conversionProgress.value = 0.9;
      conversionStatusText.value = 'Rendering preview thumbnail...';

      // 3. Render thumbnail with pdfx
      try {
        final pdfDoc = await PdfDocument.openFile(outputFile.path);
        convertedPageCount.value = pdfDoc.pagesCount;
        final firstPage = await pdfDoc.getPage(1);
        final pageImg = await firstPage.render(
          width: firstPage.width * 1.5,
          height: firstPage.height * 1.5,
          format: PdfPageImageFormat.png,
        );
        if (pageImg != null) {
          previewThumbnailBytes.value = pageImg.bytes;
        }
        await firstPage.close();
        await pdfDoc.close();
      } catch (thumbErr) {
        log('[HtmlToPdf] thumbnail error: $thumbErr');
      }

      conversionProgress.value = 1.0;
      conversionStatusText.value = 'Done!';
      MyDialogs.success(msg: 'HTML converted to PDF successfully!');
    } catch (e) {
      log('[HtmlToPdf] convertToPdf error: $e');
      MyDialogs.error(msg: 'Conversion failed: $e');
    } finally {
      isConverting.value = false;
    }
  }

  // ── Block to PDF Widget Mapping ───────────────────────────────────────────

  pw.Widget? _buildPdfWidgetFromBlock(HtmlBlock block) {
    final baseSize = baseFontSize.value;

    switch (block.type) {
      case HtmlBlockType.h1:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 8),
          child: pw.RichText(
            textAlign: block.textAlign ?? pw.TextAlign.left,
            text: _buildPdfTextSpan(block.inlineSpans, defaultFontSize: baseSize + 11, defaultBold: true),
          ),
        );
      case HtmlBlockType.h2:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
          child: pw.RichText(
            textAlign: block.textAlign ?? pw.TextAlign.left,
            text: _buildPdfTextSpan(block.inlineSpans, defaultFontSize: baseSize + 7, defaultBold: true),
          ),
        );
      case HtmlBlockType.h3:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: pw.RichText(
            textAlign: block.textAlign ?? pw.TextAlign.left,
            text: _buildPdfTextSpan(block.inlineSpans, defaultFontSize: baseSize + 4, defaultBold: true),
          ),
        );
      case HtmlBlockType.h4:
      case HtmlBlockType.h5:
      case HtmlBlockType.h6:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
          child: pw.RichText(
            textAlign: block.textAlign ?? pw.TextAlign.left,
            text: _buildPdfTextSpan(block.inlineSpans, defaultFontSize: baseSize + 2, defaultBold: true),
          ),
        );
      case HtmlBlockType.paragraph:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.RichText(
            textAlign: block.textAlign ?? pw.TextAlign.left,
            text: _buildPdfTextSpan(block.inlineSpans, defaultFontSize: baseSize),
          ),
        );
      case HtmlBlockType.blockquote:
        return pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 8),
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const pw.BoxDecoration(
            color: pw_pdf.PdfColors.grey100,
            border: pw.Border(
              left: pw.BorderSide(color: pw_pdf.PdfColors.orange700, width: 3.5),
            ),
          ),
          child: pw.RichText(
            text: _buildPdfTextSpan(block.inlineSpans, defaultFontSize: baseSize, defaultItalic: true),
          ),
        );
      case HtmlBlockType.codeBlock:
        return pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 8),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: const pw_pdf.PdfColor.fromInt(0xFF1E293B),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            block.plainText,
            style: const pw.TextStyle(
              fontStyle: pw.FontStyle.normal,
              fontSize: 9.5,
              color: pw_pdf.PdfColors.white,
            ),
          ),
        );
      case HtmlBlockType.unorderedList:
      case HtmlBlockType.orderedList:
        if (block.listItems == null || block.listItems!.isEmpty) return null;
        final isOrdered = block.type == HtmlBlockType.orderedList;
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: List.generate(block.listItems!.length, (idx) {
              final itemSpans = block.listItems![idx];
              final bulletStr = isOrdered ? '${idx + 1}. ' : '• ';
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      bulletStr,
                      style: pw.TextStyle(
                        fontSize: baseSize,
                        fontWeight: pw.FontWeight.bold,
                        color: pw_pdf.PdfColors.blueGrey800,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.RichText(
                        text: _buildPdfTextSpan(itemSpans, defaultFontSize: baseSize),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      case HtmlBlockType.table:
        if (block.tableRows == null || block.tableRows!.isEmpty) return null;
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Table(
            border: enableTableBorders.value
                ? pw.TableBorder.all(color: pw_pdf.PdfColors.grey300, width: 0.6)
                : null,
            children: List.generate(block.tableRows!.length, (rIdx) {
              final rowCells = block.tableRows![rIdx];
              final isHeader = rIdx == 0;
              return pw.TableRow(
                decoration: isHeader
                    ? const pw.BoxDecoration(color: pw_pdf.PdfColors.grey100)
                    : (rIdx % 2 == 1
                        ? const pw.BoxDecoration(color: pw_pdf.PdfColors.grey50)
                        : null),
                children: List.generate(rowCells.length, (cIdx) {
                  final spans = rowCells[cIdx];
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: pw.RichText(
                      text: _buildPdfTextSpan(
                        spans,
                        defaultFontSize: baseSize - 1.0,
                        defaultBold: isHeader,
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        );
      case HtmlBlockType.horizontalRule:
        return pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 10),
          child: pw.Divider(color: pw_pdf.PdfColors.grey300, thickness: 0.8),
        );
      case HtmlBlockType.image:
        if (!renderImages.value || block.imageBytes == null) {
          return null;
        }
        try {
          return pw.Center(
            child: pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 8),
              constraints: const pw.BoxConstraints(maxHeight: 250),
              child: pw.Image(
                pw.MemoryImage(block.imageBytes!),
                fit: pw.BoxFit.contain,
              ),
            ),
          );
        } catch (e) {
          log('[HtmlToPdf] render image widget error: $e');
          return null;
        }
      case HtmlBlockType.pageBreak:
        return pw.Container();
    }
  }

  pw.InlineSpan _buildPdfTextSpan(
    List<HtmlInlineSpan> spans, {
    required double defaultFontSize,
    bool defaultBold = false,
    bool defaultItalic = false,
  }) {
    if (spans.isEmpty) {
      return const pw.TextSpan(text: '');
    }

    final children = <pw.InlineSpan>[];

    for (final s in spans) {
      final isBold = s.isBold || defaultBold;
      final isItalic = s.isItalic || defaultItalic;

      pw.FontWeight weight = isBold ? pw.FontWeight.bold : pw.FontWeight.normal;
      pw.FontStyle style = isItalic ? pw.FontStyle.italic : pw.FontStyle.normal;

      pw.TextStyle textStyle = pw.TextStyle(
        fontSize: s.fontSize ?? defaultFontSize,
        fontWeight: weight,
        fontStyle: style,
        color: s.textColor ?? pw_pdf.PdfColors.blueGrey900,
        background: s.backgroundColor != null
            ? pw.BoxDecoration(color: s.backgroundColor)
            : null,
      );

      if (s.linkUrl != null && s.linkUrl!.isNotEmpty) {
        // Link wrapper
        children.add(
          pw.WidgetSpan(
            child: pw.UrlLink(
              destination: s.linkUrl!,
              child: pw.Text(
                s.text,
                style: textStyle.copyWith(
                  color: pw_pdf.PdfColors.blue700,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
          ),
        );
      } else {
        children.add(pw.TextSpan(
          text: s.text,
          style: textStyle,
        ));
      }
    }

    return pw.TextSpan(children: children);
  }

  // ── Share Converted PDF ───────────────────────────────────────────────────

  Future<void> shareConvertedPdf() async {
    final path = convertedPdfPath.value;
    if (path == null || !File(path).existsSync()) {
      MyDialogs.error(msg: 'No converted PDF available to share.');
      return;
    }

    try {
      await Share.shareXFiles(
        [XFile(path, mimeType: 'application/pdf')],
        text: 'Converted HTML to PDF using Translator Ably',
      );
    } catch (e) {
      log('[HtmlToPdf] share error: $e');
      MyDialogs.error(msg: 'Could not share PDF: $e');
    }
  }

  // ── Formatting Helpers ────────────────────────────────────────────────────

  String get formattedFileSize {
    final bytes = selectedFileSize.value;
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedConvertedSize {
    final bytes = convertedPdfSize.value;
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

// ── Sample Templates for Quick User Testing ─────────────────────────────────

enum HtmlSampleTemplate {
  modernInvoice(
    'Modern Invoice',
    '''<!DOCTYPE html>
<html>
<head>
  <title>Invoice #INV-2026-089</title>
</head>
<body style="font-family: sans-serif; color: #1e293b;">
  <h1 style="color: #e44d26;">INVOICE</h1>
  <p><strong>Invoice Number:</strong> #INV-2026-089<br/>
     <strong>Date:</strong> October 14, 2026<br/>
     <strong>Due Date:</strong> October 28, 2026</p>
  <hr/>
  <h3>Billed To:</h3>
  <p><strong>Acme Technologies Ltd.</strong><br/>
     42 Silicon Avenue, Tech Park<br/>
     Bangalore, KA 560100<br/>
     Email: billing@acmetech.io</p>
  <table border="1" cellpadding="8" style="width: 100%; border-collapse: collapse; margin-top: 16px;">
    <thead>
      <tr style="background-color: #f1f5f9;">
        <th>Description</th>
        <th>Hours / Qty</th>
        <th>Rate</th>
        <th>Total</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>Mobile App Development (Flutter Native)</td>
        <td>40 hrs</td>
        <td>\$65.00</td>
        <td>\$2,600.00</td>
      </tr>
      <tr>
        <td>Cloud Architecture & API Integration</td>
        <td>20 hrs</td>
        <td>\$80.00</td>
        <td>\$1,600.00</td>
      </tr>
      <tr>
        <td>Automated Testing & QA Verification</td>
        <td>15 hrs</td>
        <td>\$50.00</td>
        <td>\$750.00</td>
      </tr>
    </tbody>
  </table>
  <br/>
  <blockquote style="background-color: #f8fafc; border-left: 4px solid #e44d26; padding: 10px;">
    <strong>Payment Terms:</strong> Please settle within 14 days via bank transfer or credit card. Thank you for your business!
  </blockquote>
  <p style="text-align: right;"><strong>Subtotal:</strong> \$4,950.00<br/>
     <strong>Tax (10%):</strong> \$495.00<br/>
     <span style="font-size: 16px; color: #e44d26;"><strong>Grand Total: \$5,445.00</strong></span></p>
</body>
</html>''',
  ),
  resume(
    'Professional CV / Resume',
    '''<!DOCTYPE html>
<html>
<head>
  <title>Alex Rivera - Senior Mobile Engineer</title>
</head>
<body style="font-family: sans-serif;">
  <h1 style="color: #2563eb; margin-bottom: 2px;">ALEX RIVERA</h1>
  <p><strong>Senior Mobile Engineer & Flutter Architect</strong><br/>
     Email: alex.rivera@devmail.com | Phone: +1 (555) 234-5678 | GitHub: github.com/alexrivera</p>
  <hr/>
  <h2>Summary</h2>
  <p>Passionate software engineer with 6+ years of experience engineering high-performance cross-platform mobile solutions in Flutter & Dart. Specialized in offline-first architectures, low-latency rendering, and reactive state management.</p>
  <h2>Technical Proficiencies</h2>
  <ul>
    <li><strong>Core Languages:</strong> Dart, Kotlin, Swift, Python, TypeScript</li>
    <li><strong>Frameworks:</strong> Flutter, GetX, BLoC, Riverpod, Node.js</li>
    <li><strong>Data & Storage:</strong> SQLite, Hive, Drift, Firebase Firestore</li>
    <li><strong>Tools:</strong> Git, Docker, GitHub Actions CI/CD, Fastlane</li>
  </ul>
  <h2>Professional Experience</h2>
  <h3>Lead Flutter Developer • CloudScale Solutions (2023 - Present)</h3>
  <ul>
    <li>Spearheaded mobile engineering for enterprise document management app with over 500k active users.</li>
    <li>Reduced PDF rendering latency by 45% using native bindings and isolate worker threads.</li>
    <li>Mentored a squad of 8 junior and mid-level mobile developers.</li>
  </ul>
  <h3>Mobile App Developer • NextGen Apps (2020 - 2023)</h3>
  <ul>
    <li>Built and published 6 production apps across iOS App Store and Google Play Store.</li>
    <li>Integrated secure payment processing, offline OCR scan, and live audio processing.</li>
  </ul>
  <hr/>
  <h2>Education</h2>
  <p><strong>Bachelor of Science in Computer Science</strong> — Stanford University (2016 - 2020)</p>
</body>
</html>''',
  ),
  articleReport(
    'Research Report',
    '''<!DOCTYPE html>
<html>
<head>
  <title>Quarterly Technology & AI Trends Report</title>
</head>
<body>
  <h1 style="color: #0f172a;">Executive Brief: Applied AI in Mobile Ecosystems</h1>
  <p><em>Prepared by Industry Research Group • Published October 2026</em></p>
  <hr/>
  <h2>1. Introduction & Executive Summary</h2>
  <p>The convergence of on-device neural processing units (NPUs) and compact large language models (LLMs) has fundamentally transformed the landscape of consumer productivity applications. Rather than relying on cloud latency, modern devices now perform document parsing, OCR recognition, and real-time translation locally.</p>
  <blockquote>
    "Edge intelligence eliminates network latency, guarantees end-user privacy, and delivers continuous offline reliability across critical workflows."
  </blockquote>
  <h2>2. Key Observations</h2>
  <ul>
    <li><strong>On-Device OCR:</strong> Processing speed has increased 3.8x over the last 24 months.</li>
    <li><strong>Data Privacy:</strong> 84% of surveyed enterprise customers prioritize offline document processing over cloud APIs.</li>
    <li><strong>Energy Efficiency:</strong> Modern quantized inference requires 62% less battery drain compared to previous generation models.</li>
  </ul>
  <h2>3. Performance Benchmark Summary</h2>
  <table border="1" cellpadding="6">
    <thead>
      <tr style="background-color: #f1f5f9;">
        <th>Architecture</th>
        <th>Throughput (Tokens/s)</th>
        <th>RAM Usage (MB)</th>
        <th>Latency (ms)</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>Quantized Edge Core</td>
        <td>48.2</td>
        <td>180 MB</td>
        <td>22 ms</td>
      </tr>
      <tr>
        <td>Hybrid Local Pipeline</td>
        <td>36.5</td>
        <td>240 MB</td>
        <td>38 ms</td>
      </tr>
      <tr>
        <td>Cloud API Fallback</td>
        <td>18.0</td>
        <td>45 MB</td>
        <td>410 ms</td>
      </tr>
    </tbody>
  </table>
  <br/>
  <h2>4. Conclusion</h2>
  <p>Developers who invest in robust client-side processing pipelines will command competitive advantage in latency, user satisfaction, and operating cost structure.</p>
</body>
</html>''',
  );

  final String name;
  final String markup;
  const HtmlSampleTemplate(this.name, this.markup);
}
