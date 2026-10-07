// lib/controllers/word_to_pdf_controller.dart
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

import '../helper/my_dialogs.dart';

// ── Word Document Data Structures ───────────────────────────────────────────

enum WordBlockType {
  title,
  heading1,
  heading2,
  heading3,
  paragraph,
  bullet,
  table,
  pageBreak,
}

class WordRun {
  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrike;
  final double? fontSize;
  final Color? color;

  WordRun({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrike = false,
    this.fontSize,
    this.color,
  });
}

class WordBlock {
  final WordBlockType type;
  final List<WordRun> runs;
  final String alignment; // 'left', 'center', 'right', 'justify'
  final List<List<String>>? tableData;
  final int bulletLevel;

  WordBlock({
    required this.type,
    this.runs = const [],
    this.alignment = 'left',
    this.tableData,
    this.bulletLevel = 0,
  });

  String get fullText {
    if (tableData != null) {
      return tableData!.map((row) => row.join(' | ')).join('\n');
    }
    return runs.map((r) => r.text).join();
  }
}

// ── Conversion Settings Enums ───────────────────────────────────────────────

enum PdfPageSizeOption {
  a4('A4', 'Standard international (210 × 297 mm)', pw_pdf.PdfPageFormat.a4),
  letter('US Letter', 'Standard US format (8.5 × 11 in)', pw_pdf.PdfPageFormat.letter),
  legal('US Legal', 'Extended legal format (8.5 × 14 in)', pw_pdf.PdfPageFormat.legal);

  final String title;
  final String subtitle;
  final pw_pdf.PdfPageFormat format;
  const PdfPageSizeOption(this.title, this.subtitle, this.format);
}

enum PdfMarginOption {
  normal('Normal', '20 mm (Balanced padding)', 54.0),
  narrow('Narrow', '10 mm (More content per page)', 28.0),
  wide('Wide', '28 mm (Spacious editorial margins)', 72.0);

  final String title;
  final String subtitle;
  final double marginPoints;
  const PdfMarginOption(this.title, this.subtitle, this.marginPoints);
}

enum PdfFontOption {
  modernSans('Modern Sans', 'Crisp & clean Helvetica typography'),
  classicSerif('Classic Serif', 'Editorial & traditional Times typography'),
  monospace('Monospace', 'Technical & typewriter Courier style');

  final String title;
  final String subtitle;
  const PdfFontOption(this.title, this.subtitle);
}

// ── Controller Implementation ───────────────────────────────────────────────

class WordToPdfController extends GetxController {
  // Source Word file state
  final selectedDocPath = RxnString();
  final selectedDocName = RxnString();
  final fileSizeInBytes = 0.obs;
  final isDocxFormat = true.obs;

  // Document metadata extracted from Word file
  final parsedBlocks = <WordBlock>[].obs;
  final wordCount = 0.obs;
  final paragraphCount = 0.obs;
  final tableCount = 0.obs;
  final extractedSampleText = RxnString();

  // Settings
  final selectedPageSize = PdfPageSizeOption.a4.obs;
  final selectedMargin = PdfMarginOption.normal.obs;
  final selectedFont = PdfFontOption.modernSans.obs;
  final includeHeader = true.obs;
  final includeFooter = true.obs;
  final accentColorValue = 0xFF2B579A.obs; // Microsoft Word Blue

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

  // ── 1. Pick Word File (.docx, .doc) ───────────────────────────────────────
  Future<void> pickWordFile() async {
    try {
      isPicking.value = true;
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx', 'doc'],
      );

      if (result.isEmpty) return;
      final path = result.first.path;
      if (path == null) return;

      await loadWordFile(path, fileName: result.first.name);
    } catch (e) {
      log('[WordToPdf] pickWordFile error: $e');
      MyDialogs.info(msg: 'Failed to pick Word file: $e');
    } finally {
      isPicking.value = false;
    }
  }

  // ── 2. Load and Parse Word File ───────────────────────────────────────────
  Future<void> loadWordFile(String path, {String? fileName}) async {
    try {
      isParsing.value = true;
      statusMessage.value = 'Reading document...';
      final file = File(path);
      if (!await file.exists()) {
        MyDialogs.info(msg: 'Selected file does not exist');
        return;
      }

      selectedDocPath.value = path;
      selectedDocName.value =
          fileName ?? path.split(Platform.pathSeparator).last;
      fileSizeInBytes.value = await file.length();

      // Reset previous results
      convertedPdfPath.value = null;
      convertedPdfSize.value = 0;
      convertedPageCount.value = 0;
      previewThumbnailBytes.value = null;

      final isDocx = selectedDocName.value!.toLowerCase().endsWith('.docx');
      isDocxFormat.value = isDocx;

      final bytes = await file.readAsBytes();
      List<WordBlock> blocks = [];

      if (isDocx) {
        blocks = await _parseDocxBytes(bytes);
      } else {
        blocks = await _parseLegacyDocBytes(bytes);
      }

      if (blocks.isEmpty) {
        // Fallback: create single paragraph if empty
        blocks = [
          WordBlock(
            type: WordBlockType.paragraph,
            runs: [WordRun(text: 'Empty or unreadable document content.')],
          )
        ];
      }

      parsedBlocks.value = blocks;

      // Calculate statistics
      int words = 0;
      int paragraphs = 0;
      int tables = 0;
      final previewBuffer = StringBuffer();

      for (final b in blocks) {
        if (b.type == WordBlockType.table) {
          tables++;
        } else {
          paragraphs++;
          final text = b.fullText;
          if (text.isNotEmpty) {
            words += text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
            if (previewBuffer.length < 900) {
              previewBuffer.writeln(text);
            }
          }
        }
      }

      wordCount.value = words;
      paragraphCount.value = paragraphs;
      tableCount.value = tables;
      extractedSampleText.value = previewBuffer.toString().trim();
      statusMessage.value = 'Ready to convert';
    } catch (e) {
      log('[WordToPdf] loadWordFile error: $e');
      MyDialogs.info(msg: 'Failed to read Word file: $e');
    } finally {
      isParsing.value = false;
    }
  }

  // ── 3. Parse .docx XML Structure ──────────────────────────────────────────
  Future<List<WordBlock>> _parseDocxBytes(Uint8List bytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final docFile = archive.findFile('word/document.xml');

      if (docFile == null) {
        return _parseLegacyDocBytes(bytes);
      }

      final xmlContent = utf8.decode(docFile.content as List<int>, allowMalformed: true);
      return _parseDocumentXml(xmlContent);
    } catch (e) {
      log('[WordToPdf] _parseDocxBytes error, falling back to legacy: $e');
      return _parseLegacyDocBytes(bytes);
    }
  }

  List<WordBlock> _parseDocumentXml(String xml) {
    final blocks = <WordBlock>[];

    // Find the body tag
    final bodyStart = xml.indexOf('<w:body');
    final bodyEnd = xml.lastIndexOf('</w:body>');
    final bodyContent = (bodyStart != -1 && bodyEnd != -1)
        ? xml.substring(bodyStart, bodyEnd + 9)
        : xml;

    // Regex to match paragraphs and tables sequentially
    final elementRegex = RegExp(r'(<w:p[\s>].*?<\/w:p>|<w:tbl[\s>].*?<\/w:tbl>)', dotAll: true);
    final matches = elementRegex.allMatches(bodyContent);

    for (final match in matches) {
      final elemXml = match.group(0)!;
      if (elemXml.startsWith('<w:tbl')) {
        final tableBlock = _parseTableXml(elemXml);
        if (tableBlock != null) blocks.add(tableBlock);
      } else if (elemXml.startsWith('<w:p')) {
        final pBlock = _parseParagraphXml(elemXml);
        if (pBlock != null) blocks.add(pBlock);
      }
    }

    return blocks;
  }

  WordBlock? _parseParagraphXml(String pXml) {
    // Check for page break
    if (pXml.contains('w:type="page"') || pXml.contains('<w:lastRenderedPageBreak/>')) {
      return WordBlock(type: WordBlockType.pageBreak);
    }

    // Paragraph Style
    WordBlockType type = WordBlockType.paragraph;
    final styleMatch = RegExp(r'<w:pStyle\s+w:val="([^"]+)"').firstMatch(pXml);
    if (styleMatch != null) {
      final styleVal = styleMatch.group(1)!.toLowerCase();
      if (styleVal.contains('title')) {
        type = WordBlockType.title;
      } else if (styleVal.contains('heading1') || styleVal.contains('heading 1')) {
        type = WordBlockType.heading1;
      } else if (styleVal.contains('heading2') || styleVal.contains('heading 2')) {
        type = WordBlockType.heading2;
      } else if (styleVal.contains('heading3') || styleVal.contains('heading 3')) {
        type = WordBlockType.heading3;
      } else if (styleVal.contains('bullet') || styleVal.contains('list')) {
        type = WordBlockType.bullet;
      }
    }

    // Numbering / Bullet properties
    int bulletLevel = 0;
    if (pXml.contains('<w:numPr>')) {
      type = WordBlockType.bullet;
      final ilvlMatch = RegExp(r'<w:ilvl\s+w:val="(\d+)"').firstMatch(pXml);
      if (ilvlMatch != null) {
        bulletLevel = int.tryParse(ilvlMatch.group(1)!) ?? 0;
      }
    }

    // Alignment
    String alignment = 'left';
    final jcMatch = RegExp(r'<w:jc\s+w:val="([^"]+)"').firstMatch(pXml);
    if (jcMatch != null) {
      alignment = jcMatch.group(1)!.toLowerCase();
    }

    // Parse runs
    final runs = <WordRun>[];
    final runRegex = RegExp(r'<w:r[\s>].*?<\/w:r>', dotAll: true);
    final runMatches = runRegex.allMatches(pXml);

    for (final rMatch in runMatches) {
      final rXml = rMatch.group(0)!;
      final run = _parseRunXml(rXml);
      if (run != null && run.text.isNotEmpty) {
        runs.add(run);
      }
    }

    // If no runs or empty text, check for plain text or ignore empty
    if (runs.isEmpty) {
      return null;
    }

    final combinedText = runs.map((r) => r.text).join().trim();
    if (combinedText.isEmpty) return null;

    // Automatic heading detection fallback if not tagged
    if (type == WordBlockType.paragraph) {
      if (runs.length == 1 && runs.first.isBold && combinedText.length < 50 && !combinedText.endsWith('.')) {
        type = WordBlockType.heading2;
      } else if (combinedText.startsWith('•') || combinedText.startsWith('-') || RegExp(r'^\d+[\.\)]\s').hasMatch(combinedText)) {
        type = WordBlockType.bullet;
      }
    }

    return WordBlock(
      type: type,
      runs: runs,
      alignment: alignment,
      bulletLevel: bulletLevel,
    );
  }

  WordRun? _parseRunXml(String rXml) {
    // Check formatting flags
    final isBold = rXml.contains('<w:b/>') || rXml.contains('w:b w:val="1"') || rXml.contains('w:b w:val="true"');
    final isItalic = rXml.contains('<w:i/>') || rXml.contains('w:i w:val="1"') || rXml.contains('w:i w:val="true"');
    final isUnderline = rXml.contains('<w:u ') || rXml.contains('<w:u/>');
    final isStrike = rXml.contains('<w:strike/>') || rXml.contains('<w:strike ');

    // Font size in half-points (24 = 12pt)
    double? fontSize;
    final szMatch = RegExp(r'<w:sz\s+w:val="(\d+)"').firstMatch(rXml);
    if (szMatch != null) {
      final halfPoints = int.tryParse(szMatch.group(1)!);
      if (halfPoints != null) {
        fontSize = halfPoints / 2.0;
      }
    }

    // Color
    Color? color;
    final colorMatch = RegExp(r'<w:color\s+w:val="([0-9a-fA-F]{6})"').firstMatch(rXml);
    if (colorMatch != null) {
      final hex = colorMatch.group(1)!;
      final intVal = int.tryParse('FF$hex', radix: 16);
      if (intVal != null) {
        color = Color(intVal);
      }
    }

    // Extract text
    final textBuffer = StringBuffer();
    final tRegex = RegExp(r'<w:t[^>]*>(.*?)<\/w:t>', dotAll: true);
    for (final tMatch in tRegex.allMatches(rXml)) {
      textBuffer.write(_xmlUnescape(tMatch.group(1)!));
    }

    // Handle line breaks within run
    if (rXml.contains('<w:br/>')) {
      textBuffer.write('\n');
    }
    if (rXml.contains('<w:tab/>')) {
      textBuffer.write('    ');
    }

    final rawText = textBuffer.toString();
    if (rawText.isEmpty) return null;

    return WordRun(
      text: rawText,
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      isStrike: isStrike,
      fontSize: fontSize,
      color: color,
    );
  }

  WordBlock? _parseTableXml(String tblXml) {
    final rows = <List<String>>[];
    final trRegex = RegExp(r'<w:tr[\s>].*?<\/w:tr>', dotAll: true);
    final trMatches = trRegex.allMatches(tblXml);

    for (final trMatch in trMatches) {
      final trXml = trMatch.group(0)!;
      final cells = <String>[];
      final tcRegex = RegExp(r'<w:tc[\s>].*?<\/w:tc>', dotAll: true);
      final tcMatches = tcRegex.allMatches(trXml);

      for (final tcMatch in tcMatches) {
        final tcXml = tcMatch.group(0)!;
        final cellTextBuffer = StringBuffer();
        final tRegex = RegExp(r'<w:t[^>]*>(.*?)<\/w:t>', dotAll: true);
        for (final tMatch in tRegex.allMatches(tcXml)) {
          cellTextBuffer.write(_xmlUnescape(tMatch.group(1)!));
          cellTextBuffer.write(' ');
        }
        cells.add(cellTextBuffer.toString().trim());
      }

      if (cells.isNotEmpty && cells.any((c) => c.isNotEmpty)) {
        rows.add(cells);
      }
    }

    if (rows.isEmpty) return null;

    // Normalize column counts across rows
    int maxCols = 0;
    for (final r in rows) {
      if (r.length > maxCols) maxCols = r.length;
    }
    for (int i = 0; i < rows.length; i++) {
      while (rows[i].length < maxCols) {
        rows[i].add('');
      }
    }

    return WordBlock(
      type: WordBlockType.table,
      tableData: rows,
    );
  }

  // ── 4. Fallback Parser for Legacy .doc / Plain Streams ─────────────────────
  Future<List<WordBlock>> _parseLegacyDocBytes(Uint8List bytes) async {
    final blocks = <WordBlock>[];
    try {
      // Extract printable UTF-8 or ASCII string runs
      final sb = StringBuffer();
      for (int i = 0; i < bytes.length; i++) {
        final b = bytes[i];
        // Printable ASCII or newline / tab
        if ((b >= 32 && b <= 126) || b == 10 || b == 13 || b == 9) {
          sb.writeCharCode(b);
        } else if (b == 0 && sb.isNotEmpty && !sb.toString().endsWith(' ')) {
          sb.write(' ');
        }
      }

      final rawText = sb.toString();
      final lines = rawText.split(RegExp(r'\r?\n'));

      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.length < 2) continue;
        // Ignore binary junk lines with no alphabet
        if (!RegExp(r'[a-zA-Z0-9]').hasMatch(line)) continue;

        if (_isHeading(line)) {
          blocks.add(WordBlock(
            type: WordBlockType.heading2,
            runs: [WordRun(text: line, isBold: true)],
          ));
        } else if (line.startsWith('•') || line.startsWith('-') || RegExp(r'^\d+[\.\)]\s').hasMatch(line)) {
          blocks.add(WordBlock(
            type: WordBlockType.bullet,
            runs: [WordRun(text: line)],
          ));
        } else {
          blocks.add(WordBlock(
            type: WordBlockType.paragraph,
            runs: [WordRun(text: line)],
          ));
        }
      }
    } catch (e) {
      log('[WordToPdf] _parseLegacyDocBytes error: $e');
    }
    return blocks;
  }

  bool _isHeading(String line) {
    if (line.length < 3 || line.length > 60) return false;
    if (line.endsWith('.') || line.endsWith(';') || line.endsWith(',')) return false;
    final lettersOnly = line.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (lettersOnly.length >= 3 && lettersOnly == lettersOnly.toUpperCase()) return true;
    const commonHeaders = [
      'table of contents',
      'introduction',
      'summary',
      'executive summary',
      'background',
      'scope',
      'methodology',
      'results',
      'discussion',
      'conclusion',
      'recommendations',
      'references',
      'appendix',
      'experience',
      'education',
      'skills'
    ];
    return commonHeaders.contains(line.toLowerCase());
  }

  String _xmlUnescape(String text) {
    return text
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
        .replaceAll('&#8212;', '—');
  }

  // ── 5. Convert Word to PDF ────────────────────────────────────────────────
  Future<String?> convertToPdf() async {
    if (selectedDocPath.value == null || parsedBlocks.isEmpty) {
      MyDialogs.info(msg: 'Please select a valid Word document first');
      return null;
    }

    try {
      isConverting.value = true;
      conversionProgress.value = 0.15;
      statusMessage.value = 'Preparing PDF layout...';

      final pdfDoc = pw.Document(
        title: selectedDocName.value ?? 'Word Document',
        author: 'Translator Ably',
        creator: 'Word to PDF Converter',
      );

      final format = selectedPageSize.value.format;
      final marginPts = selectedMargin.value.marginPoints;

      // Select PDF fonts
      pw.Font bodyFont;
      pw.Font boldFont;
      pw.Font italicFont;
      pw.Font boldItalicFont;

      switch (selectedFont.value) {
        case PdfFontOption.modernSans:
          bodyFont = pw.Font.helvetica();
          boldFont = pw.Font.helveticaBold();
          italicFont = pw.Font.helveticaOblique();
          boldItalicFont = pw.Font.helveticaBoldOblique();
          break;
        case PdfFontOption.classicSerif:
          bodyFont = pw.Font.times();
          boldFont = pw.Font.timesBold();
          italicFont = pw.Font.timesItalic();
          boldItalicFont = pw.Font.timesBoldItalic();
          break;
        case PdfFontOption.monospace:
          bodyFont = pw.Font.courier();
          boldFont = pw.Font.courierBold();
          italicFont = pw.Font.courierOblique();
          boldItalicFont = pw.Font.courierBoldOblique();
          break;
      }

      final accentPdfColor = pw_pdf.PdfColor.fromInt(accentColorValue.value);

      conversionProgress.value = 0.40;
      statusMessage.value = 'Formatting blocks & tables...';

      final widgetsList = <pw.Widget>[];

      for (int i = 0; i < parsedBlocks.length; i++) {
        final block = parsedBlocks[i];

        switch (block.type) {
          case WordBlockType.pageBreak:
            // Insert explicit page break
            widgetsList.add(pw.NewPage());
            break;

          case WordBlockType.title:
            final textSpans = _buildSpans(block.runs, bodyFont, boldFont, italicFont, boldItalicFont, 22.0);
            widgetsList.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 10, bottom: 12),
                child: pw.Column(
                  crossAxisAlignment: _getPwCrossAlign(block.alignment),
                  children: [
                    pw.RichText(
                      textAlign: _getPwTextAlign(block.alignment),
                      text: pw.TextSpan(children: textSpans),
                    ),
                    pw.Container(
                      margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
                      height: 2.0,
                      color: accentPdfColor,
                    ),
                  ],
                ),
              ),
            );
            break;

          case WordBlockType.heading1:
            final textSpans = _buildSpans(block.runs, bodyFont, boldFont, italicFont, boldItalicFont, 16.0, defaultBold: true);
            widgetsList.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
                child: pw.Column(
                  crossAxisAlignment: _getPwCrossAlign(block.alignment),
                  children: [
                    pw.RichText(
                      textAlign: _getPwTextAlign(block.alignment),
                      text: pw.TextSpan(children: textSpans),
                    ),
                    pw.Container(
                      margin: const pw.EdgeInsets.only(top: 4),
                      height: 1.2,
                      color: const pw_pdf.PdfColor.fromInt(0xFFCBD5E1),
                    ),
                  ],
                ),
              ),
            );
            break;

          case WordBlockType.heading2:
            final textSpans = _buildSpans(block.runs, bodyFont, boldFont, italicFont, boldItalicFont, 13.5, defaultBold: true);
            widgetsList.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
                child: pw.RichText(
                  textAlign: _getPwTextAlign(block.alignment),
                  text: pw.TextSpan(children: textSpans),
                ),
              ),
            );
            break;

          case WordBlockType.heading3:
            final textSpans = _buildSpans(block.runs, bodyFont, boldFont, italicFont, boldItalicFont, 11.5, defaultBold: true);
            widgetsList.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8, bottom: 3),
                child: pw.RichText(
                  textAlign: _getPwTextAlign(block.alignment),
                  text: pw.TextSpan(children: textSpans),
                ),
              ),
            );
            break;

          case WordBlockType.bullet:
            final textSpans = _buildSpans(block.runs, bodyFont, boldFont, italicFont, boldItalicFont, 10.0);
            final indent = 12.0 + (block.bulletLevel * 14.0);
            widgetsList.add(
              pw.Padding(
                padding: pw.EdgeInsets.only(left: indent, bottom: 3.5),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2, right: 6),
                      child: pw.Container(
                        width: 4,
                        height: 4,
                        decoration: pw.BoxDecoration(
                          color: accentPdfColor,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.RichText(
                        textAlign: _getPwTextAlign(block.alignment),
                        text: pw.TextSpan(children: textSpans),
                      ),
                    ),
                  ],
                ),
              ),
            );
            break;

          case WordBlockType.table:
            if (block.tableData != null && block.tableData!.isNotEmpty) {
              final headerRow = block.tableData!.first;
              final dataRows = block.tableData!.length > 1
                  ? block.tableData!.sublist(1)
                  : <List<String>>[];

              widgetsList.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8),
                  child: pw.TableHelper.fromTextArray(
                    border: pw.TableBorder.all(
                      color: pw_pdf.PdfColors.grey300,
                      width: 0.6,
                    ),
                    headers: headerRow,
                    data: dataRows,
                    headerStyle: pw.TextStyle(
                      font: boldFont,
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: pw_pdf.PdfColors.white,
                    ),
                    headerDecoration: pw.BoxDecoration(
                      color: accentPdfColor,
                    ),
                    cellStyle: pw.TextStyle(
                      font: bodyFont,
                      fontSize: 8.0,
                      color: pw_pdf.PdfColors.black,
                    ),
                    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                    rowDecoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: pw_pdf.PdfColors.grey200, width: 0.5),
                      ),
                    ),
                    oddRowDecoration: const pw.BoxDecoration(
                      color: pw_pdf.PdfColor.fromInt(0xFFF8FAFC),
                    ),
                  ),
                ),
              );
            }
            break;

          case WordBlockType.paragraph:
            final textSpans = _buildSpans(block.runs, bodyFont, boldFont, italicFont, boldItalicFont, 10.0);
            widgetsList.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5.5),
                child: pw.RichText(
                  textAlign: _getPwTextAlign(block.alignment),
                  text: pw.TextSpan(children: textSpans),
                ),
              ),
            );
            break;
        }
      }

      conversionProgress.value = 0.70;
      statusMessage.value = 'Generating PDF pages...';

      final docHeaderTitle = selectedDocName.value ?? 'Word Document';

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
                border: pw.Border(
                  bottom: pw.BorderSide(color: pw_pdf.PdfColors.grey300, width: 0.6),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    docHeaderTitle,
                    style: pw.TextStyle(
                      fontSize: 8.0,
                      color: pw_pdf.PdfColors.grey600,
                      font: bodyFont,
                    ),
                  ),
                  pw.Text(
                    'Word to PDF',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      color: pw_pdf.PdfColors.grey400,
                      font: bodyFont,
                    ),
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
                border: pw.Border(
                  top: pw.BorderSide(color: pw_pdf.PdfColors.grey300, width: 0.6),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: pw.TextStyle(
                      fontSize: 8.0,
                      color: pw_pdf.PdfColors.grey600,
                      font: bodyFont,
                    ),
                  ),
                  pw.Text(
                    'Converted with Translator Ably',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      color: pw_pdf.PdfColors.grey400,
                      font: bodyFont,
                    ),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context ctx) => widgetsList,
        ),
      );

      conversionProgress.value = 0.88;
      statusMessage.value = 'Writing PDF file...';

      final outputBytes = await pdfDoc.save();
      final tempDir = await getTemporaryDirectory();
      final baseName = selectedDocName.value!.replaceAll(RegExp(r'\.[^.]+$'), '');
      final outputPath = '${tempDir.path}/${baseName}_converted.pdf';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(outputBytes, flush: true);

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
        log('[WordToPdf] thumbnail rendering error: $e');
        convertedPageCount.value = 1;
      }

      conversionProgress.value = 1.0;
      statusMessage.value = 'Conversion Complete!';
      MyDialogs.success(msg: 'Word converted to PDF successfully!');
      return outputPath;
    } catch (e) {
      log('[WordToPdf] convertToPdf error: $e');
      MyDialogs.info(msg: 'Conversion failed: $e');
      return null;
    } finally {
      isConverting.value = false;
    }
  }

  List<pw.InlineSpan> _buildSpans(
    List<WordRun> runs,
    pw.Font bodyFont,
    pw.Font boldFont,
    pw.Font italicFont,
    pw.Font boldItalicFont,
    double defaultSize, {
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

      final fontSize = run.fontSize != null && run.fontSize! > 6.0
          ? run.fontSize!
          : defaultSize;

      pw_pdf.PdfColor textColor = pw_pdf.PdfColors.black;
      if (run.color != null) {
        textColor = pw_pdf.PdfColor.fromInt(run.color!.value);
      }

      return pw.TextSpan(
        text: run.text,
        style: pw.TextStyle(
          font: fontToUse,
          fontSize: fontSize,
          color: textColor,
          decoration: run.isUnderline ? pw.TextDecoration.underline : pw.TextDecoration.none,
        ),
      );
    }).toList();
  }

  pw.TextAlign _getPwTextAlign(String alignment) {
    switch (alignment) {
      case 'center':
        return pw.TextAlign.center;
      case 'right':
        return pw.TextAlign.right;
      case 'both':
      case 'justify':
        return pw.TextAlign.justify;
      case 'left':
      default:
        return pw.TextAlign.left;
    }
  }

  pw.CrossAxisAlignment _getPwCrossAlign(String alignment) {
    switch (alignment) {
      case 'center':
        return pw.CrossAxisAlignment.center;
      case 'right':
        return pw.CrossAxisAlignment.end;
      default:
        return pw.CrossAxisAlignment.start;
    }
  }

  // ── 6. Share and Save ─────────────────────────────────────────────────────
  Future<void> shareConvertedPdf() async {
    final path = convertedPdfPath.value;
    if (path == null) return;
    try {
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'PDF Document: ${selectedDocName.value}',
        text: 'Converted from Word document (${selectedDocName.value})',
      );
    } catch (e) {
      log('[WordToPdf] share error: $e');
      MyDialogs.info(msg: 'Failed to share PDF: $e');
    }
  }

  void reset() {
    selectedDocPath.value = null;
    selectedDocName.value = null;
    fileSizeInBytes.value = 0;
    parsedBlocks.clear();
    wordCount.value = 0;
    paragraphCount.value = 0;
    tableCount.value = 0;
    extractedSampleText.value = null;
    convertedPdfPath.value = null;
    convertedPdfSize.value = 0;
    convertedPageCount.value = 0;
    previewThumbnailBytes.value = null;
    conversionProgress.value = 0.0;
    statusMessage.value = 'Ready';
  }
}
