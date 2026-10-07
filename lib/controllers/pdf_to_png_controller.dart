// lib/controllers/pdf_to_png_controller.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../ads/ad_helper.dart';
import '../helper/my_dialogs.dart';

enum PageSelectionMode {
  all,
  custom,
  range,
}

enum PngResolutionPreset {
  standard150(
    title: 'Standard (150 DPI)',
    subtitle: 'Fast render • Compact size • Great for web/mobile',
    scale: 2.083,
    maxDimension: 2200,
    tag: '150 DPI',
  ),
  high300(
    title: 'High-Res (300 DPI)',
    subtitle: 'Recommended • Crisp sharp text • Print quality',
    scale: 4.167,
    maxDimension: 3800,
    tag: '300 DPI',
  ),
  ultra600(
    title: 'Ultra HD (600 DPI)',
    subtitle: 'Maximum detail • Pixel-perfect graphics',
    scale: 6.25,
    maxDimension: 5000,
    tag: '600 DPI',
  );

  final String title;
  final String subtitle;
  final double scale;
  final double maxDimension;
  final String tag;

  const PngResolutionPreset({
    required this.title,
    required this.subtitle,
    required this.scale,
    required this.maxDimension,
    required this.tag,
  });
}

class ConvertedPngItem {
  final int pageNumber; // 1-indexed
  final String filePath;
  final String fileName;
  final int fileSizeInBytes;
  final int width;
  final int height;
  final Uint8List? memoryBytes;

  ConvertedPngItem({
    required this.pageNumber,
    required this.filePath,
    required this.fileName,
    required this.fileSizeInBytes,
    required this.width,
    required this.height,
    this.memoryBytes,
  });

  String get formattedSize {
    if (fileSizeInBytes < 1024) return '$fileSizeInBytes B';
    if (fileSizeInBytes < 1024 * 1024) {
      return '${(fileSizeInBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get dimensions => '$width × $height px';
}

class PdfToPngController extends GetxController {
  // Document state
  final selectedPdfPath = RxnString();
  final selectedPdfName = RxnString();
  final fileSizeInBytes = 0.obs;
  final pageCount = 0.obs;

  PdfDocument? _pdfDoc;

  // UI state
  final isPicking = false.obs;
  final isLoadingDoc = false.obs;
  final pageThumbnails = <int, Uint8List>{}.obs;

  // Selection state
  final selectionMode = PageSelectionMode.all.obs;
  final selectedPages = <int>{}.obs; // 0-indexed set of selected pages
  final rangeStart = 1.obs;
  final rangeEnd = 1.obs;

  // Quality & Settings
  final resolutionPreset = PngResolutionPreset.high300.obs;
  final isTransparentBackground = false.obs;

  // Conversion state
  final isConverting = false.obs;
  final isCancelling = false.obs;
  final conversionProgress = 0.0.obs;
  final statusMessage = 'Ready'.obs;
  final currentPageConverting = 0.obs;
  final totalPagesToConvert = 0.obs;

  // Results state
  final convertedImages = <ConvertedPngItem>[].obs;
  final activePreviewIndex = 0.obs;
  final isCreatingZip = false.obs;

  String get formattedPdfSize {
    final bytes = fileSizeInBytes.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  int get effectiveSelectedCount {
    if (pageCount.value <= 0) return 0;
    switch (selectionMode.value) {
      case PageSelectionMode.all:
        return pageCount.value;
      case PageSelectionMode.custom:
        return selectedPages.length;
      case PageSelectionMode.range:
        final start = rangeStart.value.clamp(1, pageCount.value);
        final end = rangeEnd.value.clamp(start, pageCount.value);
        return (end - start + 1);
    }
  }

  List<int> get effectiveSelectedPageIndices {
    if (pageCount.value <= 0) return [];
    switch (selectionMode.value) {
      case PageSelectionMode.all:
        return List.generate(pageCount.value, (i) => i);
      case PageSelectionMode.custom:
        final sorted = selectedPages.toList()..sort();
        return sorted;
      case PageSelectionMode.range:
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
      log('[PdfToPng] pickPdfFile error: $e');
      MyDialogs.info(msg: 'Failed to select PDF: $e');
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> loadPdf(String path, {String? fileName}) async {
    try {
      isLoadingDoc.value = true;
      _cleanupPdfDoc();
      pageThumbnails.clear();
      convertedImages.clear();

      final file = File(path);
      if (!await file.exists()) {
        MyDialogs.info(msg: 'Selected PDF file does not exist.');
        return;
      }

      final size = await file.length();
      selectedPdfPath.value = path;
      selectedPdfName.value =
          fileName ?? path.split(Platform.pathSeparator).last;
      fileSizeInBytes.value = size;

      _pdfDoc = await PdfDocument.openFile(path);
      final count = _pdfDoc!.pagesCount;
      pageCount.value = count;

      // Initialize selection
      selectedPages.clear();
      for (int i = 0; i < count; i++) {
        selectedPages.add(i);
      }
      rangeStart.value = 1;
      rangeEnd.value = count.clamp(1, 99999);
      selectionMode.value = PageSelectionMode.all;

      // Preload thumbnails progressively
      _loadThumbnailsInBackground();
    } catch (e) {
      log('[PdfToPng] loadPdf error: $e');
      MyDialogs.info(msg: 'Failed to open PDF document: $e');
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
        );
        await page.close();

        if (thumb != null) {
          pageThumbnails[i] = thumb.bytes;
        }
      } catch (e) {
        log('[PdfToPng] render thumb page $i error: $e');
      }
      // Give UI loop a breath
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
      selectedPages.add(0); // keep at least first page
    }
  }

  void setRange(int start, int end) {
    final count = pageCount.value;
    if (count <= 0) return;
    rangeStart.value = start.clamp(1, count);
    rangeEnd.value = end.clamp(rangeStart.value, count);
  }

  // ── 2. Convert PDF Pages to PNG ──────────────────────────────────────────
  Future<void> convertPdfToPng() async {
    final path = selectedPdfPath.value;
    if (path == null) {
      MyDialogs.info(msg: 'Please select a PDF file first.');
      return;
    }

    final pages = effectiveSelectedPageIndices;
    if (pages.isEmpty) {
      MyDialogs.info(msg: 'Please select at least one page to convert.');
      return;
    }

    try {
      isConverting.value = true;
      isCancelling.value = false;
      conversionProgress.value = 0.0;
      currentPageConverting.value = 0;
      totalPagesToConvert.value = pages.length;
      statusMessage.value = 'Preparing PDF converter...';

      convertedImages.clear();

      final tempDir = await getTemporaryDirectory();
      final baseName = (selectedPdfName.value ?? 'document')
          .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
          .replaceAll(RegExp(r'[^\w\s-]'), '_')
          .replaceAll(' ', '_');

      final preset = resolutionPreset.value;
      final isTransparent = isTransparentBackground.value;
      final bgColor = isTransparent ? null : '#FFFFFF';

      // Ensure PDF document is open
      _pdfDoc ??= await PdfDocument.openFile(path);

      for (int i = 0; i < pages.length; i++) {
        if (isCancelling.value) {
          statusMessage.value = 'Conversion cancelled';
          break;
        }

        final pageIndex = pages[i];
        final pageNum = pageIndex + 1;
        currentPageConverting.value = i + 1;
        statusMessage.value =
            'Rendering Page $pageNum of ${pageCount.value} (${i + 1}/${pages.length})...';
        conversionProgress.value = (i / pages.length).clamp(0.0, 1.0);

        // Open page and calculate high-res dimensions
        final page = await _pdfDoc!.getPage(pageNum);

        double targetScale = preset.scale;
        double targetWidth = (page.width * targetScale);
        double targetHeight = (page.height * targetScale);

        // Clamp to max safe dimension if needed to avoid out-of-memory on mobile
        final maxSide = targetWidth > targetHeight ? targetWidth : targetHeight;
        if (maxSide > preset.maxDimension) {
          final factor = preset.maxDimension / maxSide;
          targetWidth *= factor;
          targetHeight *= factor;
        }

        final pageImage = await page.render(
          width: targetWidth.roundToDouble(),
          height: targetHeight.roundToDouble(),
          format: PdfPageImageFormat.png,
          backgroundColor: bgColor,
        );
        await page.close();

        if (isCancelling.value) break;

        if (pageImage == null) {
          log('[PdfToPng] Warning: Render returned null for page $pageNum');
          continue;
        }

        // Save PNG file to cache
        final outputFileName = '${baseName}_page_$pageNum.png';
        final outputFile = File('${tempDir.path}/$outputFileName');
        await outputFile.writeAsBytes(pageImage.bytes, flush: true);

        final fileSize = await outputFile.length();
        final item = ConvertedPngItem(
          pageNumber: pageNum,
          filePath: outputFile.path,
          fileName: outputFileName,
          fileSizeInBytes: fileSize,
          width: pageImage.width ?? targetWidth.toInt(),
          height: pageImage.height ?? targetHeight.toInt(),
          memoryBytes: pageImage.bytes,
        );

        convertedImages.add(item);
        conversionProgress.value = ((i + 1) / pages.length).clamp(0.0, 1.0);
      }

      if (!isCancelling.value && convertedImages.isNotEmpty) {
        statusMessage.value = 'Successfully converted ${convertedImages.length} pages!';
        activePreviewIndex.value = 0;
        MyDialogs.success(
          msg: '${convertedImages.length} page(s) converted to PNG successfully!',
        );
        AdHelper.showInterstitialAd(onComplete: () {});
      }
    } catch (e, stack) {
      log('[PdfToPng] conversion error: $e\n$stack');
      MyDialogs.info(msg: 'Conversion failed: $e');
    } finally {
      isConverting.value = false;
      isCancelling.value = false;
    }
  }

  void cancelConversion() {
    if (isConverting.value) {
      isCancelling.value = true;
      statusMessage.value = 'Cancelling...';
    }
  }

  // ── 3. Sharing & Saving Options ──────────────────────────────────────────
  Future<void> shareSingleImage(ConvertedPngItem item) async {
    try {
      final file = File(item.filePath);
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(item.filePath, name: item.fileName, mimeType: 'image/png')],
          text: 'PDF Page ${item.pageNumber} (${item.fileName})',
        );
      } else {
        MyDialogs.info(msg: 'Image file not found.');
      }
    } catch (e) {
      log('[PdfToPng] shareSingleImage error: $e');
      MyDialogs.info(msg: 'Failed to share image: $e');
    }
  }

  Future<void> shareAllImages() async {
    if (convertedImages.isEmpty) return;
    try {
      final files = convertedImages
          .map((e) => XFile(e.filePath, name: e.fileName, mimeType: 'image/png'))
          .toList();
      await Share.shareXFiles(
        files,
        text: 'Converted ${convertedImages.length} PDF pages to PNG',
      );
    } catch (e) {
      log('[PdfToPng] shareAllImages error: $e');
      MyDialogs.info(msg: 'Failed to share images: $e');
    }
  }

  Future<void> shareAsZip() async {
    if (convertedImages.isEmpty) return;
    try {
      isCreatingZip.value = true;
      final tempDir = await getTemporaryDirectory();
      final baseName = (selectedPdfName.value ?? 'pdf_pages')
          .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
          .replaceAll(RegExp(r'[^\w\s-]'), '_')
          .replaceAll(' ', '_');

      final zipFilePath = '${tempDir.path}/${baseName}_png_archive.zip';
      final zipFile = File(zipFilePath);
      if (await zipFile.exists()) {
        await zipFile.delete();
      }

      final archive = Archive();
      for (final item in convertedImages) {
        final bytes = await File(item.filePath).readAsBytes();
        archive.addFile(ArchiveFile(item.fileName, bytes.length, bytes));
      }

      final encoder = ZipEncoder();
      final zipData = encoder.encode(archive);

      await zipFile.writeAsBytes(zipData, flush: true);
      await Share.shareXFiles(
        [XFile(zipFilePath, name: '${baseName}_images.zip', mimeType: 'application/zip')],
        text: 'PNG Images Archive ($baseName)',
      );
    } catch (e) {
      log('[PdfToPng] shareAsZip error: $e');
      MyDialogs.info(msg: 'Failed to create ZIP: $e');
    } finally {
      isCreatingZip.value = false;
    }
  }

  Future<void> saveToDownloads({ConvertedPngItem? singleItem}) async {
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

      final itemsToSave = singleItem != null ? [singleItem] : convertedImages;
      int savedCount = 0;

      for (final item in itemsToSave) {
        final source = File(item.filePath);
        if (await source.exists()) {
          final dest = File('${targetDir.path}/${item.fileName}');
          await source.copy(dest.path);
          savedCount++;
        }
      }

      if (savedCount > 0) {
        MyDialogs.success(
          msg: savedCount == 1
              ? 'Saved "${itemsToSave.first.fileName}" to ${targetDir.path.split(Platform.pathSeparator).last}!'
              : 'Saved $savedCount PNG images to ${targetDir.path.split(Platform.pathSeparator).last}!',
        );
      } else {
        MyDialogs.info(msg: 'No files to save.');
      }
    } catch (e) {
      log('[PdfToPng] saveToDownloads error: $e');
      MyDialogs.info(msg: 'Saved to app storage (Path: $e)');
    }
  }

  void reset() {
    _cleanupPdfDoc();
    selectedPdfPath.value = null;
    selectedPdfName.value = null;
    fileSizeInBytes.value = 0;
    pageCount.value = 0;
    pageThumbnails.clear();
    convertedImages.clear();
    selectedPages.clear();
    selectionMode.value = PageSelectionMode.all;
    conversionProgress.value = 0.0;
    statusMessage.value = 'Ready';
  }
}
