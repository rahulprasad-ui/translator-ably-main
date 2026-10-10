// lib/controllers/pdf_editor_controller.dart
//
// Performance-first PDF Editor Controller
// ─────────────────────────────────────────
// ✅ Stream/path based – original PDF bytes never fully loaded into RAM
// ✅ LRU page cache (max 8 pages) – older pages disposed automatically
// ✅ Lazy rendering – only visible ± 2 pages are rendered
// ✅ Render-job cancellation – stale render requests are dropped
// ✅ Isolate-based heavy processing – off the UI thread
// ✅ Overlay-based editing – text/drawing stored as state, applied on export
// ✅ Low-res thumbnails – independent LRU thumbnail cache (max 30)
// ✅ Memory management – dispose rendered images & temp files on exit

import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:read_pdf_text/read_pdf_text.dart';

import '../services/pdf_export_isolate.dart';
import '../services/pdf_native_text_service.dart';

// ── Editor Modes & Overlay models ─────────────────────────────────────────────
enum EditorMode { view, edit, annotate, sign, fillOut }

enum OverlayType { text, drawing, highlight, signature, image, formField }

class PdfDetectedTextElement {
  final String id;
  final String text;
  final Rect boundingBox;
  final double sourceWidth;
  final double sourceHeight;
  final double fontSize;
  final String fontName;
  final Color textColor;
  final double baseline;
  final bool isBold;
  final bool isItalic;
  final bool isNativePdfText;
  final int pageIndex;

  PdfDetectedTextElement({
    String? id,
    required this.text,
    required this.boundingBox,
    double? imageWidth,
    double? imageHeight,
    double? sourceWidth,
    double? sourceHeight,
    this.fontSize = 14.0,
    this.fontName = 'Helvetica',
    this.textColor = Colors.black,
    double? baseline,
    this.isBold = false,
    this.isItalic = false,
    this.isNativePdfText = false,
    this.pageIndex = 0,
  })  : id = id ?? 'elem_${text.hashCode}_${boundingBox.left.toInt()}_${boundingBox.top.toInt()}',
        sourceWidth = sourceWidth ?? (imageWidth ?? 1080.0),
        sourceHeight = sourceHeight ?? (imageHeight ?? 1920.0),
        baseline = baseline ?? (boundingBox.bottom);

  // Backward compatibility getters
  double get imageWidth => sourceWidth;
  double get imageHeight => sourceHeight;

  Rect getScaledRect(Size targetSize) {
    if (sourceWidth <= 0 || sourceHeight <= 0) return boundingBox;
    final scaleX = targetSize.width / sourceWidth;
    final scaleY = targetSize.height / sourceHeight;
    return Rect.fromLTRB(
      boundingBox.left * scaleX,
      boundingBox.top * scaleY,
      boundingBox.right * scaleX,
      boundingBox.bottom * scaleY,
    );
  }
}

class PdfOverlay {
  final String id;
  final int pageIndex;
  final OverlayType type;
  Offset position;
  Size size;
  String? text;
  Color color;
  Color? backgroundColor;
  double fontSize;
  bool isBold;
  bool isItalic;
  bool isUnderline;
  TextAlign textAlign;
  String fontFamily;
  List<Offset>? strokes;
  String? imagePath;
  Uint8List? imageBytes;

  // Vector replacement & original text tracking
  PdfDetectedTextElement? originalDetectedElement;
  String? originalText;
  String? savedText; // Phase 3: committed in-memory edited text
  double? originalPdfX;
  double? originalPdfY;
  double? originalPdfW;
  double? originalPdfH;
  double? originalLayoutPageWidth;
  double? originalLayoutPageHeight;
  bool coverOriginal;

  PdfOverlay({
    required this.id,
    required this.pageIndex,
    required this.type,
    required this.position,
    this.size = const Size(180, 50),
    this.text,
    this.savedText,
    this.color = Colors.black,
    this.backgroundColor = Colors.transparent,
    this.fontSize = 15,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.textAlign = TextAlign.left,
    this.fontFamily = 'Roboto',
    this.strokes,
    this.imagePath,
    this.imageBytes,
    this.originalDetectedElement,
    this.originalText,
    this.originalPdfX,
    this.originalPdfY,
    this.originalPdfW,
    this.originalPdfH,
    this.originalLayoutPageWidth,
    this.originalLayoutPageHeight,
    this.coverOriginal = true,
  }) {
    savedText ??= text;
  }

  PdfOverlay copyWith({
    String? id,
    int? pageIndex,
    OverlayType? type,
    Offset? position,
    Size? size,
    String? text,
    String? savedText,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    TextAlign? textAlign,
    String? fontFamily,
    List<Offset>? strokes,
    String? imagePath,
    Uint8List? imageBytes,
    PdfDetectedTextElement? originalDetectedElement,
    String? originalText,
    double? originalPdfX,
    double? originalPdfY,
    double? originalPdfW,
    double? originalPdfH,
    double? originalLayoutPageWidth,
    double? originalLayoutPageHeight,
    bool? coverOriginal,
  }) {
    return PdfOverlay(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      type: type ?? this.type,
      position: position ?? this.position,
      size: size ?? this.size,
      text: text ?? this.text,
      savedText: savedText ?? this.savedText,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontSize: fontSize ?? this.fontSize,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      textAlign: textAlign ?? this.textAlign,
      fontFamily: fontFamily ?? this.fontFamily,
      strokes: strokes ?? (this.strokes != null ? List.from(this.strokes!) : null),
      imagePath: imagePath ?? this.imagePath,
      imageBytes: imageBytes ?? this.imageBytes,
      originalDetectedElement: originalDetectedElement ?? this.originalDetectedElement,
      originalText: originalText ?? this.originalText,
      originalPdfX: originalPdfX ?? this.originalPdfX,
      originalPdfY: originalPdfY ?? this.originalPdfY,
      originalPdfW: originalPdfW ?? this.originalPdfW,
      originalPdfH: originalPdfH ?? this.originalPdfH,
      originalLayoutPageWidth: originalLayoutPageWidth ?? this.originalLayoutPageWidth,
      originalLayoutPageHeight: originalLayoutPageHeight ?? this.originalLayoutPageHeight,
      coverOriginal: coverOriginal ?? this.coverOriginal,
    );
  }
}

// ── LRU cache ────────────────────────────────────────────────────────────────
/// One search hit located in the extracted document text.
class SearchHit {
  const SearchHit({required this.pageIndex, required this.lineIndex});

  final int pageIndex;
  final int lineIndex;

  @override
  bool operator ==(Object other) =>
      other is SearchHit &&
      other.pageIndex == pageIndex &&
      other.lineIndex == lineIndex;

  @override
  int get hashCode => Object.hash(pageIndex, lineIndex);
}

// ── LRU cache ────────────────────────────────────────────────────────────────
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

// ── Async Mutex / Lock ────────────────────────────────────────────────────────
class _AsyncLock {
  Future<void>? _last;

  Future<T> synchronized<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final prev = _last;
    _last = completer.future;

    return Future<T>(() async {
      if (prev != null) {
        try {
          await prev;
        } catch (_) {}
      }
      try {
        return await action();
      } finally {
        completer.complete();
      }
    });
  }
}

// ── Controller ────────────────────────────────────────────────────────────────
class PdfEditorController extends GetxController {
  // ── Search state ───────────────────────────────────────────────────────

  /// One search hit: which page, and which text line on it.
  final searchHits = <SearchHit>[].obs;
  final searchQuery = ''.obs;
  final currentHitIndex = (-1).obs;
  final isSearching = false.obs;

  List<String>? _pdfTextCache;

  void clearSearch() {
    searchHits.clear();
    searchQuery.value = '';
    currentHitIndex.value = -1;
  }

  /// Extracts the PDF's text once (per open document) and scans it for every
  /// case-insensitive occurrence of [query]. `read_pdf_text` returns text
  /// paginated by page.
  Future<void> searchPdf(String query) async {
    final path = pdfPath;
    if (path == null || query.trim().isEmpty) return;

    isSearching.value = true;
    searchQuery.value = query;
    try {
      _pdfTextCache ??= await ReadPdfText.getPDFtextPaginated(path);
      final pages = _pdfTextCache ?? const <String>[];

      final needle = query.trim().toLowerCase();
      final hits = <SearchHit>[];
      for (var i = 0; i < pages.length; i++) {
        final lines = pages[i].split('\n');
        for (var line = 0; line < lines.length; line++) {
          final hay = lines[line].toLowerCase();
          var from = 0;
          while (true) {
            final at = hay.indexOf(needle, from);
            if (at < 0) break;
            hits.add(SearchHit(pageIndex: i, lineIndex: line));
            from = at + needle.length;
            if (hits.length >= 200) break; // safety cap for pathological docs
          }
          if (hits.length >= 200) break;
        }
        if (hits.length >= 200) break;
      }

      searchHits.assignAll(hits);
      currentHitIndex.value = hits.isEmpty ? -1 : 0;
    } catch (e) {
      log('[PdfEditor] searchPdf: $e');
      searchHits.assignAll(const <SearchHit>[]);
      currentHitIndex.value = -1;
    } finally {
      isSearching.value = false;
    }
  }

  Future<int> findAndReplaceText(String findQuery, String replaceText) async {
    final path = pdfPath;
    if (path == null || findQuery.trim().isEmpty) return 0;

    isSearching.value = true;
    try {
      _pdfTextCache ??= await ReadPdfText.getPDFtextPaginated(path);
      final pages = _pdfTextCache ?? const <String>[];
      final needle = findQuery.trim().toLowerCase();
      int count = 0;

      for (var i = 0; i < pages.length; i++) {
        final lines = pages[i].split('\n');
        for (var lineIdx = 0; lineIdx < lines.length; lineIdx++) {
          final lineContent = lines[lineIdx];
          if (lineContent.toLowerCase().contains(needle)) {
            final totalLines = math.max(1, lines.length);
            final pageH = _lastKnownPageHeight ?? 750.0;
            final approxY = (lineIdx / totalLines) * (pageH * 0.88) + 36.0;

            recordHistory();
            final newId = 'replace_${DateTime.now().millisecondsSinceEpoch}_$count';
            final overlay = PdfOverlay(
              id: newId,
              pageIndex: i,
              type: OverlayType.text,
              position: Offset(40, approxY),
              size: Size(math.max(200.0, replaceText.length * 11.0 + 24.0), 38),
              text: replaceText,
              color: Colors.black87,
              backgroundColor: Colors.white,
              fontSize: 15,
            );
            overlays.add(overlay);
            selectedOverlayId.value = newId;
            count++;
          }
        }
      }

      if (count > 0) {
        setEditorMode(EditorMode.edit);
        Get.snackbar(
          'Replaced Successfully',
          'Found and replaced $count instance(s) of "$findQuery" with "$replaceText". Drag handles to fine-tune placement.',
          backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.95),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
        );
      } else {
        Get.snackbar(
          'Not Found',
          'Could not find "$findQuery" in this document.',
          backgroundColor: Colors.black87,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
      }
      return count;
    } catch (e) {
      log('[PdfEditor] findAndReplaceText error: $e');
      return 0;
    } finally {
      isSearching.value = false;
    }
  }

  SearchHit? get currentHit =>
      (currentHitIndex.value >= 0 && currentHitIndex.value < searchHits.length)
          ? searchHits[currentHitIndex.value]
          : null;

  SearchHit? nextHit() {
    if (searchHits.isEmpty) return null;
    currentHitIndex.value = (currentHitIndex.value + 1) % searchHits.length;
    return currentHit;
  }

  SearchHit? previousHit() {
    if (searchHits.isEmpty) return null;
    currentHitIndex.value =
        (currentHitIndex.value - 1 + searchHits.length) % searchHits.length;
    return currentHit;
  }

  // ── Annotation settings ────────────────────────────────────────────────
  final strokeWidth = 3.0.obs;

  // ── Observables ────────────────────────────────────────────────────────
  final isLoading = false.obs;
  final hasError = false.obs;
  final pageCount = 0.obs;
  final currentPage = 0.obs;
  final isToolbarVisible = true.obs;
  final activeOverlayType = Rx<OverlayType?>(null);
  final overlays = <PdfOverlay>[].obs;
  final isSaving = false.obs;
  final thumbnailReadyPages = RxSet<int>({});

  // ── Mode & Selection State (matches client video frames) ───────────────────
  final editorMode = EditorMode.view.obs;
  final editSubTab = 0.obs; // 0: Edit text, 1: Insert text, 2: Insert Images
  final selectedOverlayId = Rx<String?>(null);
  /// Exact text item selected in Phase 2
  final selectedTextElement = Rx<PdfDetectedTextElement?>(null);
  /// Active inline editing overlay ID in Phase 3
  final activeEditingOverlayId = Rx<String?>(null);
  final isNightMode = false.obs;

  // ── Undo / Redo History ───────────────────────────────────────────────────
  final undoStack = <List<PdfOverlay>>[].obs;
  final redoStack = <List<PdfOverlay>>[].obs;

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  // ── Active Overlay Formatting Helpers ─────────────────────────────────────
  PdfOverlay? get selectedOverlay {
    final id = selectedOverlayId.value;
    if (id == null) return null;
    return overlays.firstWhereOrNull((o) => o.id == id);
  }

  // ── Private ────────────────────────────────────────────────────────────────
  PdfDocument? _document;
  String? pdfPath;
  ScrollController? scrollController;

  /// Native engine lock: serializes all getPage and render calls
  /// Android PdfRenderer does NOT allow multiple concurrent pages open!
  final _pdfLock = _AsyncLock();

  /// LRU page cache – max 4 full-resolution rendered pages
  final _pageCache = _LruCache<int, PdfPageImage>(4, onEvict: (_) {
    log('[LRU-page] evicted one page image');
  });

  /// LRU thumbnail cache – max 30 low-res images (Uint8List bytes)
  final _thumbCache = _LruCache<int, Uint8List>(30, onEvict: (_) {
    log('[LRU-thumb] evicted one thumbnail');
  });

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    scrollController = ScrollController();
  }

  // ── Document Text Detection (for tap-to-edit existing PDF text) ───────────
  final detectedPageTexts = <int, List<PdfDetectedTextElement>>{}.obs;
  final isDetectingText = false.obs;
  TextRecognizer? _textRecognizer;

  TextRecognizer _getTextRecognizer() {
    _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _textRecognizer!;
  }

  Future<List<PdfDetectedTextElement>> detectTextOnPage(int pageIndex) async {
    if (detectedPageTexts.containsKey(pageIndex)) {
      return detectedPageTexts[pageIndex]!;
    }
    if (_document == null && pdfPath == null) return [];

    try {
      isDetectingText.value = true;

      // 1. Try native PDFBox vector text extraction first
      if (pdfPath != null) {
        try {
          final nativeData = await NativePdfTextService.extractTextElements(
            pdfPath: pdfPath!,
            pageIndex: pageIndex,
          );

          if (nativeData.isNotEmpty) {
            final List<PdfDetectedTextElement> elements = [];
            for (var i = 0; i < nativeData.length; i++) {
              final raw = nativeData[i];
              final text = (raw['text'] as String?)?.trim() ?? '';
              if (text.isEmpty) continue;

              final x = (raw['x'] as num).toDouble();
              final y = (raw['y'] as num).toDouble();
              final w = (raw['width'] as num).toDouble();
              final h = (raw['height'] as num).toDouble();
              final pw = (raw['pageWidth'] as num).toDouble();
              final ph = (raw['pageHeight'] as num).toDouble();
              final fontSize = (raw['fontSize'] as num?)?.toDouble() ?? 14.0;
              final fontName = (raw['fontName'] as String?) ?? 'Helvetica';
              final rawColorInt = (raw['color'] as num?)?.toInt();
              Color parsedColor = const Color(0xFF1E293B);
              if (rawColorInt != null) {
                final unsigned = rawColorInt & 0xFFFFFFFF;
                final withAlpha = (unsigned & 0xFF000000) == 0 ? (0xFF000000 | unsigned) : unsigned;
                final c = Color(withAlpha);
                if (c.alpha > 40 && !(c.red > 240 && c.green > 240 && c.blue > 240)) {
                  parsedColor = c;
                }
              }
              final baseline = (raw['baseline'] as num?)?.toDouble() ?? (y + h);
              final isBold = raw['isBold'] as bool? ?? false;
              final isItalic = raw['isItalic'] as bool? ?? false;
              final id = (raw['id'] as String?) ?? 'pdf_${pageIndex}_$i';

              elements.add(PdfDetectedTextElement(
                id: id,
                text: text,
                boundingBox: Rect.fromLTWH(x, y, w, h),
                sourceWidth: pw,
                sourceHeight: ph,
                fontSize: fontSize,
                fontName: fontName,
                textColor: parsedColor,
                baseline: baseline,
                isBold: isBold,
                isItalic: isItalic,
                isNativePdfText: true,
                pageIndex: pageIndex,
              ));
            }

            if (elements.isNotEmpty) {
              print('[PdfEditor] Extracted ${elements.length} native vector text elements on page $pageIndex');
              detectedPageTexts[pageIndex] = elements;
              detectedPageTexts.refresh();
              return elements;
            }
          }
        } catch (e) {
          print('[PdfEditor] Native text extraction exception on page $pageIndex: $e');
        }
      }

      // 2. Fallback to ML Kit OCR for scanned image-only PDFs
      print('[PdfEditor] Fallback to ML Kit OCR on page $pageIndex...');
      final pageImage = await getPageImage(pageIndex);
      if (pageImage == null || pageImage.bytes.isEmpty) return [];

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/ocr_detect_${pageIndex}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(pageImage.bytes);

      final inputImage = InputImage.fromFilePath(tempFile.path);
      final recognized = await _getTextRecognizer().processImage(inputImage);

      try {
        await tempFile.delete();
      } catch (_) {}

      final List<PdfDetectedTextElement> elements = [];
      final imgW = (pageImage.width ?? 1080).toDouble();
      final imgH = (pageImage.height ?? 1920).toDouble();

      var ocrIdx = 0;
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          for (final elem in line.elements) {
            final t = elem.text.trim();
            if (t.isNotEmpty) {
              elements.add(PdfDetectedTextElement(
                id: 'ocr_${pageIndex}_${ocrIdx++}',
                text: t,
                boundingBox: elem.boundingBox,
                sourceWidth: imgW,
                sourceHeight: imgH,
                isNativePdfText: false,
                pageIndex: pageIndex,
              ));
            }
          }
          if (line.elements.length > 1) {
            final lineText = line.text.trim();
            if (lineText.isNotEmpty) {
              elements.add(PdfDetectedTextElement(
                id: 'ocr_line_${pageIndex}_${ocrIdx++}',
                text: lineText,
                boundingBox: line.boundingBox,
                sourceWidth: imgW,
                sourceHeight: imgH,
                isNativePdfText: false,
                pageIndex: pageIndex,
              ));
            }
          }
        }
      }

      print('[PdfEditor] Extracted ${elements.length} OCR text elements on page $pageIndex');
      detectedPageTexts[pageIndex] = elements;
      detectedPageTexts.refresh();
      return elements;
    } catch (e) {
      print('[PdfEditor] detectTextOnPage error: $e');
      detectedPageTexts[pageIndex] = [];
      return [];
    } finally {
      isDetectingText.value = false;
    }
  }

  /// Exact text item hit-testing (Phase 2):
  /// 1. Prioritizes exact bounding box containment.
  /// 2. If multiple items contain the tap (e.g. line vs word), selects the most specific (smallest area).
  /// 3. If tap falls just outside the boundaries, checks within [tolerance] (default 4.0 logical pts)
  ///    and picks the closest item to the tap position, avoiding false matches across distant lines.
  PdfDetectedTextElement? findDetectedTextAtPosition({
    required int pageIndex,
    required Offset tapPos,
    required Size pageSize,
    double tolerance = 16.0,
  }) {
    final list = detectedPageTexts[pageIndex];
    if (list == null || list.isEmpty) return null;

    PdfDetectedTextElement? bestExactMatch;
    double minExactArea = double.infinity;

    PdfDetectedTextElement? bestTolerantMatch;
    double minTolerantDistance = double.infinity;
    double minTolerantArea = double.infinity;

    for (final elem in list) {
      final scaled = elem.getScaledRect(pageSize);

      // Exact containment test
      if (scaled.contains(tapPos)) {
        final area = scaled.width * scaled.height;
        if (area < minExactArea) {
          minExactArea = area;
          bestExactMatch = elem;
        }
      } else if (bestExactMatch == null) {
        // Tolerant hit-test (inflated rectangle for finger precision)
        final hitRect = Rect.fromLTRB(
          scaled.left - math.max(tolerance, 24.0),
          scaled.top - tolerance,
          scaled.right + math.max(tolerance, 24.0),
          scaled.bottom + tolerance,
        );
        if (hitRect.contains(tapPos)) {
          // Distance from tap position to the closest edge of the rectangle
          final dx = (tapPos.dx < scaled.left)
              ? (scaled.left - tapPos.dx)
              : (tapPos.dx > scaled.right ? tapPos.dx - scaled.right : 0.0);
          final dy = (tapPos.dy < scaled.top)
              ? (scaled.top - tapPos.dy)
              : (tapPos.dy > scaled.bottom ? tapPos.dy - scaled.bottom : 0.0);
          final dist = math.sqrt(dx * dx + dy * dy);
          final area = scaled.width * scaled.height;

          if (dist < minTolerantDistance ||
              ((dist - minTolerantDistance).abs() < 1.0 && area < minTolerantArea)) {
            minTolerantDistance = dist;
            minTolerantArea = area;
            bestTolerantMatch = elem;
          }
        }
      }
    }

    final result = bestExactMatch ?? bestTolerantMatch;

    if (result != null) {
      final scaled = result.getScaledRect(pageSize);
      print('[PdfEditor] Hit text: "${result.text}" at tapPos: $tapPos, page: $pageIndex, '
          'sourceBox: ${result.boundingBox}, scaledBox: $scaled, isNative: ${result.isNativePdfText}');
    }

    return result;
  }

  /// Selects a specific detected text item (Phase 2 red bounding box selection)
  void selectTextElement(PdfDetectedTextElement? element) {
    if (activeEditingOverlayId.value != null &&
        (element == null || activeEditingOverlayId.value != element.id)) {
      cancelActiveInlineEditing();
    }
    selectedTextElement.value = element;
    if (element == null) {
      selectedOverlayId.value = null;
    }
  }

  // ── Phase 3: Inline Text Editing State Management ───────────────────────────
  bool isOverlayEditing(String id) => activeEditingOverlayId.value == id;

  /// Starts inline text editing mode for the given overlay
  void startInlineEditing(String overlayId) {
    activeEditingOverlayId.value = overlayId;
    selectedOverlayId.value = overlayId;
  }

  /// Saves the user's draft text to the in-memory editing state
  void saveInlineEditing(String overlayId, String newText) {
    final idx = overlays.indexWhere((o) => o.id == overlayId);
    if (idx >= 0) {
      recordHistory();
      final current = overlays[idx];
      current.savedText = newText;
      current.text = newText;
      current.backgroundColor = Colors.white; // Covers original text seamlessly
      overlays.refresh();
      log('[PdfEditor] SAVED INLINE EDIT: id=$overlayId, text="$newText"');
    }
    if (activeEditingOverlayId.value == overlayId) {
      activeEditingOverlayId.value = null;
    }
  }

  /// Cancels unsaved changes and restores the previously saved (or original) text
  void cancelInlineEditing(String overlayId) {
    final idx = overlays.indexWhere((o) => o.id == overlayId);
    if (idx >= 0) {
      final current = overlays[idx];
      final restored = current.savedText ?? current.originalText ?? '';
      current.text = restored;
      if (current.savedText == current.originalText) {
        current.backgroundColor = Colors.transparent;
      }
      overlays.refresh();
      log('[PdfEditor] CANCELLED INLINE EDIT: id=$overlayId, restored="$restored"');
    }
    if (activeEditingOverlayId.value == overlayId) {
      activeEditingOverlayId.value = null;
    }
  }

  /// Cancels any currently active inline editing session without saving
  void cancelActiveInlineEditing() {
    final activeId = activeEditingOverlayId.value;
    if (activeId != null) {
      cancelInlineEditing(activeId);
    }
  }

  /// Adobe Acrobat "Edit PDF" flow:
  /// Tapping existing text immediately selects it, frames it with a red bounding box,
  /// and enables in-place editing.
  PdfOverlay selectOrStartEditingText({
    required int pageIndex,
    required PdfDetectedTextElement detectedElement,
    required Size pageSize,
  }) {
    recordHistory();
    selectedTextElement.value = detectedElement;
    final scaledRect = detectedElement.getScaledRect(pageSize);

    log('[PdfEditor] SELECT EXISTING TEXT: page=$pageIndex, text="${detectedElement.text}", '
        'native=${detectedElement.isNativePdfText}, pdfBox=${detectedElement.boundingBox}, '
        'scaledRect=$scaledRect, pageSize=$pageSize');

    // Check if an overlay already exists for this element
    final existingIndex = overlays.indexWhere((o) =>
        o.pageIndex == pageIndex &&
        (o.id == detectedElement.id ||
            (o.originalDetectedElement?.id == detectedElement.id) ||
            ((o.position - Offset(scaledRect.left, scaledRect.top)).distance < 5.0 &&
                o.originalText == detectedElement.text)));

    if (existingIndex >= 0) {
      final existing = overlays[existingIndex];
      selectedOverlayId.value = existing.id;
      return existing;
    }

    final scale = detectedElement.sourceWidth > 0
        ? pageSize.width / detectedElement.sourceWidth
        : 1.0;
    final displayFontSize = (detectedElement.fontSize * scale).clamp(5.0, 72.0);

    final overlay = PdfOverlay(
      id: detectedElement.id,
      pageIndex: pageIndex,
      type: OverlayType.text,
      position: Offset(scaledRect.left - 1.0, scaledRect.top - 1.0),
      size: Size(
        scaledRect.width + 2.0,
        math.max(scaledRect.height + 2.0, displayFontSize * 1.15),
      ),
      text: detectedElement.text,
      savedText: detectedElement.text,
      color: detectedElement.textColor,
      backgroundColor: Colors.transparent, // Stays transparent until user actually edits
      fontSize: displayFontSize,
      isBold: detectedElement.isBold,
      isItalic: detectedElement.isItalic,
      fontFamily: detectedElement.fontName,
      originalDetectedElement: detectedElement,
      originalText: detectedElement.text,
      originalPdfX: detectedElement.isNativePdfText ? detectedElement.boundingBox.left : null,
      originalPdfY: detectedElement.isNativePdfText ? detectedElement.boundingBox.top : null,
      originalPdfW: detectedElement.isNativePdfText ? detectedElement.boundingBox.width : null,
      originalPdfH: detectedElement.isNativePdfText ? detectedElement.boundingBox.height : null,
      originalLayoutPageWidth: pageSize.width,
      originalLayoutPageHeight: pageSize.height,
      coverOriginal: true,
    );

    overlays.add(overlay);
    selectedOverlayId.value = overlay.id;
    return overlay;
  }

  @override
  void onClose() {
    _closeDocument();
    try {
      _textRecognizer?.close();
      _textRecognizer = null;
    } catch (_) {}
    scrollController?.dispose();
    scrollController = null;
    super.onClose();
  }

  void _closeDocument() {
    _pageCache.clear();
    _thumbCache.clear();
    detectedPageTexts.clear();
    selectedTextElement.value = null;
    selectedOverlayId.value = null;
    try {
      _document?.close();
    } catch (_) {}
    _document = null;
    log('[PdfEditor] document closed & caches cleared');
  }

  // ── File picking ──────────────────────────────────────────────────────────
  Future<void> pickAndOpen() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (files.isEmpty || files.first.path == null) return;
      await openPdf(files.first.path!);
    } catch (e) {
      hasError.value = true;
      log('[PdfEditor] pickAndOpen: $e');
    }
  }

  Future<void> openPdf(String path) async {
    try {
      isLoading.value = true;
      hasError.value = false;
      _closeDocument();
      overlays.clear();
      thumbnailReadyPages.clear();

      pdfPath = path;
      _pdfTextCache = null; // fresh text for the newly opened document
      clearSearch();
      _document = await PdfDocument.openFile(path);
      pageCount.value = _document!.pagesCount;
      currentPage.value = 0;
      isLoading.value = false;
      print('[PdfEditor] opened: $path | pages: ${pageCount.value}');
      detectTextOnPage(0);
    } catch (e) {
      isLoading.value = false;
      hasError.value = true;
      log('[PdfEditor] openPdf: $e');
    }
  }

  // ── Page image rendering (lazy + serialized + LRU cached) ──────────────────
  Future<PdfPageImage?> getPageImage(int pageIndex) async {
    if (_document == null) return null;

    // Cache hit – no re-render needed
    final cached = _pageCache.get(pageIndex);
    if (cached != null) return cached;

    return _pdfLock.synchronized<PdfPageImage?>(() async {
      // Re-check cache inside lock
      final cachedInside = _pageCache.get(pageIndex);
      if (cachedInside != null) return cachedInside;

      if (_document == null) return null;

      PdfPage? page;
      try {
        page = await _document!.getPage(pageIndex + 1); // pdfx is 1-based
        final double scale = (1080.0 / page.width).clamp(1.0, 2.0);
        final img = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: PdfPageImageFormat.jpeg,
          quality: 80,
          backgroundColor: '#ffffff',
        );

        if (img != null) {
          _pageCache.put(pageIndex, img);
        }
        return img;
      } catch (e) {
        log('[PdfEditor] getPageImage($pageIndex) error: $e');
        return null;
      } finally {
        try {
          await page?.close();
        } catch (_) {}
      }
    });
  }

  // ── Thumbnail rendering (serialized + low res) ─────────────────────────────
  Future<Uint8List?> getThumbnail(int pageIndex) async {
    if (_thumbCache.containsKey(pageIndex)) {
      return _thumbCache.get(pageIndex);
    }
    if (_document == null) return null;

    return _pdfLock.synchronized<Uint8List?>(() async {
      if (_thumbCache.containsKey(pageIndex)) {
        return _thumbCache.get(pageIndex);
      }
      if (_document == null) return null;

      PdfPage? page;
      try {
        page = await _document!.getPage(pageIndex + 1);
        final img = await page.render(
          width: 150,
          height: (150 * page.height / page.width).round().toDouble(),
          format: PdfPageImageFormat.jpeg,
          backgroundColor: '#ffffff',
          quality: 60,
        );

        if (img?.bytes != null) {
          _thumbCache.put(pageIndex, img!.bytes);
          thumbnailReadyPages.add(pageIndex);
          return img.bytes;
        }
      } catch (e) {
        log('[PdfEditor] getThumbnail($pageIndex) error: $e');
      } finally {
        try {
          await page?.close();
        } catch (_) {}
      }
      return null;
    });
  }

  // ── History & Undo/Redo ──────────────────────────────────────────────────
  void recordHistory() {
    undoStack.add(overlays.map((o) => o.copyWith()).toList());
    redoStack.clear();
  }

  void undo() {
    if (undoStack.isEmpty) return;
    redoStack.add(overlays.map((o) => o.copyWith()).toList());
    final prev = undoStack.removeLast();
    overlays.assignAll(prev);
  }

  void redo() {
    if (redoStack.isEmpty) return;
    undoStack.add(overlays.map((o) => o.copyWith()).toList());
    final next = redoStack.removeLast();
    overlays.assignAll(next);
  }

  void setEditorMode(EditorMode mode) {
    editorMode.value = mode;
    if (mode == EditorMode.annotate || mode == EditorMode.sign) {
      selectedOverlayId.value = null;
      selectedTextElement.value = null;
    } else {
      detectTextOnPage(currentPage.value);
    }
  }

  void setEditSubTab(int index) {
    editSubTab.value = index;
  }

  void toggleNightMode() {
    isNightMode.value = !isNightMode.value;
  }

  void selectOverlay(String? id) {
    if (activeEditingOverlayId.value != null && activeEditingOverlayId.value != id) {
      cancelActiveInlineEditing();
    }
    selectedOverlayId.value = id;
    if (id != null) {
      selectedTextElement.value = null;
    }
  }

  // ── Overlay management ─────────────────────────────────────────────────────
  void addTextOverlay(
    int pageIndex,
    Offset position,
    String text, {
    Color color = Colors.black,
    double fontSize = 15,
    bool isBold = false,
    TextAlign textAlign = TextAlign.left,
    String fontFamily = 'Roboto',
  }) {
    recordHistory();
    final newId = 'txt_${DateTime.now().millisecondsSinceEpoch}';
    overlays.add(PdfOverlay(
      id: newId,
      pageIndex: pageIndex,
      type: OverlayType.text,
      position: position,
      size: const Size(220, 56),
      text: text,
      color: color,
      fontSize: fontSize,
      isBold: isBold,
      textAlign: textAlign,
      fontFamily: fontFamily,
    ));
    selectedOverlayId.value = newId;
  }

  PdfOverlay replaceDetectedText({
    required int pageIndex,
    required PdfDetectedTextElement element,
    required Size pageSize,
    required String newText,
    Color color = Colors.black87,
    String fontFamily = 'Roboto',
    bool isBold = false,
  }) {
    recordHistory();
    final scaled = element.getScaledRect(pageSize);
    final overlayId = element.id;

    // Remove any existing overlay for this element to prevent duplication
    overlays.removeWhere((o) =>
        o.id == overlayId ||
        o.id == 'replace_${element.text.hashCode}_$pageIndex' ||
        o.originalDetectedElement?.id == element.id);

    final scale = element.sourceWidth > 0
        ? pageSize.width / element.sourceWidth
        : 1.0;
    final displayFontSize = element.fontSize > 0
        ? (element.fontSize * scale).clamp(8.0, 72.0)
        : (scaled.height * 0.78).clamp(10.0, 48.0);
    final charRatio = newText.length / math.max(1, element.text.length);
    final estimatedWidth = math.max(scaled.width * charRatio + 16, scaled.width + 8);

    final overlay = PdfOverlay(
      id: overlayId,
      pageIndex: pageIndex,
      type: OverlayType.text,
      position: Offset(scaled.left - 1.0, scaled.top - 1.0),
      size: Size(
        math.max(32.0, estimatedWidth),
        math.max(18.0, scaled.height + 4.0),
      ),
      text: newText,
      color: color,
      backgroundColor: Colors.white,
      fontSize: displayFontSize,
      fontFamily: element.fontName.isNotEmpty ? element.fontName : fontFamily,
      isBold: isBold || element.isBold,
      isItalic: element.isItalic,
      originalDetectedElement: element,
      originalText: element.text,
      originalPdfX: element.isNativePdfText ? element.boundingBox.left : null,
      originalPdfY: element.isNativePdfText ? element.boundingBox.top : null,
      originalPdfW: element.isNativePdfText ? element.boundingBox.width : null,
      originalPdfH: element.isNativePdfText ? element.boundingBox.height : null,
      originalLayoutPageWidth: pageSize.width,
      originalLayoutPageHeight: pageSize.height,
      coverOriginal: true,
    );

    overlays.add(overlay);
    selectedOverlayId.value = overlayId;
    return overlay;
  }

  void addImageOverlay(
    int pageIndex,
    Offset position,
    Uint8List bytes,
    String path,
  ) {
    recordHistory();
    final newId = 'img_${DateTime.now().millisecondsSinceEpoch}';
    overlays.add(PdfOverlay(
      id: newId,
      pageIndex: pageIndex,
      type: OverlayType.image,
      position: position,
      size: const Size(180, 140),
      imageBytes: bytes,
      imagePath: path,
    ));
    selectedOverlayId.value = newId;
  }

  void addHighlightOverlay(
    int pageIndex,
    Rect rect,
    Color color,
  ) {
    recordHistory();
    overlays.add(PdfOverlay(
      id: 'hl_${DateTime.now().millisecondsSinceEpoch}',
      pageIndex: pageIndex,
      type: OverlayType.highlight,
      position: rect.topLeft,
      size: rect.size,
      color: color,
    ));
  }

  void addDrawingOverlay(int pageIndex, List<Offset> strokes, Color color) {
    recordHistory();
    overlays.add(PdfOverlay(
      id: 'drw_${DateTime.now().millisecondsSinceEpoch}',
      pageIndex: pageIndex,
      type: OverlayType.drawing,
      position: strokes.isNotEmpty ? strokes.first : Offset.zero,
      strokes: strokes,
      color: color,
      size: Size(strokeWidth.value, strokeWidth.value),
    ));
  }

  void removeOverlay(String id) {
    recordHistory();
    overlays.removeWhere((o) => o.id == id);
    if (selectedOverlayId.value == id) selectedOverlayId.value = null;
  }

  void updateOverlayPosition(String id, Offset newPos) {
    final idx = overlays.indexWhere((o) => o.id == id);
    if (idx != -1) {
      overlays[idx].position = newPos;
      overlays.refresh();
    }
  }

  void updateOverlaySize(String id, Size newSize) {
    final idx = overlays.indexWhere((o) => o.id == id);
    if (idx != -1) {
      overlays[idx].size = newSize;
      overlays.refresh();
    }
  }

  void updateOverlayText(String id, String newText) {
    final idx = overlays.indexWhere((o) => o.id == id);
    if (idx != -1) {
      overlays[idx].text = newText;
      overlays.refresh();
    }
  }

  void toggleBold(String id) {
    final idx = overlays.indexWhere((o) => o.id == id);
    if (idx != -1) {
      recordHistory();
      overlays[idx].isBold = !overlays[idx].isBold;
      overlays.refresh();
    }
  }

  void increaseFontSize(String id) {
    final idx = overlays.indexWhere((o) => o.id == id);
    if (idx != -1) {
      recordHistory();
      overlays[idx].fontSize = (overlays[idx].fontSize + 2).clamp(8.0, 72.0);
      overlays.refresh();
    }
  }

  void decreaseFontSize(String id) {
    final idx = overlays.indexWhere((o) => o.id == id);
    if (idx != -1) {
      recordHistory();
      overlays[idx].fontSize = (overlays[idx].fontSize - 2).clamp(8.0, 72.0);
      overlays.refresh();
    }
  }

  void setOverlayColor(String id, Color color) {
    final idx = overlays.indexWhere((o) => o.id == id);
    if (idx != -1) {
      recordHistory();
      overlays[idx].color = color;
      overlays.refresh();
    }
  }

  void setOverlayAlignment(String id, TextAlign align) {
    final idx = overlays.indexWhere((o) => o.id == id);
    if (idx != -1) {
      recordHistory();
      overlays[idx].textAlign = align;
      overlays.refresh();
    }
  }

  void setOverlayFontFamily(String id, String family) {
    final idx = overlays.indexWhere((o) => o.id == id);
    if (idx != -1) {
      recordHistory();
      overlays[idx].fontFamily = family;
      overlays.refresh();
    }
  }

  void toggleItalic(String id) {
    final idx = overlays.indexWhere((o) => o.id == id);
    if (idx != -1) {
      recordHistory();
      overlays[idx].isItalic = !overlays[idx].isItalic;
      overlays.refresh();
    }
  }

  void toggleUnderline(String id) {
    final idx = overlays.indexWhere((o) => o.id == id);
    if (idx != -1) {
      recordHistory();
      overlays[idx].isUnderline = !overlays[idx].isUnderline;
      overlays.refresh();
    }
  }

  void toggleBackgroundWhiteout(String id) {
    final idx = overlays.indexWhere((o) => o.id == id);
    if (idx != -1) {
      recordHistory();
      if (overlays[idx].backgroundColor == null ||
          overlays[idx].backgroundColor == Colors.transparent) {
        overlays[idx].backgroundColor = Colors.white;
      } else {
        overlays[idx].backgroundColor = Colors.transparent;
      }
      overlays.refresh();
    }
  }

  void duplicateOverlay(String id) {
    final item = overlays.firstWhereOrNull((o) => o.id == id);
    if (item == null) return;
    recordHistory();
    final duplicated = item.copyWith(
      id: '${item.type.name}_${DateTime.now().microsecondsSinceEpoch}',
      position: Offset(item.position.dx + 20, item.position.dy + 20),
    );
    overlays.add(duplicated);
    selectedOverlayId.value = duplicated.id;
  }

  void addWhiteoutOverlay(int pageIndex, Rect rect) {
    recordHistory();
    final newId = 'wo_${DateTime.now().millisecondsSinceEpoch}';
    overlays.add(PdfOverlay(
      id: newId,
      pageIndex: pageIndex,
      type: OverlayType.highlight,
      position: rect.topLeft,
      size: rect.size,
      color: Colors.white,
    ));
    selectedOverlayId.value = newId;
  }

  /// Adds a signature from the drawn pad. Coordinates arrive in *pad* space,
  /// so they're normalized to the pad size and remapped into *page* space at a
  /// default width — placing it roughly where it was drawn. The user then
  /// drags/resizes it like any other overlay.
  void addSignatureOverlay({
    required int pageIndex,
    required List<Offset> padPoints,
    required Size padSize,
    Color color = Colors.indigo,
  }) {
    final real = padPoints.where((p) => p != Offset.zero).toList();
    if (real.isEmpty || padSize.isEmpty) return;

    double minX = real.first.dx, maxX = minX, minY = real.first.dy, maxY = minY;
    for (final p in real.skip(1)) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    if (maxX <= minX || maxY <= minY) return;

    // Center the ink block where it was drawn in the pad, scaled to a
    // reasonable page size.
    const defaultWidth = 180.0;
    final inkW = maxX - minX;
    final inkH = maxY - minY;
    final scale = defaultWidth / inkW;

    // Keep strokes local to the ink bounds; Offset.zero stays the separator.
    final strokes = <Offset>[
      for (final p in padPoints)
        p == Offset.zero
            ? Offset.zero
            : Offset(p.dx - minX, p.dy - minY),
    ];

    recordHistory();
    final newId = 'sig_${DateTime.now().millisecondsSinceEpoch}';
    overlays.add(PdfOverlay(
      id: newId,
      pageIndex: pageIndex,
      type: OverlayType.signature,
      position: Offset(minX, minY),
      size: Size(defaultWidth, inkH * scale),
      strokes: strokes,
      color: color,
    ));
    selectedOverlayId.value = newId;
  }

  List<PdfOverlay> overlaysForPage(int pageIndex) =>
      overlays.where((o) => o.pageIndex == pageIndex).toList();

  // ── Export ─────────────────────────────────────────────────────────────────
  Future<String?> exportWithOverlays() async {
    if (pdfPath == null) return null;
    isSaving.value = true;

    try {
      final tmpDir = await getTemporaryDirectory();
      final outPath =
          '${tmpDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // 1. If any overlays are text edits, attempt native vector modification to preserve vector fidelity
      final textReplacements = overlays
          .where((o) => o.type == OverlayType.text)
          .toList();

      final nonTextOverlays = overlays
          .where((o) => o.type != OverlayType.text)
          .toList();

      String currentWorkingPath = pdfPath!;

      if (textReplacements.isNotEmpty) {
        final modifications = <Map<String, dynamic>>[];

        for (final o in textReplacements) {
          final origElem = o.originalDetectedElement;
          final pageW = origElem?.sourceWidth ?? 595.0;
          final pageH = origElem?.sourceHeight ?? 842.0;

          final layoutW = (o.originalLayoutPageWidth != null && o.originalLayoutPageWidth! > 0)
              ? o.originalLayoutPageWidth!
              : pageW;
          final layoutH = (o.originalLayoutPageHeight != null && o.originalLayoutPageHeight! > 0)
              ? o.originalLayoutPageHeight!
              : pageH;

          final scaleX = pageW / layoutW;
          final scaleY = pageH / layoutH;

          final pdfX = o.originalPdfX ?? (o.position.dx * scaleX);
          final pdfY = o.originalPdfY ?? (o.position.dy * scaleY);
          final pdfW = o.originalPdfW ?? (o.size.width * scaleX);
          final pdfH = o.originalPdfH ?? (o.size.height * scaleY);
          final ptFontSize = (o.fontSize * (pageW / layoutW)).clamp(6.0, 72.0);

          modifications.add({
            'pageIndex': o.pageIndex,
            'type': 'text',
            'x': pdfX,
            'y': pdfY,
            'width': pdfW,
            'height': pdfH,
            'originalText': o.originalText ?? origElem?.text ?? '',
            'originalX': o.originalPdfX ?? origElem?.boundingBox.left ?? pdfX,
            'originalY': o.originalPdfY ?? origElem?.boundingBox.top ?? pdfY,
            'originalWidth': o.originalPdfW ?? origElem?.boundingBox.width ?? pdfW,
            'originalHeight': o.originalPdfH ?? origElem?.boundingBox.height ?? pdfH,
            'baseline': origElem?.baseline,
            'fontName': origElem?.fontName ?? o.fontFamily,
            'text': o.savedText ?? o.text ?? '',
            'color': o.color.toARGB32(),
            'backgroundColor': o.backgroundColor?.toARGB32(),
            'fontSize': ptFontSize,
            'isBold': o.isBold,
            'isItalic': o.isItalic,
            'coverOriginal': o.coverOriginal,
          });
        }

        final targetVectorOutPath = nonTextOverlays.isEmpty
            ? outPath
            : '${tmpDir.path}/vector_mod_${DateTime.now().millisecondsSinceEpoch}.pdf';

        log('[PdfEditor] Saving ${modifications.length} modifications with native vector PDF engine...');
        final nativeSuccess = await NativePdfTextService.saveModifiedPdf(
          sourcePath: currentWorkingPath,
          outPath: targetVectorOutPath,
          modifications: modifications,
        );

        if (nativeSuccess) {
          log('[PdfEditor] Native vector PDF save succeeded: $targetVectorOutPath');
          if (nonTextOverlays.isEmpty) {
            return targetVectorOutPath;
          }
          currentWorkingPath = targetVectorOutPath;
        } else {
          log('[PdfEditor] Native save returned false, falling back to isolate export...');
        }
      }

      // 2. Standard isolate export for drawings, signatures, images or fallback
      final overlayData = (textReplacements.isNotEmpty && currentWorkingPath != pdfPath!)
          ? nonTextOverlays.map(_encodeOverlay).toList()
          : overlays.map(_encodeOverlay).toList();

      final result = await compute(
        _exportJob,
        ExportJobInput(
          sourcePath: currentWorkingPath,
          outPath: outPath,
          overlays: overlayData,
        ),
      );

      return result;
    } catch (e) {
      log('[PdfEditor] exportWithOverlays: $e');
      return null;
    } finally {
      isSaving.value = false;
    }
  }

  Map<String, Object> _encodeOverlay(PdfOverlay o) {
    return {
      'id': o.id,
      'pageIndex': o.pageIndex,
      'type': o.type.index,
      'x': o.position.dx,
      'y': o.position.dy,
      'w': o.size.width,
      'h': o.size.height,
      'text': o.text ?? '',
      'colorValue': o.color.toARGB32(),
      'backgroundColorValue': o.backgroundColor?.toARGB32() ?? 0,
      'fontSize': o.fontSize,
      'isBold': o.isBold,
      'isItalic': o.isItalic,
      'isUnderline': o.isUnderline,
      'textAlignIndex': o.textAlign.index,
      'fontFamily': o.fontFamily,
      if (o.imageBytes != null) 'imageBytes': o.imageBytes!,
      if (o.imagePath != null) 'imagePath': o.imagePath!,
      'strokes': [for (final p in o.strokes ?? const <Offset>[]) [p.dx, p.dy]],
    };
  }

  /// Template method so [_exportJob] has a compile-time-known target.
  static Future<String?> _exportJob(ExportJobInput input) =>
      ExportIsolate.run(input);

  // ── Navigation ─────────────────────────────────────────────────────────────
  void goToPage(int index) {
    if (_document == null) return;
    index = index.clamp(0, pageCount.value - 1);
    currentPage.value = index;
  }

  /// Scrolls the page list to [index]. Uses `Scrollable.ensureVisible`-style
  /// math against real item heights instead of assuming every page is a fixed
  /// fraction of the screen — A4 and landscape pages scroll differently.
  void scrollToIndex(int index) {
    final controller = scrollController;
    if (controller == null || !controller.hasClients) return;

    // Item height = maxCrossAxisExtent-based page render width. Pages render
    // image-width constrained, so height ≈ width / aspect; but the pragmatic
    // fix is: scroll to the item extent reported by the layout itself.
    final pos = controller.position;
    final viewportHeight = pos.viewportDimension;
    final pageH = _lastKnownPageHeight ?? viewportHeight * 0.9;
    final target = (index * (pageH + 16)).clamp(0.0, pos.maxScrollExtent);
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  /// Page height most recently laid out, in logical px, for scroll math.
  double? _lastKnownPageHeight;
  void notifyPageHeight(double height) => _lastKnownPageHeight = height;

  // ── Cleanup ────────────────────────────────────────────────────────────────
  Future<void> cleanupTempFiles() async {
    try {
      final tmp = await getTemporaryDirectory();
      await for (final f in Directory(tmp.path).list()) {
        if (f is File && f.path.contains('edited_')) await f.delete();
      }
    } catch (_) {}
  }
}
