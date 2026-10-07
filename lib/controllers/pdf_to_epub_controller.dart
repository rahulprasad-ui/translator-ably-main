// lib/controllers/pdf_to_epub_controller.dart
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

import '../helper/my_dialogs.dart';

enum EpubFontTheme {
  modernSerif(
    title: 'Modern Serif',
    subtitle: 'Classic book typography (Georgia, Palatino)',
    fontFamily: 'Georgia, "Palatino Linotype", "Book Antiqua", Palatino, serif',
  ),
  cleanSans(
    title: 'Clean Sans-Serif',
    subtitle: 'Modern & crisp reading (Helvetica, Arial)',
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif',
  ),
  accessible(
    title: 'High Legibility',
    subtitle: 'Larger spacing and clear contrast',
    fontFamily: '"Verdana", "Lucida Sans", "Trebuchet MS", sans-serif',
  );

  final String title;
  final String subtitle;
  final String fontFamily;

  const EpubFontTheme({
    required this.title,
    required this.subtitle,
    required this.fontFamily,
  });
}

class PdfToEpubController extends GetxController {
  // Document state
  final selectedPdfPath = RxnString();
  final selectedPdfName = RxnString();
  final fileSizeInBytes = 0.obs;
  final pageCount = 0.obs;

  // Metadata settings
  final bookTitle = ''.obs;
  final bookAuthor = 'Translator Ably'.obs;
  final bookLanguage = 'en'.obs;
  final includeCover = true.obs;
  final embedPageVisuals = false.obs;
  final fontTheme = EpubFontTheme.modernSerif.obs;

  // UI state
  final isPicking = false.obs;
  final isLoadingDoc = false.obs;
  final isConverting = false.obs;
  final conversionProgress = 0.0.obs;
  final statusMessage = 'Ready'.obs;
  final extractedSampleText = RxnString();
  final coverImageBytes = Rxn<Uint8List>();

  // Result state
  final convertedEpubPath = RxnString();
  final convertedEpubSize = 0.obs;
  final totalChapters = 0.obs;

  String get formattedPdfSize {
    final bytes = fileSizeInBytes.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedEpubSize {
    final bytes = convertedEpubSize.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
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
      log('[PdfToEpub] pickPdfFile error: $e');
      MyDialogs.info(msg: 'Failed to select PDF: $e');
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> loadPdf(String path, {String? fileName}) async {
    try {
      isLoadingDoc.value = true;
      convertedEpubPath.value = null;
      convertedEpubSize.value = 0;
      coverImageBytes.value = null;
      extractedSampleText.value = null;

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

      // Auto-title without .pdf extension
      bookTitle.value = name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '').replaceAll('_', ' ');

      // Get page count and render cover page preview
      try {
        final doc = await PdfDocument.openFile(path);
        pageCount.value = doc.pagesCount;
        if (doc.pagesCount > 0) {
          final firstPage = await doc.getPage(1);
          final cover = await firstPage.render(
            width: 320,
            height: (320 * (firstPage.height / firstPage.width)),
            format: PdfPageImageFormat.jpeg,
            quality: 75,
            backgroundColor: '#FFFFFF',
          );
          await firstPage.close();
          if (cover != null) {
            coverImageBytes.value = cover.bytes;
          }
        }
        await doc.close();
      } catch (e) {
        log('[PdfToEpub] pdfx pageCount error: $e');
        try {
          pageCount.value = await ReadPdfText.getPDFlength(path);
        } catch (_) {
          pageCount.value = 1;
        }
      }

      // Quick preview snippet
      try {
        final preview = await ReadPdfText.getPDFtext(path);
        if (preview.trim().isNotEmpty) {
          extractedSampleText.value = preview.trim().length > 250
              ? '${preview.trim().substring(0, 250)}...'
              : preview.trim();
        }
      } catch (_) {}
    } catch (e) {
      log('[PdfToEpub] loadPdf error: $e');
      MyDialogs.info(msg: 'Failed to open PDF: $e');
    } finally {
      isLoadingDoc.value = false;
    }
  }

  // ── 2. Convert PDF to EPUB E-Book ──────────────────────────────────────────
  Future<void> convertPdfToEpub() async {
    final pdfPath = selectedPdfPath.value;
    if (pdfPath == null || !File(pdfPath).existsSync()) {
      MyDialogs.info(msg: 'Please select a valid PDF file first.');
      return;
    }

    try {
      isConverting.value = true;
      conversionProgress.value = 0.1;
      statusMessage.value = 'Extracting pages & text structure...';

      // 1. Extract Paginated Text
      List<String> pagesText = [];
      try {
        pagesText = await ReadPdfText.getPDFtextPaginated(pdfPath);
      } catch (e) {
        log('[PdfToEpub] paginated extraction failed: $e');
      }

      if (pagesText.isEmpty) {
        try {
          final singleText = await ReadPdfText.getPDFtext(pdfPath);
          if (singleText.trim().isNotEmpty) {
            pagesText = [singleText];
          }
        } catch (_) {}
      }

      final count = pageCount.value > 0 ? pageCount.value : (pagesText.isNotEmpty ? pagesText.length : 1);

      // If text extraction was empty, fill placeholders
      while (pagesText.length < count) {
        pagesText.add('');
      }

      conversionProgress.value = 0.35;
      statusMessage.value = 'Rendering e-book visuals & chapters...';

      // 2. Render Page Images if embed visuals or scanned
      final Map<int, Uint8List> pageImages = {};
      PdfDocument? doc;
      try {
        doc = await PdfDocument.openFile(pdfPath);
        for (int p = 0; p < count; p++) {
          final pageNum = p + 1;
          final hasText = pagesText[p].trim().isNotEmpty;

          // If user requested visuals or if page has no text (scanned photo document)
          if (embedPageVisuals.value || !hasText || (p == 0 && includeCover.value)) {
            try {
              final page = await doc.getPage(pageNum);
              final img = await page.render(
                width: 900,
                height: (900 * (page.height / page.width)),
                format: PdfPageImageFormat.jpeg,
                quality: 80,
                backgroundColor: '#FFFFFF',
              );
              await page.close();
              if (img != null) {
                pageImages[pageNum] = img.bytes;
              }
            } catch (e) {
              log('[PdfToEpub] page render $pageNum error: $e');
            }
          }
          conversionProgress.value = (0.35 + (0.35 * ((p + 1) / count))).clamp(0.35, 0.70);
        }
      } catch (e) {
        log('[PdfToEpub] pdf doc open error: $e');
      } finally {
        await doc?.close();
      }

      conversionProgress.value = 0.75;
      statusMessage.value = 'Building EPUB 3.0 e-book archive...';

      // 3. Build Standard EPUB Package
      final epubBytes = _buildEpubArchive(
        title: bookTitle.value.trim().isEmpty ? 'E-Book' : bookTitle.value.trim(),
        author: bookAuthor.value.trim().isEmpty ? 'Author' : bookAuthor.value.trim(),
        language: bookLanguage.value.trim().isEmpty ? 'en' : bookLanguage.value.trim(),
        pagesText: pagesText,
        pageImages: pageImages,
        theme: fontTheme.value,
        hasCover: includeCover.value && pageImages.containsKey(1),
      );

      conversionProgress.value = 0.90;
      statusMessage.value = 'Saving EPUB file...';

      final tempDir = await getTemporaryDirectory();
      final safeName = (bookTitle.value.trim().isEmpty ? 'ebook' : bookTitle.value.trim())
          .replaceAll(RegExp(r'[^\w\s-]'), '_')
          .replaceAll(' ', '_');
      final outputPath = '${tempDir.path}/${safeName}_ebook.epub';

      final outFile = File(outputPath);
      await outFile.writeAsBytes(epubBytes, flush: true);

      conversionProgress.value = 1.0;
      statusMessage.value = 'EPUB Created Successfully!';

      convertedEpubPath.value = outputPath;
      convertedEpubSize.value = await outFile.length();
      totalChapters.value = count;

      MyDialogs.success(msg: 'E-Book created! Ready for Kindle, Apple Books & e-readers.');
    } catch (e, stack) {
      log('[PdfToEpub] convert error: $e\n$stack');
      MyDialogs.info(msg: 'Conversion failed: $e');
    } finally {
      isConverting.value = false;
    }
  }

  // ── 3. EPUB Package Generator ─────────────────────────────────────────────
  List<int> _buildEpubArchive({
    required String title,
    required String author,
    required String language,
    required List<String> pagesText,
    required Map<int, Uint8List> pageImages,
    required EpubFontTheme theme,
    required bool hasCover,
  }) {
    final archive = Archive();
    final bookUuid = 'urn:uuid:${DateTime.now().millisecondsSinceEpoch}-translator-ably';
    final modifiedDate = '${DateTime.now().toUtc().toIso8601String().split('.').first}Z';

    // 1. mimetype (Uncompressed, first file in ZIP)
    final mimeBytes = ascii.encode('application/epub+zip');
    final mimeFile = ArchiveFile.noCompress('mimetype', mimeBytes.length, mimeBytes);
    archive.addFile(mimeFile);

    // 2. META-INF/container.xml
    const containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
    final containerBytes = utf8.encode(containerXml);
    archive.addFile(ArchiveFile('META-INF/container.xml', containerBytes.length, containerBytes));

    // 3. OEBPS/style.css
    final css = '''
@charset "utf-8";
body {
  font-family: ${theme.fontFamily};
  font-size: 1.05em;
  line-height: 1.65;
  color: #1a1a1a;
  margin: 5% 7%;
  padding: 0;
  text-rendering: optimizeLegibility;
}
h1, h2, h3 {
  font-weight: bold;
  line-height: 1.25;
  color: #0d1b2a;
  margin-top: 1.5em;
  margin-bottom: 0.6em;
  page-break-after: avoid;
}
h1 { font-size: 1.8em; text-align: center; margin-top: 2em; }
h2 { font-size: 1.4em; border-bottom: 1px solid #e0e0e0; padding-bottom: 0.3em; }
p {
  margin: 0 0 1em 0;
  text-align: justify;
  text-indent: 1.2em;
}
p.first {
  text-indent: 0;
}
p.first::first-letter {
  font-size: 2.2em;
  float: left;
  line-height: 0.9;
  margin-right: 0.12em;
  font-weight: bold;
  color: #2b4c7e;
}
.cover-img {
  max-width: 100%;
  height: auto;
  display: block;
  margin: 0 auto;
}
.page-figure {
  margin: 1.5em 0;
  text-align: center;
}
.page-img {
  max-width: 95%;
  height: auto;
  border-radius: 4px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.15);
}
.page-number-tag {
  font-size: 0.85em;
  color: #757575;
  text-align: center;
  margin-top: 2em;
  border-top: 1px dashed #cccccc;
  padding-top: 0.5em;
}
blockquote {
  margin: 1.2em 2em;
  font-style: italic;
  color: #4a5568;
  border-left: 3px solid #2b4c7e;
  padding-left: 1em;
}
ul, ol {
  margin: 1em 0 1em 1.5em;
  padding-left: 1em;
}
li {
  margin-bottom: 0.4em;
}
''';
    final cssBytes = utf8.encode(css);
    archive.addFile(ArchiveFile('OEBPS/style.css', cssBytes.length, cssBytes));

    // 4. Save Cover & Page Images into OEBPS/images/
    for (final entry in pageImages.entries) {
      final imgBytes = entry.value;
      archive.addFile(ArchiveFile('OEBPS/images/page_${entry.key}.jpg', imgBytes.length, imgBytes));
    }

    // 5. Build Chapters (1 per page)
    final chapterFiles = <String>[];
    for (int i = 0; i < pagesText.length; i++) {
      final pageNum = i + 1;
      final text = pagesText[i].trim();
      final hasImg = pageImages.containsKey(pageNum);

      final chapterHtml = _buildChapterHtml(
        pageNum: pageNum,
        totalPages: pagesText.length,
        text: text,
        bookTitle: title,
        hasImage: hasImg,
      );

      final chapterBytes = utf8.encode(chapterHtml);
      final filename = 'chapter_$pageNum.xhtml';
      archive.addFile(ArchiveFile('OEBPS/$filename', chapterBytes.length, chapterBytes));
      chapterFiles.add(filename);
    }

    // 6. Navigation Document: OEBPS/nav.xhtml (EPUB 3)
    final navHtml = StringBuffer();
    navHtml.write('''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="$language">
<head>
  <title>Table of Contents</title>
  <link rel="stylesheet" type="text/css" href="style.css"/>
</head>
<body>
  <nav epub:type="toc" id="toc">
    <h1>Table of Contents</h1>
    <ol>
''');
    for (int i = 0; i < chapterFiles.length; i++) {
      navHtml.write('      <li><a href="${chapterFiles[i]}">Page ${i + 1}</a></li>\n');
    }
    navHtml.write('''    </ol>
  </nav>
</body>
</html>''');
    final navBytes = utf8.encode(navHtml.toString());
    archive.addFile(ArchiveFile('OEBPS/nav.xhtml', navBytes.length, navBytes));

    // 7. NCX Document: OEBPS/toc.ncx (EPUB 2 backward compatibility)
    final ncx = StringBuffer();
    ncx.write('''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="$bookUuid"/>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="${pagesText.length}"/>
    <meta name="dtb:maxPageNumber" content="${pagesText.length}"/>
  </head>
  <docTitle><text>${_xmlEscape(title)}</text></docTitle>
  <docAuthor><text>${_xmlEscape(author)}</text></docAuthor>
  <navMap>
''');
    for (int i = 0; i < chapterFiles.length; i++) {
      ncx.write('''    <navPoint id="navPoint-${i + 1}" playOrder="${i + 1}">
      <navLabel><text>Page ${i + 1}</text></navLabel>
      <content src="${chapterFiles[i]}"/>
    </navPoint>
''');
    }
    ncx.write('''  </navMap>
</ncx>''');
    final ncxBytes = utf8.encode(ncx.toString());
    archive.addFile(ArchiveFile('OEBPS/toc.ncx', ncxBytes.length, ncxBytes));

    // 8. Package Manifest & Spine: OEBPS/content.opf
    final opf = StringBuffer();
    opf.write('''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="BookId">$bookUuid</dc:identifier>
    <dc:title>${_xmlEscape(title)}</dc:title>
    <dc:creator>${_xmlEscape(author)}</dc:creator>
    <dc:language>$language</dc:language>
    <meta property="dcterms:modified">$modifiedDate</meta>
''');
    if (hasCover) {
      opf.write('    <meta name="cover" content="cover-image"/>\n');
    }
    opf.write('''  </metadata>
  <manifest>
    <item id="style" href="style.css" media-type="text/css"/>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
''');
    // Manifest images
    for (final pageNum in pageImages.keys) {
      if (pageNum == 1 && hasCover) {
        opf.write('    <item id="cover-image" href="images/page_1.jpg" media-type="image/jpeg" properties="cover-image"/>\n');
      } else {
        opf.write('    <item id="img-$pageNum" href="images/page_$pageNum.jpg" media-type="image/jpeg"/>\n');
      }
    }
    // Manifest chapters
    for (int i = 0; i < chapterFiles.length; i++) {
      opf.write('    <item id="chapter-${i + 1}" href="${chapterFiles[i]}" media-type="application/xhtml+xml"/>\n');
    }
    opf.write('''  </manifest>
  <spine toc="ncx">
''');
    for (int i = 0; i < chapterFiles.length; i++) {
      opf.write('    <itemref idref="chapter-${i + 1}"/>\n');
    }
    opf.write('''  </spine>
</package>''');

    final opfBytes = utf8.encode(opf.toString());
    archive.addFile(ArchiveFile('OEBPS/content.opf', opfBytes.length, opfBytes));

    // Encode standard EPUB ZIP archive
    final encoder = ZipEncoder();
    return encoder.encode(archive);
  }

  String _buildChapterHtml({
    required int pageNum,
    required int totalPages,
    required String text,
    required String bookTitle,
    required bool hasImage,
  }) {
    final buffer = StringBuffer();
    buffer.write('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
<head>
  <title>Page $pageNum - ${_xmlEscape(bookTitle)}</title>
  <link rel="stylesheet" type="text/css" href="style.css"/>
</head>
<body>
''');

    // Heading for Chapter / Page
    buffer.write('  <h2>Page $pageNum</h2>\n');

    // Embed illustration if present
    if (hasImage && (embedPageVisuals.value || text.isEmpty)) {
      buffer.write('''  <div class="page-figure">
    <img class="page-img" src="images/page_$pageNum.jpg" alt="Page $pageNum Visual"/>
  </div>
''');
    }

    if (text.isNotEmpty) {
      // Split into formatted paragraphs
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

      for (int p = 0; p < paragraphs.length; p++) {
        final pText = paragraphs[p];
        final isFirst = (p == 0);
        final cssClass = isFirst ? ' class="first"' : '';

        // Check if paragraph looks like a heading
        if (pText.length < 60 && !pText.endsWith('.') && pText.toUpperCase() == pText) {
          buffer.write('  <h3>${_xmlEscape(pText)}</h3>\n');
        } else {
          buffer.write('  <p$cssClass>${_xmlEscape(pText)}</p>\n');
        }
      }
    }

    buffer.write('  <div class="page-number-tag">— Page $pageNum of $totalPages —</div>\n');
    buffer.write('</body>\n</html>');
    return buffer.toString();
  }

  String _xmlEscape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  // ── 4. Sharing & Saving ──────────────────────────────────────────────────
  Future<void> shareEpub() async {
    final path = convertedEpubPath.value;
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(path, name: '${bookTitle.value}.epub', mimeType: 'application/epub+zip')],
          text: 'E-Book: "${bookTitle.value}" ($formattedEpubSize)',
        );
      }
    } catch (e) {
      log('[PdfToEpub] share error: $e');
      MyDialogs.info(msg: 'Failed to share e-book: $e');
    }
  }

  Future<void> saveToDownloads() async {
    final path = convertedEpubPath.value;
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
        final fileName = '${bookTitle.value.trim().replaceAll(RegExp(r'[^\w\s-]'), '_')}.epub';
        final dest = File('${targetDir.path}/$fileName');
        await source.copy(dest.path);
        MyDialogs.success(
          msg: 'Saved "$fileName" to ${targetDir.path.split(Platform.pathSeparator).last}!',
        );
      }
    } catch (e) {
      log('[PdfToEpub] saveToDownloads error: $e');
      MyDialogs.info(msg: 'Saved to app storage (Path: $e)');
    }
  }

  void reset() {
    selectedPdfPath.value = null;
    selectedPdfName.value = null;
    fileSizeInBytes.value = 0;
    pageCount.value = 0;
    bookTitle.value = '';
    convertedEpubPath.value = null;
    convertedEpubSize.value = 0;
    coverImageBytes.value = null;
    extractedSampleText.value = null;
    conversionProgress.value = 0.0;
    statusMessage.value = 'Ready';
  }
}
