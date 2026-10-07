// lib/controllers/pdf_fill_controller.dart
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

import '../helper/my_dialogs.dart';

// ── Form Element Types ────────────────────────────────────────────────────────
enum PdfFillType {
  text,
  checkmark,
  cross,
  date,
  dot,
  signature,
}

// ── Form Element Model ────────────────────────────────────────────────────────
class PdfFillItem {
  final String id;
  final int pageIndex; // 0-indexed
  final PdfFillType type;
  Offset position; // Offset relative to page canvas (e.g. 0..pageWidth, 0..pageHeight)
  String text;
  double fontSize;
  bool isBold;
  bool isItalic;
  Color color;
  Color? backgroundColor;
  double width;
  double height;
  Uint8List? signaturePngBytes;

  PdfFillItem({
    required this.id,
    required this.pageIndex,
    required this.type,
    required this.position,
    this.text = '',
    this.fontSize = 16.0,
    this.isBold = false,
    this.isItalic = false,
    this.color = Colors.black,
    this.backgroundColor,
    this.width = 120.0,
    this.height = 36.0,
    this.signaturePngBytes,
  });

  PdfFillItem copyWith({
    String? id,
    int? pageIndex,
    PdfFillType? type,
    Offset? position,
    String? text,
    double? fontSize,
    bool? isBold,
    bool? isItalic,
    Color? color,
    Color? backgroundColor,
    double? width,
    double? height,
    Uint8List? signaturePngBytes,
  }) {
    return PdfFillItem(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      type: type ?? this.type,
      position: position ?? this.position,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      width: width ?? this.width,
      height: height ?? this.height,
      signaturePngBytes: signaturePngBytes ?? this.signaturePngBytes,
    );
  }
}

// ── LRU Page Image Cache for Smooth UI ────────────────────────────────────────
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

// ── Async Mutex Lock ─────────────────────────────────────────────────────────
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

class PdfFillController extends GetxController {
  // Document State
  final selectedPdfPath = RxnString();
  final selectedPdfName = RxnString();
  final fileSizeInBytes = 0.obs;
  final pageCount = 0.obs;
  final currentPageIndex = 0.obs;

  // Processing & Loading State
  final isPicking = false.obs;
  final isRenderingPage = false.obs;
  final isExporting = false.obs;
  final exportProgress = 0.0.obs;
  final exportStatus = 'Preparing document...'.obs;

  // Placed Elements
  final fillItems = <PdfFillItem>[].obs;
  final selectedItemId = RxnString();

  // Undo / Redo History
  final List<List<PdfFillItem>> _undoStack = [];
  final List<List<PdfFillItem>> _redoStack = [];
  final canUndo = false.obs;
  final canRedo = false.obs;

  // Page Dimensions & Cache
  final pageSizes = <int, Size>{}.obs;
  final pageDisplaySizes = <int, Size>{}.obs;
  final _pageRenderCache = _LruCache<int, Uint8List>(6);
  final _thumbCache = _LruCache<int, Uint8List>(25);
  final _AsyncLock _renderLock = _AsyncLock();

  // Saved Signatures for quick reuse
  final savedSignatures = <Uint8List>[].obs;

  // Active Tool Mode
  final activeTool = PdfFillType.text.obs;

  // Exported file path
  final exportedPdfPath = RxnString();

  PdfDocument? _pdfDoc;

  @override
  void onClose() {
    _closeDoc();
    super.onClose();
  }

  bool get hasDocument => selectedPdfPath.value != null && pageCount.value > 0;

  PdfFillItem? get selectedItem {
    final id = selectedItemId.value;
    if (id == null) return null;
    try {
      return fillItems.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  List<PdfFillItem> get currentPageItems {
    final page = currentPageIndex.value;
    return fillItems.where((item) => item.pageIndex == page).toList();
  }

  // ── Document Loading ───────────────────────────────────────────────────────
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
      log('[PdfFill] Error picking PDF: $e');
      MyDialogs.info(msg: 'Could not open PDF file. Please try again.');
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> loadPdf(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      MyDialogs.info(msg: 'Selected PDF file does not exist');
      return;
    }

    try {
      _closeDoc();
      selectedPdfPath.value = path;
      selectedPdfName.value = file.uri.pathSegments.last;
      fileSizeInBytes.value = await file.length();

      _pdfDoc = await PdfDocument.openFile(path);
      pageCount.value = _pdfDoc!.pagesCount;
      currentPageIndex.value = 0;

      fillItems.clear();
      _undoStack.clear();
      _redoStack.clear();
      _updateHistoryState();
      selectedItemId.value = null;
      exportedPdfPath.value = null;

      // Preload page size of page 1
      await getPageSize(0);
    } catch (e) {
      log('[PdfFill] Error loading PDF: $e');
      MyDialogs.info(msg: 'Failed to open PDF: $e');
      reset();
    }
  }

  void _closeDoc() {
    _pageRenderCache.clear();
    _thumbCache.clear();
    pageSizes.clear();
    try {
      _pdfDoc?.close();
    } catch (_) {}
    _pdfDoc = null;
  }

  void reset() {
    _closeDoc();
    selectedPdfPath.value = null;
    selectedPdfName.value = null;
    fileSizeInBytes.value = 0;
    pageCount.value = 0;
    currentPageIndex.value = 0;
    fillItems.clear();
    _undoStack.clear();
    _redoStack.clear();
    _updateHistoryState();
    selectedItemId.value = null;
    exportedPdfPath.value = null;
  }

  void registerPageDisplaySize(int pageIndex, Size size) {
    pageDisplaySizes[pageIndex] = size;
  }

  // ── Page Size & Rendering ──────────────────────────────────────────────────
  Future<Size> getPageSize(int pageIndex) async {
    if (pageSizes.containsKey(pageIndex)) {
      return pageSizes[pageIndex]!;
    }
    if (_pdfDoc == null) return const Size(595, 842); // standard A4

    try {
      final page = await _pdfDoc!.getPage(pageIndex + 1);
      final size = Size(page.width, page.height);
      pageSizes[pageIndex] = size;
      await page.close();
      return size;
    } catch (e) {
      return const Size(595, 842);
    }
  }

  Future<Uint8List?> renderPageImage(int pageIndex, {double targetWidth = 1080}) async {
    if (_pageRenderCache.containsKey(pageIndex)) {
      return _pageRenderCache.get(pageIndex);
    }

    if (_pdfDoc == null) return null;

    return await _renderLock.synchronized(() async {
      if (_pageRenderCache.containsKey(pageIndex)) {
        return _pageRenderCache.get(pageIndex);
      }
      try {
        final page = await _pdfDoc!.getPage(pageIndex + 1);
        final scale = (targetWidth / page.width).clamp(1.0, 3.0);
        final renderWidth = (page.width * scale).toDouble();
        final renderHeight = (page.height * scale).toDouble();

        final pageImage = await page.render(
          width: renderWidth,
          height: renderHeight,
          format: PdfPageImageFormat.jpeg,
          quality: 88,
        );
        await page.close();

        if (pageImage != null) {
          _pageRenderCache.put(pageIndex, pageImage.bytes);
          return pageImage.bytes;
        }
      } catch (e) {
        log('[PdfFill] Error rendering page $pageIndex: $e');
      }
      return null;
    });
  }

  Future<Uint8List?> getThumbnail(int pageIndex) async {
    if (_thumbCache.containsKey(pageIndex)) {
      return _thumbCache.get(pageIndex);
    }
    if (_pdfDoc == null) return null;

    try {
      final page = await _pdfDoc!.getPage(pageIndex + 1);
      final scale = 140.0 / page.width;
      final thumb = await page.render(
        width: 140,
        height: page.height * scale,
        format: PdfPageImageFormat.jpeg,
        quality: 65,
      );
      await page.close();
      if (thumb != null) {
        _thumbCache.put(pageIndex, thumb.bytes);
        return thumb.bytes;
      }
    } catch (_) {}
    return null;
  }

  // ── History (Undo / Redo) ──────────────────────────────────────────────────
  void _saveSnapshot() {
    _undoStack.add(fillItems.map((e) => e.copyWith()).toList());
    if (_undoStack.length > 30) _undoStack.removeAt(0);
    _redoStack.clear();
    _updateHistoryState();
  }

  void _updateHistoryState() {
    canUndo.value = _undoStack.isNotEmpty;
    canRedo.value = _redoStack.isNotEmpty;
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(fillItems.map((e) => e.copyWith()).toList());
    final prev = _undoStack.removeLast();
    fillItems.assignAll(prev);
    selectedItemId.value = null;
    _updateHistoryState();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(fillItems.map((e) => e.copyWith()).toList());
    final next = _redoStack.removeLast();
    fillItems.assignAll(next);
    selectedItemId.value = null;
    _updateHistoryState();
  }

  // ── Add Elements to Canvas ─────────────────────────────────────────────────
  void addTextField({Offset? atPosition, String initialText = 'Type text here'}) {
    _saveSnapshot();
    final pos = atPosition ?? const Offset(40, 60);
    final newItem = PdfFillItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      pageIndex: currentPageIndex.value,
      type: PdfFillType.text,
      position: pos,
      text: initialText,
      fontSize: 16.0,
      width: 150.0,
      height: 38.0,
      color: Colors.black,
    );
    fillItems.add(newItem);
    selectedItemId.value = newItem.id;
  }

  void addCheckmark({Offset? atPosition}) {
    _saveSnapshot();
    final pos = atPosition ?? const Offset(40, 60);
    final newItem = PdfFillItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      pageIndex: currentPageIndex.value,
      type: PdfFillType.checkmark,
      position: pos,
      text: '✓',
      fontSize: 22.0,
      width: 36.0,
      height: 36.0,
      color: const Color(0xFF0D9488), // Teal green checkmark
    );
    fillItems.add(newItem);
    selectedItemId.value = newItem.id;
  }

  void addCross({Offset? atPosition}) {
    _saveSnapshot();
    final pos = atPosition ?? const Offset(40, 60);
    final newItem = PdfFillItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      pageIndex: currentPageIndex.value,
      type: PdfFillType.cross,
      position: pos,
      text: '✕',
      fontSize: 20.0,
      width: 36.0,
      height: 36.0,
      color: const Color(0xFFDC2626), // Red cross
    );
    fillItems.add(newItem);
    selectedItemId.value = newItem.id;
  }

  void addRadioDot({Offset? atPosition}) {
    _saveSnapshot();
    final pos = atPosition ?? const Offset(40, 60);
    final newItem = PdfFillItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      pageIndex: currentPageIndex.value,
      type: PdfFillType.dot,
      position: pos,
      text: '●',
      fontSize: 18.0,
      width: 32.0,
      height: 32.0,
      color: Colors.black87,
    );
    fillItems.add(newItem);
    selectedItemId.value = newItem.id;
  }

  void addDateStamp({Offset? atPosition, String? customDate}) {
    _saveSnapshot();
    final pos = atPosition ?? const Offset(40, 60);
    final now = DateTime.now();
    final formattedDate = customDate ??
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final newItem = PdfFillItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      pageIndex: currentPageIndex.value,
      type: PdfFillType.date,
      position: pos,
      text: formattedDate,
      fontSize: 15.0,
      width: 120.0,
      height: 34.0,
      color: const Color(0xFF1E293B),
    );
    fillItems.add(newItem);
    selectedItemId.value = newItem.id;
  }

  void addSignature(Uint8List signatureBytes, {Offset? atPosition}) {
    _saveSnapshot();
    final pos = atPosition ?? const Offset(40, 80);

    // Save to quick reuse list if not already present
    if (!savedSignatures.any((bytes) => bytes.length == signatureBytes.length)) {
      savedSignatures.add(signatureBytes);
    }

    final newItem = PdfFillItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      pageIndex: currentPageIndex.value,
      type: PdfFillType.signature,
      position: pos,
      width: 160.0,
      height: 70.0,
      signaturePngBytes: signatureBytes,
    );
    fillItems.add(newItem);
    selectedItemId.value = newItem.id;
  }

  // ── Element Manipulation ───────────────────────────────────────────────────
  void selectItem(String? id) {
    selectedItemId.value = id;
  }

  void updateItemPosition(String id, Offset newPosition) {
    final idx = fillItems.indexWhere((e) => e.id == id);
    if (idx != -1) {
      fillItems[idx].position = newPosition;
      fillItems.refresh();
    }
  }

  void commitItemPosition(String id) {
    _saveSnapshot();
  }

  void updateItemSize(String id, double width, double height) {
    final idx = fillItems.indexWhere((e) => e.id == id);
    if (idx != -1) {
      fillItems[idx].width = width.clamp(24.0, 500.0);
      fillItems[idx].height = height.clamp(20.0, 500.0);
      fillItems.refresh();
    }
  }

  void commitItemSize(String id) {
    _saveSnapshot();
  }

  void updateItemText(String id, String newText) {
    _saveSnapshot();
    final idx = fillItems.indexWhere((e) => e.id == id);
    if (idx != -1) {
      fillItems[idx].text = newText;
      fillItems.refresh();
    }
  }

  void updateItemFontSize(String id, double newSize) {
    _saveSnapshot();
    final idx = fillItems.indexWhere((e) => e.id == id);
    if (idx != -1) {
      fillItems[idx].fontSize = newSize.clamp(8.0, 48.0);
      fillItems.refresh();
    }
  }

  void updateItemColor(String id, Color newColor) {
    _saveSnapshot();
    final idx = fillItems.indexWhere((e) => e.id == id);
    if (idx != -1) {
      fillItems[idx].color = newColor;
      fillItems.refresh();
    }
  }

  void toggleItemBold(String id) {
    _saveSnapshot();
    final idx = fillItems.indexWhere((e) => e.id == id);
    if (idx != -1) {
      fillItems[idx].isBold = !fillItems[idx].isBold;
      fillItems.refresh();
    }
  }

  void toggleItemItalic(String id) {
    _saveSnapshot();
    final idx = fillItems.indexWhere((e) => e.id == id);
    if (idx != -1) {
      fillItems[idx].isItalic = !fillItems[idx].isItalic;
      fillItems.refresh();
    }
  }

  void duplicateItem(String id) {
    final item = fillItems.firstWhereOrNull((e) => e.id == id);
    if (item == null) return;
    _saveSnapshot();
    final duplicated = item.copyWith(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      position: Offset(item.position.dx + 20, item.position.dy + 20),
    );
    fillItems.add(duplicated);
    selectedItemId.value = duplicated.id;
  }

  void deleteItem(String id) {
    _saveSnapshot();
    fillItems.removeWhere((e) => e.id == id);
    if (selectedItemId.value == id) {
      selectedItemId.value = null;
    }
  }

  void clearCurrentPage() {
    final page = currentPageIndex.value;
    final itemsOnPage = fillItems.where((e) => e.pageIndex == page).toList();
    if (itemsOnPage.isEmpty) return;

    _saveSnapshot();
    fillItems.removeWhere((e) => e.pageIndex == page);
    selectedItemId.value = null;
    MyDialogs.info(msg: 'Cleared all items on page ${page + 1}');
  }

  // ── High Quality Pixel-Perfect WYSIWYG PDF Export ────────────────────────
  Future<String?> exportFilledPdf() async {
    if (!hasDocument || _pdfDoc == null) {
      MyDialogs.info(msg: 'Please open a PDF first');
      return null;
    }

    try {
      isExporting.value = true;
      exportProgress.value = 0.0;
      exportStatus.value = 'Preparing high-resolution PDF rendering...';

      final totalPages = pageCount.value;
      final pwDoc = pw.Document();

      for (int i = 0; i < totalPages; i++) {
        final pageNum = i + 1;
        exportProgress.value = (i / totalPages) * 0.88;
        exportStatus.value =
            'Baking page $pageNum of $totalPages (signatures & fields)...';

        final page = await _pdfDoc!.getPage(pageNum);
        final pageWidthPt = page.width;
        final pageHeightPt = page.height;

        // 1. Exact display canvas size where the user positioned their elements
        final displaySize =
            pageDisplaySizes[i] ?? Size(pageWidthPt, pageHeightPt);

        // 2. High-res target resolution (2000px width for 300+ DPI razor sharpness)
        final double renderScale =
            (2000.0 / displaySize.width).clamp(1.5, 3.5);
        final int targetW = (displaySize.width * renderScale).round();
        final int targetH = (displaySize.height * renderScale).round();

        // 3. Render base PDF page image
        final pageImage = await page.render(
          width: targetW.toDouble(),
          height: targetH.toDouble(),
          format: PdfPageImageFormat.jpeg,
          quality: 94,
        );
        await page.close();

        if (pageImage == null) continue;

        // 4. Decode base image into Flutter UI Image for Canvas composition
        final ui.Codec baseCodec =
            await ui.instantiateImageCodec(pageImage.bytes);
        final ui.FrameInfo baseFrame = await baseCodec.getNextFrame();
        final ui.Image baseImg = baseFrame.image;

        // 5. Setup PictureRecorder & Canvas (exact Flutter engine WYSIWYG)
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder,
            Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()));

        // Draw base PDF image
        canvas.drawImageRect(
          baseImg,
          Rect.fromLTWH(
              0, 0, baseImg.width.toDouble(), baseImg.height.toDouble()),
          Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
          Paint()..filterQuality = FilterQuality.high,
        );

        // 6. Draw all items on this page
        final itemsOnThisPage =
            fillItems.where((e) => e.pageIndex == i).toList();

        for (final item in itemsOnThisPage) {
          final scale = targetW / displaySize.width;
          final itemX = item.position.dx * scale;
          final itemY = item.position.dy * scale;
          final itemW = item.width * scale;
          final itemH = item.height * scale;
          final fontSize = item.fontSize * scale;

          if (item.type == PdfFillType.signature &&
              item.signaturePngBytes != null) {
            try {
              final ui.Codec sigCodec =
                  await ui.instantiateImageCodec(item.signaturePngBytes!);
              final ui.FrameInfo sigFrame = await sigCodec.getNextFrame();
              final ui.Image sigImg = sigFrame.image;

              canvas.drawImageRect(
                sigImg,
                Rect.fromLTWH(
                    0, 0, sigImg.width.toDouble(), sigImg.height.toDouble()),
                Rect.fromLTWH(itemX, itemY, itemW, itemH),
                Paint()..filterQuality = FilterQuality.high,
              );
            } catch (e) {
              log('[PdfFill] Error drawing signature: $e');
            }
          } else if (item.type == PdfFillType.checkmark) {
            // Crisp Vector Checkmark
            final p = Paint()
              ..color = item.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = (itemH * 0.12).clamp(3.0, 12.0)
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round;

            final path = Path();
            path.moveTo(itemX + itemW * 0.18, itemY + itemH * 0.52);
            path.lineTo(itemX + itemW * 0.42, itemY + itemH * 0.76);
            path.lineTo(itemX + itemW * 0.82, itemY + itemH * 0.22);
            canvas.drawPath(path, p);
          } else if (item.type == PdfFillType.cross) {
            // Crisp Vector Cross
            final p = Paint()
              ..color = item.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = (itemH * 0.12).clamp(3.0, 12.0)
              ..strokeCap = StrokeCap.round;

            final pad = itemW * 0.22;
            canvas.drawLine(
              Offset(itemX + pad, itemY + pad),
              Offset(itemX + itemW - pad, itemY + itemH - pad),
              p,
            );
            canvas.drawLine(
              Offset(itemX + itemW - pad, itemY + pad),
              Offset(itemX + pad, itemY + itemH - pad),
              p,
            );
          } else if (item.type == PdfFillType.dot) {
            // Crisp Vector Radio Dot
            final radius = (itemW * 0.32).clamp(3.0, itemW * 0.45);
            canvas.drawCircle(
              Offset(itemX + itemW * 0.5, itemY + itemH * 0.5),
              radius,
              Paint()
                ..color = item.color
                ..style = PaintingStyle.fill,
            );
          } else {
            // Text / Date Stamp with exact font styling & vertical alignment
            final tp = TextPainter(
              text: TextSpan(
                text: item.text,
                style: TextStyle(
                  color: item.color,
                  fontSize: fontSize,
                  fontWeight:
                      item.isBold ? FontWeight.bold : FontWeight.normal,
                  fontStyle:
                      item.isItalic ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              textDirection: TextDirection.ltr,
            );
            tp.layout(maxWidth: (targetW - itemX).clamp(10.0, targetW.toDouble()));

            final textOffsetY =
                itemY + ((itemH - tp.height) / 2).clamp(0.0, itemH);
            tp.paint(canvas, Offset(itemX, textOffsetY));
          }
        }

        // 7. Render combined canvas image to high quality PNG bytes
        final picture = recorder.endRecording();
        final compositeImg = await picture.toImage(targetW, targetH);
        final byteData =
            await compositeImg.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) continue;

        final bakedPngBytes = byteData.buffer.asUint8List();
        final pwImage = pw.MemoryImage(bakedPngBytes);

        // 8. Add full bleed high-res page to PDF
        pwDoc.addPage(
          pw.Page(
            pageFormat: pw_pdf.PdfPageFormat(pageWidthPt, pageHeightPt),
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(pwImage, fit: pw.BoxFit.fill),
              );
            },
          ),
        );
      }

      exportProgress.value = 0.94;
      exportStatus.value = 'Finalizing PDF output file...';

      final outputBytes = await pwDoc.save();
      final tempDir = await getTemporaryDirectory();
      final baseName =
          selectedPdfName.value?.replaceAll('.pdf', '') ?? 'Document';
      final outPath =
          '${tempDir.path}/${baseName}_FILLED_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outFile = File(outPath);
      await outFile.writeAsBytes(outputBytes);

      exportedPdfPath.value = outPath;
      exportProgress.value = 1.0;
      exportStatus.value = 'Complete!';

      return outPath;
    } catch (e) {
      log('[PdfFill] Error exporting filled PDF: $e');
      MyDialogs.info(msg: 'Export failed: $e');
      return null;
    } finally {
      isExporting.value = false;
    }
  }

  // ── Sharing & Output Actions ──────────────────────────────────────────────
  Future<void> shareFilledPdf() async {
    final path = exportedPdfPath.value;
    if (path == null || !File(path).existsSync()) {
      final generated = await exportFilledPdf();
      if (generated == null) return;
    }

    try {
      await Share.shareXFiles(
        [XFile(exportedPdfPath.value!, mimeType: 'application/pdf')],
        text: 'Filled PDF: ${selectedPdfName.value}',
      );
    } catch (e) {
      MyDialogs.info(msg: 'Sharing failed: $e');
    }
  }
}
