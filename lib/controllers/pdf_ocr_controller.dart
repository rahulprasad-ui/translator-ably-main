// lib/controllers/pdf_ocr_controller.dart
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:share_plus/share_plus.dart';

import '../helper/my_dialogs.dart';
import '../model/home.dart';
import '../helper/pref.dart';
import '../screen/tab/text_translate_tab.dart';

enum OcrSourceType {
  pdf,
  images,
}

enum OcrMode {
  allPages,
  selectedPages,
  pageRange,
}

class OcrImageInputItem {
  final String id;
  final String path;
  final String name;
  final int sizeInBytes;

  OcrImageInputItem({
    required this.id,
    required this.path,
    required this.name,
    required this.sizeInBytes,
  });

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class OcrBlockInfo {
  final String text;
  final Rect boundingBox;

  OcrBlockInfo({
    required this.text,
    required this.boundingBox,
  });
}

class OcrPageItem {
  final int pageIndex; // 0-indexed
  final int pageNumber; // 1-indexed
  final String text;
  final int wordCount;
  final int charCount;
  final List<String> blocks;
  final List<OcrBlockInfo> blockInfos;
  final Rect? documentBoundingBox;
  final double imageWidth;
  final double imageHeight;
  final String? imagePath;
  Uint8List? thumbnailBytes;

  OcrPageItem({
    required this.pageIndex,
    required this.pageNumber,
    required this.text,
    required this.wordCount,
    required this.charCount,
    required this.blocks,
    this.blockInfos = const [],
    this.documentBoundingBox,
    this.imageWidth = 0,
    this.imageHeight = 0,
    this.imagePath,
    this.thumbnailBytes,
  });
}

// ── LRU Cache ─────────────────────────────────────────────────────────────
class _LruCache<K, V> {
  final int capacity;
  final void Function(V)? onEvict;
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  _LruCache(this.capacity, {this.onEvict});

  V? get(K key) {
    final v = _map.remove(key);
    if (v != null) _map[key] = v;
    return v;
  }

  void put(K key, V value) {
    _map.remove(key);
    _map[key] = value;
    if (_map.length > capacity) {
      final oldest = _map.keys.first;
      final evicted = _map.remove(oldest);
      if (evicted != null) onEvict?.call(evicted);
    }
  }

  bool containsKey(K key) => _map.containsKey(key);

  void clear() {
    for (final v in _map.values) {
      onEvict?.call(v);
    }
    _map.clear();
  }
}

// ── Async Lock ────────────────────────────────────────────────────────────
class _AsyncLock {
  Future<void>? _last;

  Future<T> synchronized<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final prev = _last;
    _last = completer.future;

    return Future<T>.sync(() async {
      if (prev != null) {
        try {
          await prev;
        } catch (_) {}
      }
      return await action();
    }).whenComplete(() {
      completer.complete();
    });
  }
}

class PdfOcrController extends GetxController {
  final sourceType = OcrSourceType.pdf.obs;

  // PDF Source State
  final selectedPdfPath = RxnString();
  final selectedPdfName = RxnString();
  final fileSizeInBytes = 0.obs;
  final pageCount = 0.obs;

  // Image Source State
  final pickedImages = <OcrImageInputItem>[].obs;
  final ImagePicker _imagePicker = ImagePicker();

  final isPicking = false.obs;
  final isProcessing = false.obs;
  final progress = 0.0.obs;
  final statusMessage = 'Ready'.obs;
  final isCancelling = false.obs;

  // OCR Mode & Selection (for PDF)
  final ocrMode = OcrMode.allPages.obs;
  final selectedPages = <int>{}.obs;
  final rangeStart = 1.obs;
  final rangeEnd = 1.obs;

  // OCR Results
  final ocrPages = <OcrPageItem>[].obs;
  final combinedText = ''.obs;
  final isOcrCompleted = false.obs;
  final currentViewPageIndex = 0.obs;

  // TTS Reader
  final FlutterTts _flutterTts = FlutterTts();
  final isTtsPlaying = false.obs;

  // Search filter in results
  final searchQuery = ''.obs;
  final searchController = TextEditingController();

  // Detailed Progress Metrics
  final currentProcessingPage = 0.obs;
  final totalProcessingPages = 0.obs;
  final currentStep = ''.obs;

  // Internal PDF rendering for thumbnails
  PdfDocument? _pdfDoc;
  final _renderLock = _AsyncLock();

  // LRU Thumbnail cache strictly limited to 15 items to conserve memory
  final _thumbCache = _LruCache<int, Uint8List>(15);
  final thumbnailReadyPages = RxSet<int>({});

  bool get hasContent =>
      (sourceType.value == OcrSourceType.pdf && selectedPdfPath.value != null) ||
      (sourceType.value == OcrSourceType.images && pickedImages.isNotEmpty);

  String get formattedFileSize {
    if (sourceType.value == OcrSourceType.images) {
      final total = pickedImages.fold<int>(0, (sum, e) => sum + e.sizeInBytes);
      if (total < 1024) return '$total B';
      if (total < 1024 * 1024) return '${(total / 1024).toStringAsFixed(1)} KB';
      return '${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    final bytes = fileSizeInBytes.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  int get totalWords {
    if (combinedText.value.trim().isEmpty) return 0;
    return RegExp(r'\S+').allMatches(combinedText.value).length;
  }

  int get totalCharacters => combinedText.value.length;

  int get readingTimeMinutes {
    final words = totalWords;
    if (words == 0) return 0;
    return (words / 200).ceil().clamp(1, 999);
  }

  @override
  void onInit() {
    super.onInit();
    _initTts();
  }

  @override
  void onClose() {
    _stopTts();
    _closeDoc();
    searchController.dispose();
    super.onClose();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setPitch(1.0);
      _flutterTts.setCompletionHandler(() {
        isTtsPlaying.value = false;
      });
      _flutterTts.setErrorHandler((_) {
        isTtsPlaying.value = false;
      });
    } catch (_) {}
  }

  void _closeDoc() {
    try {
      _pdfDoc?.close();
      _pdfDoc = null;
    } catch (_) {}
    _thumbCache.clear();
    thumbnailReadyPages.clear();
  }

  // ── 1. Pick PDF File ──────────────────────────────────────────────────────
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

      sourceType.value = OcrSourceType.pdf;
      await loadPdf(path, fileName: result.first.name);
    } catch (e) {
      log('[PdfOcr] pickPdfFile error: $e');
      MyDialogs.info(msg: 'Failed to pick PDF file: $e');
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> loadPdf(String path, {String? fileName}) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        MyDialogs.info(msg: 'File does not exist');
        return;
      }

      _closeDoc();
      _stopTts();
      resetResults();

      sourceType.value = OcrSourceType.pdf;
      selectedPdfPath.value = path;
      selectedPdfName.value =
          fileName ?? path.split(Platform.pathSeparator).last;
      fileSizeInBytes.value = await file.length();

      _pdfDoc = await PdfDocument.openFile(path);
      pageCount.value = _pdfDoc!.pagesCount;

      selectedPages.clear();
      for (int i = 0; i < pageCount.value; i++) {
        selectedPages.add(i);
      }

      rangeStart.value = 1;
      rangeEnd.value = pageCount.value.clamp(1, 99999);
    } catch (e) {
      log('[PdfOcr] loadPdf error: $e');
      MyDialogs.info(msg: 'Could not load PDF document: $e');
    }
  }

  // ── 2. Pick Images (Gallery or Camera with Automatic Fallback) ─────────────
  Future<void> pickImagesFromGallery({bool append = true}) async {
    try {
      isPicking.value = true;
      List<String> imagePaths = [];

      try {
        final images = await _imagePicker.pickMultiImage();
        if (images.isNotEmpty) {
          imagePaths = images.map((e) => e.path).toList();
        }
      } on MissingPluginException catch (_) {
        // Graceful fallback to FilePicker (which is already compiled into the app)
        log('[PdfOcr] ImagePicker missing plugin, falling back to FilePicker');
        final result = await FilePicker.pickFiles(
          type: FileType.image,
        );
        if (result.isNotEmpty) {
          imagePaths = result.map((e) => e.path).whereType<String>().toList();
        }
      } catch (e) {
        log('[PdfOcr] ImagePicker error: $e, trying FilePicker fallback');
        final result = await FilePicker.pickFiles(
          type: FileType.image,
        );
        if (result.isNotEmpty) {
          imagePaths = result.map((e) => e.path).whereType<String>().toList();
        }
      }

      if (imagePaths.isEmpty) return;

      if (!append) {
        pickedImages.clear();
      }

      sourceType.value = OcrSourceType.images;
      resetResults();

      for (final path in imagePaths) {
        final file = File(path);
        if (await file.exists()) {
          final size = await file.length();
          final fileName = path.split(Platform.pathSeparator).last;
          final item = OcrImageInputItem(
            id: '${DateTime.now().millisecondsSinceEpoch}_$fileName',
            path: path,
            name: fileName,
            sizeInBytes: size,
          );
          if (!pickedImages.any((e) => e.path == item.path)) {
            pickedImages.add(item);
          }
        }
      }
    } catch (e) {
      log('[PdfOcr] pickImagesFromGallery error: $e');
      MyDialogs.info(msg: 'Failed to pick images: $e');
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> captureImageFromCamera() async {
    try {
      isPicking.value = true;
      String? photoPath;

      try {
        final photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 95,
        );
        if (photo != null) {
          photoPath = photo.path;
        }
      } on MissingPluginException catch (_) {
        log('[PdfOcr] Camera plugin requires full app restart');
        MyDialogs.info(
          msg:
              'Camera plugin added! Please fully stop and restart (Re-run) the app once to enable camera access.',
        );
        // Fallback to file/image picker so user is not blocked
        final result = await FilePicker.pickFiles(type: FileType.image);
        if (result.isNotEmpty && result.first.path != null) {
          photoPath = result.first.path;
        }
      } catch (e) {
        log('[PdfOcr] Camera error: $e');
        final result = await FilePicker.pickFiles(type: FileType.image);
        if (result.isNotEmpty && result.first.path != null) {
          photoPath = result.first.path;
        }
      }

      if (photoPath == null) return;

      final file = File(photoPath);
      if (await file.exists()) {
        sourceType.value = OcrSourceType.images;
        resetResults();

        final size = await file.length();
        final fileName = photoPath.split(Platform.pathSeparator).last;
        final item = OcrImageInputItem(
          id: '${DateTime.now().millisecondsSinceEpoch}_camera',
          path: photoPath,
          name: fileName.isNotEmpty ? fileName : 'Camera_Scan.jpg',
          sizeInBytes: size,
        );
        pickedImages.add(item);

        // Automatically start OCR right after camera capture so document layer appears immediately!
        startOcr();
      }
    } catch (e) {
      log('[PdfOcr] captureImageFromCamera error: $e');
      MyDialogs.info(msg: 'Camera error: $e');
    } finally {
      isPicking.value = false;
    }
  }

  void removeImage(int index) {
    if (index >= 0 && index < pickedImages.length) {
      pickedImages.removeAt(index);
    }
  }

  void clearImages() {
    pickedImages.clear();
    resetResults();
  }

  Future<Uint8List?> getThumbnail(int pageIndex) async {
    final cached = _thumbCache.get(pageIndex);
    if (cached != null) return cached;
    return _loadThumbnail(pageIndex);
  }

  Future<Uint8List?> _loadThumbnail(int pageIndex) async {
    if (_thumbCache.containsKey(pageIndex)) return _thumbCache.get(pageIndex);
    if (_pdfDoc == null) return null;

    return _renderLock.synchronized<Uint8List?>(() async {
      final cached = _thumbCache.get(pageIndex);
      if (cached != null) return cached;
      if (_pdfDoc == null) return null;

      try {
        final page = await _pdfDoc!.getPage(pageIndex + 1);
        final pageImage = await page.render(
          width: 240.0,
          height: (240.0 * (page.height / page.width)),
          format: PdfPageImageFormat.jpeg,
          quality: 65,
        );
        await page.close();

        if (pageImage != null) {
          _thumbCache.put(pageIndex, pageImage.bytes);
          thumbnailReadyPages.add(pageIndex);
          return pageImage.bytes;
        }
      } catch (e) {
        log('[PdfOcr] thumbnail render page $pageIndex error: $e');
      }
      return null;
    });
  }

  void togglePageSelection(int pageIndex) {
    if (selectedPages.contains(pageIndex)) {
      if (selectedPages.length > 1) {
        selectedPages.remove(pageIndex);
      } else {
        MyDialogs.info(msg: 'At least one page must be selected');
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

  List<int> getResolvedPagesToProcess() {
    final count = pageCount.value;
    if (count == 0) return [];

    switch (ocrMode.value) {
      case OcrMode.allPages:
        return List.generate(count, (i) => i);
      case OcrMode.selectedPages:
        final list = selectedPages.toList()..sort();
        return list.isEmpty ? [0] : list;
      case OcrMode.pageRange:
        final s = (rangeStart.value - 1).clamp(0, count - 1);
        final e = (rangeEnd.value - 1).clamp(0, count - 1);
        final start = s <= e ? s : e;
        final end = s <= e ? e : s;
        return List.generate(end - start + 1, (i) => start + i);
    }
  }

  // ── Unified Start OCR Process (Handles Image & PDF) ───────────────────────
  Future<void> startOcr() async {
    if (sourceType.value == OcrSourceType.images) {
      await _startImageOcr();
    } else {
      await _startPdfOcr();
    }
  }

  // ── Image OCR Engine ──────────────────────────────────────────────────────
  Future<void> _startImageOcr() async {
    if (pickedImages.isEmpty) {
      MyDialogs.info(msg: 'Please select at least one image');
      return;
    }

    isProcessing.value = true;
    isCancelling.value = false;
    progress.value = 0.0;
    totalProcessingPages.value = pickedImages.length;
    currentProcessingPage.value = 0;
    currentStep.value = 'Initializing AI Vision OCR...';
    statusMessage.value = 'Starting Image OCR...';
    ocrPages.clear();
    combinedText.value = '';

    TextRecognizer? textRecognizer;
    try {
      textRecognizer = await _createSafeTextRecognizer();
      final total = pickedImages.length;
      final bufferAll = StringBuffer();

      for (int i = 0; i < total; i++) {
        // Multi-point cancellation check 1
        if (isCancelling.value) {
          log('[ImageOcr] Cancellation requested. Aborting remaining ${total - i} images.');
          break;
        }

        final item = pickedImages[i];
        final imageNumber = i + 1;

        currentProcessingPage.value = imageNumber;
        progress.value = i / total;
        currentStep.value =
            'Analyzing Image $imageNumber of $total (${item.name})...';
        statusMessage.value = 'Recognizing image $imageNumber of $total';

        final file = File(item.path);
        if (!await file.exists()) {
          continue;
        }

        // Multi-point cancellation check 2
        if (isCancelling.value) break;

        // Process safely with Google ML Kit Text Recognition
        final inputImage = InputImage.fromFilePath(item.path);
        final RecognizedText recognized =
            await _processImageSafe(textRecognizer, inputImage);

        // Multi-point cancellation check 3
        if (isCancelling.value) break;

        String extracted = _formatRecognizedText(recognized);
        final blockTexts = <String>[];
        final blockInfos = <OcrBlockInfo>[];

        double minLeft = double.infinity;
        double minTop = double.infinity;
        double maxRight = double.negativeInfinity;
        double maxBottom = double.negativeInfinity;

        for (final block in recognized.blocks) {
          final t = block.text.trim();
          if (t.isNotEmpty) {
            blockTexts.add(t);
            final box = block.boundingBox;
            blockInfos.add(OcrBlockInfo(text: t, boundingBox: box));
            if (box.left < minLeft) minLeft = box.left;
            if (box.top < minTop) minTop = box.top;
            if (box.right > maxRight) maxRight = box.right;
            if (box.bottom > maxBottom) maxBottom = box.bottom;
          }
        }

        if (extracted.isEmpty) {
          extracted = '[No text detected in Image $imageNumber]';
        }

        final wordCount = RegExp(r'\S+').allMatches(extracted).length;
        final charCount = extracted.length;

        // Load image bytes and detect dimensions for precise layer overlay
        Uint8List? thumbBytes;
        double imgWidth = 0;
        double imgHeight = 0;
        try {
          thumbBytes = await file.readAsBytes();
          if (thumbBytes.isNotEmpty) {
            final codec = await ui.instantiateImageCodec(thumbBytes);
            final frame = await codec.getNextFrame();
            imgWidth = frame.image.width.toDouble();
            imgHeight = frame.image.height.toDouble();
          }
        } catch (e) {
          log('[PdfOcr] Failed to decode image dimensions: $e');
        }

        // Calculate overarching Document Bounding Box layer
        Rect? docBox;
        if (minLeft != double.infinity && maxRight > minLeft && maxBottom > minTop) {
          final padX = (maxRight - minLeft) * 0.02;
          final padY = (maxBottom - minTop) * 0.02;
          final boundW = imgWidth > 0 ? imgWidth : (maxRight + padX * 2);
          final boundH = imgHeight > 0 ? imgHeight : (maxBottom + padY * 2);
          docBox = Rect.fromLTRB(
            (minLeft - padX).clamp(0.0, boundW),
            (minTop - padY).clamp(0.0, boundH),
            (maxRight + padX).clamp(0.0, boundW),
            (maxBottom + padY).clamp(0.0, boundH),
          );
        }

        final pageItem = OcrPageItem(
          pageIndex: i,
          pageNumber: imageNumber,
          text: extracted,
          wordCount: wordCount,
          charCount: charCount,
          blocks: blockTexts,
          blockInfos: blockInfos,
          documentBoundingBox: docBox,
          imageWidth: imgWidth,
          imageHeight: imgHeight,
          imagePath: item.path,
          thumbnailBytes: thumbBytes,
        );

        ocrPages.add(pageItem);

        if (bufferAll.isNotEmpty) {
          bufferAll.write('\n\n\n════════════════════════════════════\n');
          bufferAll.write('📷 Image $imageNumber: ${item.name}\n');
          bufferAll.write('════════════════════════════════════\n\n');
        }
        bufferAll.write(extracted);

        progress.value = (i + 1.0) / total;
      }

      if (isCancelling.value) {
        ocrPages.clear();
        combinedText.value = '';
        isOcrCompleted.value = false;
        statusMessage.value = 'OCR Cancelled';
        currentStep.value = 'Cancelled';
        MyDialogs.info(msg: 'Image OCR cancelled. Pending images skipped.');
      } else {
        combinedText.value = bufferAll.toString().trim();
        isOcrCompleted.value = true;
        currentViewPageIndex.value = 0;
        statusMessage.value = 'Image OCR Completed';
        currentStep.value = 'All images recognized successfully';
        MyDialogs.success(msg: 'Image OCR done! Extracted $totalWords words.');
      }
    } catch (e) {
      log('[ImageOcr] error: $e');
      MyDialogs.info(msg: 'Image OCR Error: $e');
    } finally {
      try {
        await textRecognizer?.close();
      } catch (_) {}
      isProcessing.value = false;
      isCancelling.value = false;
    }
  }

  // ── PDF OCR Engine ────────────────────────────────────────────────────────
  Future<void> _startPdfOcr() async {
    final path = selectedPdfPath.value;
    if (path == null) {
      MyDialogs.info(msg: 'Please select a PDF file first');
      return;
    }

    final pagesToProcess = getResolvedPagesToProcess();
    if (pagesToProcess.isEmpty) {
      MyDialogs.info(msg: 'No pages selected for OCR');
      return;
    }

    isProcessing.value = true;
    isCancelling.value = false;
    progress.value = 0.0;
    totalProcessingPages.value = pagesToProcess.length;
    currentProcessingPage.value = 0;
    currentStep.value = 'Initializing AI OCR Engine...';
    statusMessage.value = 'Starting OCR Extraction...';
    ocrPages.clear();
    combinedText.value = '';

    TextRecognizer? textRecognizer;
    Directory? tempDir;
    final leftoverTempFiles = <File>[];

    try {
      textRecognizer = await _createSafeTextRecognizer();
      tempDir = await getTemporaryDirectory();

      final total = pagesToProcess.length;

      List<String> nativePdfPages = [];
      try {
        final rawNative = await ReadPdfText.getPDFtext(path);
        if (rawNative.trim().isNotEmpty) {
          nativePdfPages = rawNative.split(RegExp(r'\f|\n\n---\s*Page\s*\d+\s*---\n\n'));
        }
      } catch (_) {}

      final bufferAll = StringBuffer();

      for (int i = 0; i < total; i++) {
        if (isCancelling.value) {
          log('[PdfOcr] Cancellation requested. Aborting remaining ${total - i} pages.');
          break;
        }

        final pageIndex = pagesToProcess[i];
        final pageNumber = pageIndex + 1;

        currentProcessingPage.value = i + 1;
        progress.value = i / total;
        currentStep.value = 'Rendering page $pageNumber of ${pageCount.value}...';
        statusMessage.value = 'Processing page $pageNumber (${i + 1}/$total)';

        // 1. High-resolution rendering for OCR
        final page = await _pdfDoc!.getPage(pageNumber);
        final double renderScale = (2200.0 / page.width).clamp(1.5, 3.2);
        final renderWidth = (page.width * renderScale).toDouble();
        final renderHeight = (page.height * renderScale).toDouble();

        final renderedImage = await page.render(
          width: renderWidth,
          height: renderHeight,
          format: PdfPageImageFormat.jpeg,
          quality: 90,
        );
        await page.close();

        if (isCancelling.value) break;

        if (renderedImage == null) continue;

        // 2. Save temporary high-res image for ML Kit
        final tempImagePath =
            '${tempDir.path}/ocr_page_${DateTime.now().millisecondsSinceEpoch}_$pageNumber.jpg';
        final tempImageFile = File(tempImagePath);
        await tempImageFile.writeAsBytes(renderedImage.bytes);
        leftoverTempFiles.add(tempImageFile);

        progress.value = (i + 0.5) / total;
        currentStep.value = 'Running AI Neural OCR on page $pageNumber...';

        if (isCancelling.value) {
          try {
            if (await tempImageFile.exists()) await tempImageFile.delete();
          } catch (_) {}
          break;
        }

        // 3. Process safely with Google ML Kit
        final inputImage = InputImage.fromFilePath(tempImagePath);
        final RecognizedText recognized =
            await _processImageSafe(textRecognizer, inputImage);

        // Delete temporary image immediately to keep memory/cache minimal
        try {
          if (await tempImageFile.exists()) {
            await tempImageFile.delete();
            leftoverTempFiles.remove(tempImageFile);
          }
        } catch (_) {}

        if (isCancelling.value) break;

        String extracted = _formatRecognizedText(recognized);
        final blockTexts = <String>[];
        final blockInfos = <OcrBlockInfo>[];

        double minLeft = double.infinity;
        double minTop = double.infinity;
        double maxRight = double.negativeInfinity;
        double maxBottom = double.negativeInfinity;

        for (final block in recognized.blocks) {
          final t = block.text.trim();
          if (t.isNotEmpty) {
            blockTexts.add(t);
            final box = block.boundingBox;
            blockInfos.add(OcrBlockInfo(text: t, boundingBox: box));
            if (box.left < minLeft) minLeft = box.left;
            if (box.top < minTop) minTop = box.top;
            if (box.right > maxRight) maxRight = box.right;
            if (box.bottom > maxBottom) maxBottom = box.bottom;
          }
        }

        if (extracted.length < 15 && nativePdfPages.isNotEmpty && pageIndex < nativePdfPages.length) {
          final nativeText = nativePdfPages[pageIndex].trim();
          if (nativeText.isNotEmpty) {
            extracted = nativeText;
            if (blockTexts.isEmpty) {
              blockTexts.addAll(nativeText.split('\n\n').where((s) => s.trim().isNotEmpty));
            }
          }
        }

        if (extracted.isEmpty) {
          extracted = '[No readable text detected on Page $pageNumber]';
        }

        final wordCount = RegExp(r'\S+').allMatches(extracted).length;
        final charCount = extracted.length;

        // Calculate overarching Document Bounding Box layer for PDF page
        Rect? docBox;
        if (minLeft != double.infinity && maxRight > minLeft && maxBottom > minTop) {
          final padX = (maxRight - minLeft) * 0.02;
          final padY = (maxBottom - minTop) * 0.02;
          final boundW = renderWidth > 0 ? renderWidth : (maxRight + padX * 2);
          final boundH = renderHeight > 0 ? renderHeight : (maxBottom + padY * 2);
          docBox = Rect.fromLTRB(
            (minLeft - padX).clamp(0.0, boundW),
            (minTop - padY).clamp(0.0, boundH),
            (maxRight + padX).clamp(0.0, boundW),
            (maxBottom + padY).clamp(0.0, boundH),
          );
        }

        final pageItem = OcrPageItem(
          pageIndex: pageIndex,
          pageNumber: pageNumber,
          text: extracted,
          wordCount: wordCount,
          charCount: charCount,
          blocks: blockTexts,
          blockInfos: blockInfos,
          documentBoundingBox: docBox,
          imageWidth: renderWidth,
          imageHeight: renderHeight,
          thumbnailBytes: renderedImage.bytes,
        );

        ocrPages.add(pageItem);

        if (bufferAll.isNotEmpty) bufferAll.write('\n\n--- Page $pageNumber ---\n\n');
        bufferAll.write(extracted);

        progress.value = (i + 1.0) / total;
      }

      if (isCancelling.value) {
        ocrPages.clear();
        combinedText.value = '';
        isOcrCompleted.value = false;
        statusMessage.value = 'OCR Cancelled';
        currentStep.value = 'Cancelled';
        MyDialogs.info(msg: 'OCR cancelled. Pending pages skipped.');
      } else {
        combinedText.value = bufferAll.toString().trim();
        isOcrCompleted.value = true;
        currentViewPageIndex.value = 0;
        statusMessage.value = 'OCR Completed Successfully';
        currentStep.value = 'All pages successfully processed';
        MyDialogs.success(msg: 'OCR completed! Extracted $totalWords words.');
      }
    } catch (e) {
      log('[PdfOcr] OCR error: $e');
      MyDialogs.info(msg: 'OCR Error: $e');
    } finally {
      for (final f in leftoverTempFiles) {
        try {
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      try {
        await textRecognizer?.close();
      } catch (_) {}
      isProcessing.value = false;
      isCancelling.value = false;
    }
  }

  void cancelOcr() {
    isCancelling.value = true;
    currentStep.value = 'Aborting remaining items...';
    statusMessage.value = 'Cancelling...';
  }

  void resetResults() {
    ocrPages.clear();
    combinedText.value = '';
    isOcrCompleted.value = false;
    currentViewPageIndex.value = 0;
    searchQuery.value = '';
    searchController.clear();
  }

  void reset() {
    _stopTts();
    _closeDoc();
    selectedPdfPath.value = null;
    selectedPdfName.value = null;
    pickedImages.clear();
    fileSizeInBytes.value = 0;
    pageCount.value = 0;
    resetResults();
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  Future<void> copyAllText() async {
    final text = combinedText.value;
    if (text.isEmpty) {
      MyDialogs.info(msg: 'No extracted text to copy');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    MyDialogs.success(msg: 'All text copied to clipboard!');
  }

  Future<void> copyCurrentPageText(int index) async {
    if (index < 0 || index >= ocrPages.length) return;
    final text = ocrPages[index].text;
    await Clipboard.setData(ClipboardData(text: text));
    MyDialogs.success(msg: 'Page ${ocrPages[index].pageNumber} text copied!');
  }

  void translateText() {
    final text = combinedText.value.trim();
    if (text.isEmpty) {
      MyDialogs.info(msg: 'No extracted text to translate');
      return;
    }
    Pref.pdfText = text;
    Get.to(() => const TextTranslateTab(hType: HomeType.pdf_translator));
  }

  void translatePageText(int index) {
    if (index < 0 || index >= ocrPages.length) return;
    final text = ocrPages[index].text.trim();
    if (text.isEmpty) {
      MyDialogs.info(msg: 'No text available to translate');
      return;
    }
    Pref.pdfText = text;
    Get.to(() => const TextTranslateTab(hType: HomeType.pdf_translator));
  }

  Future<void> toggleTts() async {
    if (isTtsPlaying.value) {
      await _stopTts();
    } else {
      final text = combinedText.value.trim();
      if (text.isEmpty) {
        MyDialogs.info(msg: 'No text available to read aloud');
        return;
      }
      try {
        isTtsPlaying.value = true;
        await _flutterTts.speak(text);
      } catch (e) {
        isTtsPlaying.value = false;
        MyDialogs.info(msg: 'TTS Error: $e');
      }
    }
  }

  Future<void> _stopTts() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    isTtsPlaying.value = false;
  }

  Future<void> shareExtractedText() async {
    final text = combinedText.value.trim();
    if (text.isEmpty) {
      MyDialogs.info(msg: 'No text to share');
      return;
    }
    final name = selectedPdfName.value ?? 'OCR_Extracted_Text';
    await Share.share(
      text,
      subject: 'OCR Extracted Text - $name',
    );
  }

  // ── Export Formats ─────────────────────────────────────────────────────────
  Future<void> exportAsTxt() async {
    try {
      final text = combinedText.value.trim();
      if (text.isEmpty) {
        MyDialogs.info(msg: 'No text to export');
        return;
      }

      final dir = await getTemporaryDirectory();
      final baseName = (selectedPdfName.value ?? 'OCR_Document')
          .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      final exportPath =
          '${dir.path}/${baseName}_OCR_${DateTime.now().millisecondsSinceEpoch}.txt';

      final file = File(exportPath);
      await file.writeAsString(text, encoding: utf8);

      await Share.shareXFiles(
        [XFile(exportPath, mimeType: 'text/plain')],
        text: 'OCR Extracted Text: $baseName',
      );
      MyDialogs.success(msg: 'TXT file created!');
    } catch (e) {
      MyDialogs.info(msg: 'Export TXT failed: $e');
    }
  }

  Future<void> exportAsPdf() async {
    try {
      if (ocrPages.isEmpty) {
        MyDialogs.info(msg: 'No OCR pages available to export');
        return;
      }

      final pdfDoc = pw.Document();
      final baseName = (selectedPdfName.value ?? 'OCR_Document')
          .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');

      for (final page in ocrPages) {
        pdfDoc.addPage(
          pw.Page(
            pageFormat: pw_pdf.PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        baseName,
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: pw_pdf.PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'Item ${page.pageNumber}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: pw_pdf.PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Divider(thickness: 0.8, color: pw_pdf.PdfColors.grey400),
                  pw.SizedBox(height: 12),
                  pw.Expanded(
                    child: pw.Text(
                      page.text,
                      style: const pw.TextStyle(
                        fontSize: 11,
                        lineSpacing: 2.0,
                      ),
                    ),
                  ),
                  pw.Divider(thickness: 0.5, color: pw_pdf.PdfColors.grey300),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'OCR by Translator App',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: pw_pdf.PdfColors.grey500,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      final dir = await getTemporaryDirectory();
      final exportPath =
          '${dir.path}/${baseName}_OCR_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(exportPath);
      await file.writeAsBytes(await pdfDoc.save());

      await Share.shareXFiles(
        [XFile(exportPath, mimeType: 'application/pdf')],
        text: 'OCR PDF Document: $baseName',
      );
      MyDialogs.success(msg: 'PDF document generated!');
    } catch (e) {
      MyDialogs.info(msg: 'Export PDF failed: $e');
    }
  }

  Future<void> exportAsDocx() async {
    try {
      if (ocrPages.isEmpty) {
        MyDialogs.info(msg: 'No OCR pages available to export');
        return;
      }

      final baseName = (selectedPdfName.value ?? 'OCR_Document')
          .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');

      final archive = Archive();

      const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
      archive.addFile(ArchiveFile(
          '[Content_Types].xml', contentTypes.length, utf8.encode(contentTypes)));

      const rootRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
      archive.addFile(
          ArchiveFile('_rels/.rels', rootRels.length, utf8.encode(rootRels)));

      final docBuffer = StringBuffer();
      docBuffer.write('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
''');

      for (int i = 0; i < ocrPages.length; i++) {
        final page = ocrPages[i];
        if (i > 0) {
          docBuffer.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>\n');
        }

        docBuffer.write(
            '<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:rPr><w:b/><w:color w:val="FF8C42"/></w:rPr><w:t>Item ${page.pageNumber}</w:t></w:r></w:p>\n');

        final lines = page.text.split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) {
            docBuffer.write('<w:p/>\n');
          } else {
            final escaped = _xmlEscape(trimmed);
            docBuffer.write(
                '<w:p><w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Calibri"/></w:rPr><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>\n');
          }
        }
      }

      docBuffer.write('''
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
    </w:sectPr>
  </w:body>
</w:document>''');

      final docXmlBytes = utf8.encode(docBuffer.toString());
      archive.addFile(
          ArchiveFile('word/document.xml', docXmlBytes.length, docXmlBytes));

      final zipData = ZipEncoder().encode(archive);
      final dir = await getTemporaryDirectory();
      final exportPath =
          '${dir.path}/${baseName}_OCR_${DateTime.now().millisecondsSinceEpoch}.docx';
      final file = File(exportPath);
      await file.writeAsBytes(zipData);

      await Share.shareXFiles(
        [
          XFile(exportPath,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
        ],
        text: 'OCR Word Document: $baseName',
      );
      MyDialogs.success(msg: 'Word (.docx) document created!');
    } catch (e) {
      MyDialogs.info(msg: 'Export DOCX failed: $e');
    }
  }

  String _formatRecognizedText(RecognizedText recognized) {
    if (recognized.blocks.isEmpty) {
      return recognized.text.trim();
    }

    final paragraphBuffers = <String>[];

    for (final block in recognized.blocks) {
      if (block.text.trim().isEmpty) continue;

      final lines = block.lines
          .map((l) => l.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (lines.isEmpty) continue;

      final blockBuffer = StringBuffer();
      for (int i = 0; i < lines.length; i++) {
        final currentLine = lines[i];
        if (i == 0) {
          blockBuffer.write(currentLine);
        } else {
          final prevLine = lines[i - 1];
          final isBullet = _isBulletOrNumber(currentLine);
          final prevEndedSentence = prevLine.endsWith('.') ||
              prevLine.endsWith(':') ||
              prevLine.endsWith('?') ||
              prevLine.endsWith('!');

          if (isBullet || prevEndedSentence) {
            blockBuffer.write('\n');
            blockBuffer.write(currentLine);
          } else if (prevLine.endsWith('-')) {
            // De-hyphenate broken word across line break
            final currentBuffer = blockBuffer.toString();
            blockBuffer.clear();
            blockBuffer.write(
                currentBuffer.substring(0, currentBuffer.length - 1));
            blockBuffer.write(currentLine);
          } else {
            // Natural line continuation in paragraph
            blockBuffer.write(' ');
            blockBuffer.write(currentLine);
          }
        }
      }

      final blockText = blockBuffer.toString().trim();
      if (blockText.isNotEmpty) {
        paragraphBuffers.add(blockText);
      }
    }

    return paragraphBuffers.join('\n\n');
  }

  bool _isBulletOrNumber(String line) {
    if (line.startsWith('•') ||
        line.startsWith('-') ||
        line.startsWith('*') ||
        line.startsWith('▪') ||
        line.startsWith('▶') ||
        line.startsWith('○') ||
        line.startsWith('●')) {
      return true;
    }
    if (RegExp(r'^\d+[\.\)]\s+').hasMatch(line) ||
        RegExp(r'^[a-zA-Z][\.\)]\s+').hasMatch(line)) {
      return true;
    }
    return false;
  }

  Future<TextRecognizer> _createSafeTextRecognizer() async {
    try {
      return TextRecognizer(script: TextRecognitionScript.latin);
    } catch (e) {
      log('[PdfOcr] TextRecognizer initialization error: $e');
      return TextRecognizer();
    }
  }

  Future<RecognizedText> _processImageSafe(
    TextRecognizer recognizer,
    InputImage inputImage,
  ) async {
    try {
      return await recognizer.processImage(inputImage);
    } catch (e) {
      log('[PdfOcr] processImage failed with selected script: $e. Retrying with Latin model fallback.');
      TextRecognizer? fallback;
      try {
        fallback = TextRecognizer(script: TextRecognitionScript.latin);
        return await fallback.processImage(inputImage);
      } catch (fallbackError) {
        log('[PdfOcr] Latin fallback also encountered error: $fallbackError');
        return RecognizedText(text: '', blocks: []);
      } finally {
        try {
          await fallback?.close();
        } catch (_) {}
      }
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
}
