// lib/controllers/pdf_sign_controller.dart
import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../ads/ad_helper.dart';
import '../helper/my_dialogs.dart';

// ── Model for Placed Signatures & Stamps on PDF ─────────────────────────────
class PlacedSignatureItem {
  final String id;
  final int pageIndex; // 0-indexed
  Offset position; // relative to rendered page canvas
  double width;
  double height;
  final Uint8List signatureBytes;
  final String label; // 'Signature', 'Initials', 'Date'

  PlacedSignatureItem({
    required this.id,
    required this.pageIndex,
    required this.position,
    required this.width,
    required this.height,
    required this.signatureBytes,
    this.label = 'Signature',
  });

  PlacedSignatureItem copyWith({
    String? id,
    int? pageIndex,
    Offset? position,
    double? width,
    double? height,
    Uint8List? signatureBytes,
    String? label,
  }) {
    return PlacedSignatureItem(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      position: position ?? this.position,
      width: width ?? this.width,
      height: height ?? this.height,
      signatureBytes: signatureBytes ?? this.signatureBytes,
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

class PdfSignController extends GetxController {
  // ── Document State ────────────────────────────────────────────────────────
  final selectedPdfPath = RxnString();
  final selectedPdfName = RxnString();
  final pageCount = 0.obs;
  final currentPageIndex = 0.obs; // 0-indexed
  final fileSizeInBytes = 0.obs;

  final isPicking = false.obs;
  final isRenderingPage = false.obs;
  final isExporting = false.obs;
  final exportProgress = 0.0.obs;
  final exportStatus = ''.obs;

  PdfDocument? _pdfDoc;
  final _pageCache = _LruCache<int, Uint8List>(8);
  final currentPageBytes = Rxn<Uint8List>();
  final currentPageWidth = 595.0.obs; // Default A4 point width
  final currentPageHeight = 842.0.obs; // Default A4 point height

  // ── Signatures State ──────────────────────────────────────────────────────
  final placedSignatures = <PlacedSignatureItem>[].obs;
  final savedSignatures = <Uint8List>[].obs;
  final selectedSignatureId = RxnString();

  // Undo / Redo stacks
  final List<List<PlacedSignatureItem>> _undoStack = [];
  final List<List<PlacedSignatureItem>> _redoStack = [];

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
      log('[PdfSign] pickPdfFile error: $e');
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
      placedSignatures.clear();
      _undoStack.clear();
      _redoStack.clear();
      selectedSignatureId.value = null;

      selectedPdfPath.value = path;
      selectedPdfName.value = path.split(Platform.pathSeparator).last;
      fileSizeInBytes.value = await file.length();

      _pdfDoc = await PdfDocument.openFile(path);
      pageCount.value = _pdfDoc!.pagesCount;
      currentPageIndex.value = 0;

      await renderCurrentPage();
    } catch (e) {
      log('[PdfSign] loadPdf error: $e');
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

      final double scale = (1400.0 / page.width).clamp(1.5, 2.5);
      final rendered = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: PdfPageImageFormat.jpeg,
        quality: 85,
      );
      await page.close();

      if (rendered != null) {
        _pageCache.put(pageNum, rendered.bytes);
        currentPageBytes.value = rendered.bytes;
      }
    } catch (e) {
      log('[PdfSign] renderCurrentPage error: $e');
    } finally {
      isRenderingPage.value = false;
    }
  }

  void goToPage(int index) {
    if (index >= 0 && index < pageCount.value && index != currentPageIndex.value) {
      selectedSignatureId.value = null;
      currentPageIndex.value = index;
      renderCurrentPage();
    }
  }

  // ── 2. Signature Placement ────────────────────────────────────────────────
  void _saveSnapshot() {
    _undoStack.add(placedSignatures.map((e) => e.copyWith()).toList());
    _redoStack.clear();
    if (_undoStack.length > 25) {
      _undoStack.removeAt(0);
    }
  }

  void addSignature(
    Uint8List signatureBytes, {
    double width = 160.0,
    double height = 75.0,
    Offset? position,
    String label = 'Signature',
    bool saveToWallet = true,
  }) {
    _saveSnapshot();

    if (saveToWallet &&
        !savedSignatures.any((b) => b.length == signatureBytes.length)) {
      savedSignatures.add(signatureBytes);
    }

    final pos = position ??
        Offset(
          (currentPageWidth.value - width) / 2,
          currentPageHeight.value * 0.7,
        );

    final item = PlacedSignatureItem(
      id: '${DateTime.now().microsecondsSinceEpoch}_sig',
      pageIndex: currentPageIndex.value,
      position: pos,
      width: width,
      height: height,
      signatureBytes: signatureBytes,
      label: label,
    );

    placedSignatures.add(item);
    selectedSignatureId.value = item.id;
    HapticFeedback.lightImpact();
  }

  // Generate Date Stamp PNG
  Future<void> addDateStamp() async {
    final now = DateTime.now();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr = '${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year}';

    final bytes = await _generateTextStampPng('Date: $dateStr');
    if (bytes != null) {
      addSignature(
        bytes,
        width: 140.0,
        height: 38.0,
        label: 'Date Stamp',
        saveToWallet: false,
      );
    }
  }

  // Generate Initials Stamp PNG
  Future<void> addInitials(String initials) async {
    if (initials.trim().isEmpty) return;
    final bytes = await _generateTextStampPng(initials.trim().toUpperCase());
    if (bytes != null) {
      addSignature(
        bytes,
        width: 90.0,
        height: 55.0,
        label: 'Initials',
        saveToWallet: true,
      );
    }
  }

  Future<Uint8List?> _generateTextStampPng(String text) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(360, 100);

    final textStyle = const TextStyle(
      color: Color(0xFF0F172A),
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    );
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: size.width);

    final offset = Offset(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  // ── 3. Manipulation & Gestures ────────────────────────────────────────────
  void selectSignature(String? id) {
    selectedSignatureId.value = id;
  }

  void updateSignaturePosition(String id, Offset newPos) {
    final idx = placedSignatures.indexWhere((e) => e.id == id);
    if (idx != -1) {
      placedSignatures[idx].position = newPos;
      placedSignatures.refresh();
    }
  }

  void commitSignaturePosition(String id) {
    _saveSnapshot();
  }

  void updateSignatureSize(String id, double width, double height) {
    final idx = placedSignatures.indexWhere((e) => e.id == id);
    if (idx != -1) {
      placedSignatures[idx].width = width.clamp(40.0, 500.0);
      placedSignatures[idx].height = height.clamp(20.0, 400.0);
      placedSignatures.refresh();
    }
  }

  void commitSignatureSize(String id) {
    _saveSnapshot();
  }

  void duplicateSignature(String id) {
    final item = placedSignatures.firstWhereOrNull((e) => e.id == id);
    if (item == null) return;
    _saveSnapshot();
    final dup = item.copyWith(
      id: '${DateTime.now().microsecondsSinceEpoch}_dup',
      position: Offset(item.position.dx + 25, item.position.dy + 25),
    );
    placedSignatures.add(dup);
    selectedSignatureId.value = dup.id;
    HapticFeedback.lightImpact();
  }

  void deleteSignature(String id) {
    _saveSnapshot();
    placedSignatures.removeWhere((e) => e.id == id);
    if (selectedSignatureId.value == id) {
      selectedSignatureId.value = null;
    }
    HapticFeedback.lightImpact();
  }

  void clearCurrentPageSignatures() {
    final pIdx = currentPageIndex.value;
    final count = placedSignatures.where((e) => e.pageIndex == pIdx).length;
    if (count == 0) return;

    _saveSnapshot();
    placedSignatures.removeWhere((e) => e.pageIndex == pIdx);
    selectedSignatureId.value = null;
    MyDialogs.info(msg: 'Removed $count signature(s) on Page ${pIdx + 1}');
  }

  void undo() {
    if (!canUndo) return;
    _redoStack.add(placedSignatures.map((e) => e.copyWith()).toList());
    final prev = _undoStack.removeLast();
    placedSignatures.assignAll(prev);
    selectedSignatureId.value = null;
    HapticFeedback.lightImpact();
  }

  void redo() {
    if (!canRedo) return;
    _undoStack.add(placedSignatures.map((e) => e.copyWith()).toList());
    final next = _redoStack.removeLast();
    placedSignatures.assignAll(next);
    selectedSignatureId.value = null;
    HapticFeedback.lightImpact();
  }

  // ── 4. High-Res Flattened PDF Export ──────────────────────────────────────
  Future<String?> exportSignedPdf() async {
    if (!hasDocument || _pdfDoc == null) {
      MyDialogs.info(msg: 'Please open a PDF document first');
      return null;
    }

    try {
      isExporting.value = true;
      exportProgress.value = 0.0;
      exportStatus.value = 'Preparing high-resolution PDF signer...';

      final totalPages = pageCount.value;
      final pwDoc = pw.Document();

      for (int i = 0; i < totalPages; i++) {
        final pageNum = i + 1;
        exportProgress.value = (i / totalPages) * 0.85;
        exportStatus.value = 'Permanently baking signatures onto page $pageNum of $totalPages...';

        final page = await _pdfDoc!.getPage(pageNum);
        final double nativeWidth = page.width.toDouble();
        final double nativeHeight = page.height.toDouble();

        // High quality render scale
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
        final signaturesOnPage =
            placedSignatures.where((e) => e.pageIndex == i).toList();

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
                  for (final item in signaturesOnPage)
                    pw.Positioned(
                      left: item.position.dx,
                      top: item.position.dy,
                      child: pw.SizedBox(
                        width: item.width,
                        height: item.height,
                        child: pw.Image(
                          pw.MemoryImage(item.signatureBytes),
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      }

      exportProgress.value = 0.95;
      exportStatus.value = 'Finalizing signed document...';

      final outputBytes = await pwDoc.save();
      final tempDir = await getTemporaryDirectory();
      final baseName = selectedPdfName.value?.replaceAll('.pdf', '') ?? 'document';
      final outPath =
          '${tempDir.path}/${baseName}_signed_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outFile = File(outPath);
      await outFile.writeAsBytes(outputBytes, flush: true);

      exportProgress.value = 1.0;
      exportStatus.value = 'Signatures successfully baked!';
      AdHelper.showInterstitialAd(onComplete: () {});
      return outPath;
    } catch (e) {
      log('[PdfSign] exportSignedPdf error: $e');
      MyDialogs.info(msg: 'Failed to export signed PDF: $e');
      return null;
    } finally {
      isExporting.value = false;
    }
  }

  void shareSignedPdf(String path) {
    Share.shareXFiles(
      [XFile(path)],
      subject: 'Signed PDF Document: ${selectedPdfName.value}',
      text: 'Here is the officially signed PDF document.',
    );
  }
}
