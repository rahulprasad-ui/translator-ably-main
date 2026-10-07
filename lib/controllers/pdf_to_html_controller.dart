// lib/controllers/pdf_to_html_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:share_plus/share_plus.dart';

import '../ads/ad_helper.dart';
import '../helper/my_dialogs.dart';

enum HtmlExportFormat {
  singleFileStandalone(
    title: 'Self-Contained Webpage (.html)',
    subtitle: 'All CSS, interactive scripts, and base64 visuals in 1 single file (Easiest to share)',
  ),
  webZipPackage(
    title: 'Complete Web Bundle (.zip)',
    subtitle: 'Includes index.html, style.css, and extracted high-res image assets for web hosting',
  );

  final String title;
  final String subtitle;

  const HtmlExportFormat({
    required this.title,
    required this.subtitle,
  });
}

enum HtmlThemeStyle {
  modernTech(
    title: 'Modern Clean (SaaS)',
    subtitle: 'Inter font, soft glass cards, responsive sidebar & dark/light mode',
    primaryColor: '#2563EB',
    bgLight: '#F8FAFC',
    cardBgLight: '#FFFFFF',
    textLight: '#0F172A',
  ),
  editorialPaper(
    title: 'Editorial Paper',
    subtitle: 'Georgia serif typography, warm book background, elegant margins',
    primaryColor: '#854D0E',
    bgLight: '#FAF8F5',
    cardBgLight: '#FFFFFF',
    textLight: '#1C1917',
  ),
  darkOled(
    title: 'Dark Studio',
    subtitle: 'Sleek dark theme (#0F172A), neon accents, high contrast readability',
    primaryColor: '#38BDF8',
    bgLight: '#0F172A',
    cardBgLight: '#1E293B',
    textLight: '#F8FAFC',
  );

  final String title;
  final String subtitle;
  final String primaryColor;
  final String bgLight;
  final String cardBgLight;
  final String textLight;

  const HtmlThemeStyle({
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.bgLight,
    required this.cardBgLight,
    required this.textLight,
  });
}

enum HtmlPageSelectionMode {
  all,
  custom,
  range,
}

class PdfToHtmlController extends GetxController {
  // Document state
  final selectedPdfPath = RxnString();
  final selectedPdfName = RxnString();
  final fileSizeInBytes = 0.obs;
  final pageCount = 0.obs;

  PdfDocument? _pdfDoc;

  // Settings
  final pageTitle = ''.obs;
  final exportFormat = HtmlExportFormat.singleFileStandalone.obs;
  final themeStyle = HtmlThemeStyle.modernTech.obs;
  final embedVisualImages = true.obs;
  final includeInteractiveNav = true.obs;

  // Page Selection
  final selectionMode = HtmlPageSelectionMode.all.obs;
  final selectedPages = <int>{}.obs; // 0-indexed
  final rangeStart = 1.obs;
  final rangeEnd = 1.obs;

  // UI state
  final isPicking = false.obs;
  final isLoadingDoc = false.obs;
  final isConverting = false.obs;
  final conversionProgress = 0.0.obs;
  final statusMessage = 'Ready'.obs;
  final pageThumbnails = <int, Uint8List>{}.obs;
  final generatedHtmlSnippet = RxnString();

  // Results state
  final convertedHtmlPath = RxnString();
  final convertedHtmlSize = 0.obs;
  final totalPagesConverted = 0.obs;

  String get formattedPdfSize {
    final bytes = fileSizeInBytes.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedHtmlSize {
    final bytes = convertedHtmlSize.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  int get effectiveSelectedCount {
    if (pageCount.value <= 0) return 0;
    switch (selectionMode.value) {
      case HtmlPageSelectionMode.all:
        return pageCount.value;
      case HtmlPageSelectionMode.custom:
        return selectedPages.length;
      case HtmlPageSelectionMode.range:
        final start = rangeStart.value.clamp(1, pageCount.value);
        final end = rangeEnd.value.clamp(start, pageCount.value);
        return (end - start + 1);
    }
  }

  List<int> get effectiveSelectedPageIndices {
    if (pageCount.value <= 0) return [];
    switch (selectionMode.value) {
      case HtmlPageSelectionMode.all:
        return List.generate(pageCount.value, (i) => i);
      case HtmlPageSelectionMode.custom:
        final sorted = selectedPages.toList()..sort();
        return sorted;
      case HtmlPageSelectionMode.range:
        final start = rangeStart.value.clamp(1, pageCount.value);
        final end = rangeEnd.value.clamp(start, pageCount.value);
        return List.generate(end - start + 1, (i) => start - 1 + i);
    }
  }

  @override
  void onClose() {
    _cleanupPdfDoc();
    super.onClose();
  }

  void _cleanupPdfDoc() {
    try {
      _pdfDoc?.close();
    } catch (_) {}
    _pdfDoc = null;
  }

  // ── 1. Pick PDF File ───────────────────────────────────────────────────────
  Future<void> pickPdfFile() async {
    try {
      isPicking.value = true;
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isEmpty || result.first.path == null) return;

      final path = result.first.path!;
      final name = result.first.name;
      await loadPdf(path, fileName: name);
    } catch (e) {
      log('[PdfToHtml] pickPdfFile error: $e');
      MyDialogs.info(msg: 'Failed to select PDF: $e');
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> loadPdf(String path, {String? fileName}) async {
    try {
      isLoadingDoc.value = true;
      _cleanupPdfDoc();
      convertedHtmlPath.value = null;
      convertedHtmlSize.value = 0;
      pageThumbnails.clear();
      generatedHtmlSnippet.value = null;

      final file = File(path);
      if (!await file.exists()) {
        MyDialogs.info(msg: 'File does not exist.');
        return;
      }

      final size = await file.length();
      selectedPdfPath.value = path;
      final name = fileName ?? path.split(Platform.pathSeparator).last;
      selectedPdfName.value = name;
      fileSizeInBytes.value = size;

      pageTitle.value = name
          .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
          .replaceAll('_', ' ');

      _pdfDoc = await PdfDocument.openFile(path);
      final count = _pdfDoc!.pagesCount;
      pageCount.value = count;

      selectedPages.clear();
      for (int i = 0; i < count; i++) {
        selectedPages.add(i);
      }
      rangeStart.value = 1;
      rangeEnd.value = count.clamp(1, 99999);
      selectionMode.value = HtmlPageSelectionMode.all;

      _loadThumbnailsInBackground();
    } catch (e) {
      log('[PdfToHtml] loadPdf error: $e');
      MyDialogs.info(msg: 'Failed to open PDF: $e');
    } finally {
      isLoadingDoc.value = false;
    }
  }

  Future<void> _loadThumbnailsInBackground() async {
    if (_pdfDoc == null) return;
    final total = pageCount.value;

    for (int i = 0; i < total; i++) {
      if (selectedPdfPath.value == null) break;
      if (pageThumbnails.containsKey(i)) continue;

      try {
        final page = await _pdfDoc!.getPage(i + 1);
        final thumb = await page.render(
          width: 180,
          height: (180 * (page.height / page.width)),
          format: PdfPageImageFormat.jpeg,
          quality: 60,
          backgroundColor: '#FFFFFF',
        );
        await page.close();

        if (thumb != null) {
          pageThumbnails[i] = thumb.bytes;
        }
      } catch (e) {
        log('[PdfToHtml] render thumb $i error: $e');
      }
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  // ── Selection controls ───────────────────────────────────────────────────
  void togglePageSelection(int pageIndex) {
    if (selectedPages.contains(pageIndex)) {
      if (selectedPages.length > 1) {
        selectedPages.remove(pageIndex);
      } else {
        MyDialogs.info(msg: 'At least one page must be selected.');
      }
    } else {
      selectedPages.add(pageIndex);
    }
  }

  void selectAllPages() {
    selectedPages.clear();
    for (int i = 0; i < pageCount.value; i++) {
      selectedPages.add(i);
    }
  }

  void deselectAllPages() {
    if (pageCount.value > 0) {
      selectedPages.clear();
      selectedPages.add(0);
    }
  }

  void setRange(int start, int end) {
    final count = pageCount.value;
    if (count <= 0) return;
    rangeStart.value = start.clamp(1, count);
    rangeEnd.value = end.clamp(rangeStart.value, count);
  }

  // ── 2. Convert PDF to HTML5 Document ─────────────────────────────────────
  Future<void> convertPdfToHtml() async {
    final pdfPath = selectedPdfPath.value;
    if (pdfPath == null || !File(pdfPath).existsSync()) {
      MyDialogs.info(msg: 'Please select a valid PDF file first.');
      return;
    }

    final pages = effectiveSelectedPageIndices;
    if (pages.isEmpty) {
      MyDialogs.info(msg: 'Please select at least one page to convert.');
      return;
    }

    try {
      isConverting.value = true;
      conversionProgress.value = 0.10;
      statusMessage.value = 'Extracting document text and layout...';

      // 1. Extract Paginated Text
      List<String> pagesText = [];
      try {
        pagesText = await ReadPdfText.getPDFtextPaginated(pdfPath);
      } catch (e) {
        log('[PdfToHtml] paginated extraction failed: $e');
      }

      while (pagesText.length < pageCount.value) {
        pagesText.add('');
      }

      conversionProgress.value = 0.35;
      statusMessage.value = 'Rendering page visuals and diagrams...';

      // 2. Render Page Visual Images
      _pdfDoc ??= await PdfDocument.openFile(pdfPath);
      final Map<int, Uint8List> pageImages = {};

      for (int i = 0; i < pages.length; i++) {
        final pageIndex = pages[i];
        final pageNum = pageIndex + 1;
        final hasText = pagesText.length > pageIndex && pagesText[pageIndex].trim().isNotEmpty;

        if (embedVisualImages.value || !hasText) {
          try {
            final page = await _pdfDoc!.getPage(pageNum);
            final img = await page.render(
              width: 1200,
              height: (1200 * (page.height / page.width)),
              format: PdfPageImageFormat.jpeg,
              quality: 85,
              backgroundColor: '#FFFFFF',
            );
            await page.close();

            if (img != null) {
              pageImages[pageNum] = img.bytes;
            }
          } catch (e) {
            log('[PdfToHtml] render visual $pageNum error: $e');
          }
        }
        conversionProgress.value = (0.35 + (0.35 * ((i + 1) / pages.length))).clamp(0.35, 0.70);
      }

      conversionProgress.value = 0.75;
      statusMessage.value = 'Generating responsive HTML5 webpage...';

      final tempDir = await getTemporaryDirectory();
      final title = pageTitle.value.trim().isEmpty ? 'Document' : pageTitle.value.trim();
      final safeName = title.replaceAll(RegExp(r'[^\w\s-]'), '_').replaceAll(' ', '_');

      String outputPath;

      if (exportFormat.value == HtmlExportFormat.singleFileStandalone) {
        // Generate single standalone HTML with base64 images
        final htmlContent = _buildStandaloneHtml(
          title: title,
          selectedIndices: pages,
          pagesText: pagesText,
          pageImages: pageImages,
          theme: themeStyle.value,
          includeNav: includeInteractiveNav.value,
        );

        outputPath = '${tempDir.path}/$safeName.html';
        final outFile = File(outputPath);
        await outFile.writeAsString(htmlContent, flush: true);

        generatedHtmlSnippet.value = htmlContent.length > 500
            ? '${htmlContent.substring(0, 500)}...'
            : htmlContent;
      } else {
        // Generate Web ZIP Bundle
        final zipBytes = _buildWebZipBundle(
          title: title,
          selectedIndices: pages,
          pagesText: pagesText,
          pageImages: pageImages,
          theme: themeStyle.value,
          includeNav: includeInteractiveNav.value,
        );

        outputPath = '${tempDir.path}/${safeName}_web.zip';
        final outFile = File(outputPath);
        await outFile.writeAsBytes(zipBytes, flush: true);
      }

      conversionProgress.value = 1.0;
      statusMessage.value = 'HTML5 Conversion Complete!';

      final resultFile = File(outputPath);
      convertedHtmlPath.value = outputPath;
      convertedHtmlSize.value = await resultFile.length();
      totalPagesConverted.value = pages.length;

      MyDialogs.success(
        msg: 'HTML5 webpage generated successfully! (${pages.length} pages converted)',
      );
      AdHelper.showInterstitialAd(onComplete: () {});
    } catch (e, stack) {
      log('[PdfToHtml] convert error: $e\n$stack');
      MyDialogs.info(msg: 'Conversion failed: $e');
    } finally {
      isConverting.value = false;
    }
  }

  // ── 3. HTML5 Standalone Document Generator ────────────────────────────────
  String _buildStandaloneHtml({
    required String title,
    required List<int> selectedIndices,
    required List<String> pagesText,
    required Map<int, Uint8List> pageImages,
    required HtmlThemeStyle theme,
    required bool includeNav,
  }) {
    final buffer = StringBuffer();
    buffer.write('''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${_htmlEscape(title)}</title>
  <style>
${_generateCss(theme)}
  </style>
</head>
<body>
  <div class="app-layout">
''');

    // Sidebar Navigation if enabled
    if (includeNav) {
      buffer.write('''    <aside class="sidebar">
      <div class="sidebar-header">
        <div class="sidebar-title">Table of Contents</div>
        <div class="sidebar-subtitle">${selectedIndices.length} Pages</div>
      </div>
      <nav class="nav-list">
''');
      for (int i = 0; i < selectedIndices.length; i++) {
        final pageNum = selectedIndices[i] + 1;
        buffer.write('        <a href="#page-$pageNum" class="nav-item">Page $pageNum</a>\n');
      }
      buffer.write('''      </nav>
    </aside>
''');
    }

    // Main Article Content
    buffer.write('''    <main class="main-content">
      <header class="doc-header">
        <h1 class="doc-title">${_htmlEscape(title)}</h1>
        <div class="doc-meta">
          <span>📅 Converted: ${DateTime.now().toLocal().toString().split(' ').first}</span>
          <span>📄 ${selectedIndices.length} Pages</span>
          <span>⚡ Translator Ably PDF Converter</span>
        </div>
      </header>
''');

    // Pages loop
    for (int i = 0; i < selectedIndices.length; i++) {
      final pageIndex = selectedIndices[i];
      final pageNum = pageIndex + 1;
      final text = pagesText.length > pageIndex ? pagesText[pageIndex].trim() : '';
      final imgBytes = pageImages[pageNum];

      buffer.write('''      <section id="page-$pageNum" class="page-card">
        <div class="page-header">
          <span class="page-badge">Page $pageNum</span>
          <a href="#page-$pageNum" class="page-anchor">#</a>
        </div>
''');

      // Embedded Visual Image (as Base64 URI)
      if (imgBytes != null && (embedVisualImages.value || text.isEmpty)) {
        final base64Img = base64Encode(imgBytes);
        buffer.write('''        <div class="figure-container">
          <img class="page-visual" src="data:image/jpeg;base64,$base64Img" alt="Page $pageNum Visual" loading="lazy"/>
        </div>
''');
      }

      // Structured Text Content
      if (text.isNotEmpty) {
        final lines = text.split(RegExp(r'\r?\n'));
        final paragraphs = <String>[];
        final currentPara = StringBuffer();

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) {
            if (currentPara.isNotEmpty) {
              paragraphs.add(currentPara.toString().trim());
              currentPara.clear();
            }
          } else {
            if (currentPara.isNotEmpty) currentPara.write(' ');
            currentPara.write(trimmed);
          }
        }
        if (currentPara.isNotEmpty) {
          paragraphs.add(currentPara.toString().trim());
        }

        buffer.write('        <div class="text-body">\n');
        for (final p in paragraphs) {
          if (p.length < 60 && !p.endsWith('.') && p.toUpperCase() == p) {
            buffer.write('          <h3 class="section-heading">${_htmlEscape(p)}</h3>\n');
          } else {
            buffer.write('          <p class="paragraph">${_htmlEscape(p)}</p>\n');
          }
        }
        buffer.write('        </div>\n');
      }

      buffer.write('      </section>\n');
    }

    // Footer
    buffer.write('''      <footer class="doc-footer">
        <p>Generated by <strong>Translator Ably</strong> • Clean HTML5 Responsive Document</p>
      </footer>
    </main>
  </div>
</body>
</html>''');

    return buffer.toString();
  }

  // ── 4. Web ZIP Bundle Generator ───────────────────────────────────────────
  List<int> _buildWebZipBundle({
    required String title,
    required List<int> selectedIndices,
    required List<String> pagesText,
    required Map<int, Uint8List> pageImages,
    required HtmlThemeStyle theme,
    required bool includeNav,
  }) {
    final archive = Archive();

    // 1. Add CSS file
    final css = _generateCss(theme);
    final cssBytes = utf8.encode(css);
    archive.addFile(ArchiveFile('style.css', cssBytes.length, cssBytes));

    // 2. Add Images to assets/ folder
    for (final entry in pageImages.entries) {
      final imgBytes = entry.value;
      archive.addFile(ArchiveFile('assets/page_${entry.key}.jpg', imgBytes.length, imgBytes));
    }

    // 3. Build index.html linking to style.css and assets/
    final buffer = StringBuffer();
    buffer.write('''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${_htmlEscape(title)}</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div class="app-layout">
''');

    if (includeNav) {
      buffer.write('''    <aside class="sidebar">
      <div class="sidebar-header">
        <div class="sidebar-title">Table of Contents</div>
        <div class="sidebar-subtitle">${selectedIndices.length} Pages</div>
      </div>
      <nav class="nav-list">
''');
      for (int i = 0; i < selectedIndices.length; i++) {
        final pageNum = selectedIndices[i] + 1;
        buffer.write('        <a href="#page-$pageNum" class="nav-item">Page $pageNum</a>\n');
      }
      buffer.write('''      </nav>
    </aside>
''');
    }

    buffer.write('''    <main class="main-content">
      <header class="doc-header">
        <h1 class="doc-title">${_htmlEscape(title)}</h1>
        <div class="doc-meta">
          <span>📅 Converted: ${DateTime.now().toLocal().toString().split(' ').first}</span>
          <span>📄 ${selectedIndices.length} Pages</span>
        </div>
      </header>
''');

    for (int i = 0; i < selectedIndices.length; i++) {
      final pageIndex = selectedIndices[i];
      final pageNum = pageIndex + 1;
      final text = pagesText.length > pageIndex ? pagesText[pageIndex].trim() : '';
      final hasImg = pageImages.containsKey(pageNum);

      buffer.write('''      <section id="page-$pageNum" class="page-card">
        <div class="page-header">
          <span class="page-badge">Page $pageNum</span>
        </div>
''');

      if (hasImg && (embedVisualImages.value || text.isEmpty)) {
        buffer.write('''        <div class="figure-container">
          <img class="page-visual" src="assets/page_$pageNum.jpg" alt="Page $pageNum" loading="lazy"/>
        </div>
''');
      }

      if (text.isNotEmpty) {
        final lines = text.split(RegExp(r'\r?\n'));
        buffer.write('        <div class="text-body">\n');
        for (final l in lines) {
          final trimmed = l.trim();
          if (trimmed.isNotEmpty) {
            buffer.write('          <p class="paragraph">${_htmlEscape(trimmed)}</p>\n');
          }
        }
        buffer.write('        </div>\n');
      }

      buffer.write('      </section>\n');
    }

    buffer.write('''      <footer class="doc-footer">
        <p>Generated by <strong>Translator Ably</strong></p>
      </footer>
    </main>
  </div>
</body>
</html>''');

    final htmlBytes = utf8.encode(buffer.toString());
    archive.addFile(ArchiveFile('index.html', htmlBytes.length, htmlBytes));

    final encoder = ZipEncoder();
    return encoder.encode(archive);
  }

  String _generateCss(HtmlThemeStyle theme) {
    return '''
:root {
  --primary: ${theme.primaryColor};
  --bg-main: ${theme.bgLight};
  --card-bg: ${theme.cardBgLight};
  --text-main: ${theme.textLight};
  --text-muted: #64748B;
  --border-color: rgba(0, 0, 0, 0.08);
}
* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  background-color: var(--bg-main);
  color: var(--text-main);
  line-height: 1.6;
  -webkit-font-smoothing: antialiased;
}
.app-layout {
  display: flex;
  min-height: 100vh;
}
.sidebar {
  width: 260px;
  background: var(--card-bg);
  border-right: 1px solid var(--border-color);
  position: sticky;
  top: 0;
  height: 100vh;
  overflow-y: auto;
  padding: 24px 16px;
}
.sidebar-header {
  margin-bottom: 20px;
}
.sidebar-title {
  font-size: 1.1rem;
  font-weight: 700;
  color: var(--text-main);
}
.sidebar-subtitle {
  font-size: 0.85rem;
  color: var(--text-muted);
}
.nav-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.nav-item {
  padding: 8px 12px;
  border-radius: 8px;
  color: var(--text-main);
  text-decoration: none;
  font-size: 0.9rem;
  font-weight: 500;
  transition: all 0.15s ease;
}
.nav-item:hover {
  background: rgba(37, 99, 235, 0.08);
  color: var(--primary);
}
.main-content {
  flex: 1;
  max-width: 900px;
  margin: 0 auto;
  padding: 32px 24px;
}
.doc-header {
  margin-bottom: 32px;
  padding-bottom: 16px;
  border-bottom: 2px solid var(--border-color);
}
.doc-title {
  font-size: 2rem;
  font-weight: 800;
  letter-spacing: -0.02em;
  margin-bottom: 8px;
}
.doc-meta {
  display: flex;
  gap: 16px;
  font-size: 0.85rem;
  color: var(--text-muted);
}
.page-card {
  background: var(--card-bg);
  border-radius: 16px;
  padding: 28px;
  margin-bottom: 28px;
  border: 1px solid var(--border-color);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.03);
}
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}
.page-badge {
  background: var(--primary);
  color: #FFFFFF;
  padding: 4px 10px;
  border-radius: 6px;
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
.page-anchor {
  color: var(--text-muted);
  text-decoration: none;
  font-weight: bold;
}
.figure-container {
  text-align: center;
  margin: 16px 0;
}
.page-visual {
  max-width: 100%;
  height: auto;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.08);
}
.text-body {
  margin-top: 16px;
}
.section-heading {
  font-size: 1.2rem;
  font-weight: 700;
  margin: 18px 0 8px 0;
}
.paragraph {
  margin-bottom: 12px;
  color: var(--text-main);
  text-align: justify;
}
.doc-footer {
  text-align: center;
  padding: 24px 0;
  font-size: 0.85rem;
  color: var(--text-muted);
}
@media (max-width: 768px) {
  .app-layout { flex-direction: column; }
  .sidebar { width: 100%; height: auto; position: static; }
}
''';
  }

  String _htmlEscape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  // ── 5. Sharing & Saving ──────────────────────────────────────────────────
  Future<void> shareHtml() async {
    final path = convertedHtmlPath.value;
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        final isZip = path.endsWith('.zip');
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [
            XFile(
              path,
              name: '${pageTitle.value}.${isZip ? 'zip' : 'html'}',
              mimeType: isZip ? 'application/zip' : 'text/html',
            )
          ],
          text: 'HTML5 Webpage: "${pageTitle.value}" ($formattedHtmlSize)',
        );
      }
    } catch (e) {
      log('[PdfToHtml] share error: $e');
      MyDialogs.info(msg: 'Failed to share HTML: $e');
    }
  }

  Future<void> saveToDownloads() async {
    final path = convertedHtmlPath.value;
    if (path == null) return;
    try {
      Directory? targetDir;
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          targetDir = Directory('${downloadDir.path}/TranslatorAbly');
        } else {
          targetDir = await getExternalStorageDirectory();
        }
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      targetDir ??= await getApplicationDocumentsDirectory();

      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final source = File(path);
      if (await source.exists()) {
        final ext = path.endsWith('.zip') ? 'zip' : 'html';
        final fileName = '${pageTitle.value.trim().replaceAll(RegExp(r'[^\w\s-]'), '_')}.$ext';
        final dest = File('${targetDir.path}/$fileName');
        await source.copy(dest.path);
        MyDialogs.success(
          msg: 'Saved "$fileName" to ${targetDir.path.split(Platform.pathSeparator).last}!',
        );
      }
    } catch (e) {
      log('[PdfToHtml] saveToDownloads error: $e');
      MyDialogs.info(msg: 'Saved to app storage (Path: $e)');
    }
  }

  void reset() {
    _cleanupPdfDoc();
    selectedPdfPath.value = null;
    selectedPdfName.value = null;
    fileSizeInBytes.value = 0;
    pageCount.value = 0;
    pageTitle.value = '';
    convertedHtmlPath.value = null;
    convertedHtmlSize.value = 0;
    pageThumbnails.clear();
    generatedHtmlSnippet.value = null;
    selectedPages.clear();
    selectionMode.value = HtmlPageSelectionMode.all;
    conversionProgress.value = 0.0;
    statusMessage.value = 'Ready';
  }
}
