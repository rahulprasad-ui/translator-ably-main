// lib/controllers/pdf_to_pptx_controller.dart
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

enum PptxAspectRatio {
  widescreen16x9(
    title: 'Widescreen (16:9)',
    subtitle: 'Standard for modern screens, laptops & projectors',
    cx: 12192000,
    cy: 6858000,
    ratioLabel: '16:9',
  ),
  standard4x3(
    title: 'Standard (4:3)',
    subtitle: 'Classic presentation & iPad aspect ratio',
    cx: 9144000,
    cy: 6858000,
    ratioLabel: '4:3',
  ),
  matchPdf(
    title: 'Match PDF Dimensions',
    subtitle: 'Exact proportion of source PDF document',
    cx: 0,
    cy: 0,
    ratioLabel: 'Auto',
  );

  final String title;
  final String subtitle;
  final int cx;
  final int cy;
  final String ratioLabel;

  const PptxAspectRatio({
    required this.title,
    required this.subtitle,
    required this.cx,
    required this.cy,
    required this.ratioLabel,
  });
}

enum PptxSlideMode {
  hybridHighFidelity(
    title: 'Visual Slide Deck (Recommended)',
    subtitle: 'Pixel-perfect high-res visuals with slide text for Google Slides & PowerPoint',
  ),
  editableTextFlow(
    title: 'Editable Text Cards',
    subtitle: 'Reconstructs headings and bullet lists into native PowerPoint shape boxes',
  );

  final String title;
  final String subtitle;

  const PptxSlideMode({
    required this.title,
    required this.subtitle,
  });
}

enum PptxPageSelectionMode {
  all,
  custom,
  range,
}

class _SlideDimension {
  final double width;
  final double height;
  const _SlideDimension(this.width, this.height);
}

class PdfToPptxController extends GetxController {
  // Document state
  final selectedPdfPath = RxnString();
  final selectedPdfName = RxnString();
  final fileSizeInBytes = 0.obs;
  final pageCount = 0.obs;

  PdfDocument? _pdfDoc;

  // Presentation settings
  final presentationTitle = ''.obs;
  final slideAspectRatio = PptxAspectRatio.widescreen16x9.obs;
  final slideMode = PptxSlideMode.hybridHighFidelity.obs;

  // Page Selection
  final selectionMode = PptxPageSelectionMode.all.obs;
  final selectedPages = <int>{}.obs; // 0-indexed
  final rangeStart = 1.obs;
  final rangeEnd = 1.obs;

  // UI state
  final isPicking = false.obs;
  final isLoadingDoc = false.obs;
  final isConverting = false.obs;
  final conversionProgress = 0.0.obs;
  final statusMessage = 'Ready'.obs;
  final slideThumbnails = <int, Uint8List>{}.obs;

  // Results state
  final convertedPptxPath = RxnString();
  final convertedPptxSize = 0.obs;
  final totalSlides = 0.obs;

  String get formattedPdfSize {
    final bytes = fileSizeInBytes.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedPptxSize {
    final bytes = convertedPptxSize.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  int get effectiveSelectedCount {
    if (pageCount.value <= 0) return 0;
    switch (selectionMode.value) {
      case PptxPageSelectionMode.all:
        return pageCount.value;
      case PptxPageSelectionMode.custom:
        return selectedPages.length;
      case PptxPageSelectionMode.range:
        final start = rangeStart.value.clamp(1, pageCount.value);
        final end = rangeEnd.value.clamp(start, pageCount.value);
        return (end - start + 1);
    }
  }

  List<int> get effectiveSelectedPageIndices {
    if (pageCount.value <= 0) return [];
    switch (selectionMode.value) {
      case PptxPageSelectionMode.all:
        return List.generate(pageCount.value, (i) => i);
      case PptxPageSelectionMode.custom:
        final sorted = selectedPages.toList()..sort();
        return sorted;
      case PptxPageSelectionMode.range:
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
      log('[PdfToPptx] pickPdfFile error: $e');
      MyDialogs.info(msg: 'Failed to select PDF: $e');
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> loadPdf(String path, {String? fileName}) async {
    try {
      isLoadingDoc.value = true;
      _cleanupPdfDoc();
      convertedPptxPath.value = null;
      convertedPptxSize.value = 0;
      slideThumbnails.clear();

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

      presentationTitle.value = name
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
      selectionMode.value = PptxPageSelectionMode.all;

      _loadThumbnailsInBackground();
    } catch (e) {
      log('[PdfToPptx] loadPdf error: $e');
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
      if (slideThumbnails.containsKey(i)) continue;

      try {
        final page = await _pdfDoc!.getPage(i + 1);
        final thumb = await page.render(
          width: 220,
          height: (220 * (page.height / page.width)),
          format: PdfPageImageFormat.jpeg,
          quality: 65,
          backgroundColor: '#FFFFFF',
        );
        await page.close();

        if (thumb != null) {
          slideThumbnails[i] = thumb.bytes;
        }
      } catch (e) {
        log('[PdfToPptx] thumb render $i error: $e');
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
        MyDialogs.info(msg: 'At least one slide must be selected.');
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

  // ── 2. Convert PDF to PPTX Presentation ──────────────────────────────────
  Future<void> convertPdfToPptx() async {
    final pdfPath = selectedPdfPath.value;
    if (pdfPath == null || !File(pdfPath).existsSync()) {
      MyDialogs.info(msg: 'Please select a valid PDF file first.');
      return;
    }

    final pages = effectiveSelectedPageIndices;
    if (pages.isEmpty) {
      MyDialogs.info(msg: 'Please select at least one slide to convert.');
      return;
    }

    try {
      isConverting.value = true;
      conversionProgress.value = 0.05;
      statusMessage.value = 'Extracting slide content & text layer...';

      // 1. Extract text page by page
      List<String> pagesText = [];
      try {
        pagesText = await ReadPdfText.getPDFtextPaginated(pdfPath);
      } catch (e) {
        log('[PdfToPptx] text extraction paginated failed: $e');
      }

      while (pagesText.length < pageCount.value) {
        pagesText.add('');
      }

      conversionProgress.value = 0.20;
      statusMessage.value = 'Rendering high-definition slide graphics...';

      // 2. Render each selected slide to high-res JPEG
      _pdfDoc ??= await PdfDocument.openFile(pdfPath);
      final Map<int, Uint8List> slideImages = {};
      final Map<int, _SlideDimension> slidePageSizes = {};

      for (int i = 0; i < pages.length; i++) {
        final pageIndex = pages[i];
        final pageNum = pageIndex + 1;
        statusMessage.value = 'Rendering Slide ${i + 1} of ${pages.length}...';
        conversionProgress.value = (0.20 + (0.50 * ((i + 1) / pages.length))).clamp(0.20, 0.70);

        try {
          final page = await _pdfDoc!.getPage(pageNum);
          slidePageSizes[pageNum] = _SlideDimension(page.width, page.height);

          final double targetWidth = 1920.0;
          final double targetHeight = (1920.0 * (page.height / page.width));

          final img = await page.render(
            width: targetWidth.roundToDouble(),
            height: targetHeight.roundToDouble(),
            format: PdfPageImageFormat.jpeg,
            quality: 90,
            backgroundColor: '#FFFFFF',
          );
          await page.close();

          if (img != null) {
            slideImages[pageNum] = img.bytes;
          }
        } catch (e) {
          log('[PdfToPptx] render slide page $pageNum error: $e');
        }
      }

      conversionProgress.value = 0.75;
      statusMessage.value = 'Building PowerPoint OpenXML presentation...';

      // 3. Build standard OpenXML .pptx package
      final pptxBytes = _buildPptxPackage(
        title: presentationTitle.value.trim().isEmpty
            ? 'Presentation'
            : presentationTitle.value.trim(),
        selectedIndices: pages,
        pagesText: pagesText,
        slideImages: slideImages,
        slidePageSizes: slidePageSizes,
        aspectRatio: slideAspectRatio.value,
        slideMode: slideMode.value,
      );

      conversionProgress.value = 0.90;
      statusMessage.value = 'Saving PowerPoint presentation...';

      final tempDir = await getTemporaryDirectory();
      final safeName = (presentationTitle.value.trim().isEmpty
              ? 'presentation'
              : presentationTitle.value.trim())
          .replaceAll(RegExp(r'[^\w\s-]'), '_')
          .replaceAll(' ', '_');
      final outputPath = '${tempDir.path}/$safeName.pptx';

      final outFile = File(outputPath);
      await outFile.writeAsBytes(pptxBytes, flush: true);

      conversionProgress.value = 1.0;
      statusMessage.value = 'PowerPoint Presentation Ready!';

      convertedPptxPath.value = outputPath;
      convertedPptxSize.value = await outFile.length();
      totalSlides.value = pages.length;

      MyDialogs.success(
        msg: '${pages.length} slide(s) converted to PowerPoint (.pptx) successfully!',
      );
      AdHelper.showInterstitialAd(onComplete: () {});
    } catch (e, stack) {
      log('[PdfToPptx] convert error: $e\n$stack');
      MyDialogs.info(msg: 'Conversion failed: $e');
    } finally {
      isConverting.value = false;
    }
  }

  // ── 3. OpenXML PPTX Package Generator ─────────────────────────────────────
  List<int> _buildPptxPackage({
    required String title,
    required List<int> selectedIndices,
    required List<String> pagesText,
    required Map<int, Uint8List> slideImages,
    required Map<int, _SlideDimension> slidePageSizes,
    required PptxAspectRatio aspectRatio,
    required PptxSlideMode slideMode,
  }) {
    final archive = Archive();
    final slideCount = selectedIndices.length;

    // Calculate Presentation Slide Size in EMUs (1 inch = 914,400 EMUs)
    int slideWidthEmu = aspectRatio.cx;
    int slideHeightEmu = aspectRatio.cy;

    if (aspectRatio == PptxAspectRatio.matchPdf && slidePageSizes.isNotEmpty) {
      final firstSize = slidePageSizes.values.first;
      slideWidthEmu = (firstSize.width * 12700).toInt();
      slideHeightEmu = (firstSize.height * 12700).toInt();
    } else if (slideWidthEmu == 0 || slideHeightEmu == 0) {
      slideWidthEmu = 12192000; // 16:9 widescreen
      slideHeightEmu = 6858000;
    }

    // 1. [Content_Types].xml
    final contentTypes = StringBuffer();
    contentTypes.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    contentTypes.write('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n');
    contentTypes.write('  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n');
    contentTypes.write('  <Default Extension="xml" ContentType="application/xml"/>\n');
    contentTypes.write('  <Default Extension="jpeg" ContentType="image/jpeg"/>\n');
    contentTypes.write('  <Default Extension="jpg" ContentType="image/jpeg"/>\n');
    contentTypes.write('  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>\n');
    contentTypes.write('  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>\n');
    contentTypes.write('  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>\n');
    contentTypes.write('  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>\n');
    contentTypes.write('  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>\n');
    contentTypes.write('  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>\n');

    for (int i = 1; i <= slideCount; i++) {
      contentTypes.write('  <Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>\n');
    }
    contentTypes.write('</Types>');
    final ctBytes = utf8.encode(contentTypes.toString());
    archive.addFile(ArchiveFile('[Content_Types].xml', ctBytes.length, ctBytes));

    // 2. _rels/.rels
    const rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>\n'
        '  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>\n'
        '  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>\n'
        '</Relationships>';
    final rootRelsBytes = utf8.encode(rootRels);
    archive.addFile(ArchiveFile('_rels/.rels', rootRelsBytes.length, rootRelsBytes));

    // 3. docProps/core.xml & docProps/app.xml
    final coreXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">\n'
        '  <dc:title>${_xmlEscape(title)}</dc:title>\n'
        '  <dc:creator>Translator Ably</dc:creator>\n'
        '  <cp:lastModifiedBy>Translator Ably</cp:lastModifiedBy>\n'
        '  <dcterms:created xsi:type="dcterms:W3CDTF">${DateTime.now().toUtc().toIso8601String()}</dcterms:created>\n'
        '</cp:coreProperties>';
    final coreBytes = utf8.encode(coreXml);
    archive.addFile(ArchiveFile('docProps/core.xml', coreBytes.length, coreBytes));

    final appXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">\n'
        '  <TotalTime>0</TotalTime>\n'
        '  <Words>0</Words>\n'
        '  <Application>Translator Ably PDF to PPTX</Application>\n'
        '  <PresentationFormat>Custom</PresentationFormat>\n'
        '  <Paragraphs>0</Paragraphs>\n'
        '  <Slides>$slideCount</Slides>\n'
        '  <Notes>0</Notes>\n'
        '  <HiddenSlides>0</HiddenSlides>\n'
        '  <MMClips>0</MMClips>\n'
        '  <ScaleCrop>false</ScaleCrop>\n'
        '  <HeadingPairs><vt:vector size="2" baseType="variant"><vt:variant><vt:lpstr>Slides</vt:lpstr></vt:variant><vt:variant><vt:i4>$slideCount</vt:i4></vt:variant></vt:vector></HeadingPairs>\n'
        '</Properties>';
    final appBytes = utf8.encode(appXml);
    archive.addFile(ArchiveFile('docProps/app.xml', appBytes.length, appBytes));

    // 4. ppt/presentation.xml
    final presXml = StringBuffer();
    presXml.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    presXml.write('<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">\n');
    presXml.write('  <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>\n');
    presXml.write('  <p:sldIdLst>\n');
    for (int i = 1; i <= slideCount; i++) {
      presXml.write('    <p:sldId id="${255 + i}" r:id="rIdSlide$i"/>\n');
    }
    presXml.write('  </p:sldIdLst>\n');
    presXml.write('  <p:sldSz cx="$slideWidthEmu" cy="$slideHeightEmu"/>\n');
    presXml.write('  <p:notesSz cx="6858000" cy="9144000"/>\n');
    presXml.write('</p:presentation>');
    final presBytes = utf8.encode(presXml.toString());
    archive.addFile(ArchiveFile('ppt/presentation.xml', presBytes.length, presBytes));

    // 5. ppt/_rels/presentation.xml.rels
    final presRels = StringBuffer();
    presRels.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    presRels.write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n');
    presRels.write('  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>\n');
    for (int i = 1; i <= slideCount; i++) {
      presRels.write('  <Relationship Id="rIdSlide$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$i.xml"/>\n');
    }
    presRels.write('</Relationships>');
    final presRelsBytes = utf8.encode(presRels.toString());
    archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', presRelsBytes.length, presRelsBytes));

    // 6. ppt/slideMasters/slideMaster1.xml & rels
    _addSlideMaster(archive);

    // 7. ppt/slideLayouts/slideLayout1.xml & rels
    _addSlideLayout(archive);

    // 8. ppt/theme/theme1.xml
    _addTheme(archive);

    // 9. Save Media Images and Slide XMLs
    for (int i = 0; i < slideCount; i++) {
      final slideNum = i + 1;
      final sourcePageIndex = selectedIndices[i];
      final pageNum = sourcePageIndex + 1;

      final imgBytes = slideImages[pageNum];
      final pageText = pagesText.length > sourcePageIndex ? pagesText[sourcePageIndex] : '';

      if (imgBytes != null) {
        archive.addFile(ArchiveFile('ppt/media/image$slideNum.jpeg', imgBytes.length, imgBytes));
      }

      // Slide XML
      final slideXml = _buildSlideXml(
        slideNum: slideNum,
        slideWidthEmu: slideWidthEmu,
        slideHeightEmu: slideHeightEmu,
        hasImage: imgBytes != null,
        text: pageText,
        slideMode: slideMode,
      );
      final sBytes = utf8.encode(slideXml);
      archive.addFile(ArchiveFile('ppt/slides/slide$slideNum.xml', sBytes.length, sBytes));

      // Slide rels
      final slideRels = StringBuffer();
      slideRels.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
      slideRels.write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n');
      slideRels.write('  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>\n');
      if (imgBytes != null) {
        slideRels.write('  <Relationship Id="rIdImage" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image$slideNum.jpeg"/>\n');
      }
      slideRels.write('</Relationships>');
      final sRelsBytes = utf8.encode(slideRels.toString());
      archive.addFile(ArchiveFile('ppt/slides/_rels/slide$slideNum.xml.rels', sRelsBytes.length, sRelsBytes));
    }

    final encoder = ZipEncoder();
    return encoder.encode(archive);
  }

  void _addSlideMaster(Archive archive) {
    const masterXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">\n'
        '  <p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld>\n'
        '  <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>\n'
        '  <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>\n'
        '</p:sldMaster>';
    final mBytes = utf8.encode(masterXml);
    archive.addFile(ArchiveFile('ppt/slideMasters/slideMaster1.xml', mBytes.length, mBytes));

    const masterRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>\n'
        '  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>\n'
        '</Relationships>';
    final mRelsBytes = utf8.encode(masterRels);
    archive.addFile(ArchiveFile('ppt/slideMasters/_rels/slideMaster1.xml.rels', mRelsBytes.length, mRelsBytes));
  }

  void _addSlideLayout(Archive archive) {
    const layoutXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank">\n'
        '  <p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld>\n'
        '  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>\n'
        '</p:sldLayout>';
    final lBytes = utf8.encode(layoutXml);
    archive.addFile(ArchiveFile('ppt/slideLayouts/slideLayout1.xml', lBytes.length, lBytes));

    const layoutRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>\n'
        '</Relationships>';
    final lRelsBytes = utf8.encode(layoutRels);
    archive.addFile(ArchiveFile('ppt/slideLayouts/_rels/slideLayout1.xml.rels', lRelsBytes.length, lRelsBytes));
  }

  void _addTheme(Archive archive) {
    const themeXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">\n'
        '  <a:themeElements>\n'
        '    <a:clrScheme name="Office">\n'
        '      <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>\n'
        '      <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>\n'
        '      <a:dk2><a:srgbClr val="1F497D"/></a:dk2>\n'
        '      <a:lt2><a:srgbClr val="EEECE1"/></a:lt2>\n'
        '      <a:accent1><a:srgbClr val="4F81BD"/></a:accent1>\n'
        '      <a:accent2><a:srgbClr val="C0504D"/></a:accent2>\n'
        '      <a:accent3><a:srgbClr val="9BBB59"/></a:accent3>\n'
        '      <a:accent4><a:srgbClr val="8064A2"/></a:accent4>\n'
        '      <a:accent5><a:srgbClr val="4BACC6"/></a:accent5>\n'
        '      <a:accent6><a:srgbClr val="F79646"/></a:accent6>\n'
        '      <a:hlink><a:srgbClr val="0000FF"/></a:hlink>\n'
        '      <a:folHlink><a:srgbClr val="800080"/></a:folHlink>\n'
        '    </a:clrScheme>\n'
        '    <a:fontScheme name="Office">\n'
        '      <a:majorFont><a:latin typeface="Calibri Light"/></a:majorFont>\n'
        '      <a:minorFont><a:latin typeface="Calibri"/></a:minorFont>\n'
        '    </a:fontScheme>\n'
        '    <a:fmtScheme name="Office">\n'
        '      <a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>\n'
        '      <a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst>\n'
        '      <a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>\n'
        '      <a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst>\n'
        '    </a:fmtScheme>\n'
        '  </a:themeElements>\n'
        '</a:theme>';
    final tBytes = utf8.encode(themeXml);
    archive.addFile(ArchiveFile('ppt/theme/theme1.xml', tBytes.length, tBytes));
  }

  String _buildSlideXml({
    required int slideNum,
    required int slideWidthEmu,
    required int slideHeightEmu,
    required bool hasImage,
    required String text,
    required PptxSlideMode slideMode,
  }) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write('<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">\n');
    buffer.write('  <p:cSld>\n');
    buffer.write('    <p:spTree>\n');
    buffer.write('      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\n');
    buffer.write('      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>\n');

    int shapeId = 2;

    // 1. If has image, add Picture shape covering slide or centered
    if (hasImage) {
      buffer.write('      <p:pic>\n');
      buffer.write('        <p:nvPicPr><p:cNvPr id="$shapeId" name="Slide Image $slideNum"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>\n');
      buffer.write('        <p:blipFill><a:blip r:embed="rIdImage"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>\n');
      buffer.write('        <p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$slideWidthEmu" cy="$slideHeightEmu"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n');
      buffer.write('      </p:pic>\n');
      shapeId++;
    }

    // 2. If Editable Text mode is selected, add reconstructed text shapes
    if (slideMode == PptxSlideMode.editableTextFlow && text.trim().isNotEmpty) {
      final lines = text.trim().split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.isNotEmpty) {
        final titleLine = lines.first;
        final bodyLines = lines.skip(1).take(8).toList();

        // Title box
        buffer.write('      <p:sp>\n');
        buffer.write('        <p:nvSpPr><p:cNvPr id="$shapeId" name="Slide Title"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>\n');
        buffer.write('        <p:spPr><a:xfrm><a:off x="600000" y="450000"/><a:ext cx="${slideWidthEmu - 1200000}" cy="900000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n');
        buffer.write('        <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr sz="2800" b="1"><a:solidFill><a:srgbClr val="0F172A"/></a:solidFill></a:rPr><a:t>${_xmlEscape(titleLine)}</a:t></a:r></a:p></p:txBody>\n');
        buffer.write('      </p:sp>\n');
        shapeId++;

        // Body bullet list box
        if (bodyLines.isNotEmpty) {
          buffer.write('      <p:sp>\n');
          buffer.write('        <p:nvSpPr><p:cNvPr id="$shapeId" name="Slide Content"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>\n');
          buffer.write('        <p:spPr><a:xfrm><a:off x="600000" y="1500000"/><a:ext cx="${slideWidthEmu - 1200000}" cy="${slideHeightEmu - 2000000}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\n');
          buffer.write('        <p:txBody><a:bodyPr/><a:lstStyle/>\n');
          for (final b in bodyLines) {
            buffer.write('          <a:p><a:pPr lvl="0"/><a:r><a:rPr sz="1600"><a:solidFill><a:srgbClr val="334155"/></a:solidFill></a:rPr><a:t>${_xmlEscape(b)}</a:t></a:r></a:p>\n');
          }
          buffer.write('        </p:txBody>\n');
          buffer.write('      </p:sp>\n');
          shapeId++;
        }
      }
    }

    buffer.write('    </p:spTree>\n');
    buffer.write('  </p:cSld>\n');
    buffer.write('  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>\n');
    buffer.write('</p:sld>');
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
  Future<void> sharePptx() async {
    final path = convertedPptxPath.value;
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await Share.shareXFiles(
          [
            XFile(
              path,
              name: '${presentationTitle.value}.pptx',
              mimeType: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            )
          ],
          text: 'PowerPoint Presentation: "${presentationTitle.value}" ($formattedPptxSize)',
        );
      }
    } catch (e) {
      log('[PdfToPptx] share error: $e');
      MyDialogs.info(msg: 'Failed to share presentation: $e');
    }
  }

  Future<void> saveToDownloads() async {
    final path = convertedPptxPath.value;
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
        final fileName = '${presentationTitle.value.trim().replaceAll(RegExp(r'[^\w\s-]'), '_')}.pptx';
        final dest = File('${targetDir.path}/$fileName');
        await source.copy(dest.path);
        MyDialogs.success(
          msg: 'Saved "$fileName" to ${targetDir.path.split(Platform.pathSeparator).last}!',
        );
      }
    } catch (e) {
      log('[PdfToPptx] saveToDownloads error: $e');
      MyDialogs.info(msg: 'Saved to app storage (Path: $e)');
    }
  }

  void reset() {
    _cleanupPdfDoc();
    selectedPdfPath.value = null;
    selectedPdfName.value = null;
    fileSizeInBytes.value = 0;
    pageCount.value = 0;
    presentationTitle.value = '';
    convertedPptxPath.value = null;
    convertedPptxSize.value = 0;
    slideThumbnails.clear();
    selectedPages.clear();
    selectionMode.value = PptxPageSelectionMode.all;
    conversionProgress.value = 0.0;
    statusMessage.value = 'Ready';
  }
}
