// lib/controllers/pdf_to_word_controller.dart
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:share_plus/share_plus.dart';

import '../ads/ad_helper.dart';

enum _BlockType { heading, bullet, tabular, body }

class _ParsedBlock {
  final _BlockType type;
  final String text;
  final String? rightText;

  _ParsedBlock({
    required this.type,
    required this.text,
    this.rightText,
  });
}

class PdfToWordController extends GetxController {
  final selectedPdfPath = RxnString();
  final selectedPdfName = RxnString();
  final fileSizeInBytes = 0.obs;
  final pageCount = 0.obs;

  final isPicking = false.obs;
  final isConverting = false.obs;
  final conversionProgress = 0.0.obs;
  final statusMessage = 'Ready'.obs;

  // Formatting mode: Smart Flow (reconstructed paragraphs & headings) vs Exact lines
  final isSmartFlow = true.obs;

  final convertedFilePath = RxnString();
  final convertedFileSize = 0.obs;
  final extractedSampleText = RxnString();

  String get formattedFileSize {
    final bytes = fileSizeInBytes.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedConvertedSize {
    final bytes = convertedFileSize.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Pick PDF File ─────────────────────────────────────────────────────────
  Future<void> pickPdfFile() async {
    try {
      isPicking.value = true;
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isEmpty) return;

      final path = result.first.path;
      if (path == null) return;

      await loadPdf(path, fileName: result.first.name);
    } catch (e) {
      log('[PdfToWord] pickPdfFile error: $e');
      Get.snackbar(
        'Error',
        'Failed to select PDF: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> loadPdf(String path, {String? fileName}) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        Get.snackbar('Error', 'File does not exist',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      selectedPdfPath.value = path;
      selectedPdfName.value =
          fileName ?? path.split(Platform.pathSeparator).last;
      fileSizeInBytes.value = await file.length();
      convertedFilePath.value = null;
      convertedFileSize.value = 0;
      extractedSampleText.value = null;

      // Get page count using pdfx
      try {
        final doc = await PdfDocument.openFile(path);
        pageCount.value = doc.pagesCount;
        await doc.close();
      } catch (e) {
        log('[PdfToWord] PdfDocument pageCount error: $e');
        try {
          pageCount.value = await ReadPdfText.getPDFlength(path);
        } catch (_) {
          pageCount.value = 1;
        }
      }
    } catch (e) {
      log('[PdfToWord] loadPdf error: $e');
      Get.snackbar(
        'Error',
        'Could not load PDF: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  // ── Execute PDF to Word (.docx) Conversion ────────────────────────────────
  Future<String?> convertPdfToWord() async {
    final pdfPath = selectedPdfPath.value;
    if (pdfPath == null || !File(pdfPath).existsSync()) {
      Get.snackbar('Error', 'Please select a valid PDF first');
      return null;
    }

    try {
      isConverting.value = true;
      conversionProgress.value = 0.15;
      statusMessage.value = 'Extracting text and layout from PDF...';

      // 1. Extract text page by page
      List<String> pagesText = [];
      try {
        pagesText = await ReadPdfText.getPDFtextPaginated(pdfPath);
      } catch (e) {
        log('[PdfToWord] paginated extraction failed, trying single text: $e');
      }

      if (pagesText.isEmpty) {
        final singleText = await ReadPdfText.getPDFtext(pdfPath);
        if (singleText.trim().isNotEmpty) {
          pagesText = [singleText];
        }
      }

      conversionProgress.value = 0.55;
      statusMessage.value = 'Reconstructing document layout & typography...';

      // Sample preview for UI
      if (pagesText.isNotEmpty) {
        final preview = pagesText.first.trim();
        extractedSampleText.value = preview.length > 200
            ? '${preview.substring(0, 200)}...'
            : preview;
      }

      // If PDF has no text at all (e.g. pure scanned photos)
      if (pagesText.isEmpty || pagesText.every((p) => p.trim().isEmpty)) {
        pagesText = [
          'Document contains scanned images or no extractable text layer.\n'
              'Source: ${selectedPdfName.value}'
        ];
      }

      // 2. Generate DOCX package bytes using Smart Flow or Raw layout
      final docxBytes = _buildDocxArchive(
        pagesText,
        title: selectedPdfName.value ?? 'Document',
        smartFlow: isSmartFlow.value,
      );

      conversionProgress.value = 0.85;
      statusMessage.value = 'Saving Word file...';

      // 3. Save to output directory
      final tempDir = await getTemporaryDirectory();
      final baseName =
          (selectedPdfName.value ?? 'document').replaceAll('.pdf', '');
      final outputPath = '${tempDir.path}/${baseName}_converted.docx';

      final outFile = File(outputPath);
      await outFile.writeAsBytes(docxBytes, flush: true);

      conversionProgress.value = 1.0;
      statusMessage.value = 'Conversion Complete!';

      convertedFilePath.value = outputPath;
      convertedFileSize.value = await outFile.length();
      AdHelper.showInterstitialAd(onComplete: () {});

      return outputPath;
    } catch (e) {
      log('[PdfToWord] convertPdfToWord error: $e');
      Get.snackbar(
        'Conversion Failed',
        'Could not convert PDF to Word: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return null;
    } finally {
      isConverting.value = false;
    }
  }

  // ── OpenXML DOCX Package Builder ──────────────────────────────────────────
  List<int> _buildDocxArchive(
    List<String> pagesText, {
    required String title,
    required bool smartFlow,
  }) {
    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypes =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n'
        '  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n'
        '  <Default Extension="xml" ContentType="application/xml"/>\n'
        '  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>\n'
        '</Types>';
    final contentTypesBytes = utf8.encode(contentTypes);
    archive.addFile(ArchiveFile(
        '[Content_Types].xml', contentTypesBytes.length, contentTypesBytes));

    // 2. _rels/.rels
    const rootRels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>\n'
        '</Relationships>';
    final rootRelsBytes = utf8.encode(rootRels);
    archive.addFile(
        ArchiveFile('_rels/.rels', rootRelsBytes.length, rootRelsBytes));

    // 3. word/document.xml
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write(
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">\n');
    buffer.write('<w:body>\n');

    for (int p = 0; p < pagesText.length; p++) {
      final pageContent = pagesText[p];

      if (smartFlow) {
        // Smart Flow: Reconstruct paragraphs, headings, bullets, and table columns
        final blocks = _parsePageIntoSmartBlocks(pageContent);
        for (final block in blocks) {
          _writeBlockToXml(buffer, block);
        }
      } else {
        // Exact line-by-line fallback
        final lines = pageContent.split('\n');
        for (final rawLine in lines) {
          final line = rawLine.trimRight();
          final safeText = _xmlEscape(line);
          buffer.write('<w:p>');
          if (safeText.isNotEmpty) {
            buffer.write(
                '<w:pPr><w:spacing w:line="240" w:lineRule="auto" w:after="0"/></w:pPr>');
            buffer.write(
                '<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/><w:color w:val="222222"/></w:rPr><w:t xml:space="preserve">$safeText</w:t></w:r>');
          }
          buffer.write('</w:p>\n');
        }
      }

      // Add page break between pages
      if (p < pagesText.length - 1) {
        buffer.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>\n');
      }
    }

    // Standard Section page margins (1 inch = 1440 twips, A4/Letter size)
    buffer.write('<w:sectPr>');
    buffer.write('<w:pgSz w:w="12240" w:h="15840"/>');
    buffer.write(
        '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>');
    buffer.write('</w:sectPr>\n');

    buffer.write('</w:body>\n');
    buffer.write('</w:document>');

    final docBytes = utf8.encode(buffer.toString());
    archive
        .addFile(ArchiveFile('word/document.xml', docBytes.length, docBytes));

    final zipEncoder = ZipEncoder();
    return zipEncoder.encode(archive);
  }

  // ── Smart Layout Parsing ──────────────────────────────────────────────────
  List<_ParsedBlock> _parsePageIntoSmartBlocks(String pageText) {
    final rawLines = pageText.split('\n');
    final blocks = <_ParsedBlock>[];

    _ParsedBlock? currentBlock;

    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i].trim();

      if (line.isEmpty) {
        if (currentBlock != null) {
          blocks.add(currentBlock);
          currentBlock = null;
        }
        continue;
      }

      final isBullet = _isBulletLine(line);
      final isHeading = _isHeadingLine(line);
      final tabSplit = _checkTabularSplit(line);

      if (isHeading) {
        if (currentBlock != null) blocks.add(currentBlock);
        blocks.add(_ParsedBlock(type: _BlockType.heading, text: line));
        currentBlock = null;
      } else if (tabSplit != null) {
        // Tabular aligned line (e.g. Job Title on left, Dates on right)
        if (currentBlock != null) blocks.add(currentBlock);
        blocks.add(_ParsedBlock(
          type: _BlockType.tabular,
          text: tabSplit[0],
          rightText: tabSplit[1],
        ));
        currentBlock = null;
      } else if (isBullet) {
        if (currentBlock != null) blocks.add(currentBlock);
        currentBlock = _ParsedBlock(type: _BlockType.bullet, text: line);
      } else {
        // Normal text line
        if (currentBlock != null && currentBlock.type == _BlockType.body) {
          // Merge continuation into body paragraph
          final merged = _mergeContinuation(currentBlock.text, line);
          currentBlock = _ParsedBlock(type: _BlockType.body, text: merged);
        } else if (currentBlock != null &&
            currentBlock.type == _BlockType.bullet) {
          // Merge continuation into bullet point
          final merged = _mergeContinuation(currentBlock.text, line);
          currentBlock = _ParsedBlock(type: _BlockType.bullet, text: merged);
        } else {
          currentBlock = _ParsedBlock(type: _BlockType.body, text: line);
        }
      }
    }

    if (currentBlock != null) {
      blocks.add(currentBlock);
    }

    return blocks;
  }

  bool _isBulletLine(String line) {
    if (line.startsWith('•') ||
        line.startsWith('-') ||
        line.startsWith('*') ||
        line.startsWith('▪') ||
        line.startsWith('▶') ||
        line.startsWith('○') ||
        line.startsWith('●')) {
      return true;
    }
    // E.g. "1. ", "2) ", "A. ", "a) "
    if (RegExp(r'^\d+[\.\)]\s+').hasMatch(line) ||
        RegExp(r'^[a-zA-Z][\.\)]\s+').hasMatch(line)) {
      return true;
    }
    return false;
  }

  bool _isHeadingLine(String line) {
    if (line.length > 55 || line.length < 2) return false;
    if (line.endsWith('.') || line.endsWith(';') || line.endsWith(',')) {
      return false;
    }
    if (_isBulletLine(line)) return false;

    // Check if line is ALL CAPS (common for headings e.g. EDUCATION, WORK EXPERIENCE)
    final letters = line.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (letters.length >= 3 && letters == letters.toUpperCase()) {
      return true;
    }

    // Common section keywords
    final lower = line.toLowerCase();
    const commonHeaders = [
      'summary',
      'experience',
      'work experience',
      'education',
      'skills',
      'technical skills',
      'projects',
      'certifications',
      'achievements',
      'contact',
      'personal details',
      'languages',
      'interests',
      'references',
      'profile'
    ];
    if (commonHeaders.contains(lower)) return true;

    return false;
  }

  List<String>? _checkTabularSplit(String line) {
    // If line has 3 or more spaces separating two substantial chunks of text
    final match = RegExp(r'^(.{2,})\s{3,}(.{2,})$').firstMatch(line);
    if (match != null) {
      final left = match.group(1)?.trim();
      final right = match.group(2)?.trim();
      if (left != null && right != null && left.isNotEmpty && right.isNotEmpty) {
        return [left, right];
      }
    }
    return null;
  }

  String _mergeContinuation(String prev, String next) {
    if (prev.endsWith('-')) {
      // De-hyphenate broken word across line break
      return '${prev.substring(0, prev.length - 1)}$next';
    }
    return '$prev $next';
  }

  void _writeBlockToXml(StringBuffer buffer, _ParsedBlock block) {
    switch (block.type) {
      case _BlockType.heading:
        final safeText = _xmlEscape(block.text);
        buffer.write('<w:p>');
        buffer.write(
            '<w:pPr><w:spacing w:before="240" w:after="80"/><w:jc w:val="left"/></w:pPr>');
        buffer.write(
            '<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:b/><w:sz w:val="28"/><w:color w:val="2B579A"/></w:rPr><w:t xml:space="preserve">$safeText</w:t></w:r>');
        buffer.write('</w:p>\n');
        break;

      case _BlockType.bullet:
        final safeText = _xmlEscape(block.text);
        buffer.write('<w:p>');
        buffer.write(
            '<w:pPr><w:ind w:left="420" w:hanging="260"/><w:spacing w:after="70" w:line="250" w:lineRule="auto"/></w:pPr>');
        buffer.write(
            '<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/><w:color w:val="222222"/></w:rPr><w:t xml:space="preserve">$safeText</w:t></w:r>');
        buffer.write('</w:p>\n');
        break;

      case _BlockType.tabular:
        final safeLeft = _xmlEscape(block.text);
        final safeRight = _xmlEscape(block.rightText ?? '');
        buffer.write('<w:p>');
        buffer.write('<w:pPr>');
        buffer.write('<w:tabs><w:tab w:val="right" w:pos="9360"/></w:tabs>');
        buffer.write('<w:spacing w:after="80" w:line="250" w:lineRule="auto"/>');
        buffer.write('</w:pPr>');
        // Left text (bold)
        buffer.write(
            '<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:b/><w:sz w:val="22"/><w:color w:val="1E2238"/></w:rPr><w:t xml:space="preserve">$safeLeft</w:t></w:r>');
        // Tab + Right text (secondary)
        buffer.write(
            '<w:r><w:tab/><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/><w:color w:val="666666"/></w:rPr><w:t xml:space="preserve">$safeRight</w:t></w:r>');
        buffer.write('</w:p>\n');
        break;

      case _BlockType.body:
        final safeText = _xmlEscape(block.text);
        buffer.write('<w:p>');
        buffer.write(
            '<w:pPr><w:spacing w:after="120" w:line="260" w:lineRule="auto"/></w:pPr>');
        buffer.write(
            '<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/><w:color w:val="222222"/></w:rPr><w:t xml:space="preserve">$safeText</w:t></w:r>');
        buffer.write('</w:p>\n');
        break;
    }
  }

  String _xmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  // ── Share Result ──────────────────────────────────────────────────────────
  Future<void> shareResult() async {
    final path = convertedFilePath.value;
    if (path == null || !File(path).existsSync()) return;

    try {
      final xfile = XFile(path);
      await Share.shareXFiles([xfile], text: 'Converted Word Document');
    } catch (e) {
      log('[PdfToWord] shareResult error: $e');
      Get.snackbar('Error', 'Failed to share: $e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void reset() {
    selectedPdfPath.value = null;
    selectedPdfName.value = null;
    fileSizeInBytes.value = 0;
    pageCount.value = 0;
    convertedFilePath.value = null;
    convertedFileSize.value = 0;
    extractedSampleText.value = null;
    conversionProgress.value = 0.0;
  }
}
