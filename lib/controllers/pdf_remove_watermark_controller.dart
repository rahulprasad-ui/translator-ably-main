// lib/controllers/pdf_remove_watermark_controller.dart
import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../helper/my_dialogs.dart';

// ── Watermark Erase Region Model ────────────────────────────────────────────
class WatermarkEraseBox {
  final String id;
  final int pageIndex; // 0-indexed (ignored if applyToAllPages is true)
  Rect rect; // In native PDF point coordinates (0..pageWidth, 0..pageHeight)
  Color fillColor;
  bool applyToAllPages;
  String label;

  WatermarkEraseBox({
    required this.id,
    required this.pageIndex,
    required this.rect,
    this.fillColor = Colors.white,
    this.applyToAllPages = true,
    this.label = 'Watermark',
  });

  WatermarkEraseBox copyWith({
    String? id,
    int? pageIndex,
    Rect? rect,
    Color? fillColor,
    bool? applyToAllPages,
    String? label,
  }) {
    return WatermarkEraseBox(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      rect: rect ?? this.rect,
      fillColor: fillColor ?? this.fillColor,
      applyToAllPages: applyToAllPages ?? this.applyToAllPages,
      label: label ?? this.label,
    );
  }
}

// ── LRU Page Image Cache for 60/120 FPS Rendering ──────────────────────────
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

class PdfRemoveWatermarkController extends GetxController {
  // ── Document State ────────────────────────────────────────────────────────
  final selectedPdfPath = RxnString();
  final selectedPdfName = RxnString();
  final pageCount = 0.obs;
  final currentPageIndex = 0.obs; // 0-indexed
  final fileSizeInBytes = 0.obs;

  final isPicking = false.obs;
  final isRenderingPage = false.obs;
  final isExporting = false.obs;
  final isAutoDetecting = false.obs;
  final exportProgress = 0.0.obs;
  final exportStatus = ''.obs;

  PdfDocument? _pdfDoc;
  final _pageCache = _LruCache<int, Uint8List>(8);
  final currentPageBytes = Rxn<Uint8List>();
  final currentPageWidth = 595.0.obs;
  final currentPageHeight = 842.0.obs;

  // ── Watermark Erase State ─────────────────────────────────────────────────
  final eraseBoxes = <WatermarkEraseBox>[].obs;
  final selectedBoxId = RxnString();
  final isLivePreviewClean = false.obs; // Toggle: show with boxes or clean erased preview
  final selectedColor = const Color(0xFFFFFFFF).obs;

  // Undo / Redo stacks
  final List<List<WatermarkEraseBox>> _undoStack = [];
  final List<List<WatermarkEraseBox>> _redoStack = [];

  bool get hasDocument => selectedPdfPath.value != null && _pdfDoc != null;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  String get formattedFileSize {
    final bytes = fileSizeInBytes.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  void onClose() {
    _pdfDoc?.close();
    _pageCache.clear();
    super.onClose();
  }

  // ── 1. Document Loading ───────────────────────────────────────────────────
  Future<void> pickPdfFile() async {
    try {
      isPicking.value = true;
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isNotEmpty && result.first.path != null) {
        await loadPdf(result.first.path!);
      }
    } catch (e) {
      log('[PdfRemoveWatermark] pickPdfFile error: $e');
      MyDialogs.info(msg: 'Failed to pick PDF: $e');
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> loadPdf(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        MyDialogs.info(msg: 'Selected PDF file does not exist');
        return;
      }

      await _pdfDoc?.close();
      _pageCache.clear();
      eraseBoxes.clear();
      _undoStack.clear();
      _redoStack.clear();
      selectedBoxId.value = null;

      selectedPdfPath.value = path;
      selectedPdfName.value = path.split(Platform.pathSeparator).last;
      fileSizeInBytes.value = await file.length();

      _pdfDoc = await PdfDocument.openFile(path);
      pageCount.value = _pdfDoc!.pagesCount;
      currentPageIndex.value = 0;

      await renderCurrentPage();
    } catch (e) {
      log('[PdfRemoveWatermark] loadPdf error: $e');
      MyDialogs.info(msg: 'Failed to open PDF: $e');
    }
  }

  Future<void> renderCurrentPage() async {
    if (_pdfDoc == null) return;
    final pageNum = currentPageIndex.value + 1;

    final cached = _pageCache.get(pageNum);
    if (cached != null) {
      currentPageBytes.value = cached;
      return;
    }

    try {
      isRenderingPage.value = true;
      final page = await _pdfDoc!.getPage(pageNum);
      currentPageWidth.value = page.width.toDouble();
      currentPageHeight.value = page.height.toDouble();

      final double scale = (1500.0 / page.width).clamp(1.5, 2.5);
      final rendered = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: PdfPageImageFormat.jpeg,
        quality: 88,
      );
      await page.close();

      if (rendered != null) {
        _pageCache.put(pageNum, rendered.bytes);
        currentPageBytes.value = rendered.bytes;
      }
    } catch (e) {
      log('[PdfRemoveWatermark] renderCurrentPage error: $e');
    } finally {
      isRenderingPage.value = false;
    }
  }

  void goToPage(int index) {
    if (index >= 0 && index < pageCount.value && index != currentPageIndex.value) {
      selectedBoxId.value = null;
      currentPageIndex.value = index;
      renderCurrentPage();
    }
  }

  // ── 2. Watermark Erase Box Management ─────────────────────────────────────
  void _saveSnapshot() {
    _undoStack.add(eraseBoxes.map((e) => e.copyWith()).toList());
    _redoStack.clear();
    if (_undoStack.length > 25) {
      _undoStack.removeAt(0);
    }
  }

  void addCustomBox() {
    _saveSnapshot();
    final pW = currentPageWidth.value;
    final pH = currentPageHeight.value;

    final newBox = WatermarkEraseBox(
      id: '${DateTime.now().microsecondsSinceEpoch}_erase',
      pageIndex: currentPageIndex.value,
      rect: Rect.fromLTWH(
        (pW - 200) / 2,
        (pH - 60) / 2,
        200,
        60,
      ),
      fillColor: selectedColor.value,
      applyToAllPages: true,
      label: 'Custom Box',
    );

    eraseBoxes.add(newBox);
    selectedBoxId.value = newBox.id;
    HapticFeedback.lightImpact();
  }

  // Preset 1: Footer Watermark (e.g. CamScanner or page branding band)
  void addFooterWatermarkPreset() {
    _saveSnapshot();
    final pW = currentPageWidth.value;
    final pH = currentPageHeight.value;

    final boxH = (pH * 0.07).clamp(40.0, 75.0);
    final newBox = WatermarkEraseBox(
      id: '${DateTime.now().microsecondsSinceEpoch}_footer',
      pageIndex: currentPageIndex.value,
      rect: Rect.fromLTWH(0, pH - boxH, pW, boxH),
      fillColor: selectedColor.value,
      applyToAllPages: true,
      label: 'Footer Watermark',
    );

    eraseBoxes.add(newBox);
    selectedBoxId.value = newBox.id;
    HapticFeedback.lightImpact();
    MyDialogs.success(msg: 'Footer watermark erase band added to all pages');
  }

  // Preset 2: Header Watermark
  void addHeaderWatermarkPreset() {
    _saveSnapshot();
    final pW = currentPageWidth.value;
    final pH = currentPageHeight.value;

    final boxH = (pH * 0.06).clamp(35.0, 65.0);
    final newBox = WatermarkEraseBox(
      id: '${DateTime.now().microsecondsSinceEpoch}_header',
      pageIndex: currentPageIndex.value,
      rect: Rect.fromLTWH(0, 0, pW, boxH),
      fillColor: selectedColor.value,
      applyToAllPages: true,
      label: 'Header Watermark',
    );

    eraseBoxes.add(newBox);
    selectedBoxId.value = newBox.id;
    HapticFeedback.lightImpact();
    MyDialogs.success(msg: 'Header watermark erase band added to all pages');
  }

  // Preset 3: Center Diagonal / Stamp Watermark
  void addCenterWatermarkPreset() {
    _saveSnapshot();
    final pW = currentPageWidth.value;
    final pH = currentPageHeight.value;

    final boxW = pW * 0.75;
    final boxH = pH * 0.22;
    final newBox = WatermarkEraseBox(
      id: '${DateTime.now().microsecondsSinceEpoch}_center',
      pageIndex: currentPageIndex.value,
      rect: Rect.fromLTWH((pW - boxW) / 2, (pH - boxH) / 2, boxW, boxH),
      fillColor: selectedColor.value,
      applyToAllPages: true,
      label: 'Center Watermark',
    );

    eraseBoxes.add(newBox);
    selectedBoxId.value = newBox.id;
    HapticFeedback.lightImpact();
    MyDialogs.success(msg: 'Center watermark erase box added to all pages');
  }

  // Auto-Detect Watermarks using AI Text Recognition
  Future<void> autoDetectWatermarks({String? customKeyword}) async {
    if (!hasDocument || _pdfDoc == null) return;

    try {
      isAutoDetecting.value = true;
      final pageNum = currentPageIndex.value + 1;
      final page = await _pdfDoc!.getPage(pageNum);

      // Render high quality page for ML Kit
      final rendered = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: PdfPageImageFormat.jpeg,
        quality: 90,
      );
      await page.close();

      if (rendered == null) {
        MyDialogs.info(msg: 'Could not analyze current page');
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_ocr_watermark_$pageNum.jpg');
      await tempFile.writeAsBytes(rendered.bytes);

      final recognizer = TextRecognizer();
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final recognized = await recognizer.processImage(inputImage);
      await recognizer.close();
      try {
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}

      // Common watermark words
      final targetWords = [
        'watermark',
        'camscanner',
        'scanned with',
        'scanned by',
        'draft',
        'confidential',
        'sample',
        'copy',
        'do not copy',
        'trial',
        'demo',
      ];
      if (customKeyword != null && customKeyword.trim().isNotEmpty) {
        targetWords.add(customKeyword.trim().toLowerCase());
      }

      final scaleX = currentPageWidth.value / (page.width * 2.0);
      final scaleY = currentPageHeight.value / (page.height * 2.0);

      int detectedCount = 0;
      _saveSnapshot();

      for (final block in recognized.blocks) {
        final textLower = block.text.toLowerCase();
        final isMatch = targetWords.any((kw) => textLower.contains(kw));

        if (isMatch) {
          final box = block.boundingBox;
          final pad = 6.0;
          final r = Rect.fromLTWH(
            (box.left * scaleX - pad).clamp(0.0, currentPageWidth.value),
            (box.top * scaleY - pad).clamp(0.0, currentPageHeight.value),
            ((box.width * scaleX) + pad * 2)
                .clamp(10.0, currentPageWidth.value),
            ((box.height * scaleY) + pad * 2)
                .clamp(10.0, currentPageHeight.value),
          );

          eraseBoxes.add(
            WatermarkEraseBox(
              id: '${DateTime.now().microsecondsSinceEpoch}_ai_$detectedCount',
              pageIndex: currentPageIndex.value,
              rect: r,
              fillColor: selectedColor.value,
              applyToAllPages: true,
              label: 'Detected: ${block.text.trim()}',
            ),
          );
          detectedCount++;
        }
      }

      if (detectedCount > 0) {
        MyDialogs.success(
            msg: 'Auto-detected and targeted $detectedCount watermark(s)!');
      } else {
        MyDialogs.info(
            msg:
                'No standard watermark text detected. You can use preset buttons or draw custom erase box.');
      }
    } catch (e) {
      log('[PdfRemoveWatermark] autoDetect error: $e');
      MyDialogs.info(msg: 'Auto-detection error: $e');
    } finally {
      isAutoDetecting.value = false;
    }
  }

  void selectBox(String? id) {
    selectedBoxId.value = id;
  }

  void updateBoxPosition(String id, Offset newOffset) {
    final idx = eraseBoxes.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final box = eraseBoxes[idx];
      final clampedL = newOffset.dx.clamp(0.0, currentPageWidth.value - box.rect.width);
      final clampedT = newOffset.dy.clamp(0.0, currentPageHeight.value - box.rect.height);
      eraseBoxes[idx].rect = Rect.fromLTWH(
        clampedL,
        clampedT,
        box.rect.width,
        box.rect.height,
      );
      eraseBoxes.refresh();
    }
  }

  void commitBoxPosition(String id) {
    _saveSnapshot();
  }

  void updateBoxSize(String id, double newWidth, double newHeight) {
    final idx = eraseBoxes.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final box = eraseBoxes[idx];
      final clampedW = newWidth.clamp(20.0, currentPageWidth.value - box.rect.left);
      final clampedH = newHeight.clamp(15.0, currentPageHeight.value - box.rect.top);
      eraseBoxes[idx].rect = Rect.fromLTWH(
        box.rect.left,
        box.rect.top,
        clampedW,
        clampedH,
      );
      eraseBoxes.refresh();
    }
  }

  void commitBoxSize(String id) {
    _saveSnapshot();
  }

  void toggleApplyToAllPages(String id) {
    _saveSnapshot();
    final idx = eraseBoxes.indexWhere((e) => e.id == id);
    if (idx != -1) {
      eraseBoxes[idx].applyToAllPages = !eraseBoxes[idx].applyToAllPages;
      eraseBoxes.refresh();
      HapticFeedback.lightImpact();
    }
  }

  void updateBoxColor(String id, Color newColor) {
    _saveSnapshot();
    final idx = eraseBoxes.indexWhere((e) => e.id == id);
    if (idx != -1) {
      eraseBoxes[idx].fillColor = newColor;
      eraseBoxes.refresh();
    }
  }

  void deleteBox(String id) {
    _saveSnapshot();
    eraseBoxes.removeWhere((e) => e.id == id);
    if (selectedBoxId.value == id) {
      selectedBoxId.value = null;
    }
    HapticFeedback.lightImpact();
  }

  void clearAllBoxes() {
    if (eraseBoxes.isEmpty) return;
    _saveSnapshot();
    eraseBoxes.clear();
    selectedBoxId.value = null;
    HapticFeedback.lightImpact();
    MyDialogs.info(msg: 'All watermark erase boxes cleared');
  }

  void undo() {
    if (!canUndo) return;
    _redoStack.add(eraseBoxes.map((e) => e.copyWith()).toList());
    final prev = _undoStack.removeLast();
    eraseBoxes.assignAll(prev);
    selectedBoxId.value = null;
    HapticFeedback.lightImpact();
  }

  void redo() {
    if (!canRedo) return;
    _undoStack.add(eraseBoxes.map((e) => e.copyWith()).toList());
    final next = _redoStack.removeLast();
    eraseBoxes.assignAll(next);
    selectedBoxId.value = null;
    HapticFeedback.lightImpact();
  }

  // ── 3. High-Quality Watermark-Free PDF Export ──────────────────────────────
  Future<String?> exportWatermarkFreePdf() async {
    if (!hasDocument || _pdfDoc == null) {
      MyDialogs.info(msg: 'Please open a PDF document first');
      return null;
    }

    if (eraseBoxes.isEmpty) {
      MyDialogs.info(
          msg: 'Please add at least one watermark erase box or select a preset');
      return null;
    }

    try {
      isExporting.value = true;
      exportProgress.value = 0.0;
      exportStatus.value = 'Preparing high-resolution PDF cleaner...';

      final totalPages = pageCount.value;
      final pwDoc = pw.Document();

      for (int i = 0; i < totalPages; i++) {
        final pageNum = i + 1;
        exportProgress.value = (i / totalPages) * 0.88;
        exportStatus.value =
            'Permanently erasing watermarks on page $pageNum of $totalPages...';

        final page = await _pdfDoc!.getPage(pageNum);
        final double nativeWidth = page.width.toDouble();
        final double nativeHeight = page.height.toDouble();

        // High quality rendering
        final double renderScale = (2200.0 / nativeWidth).clamp(2.0, 3.2);
        final renderedPage = await page.render(
          width: nativeWidth * renderScale,
          height: nativeHeight * renderScale,
          format: PdfPageImageFormat.jpeg,
          quality: 92,
        );
        await page.close();

        if (renderedPage == null) continue;

        final basePdfImage = pw.MemoryImage(renderedPage.bytes);

        // Filter boxes for this page: either applyToAllPages or pageIndex matches
        final boxesForPage = eraseBoxes
            .where((b) => b.applyToAllPages || b.pageIndex == i)
            .toList();

        pwDoc.addPage(
          pw.Page(
            pageFormat: pw_pdf.PdfPageFormat(nativeWidth, nativeHeight),
            margin: pw.EdgeInsets.zero,
            build: (pw.Context ctx) {
              return pw.Stack(
                children: [
                  pw.Positioned.fill(
                    child: pw.Image(basePdfImage, fit: pw.BoxFit.fill),
                  ),
                  for (final item in boxesForPage)
                    pw.Positioned(
                      left: item.rect.left,
                      top: item.rect.top,
                      child: pw.Container(
                        width: item.rect.width,
                        height: item.rect.height,
                        color: pw_pdf.PdfColor.fromInt(item.fillColor.value),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      }

      exportProgress.value = 0.95;
      exportStatus.value = 'Finalizing clean PDF document...';

      final outputBytes = await pwDoc.save();
      final tempDir = await getTemporaryDirectory();
      final baseName =
          selectedPdfName.value?.replaceAll('.pdf', '') ?? 'document';
      final outPath =
          '${tempDir.path}/${baseName}_no_watermark_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outFile = File(outPath);
      await outFile.writeAsBytes(outputBytes, flush: true);

      exportProgress.value = 1.0;
      exportStatus.value = 'Watermarks successfully removed!';
      return outPath;
    } catch (e) {
      log('[PdfRemoveWatermark] exportWatermarkFreePdf error: $e');
      MyDialogs.info(msg: 'Failed to export clean PDF: $e');
      return null;
    } finally {
      isExporting.value = false;
    }
  }

  void shareCleanPdf(String path) {
    Share.shareXFiles(
      [XFile(path)],
      subject: 'Clean PDF Document (Watermarks Removed): ${selectedPdfName.value}',
      text: 'Here is your clean PDF document with watermarks removed.',
    );
  }
}
