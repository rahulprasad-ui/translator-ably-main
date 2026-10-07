// lib/controllers/pdf_compress_controller.dart
import 'dart:developer';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // compute()
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:get/get.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../ads/ad_helper.dart';

// ── Isolate helper ─────────────────────────────────────────────────────────────
// Top-level so compute() can spawn it in a separate isolate.
// Converts JPEG bytes to grayscale without touching the UI thread.
Future<Uint8List> _computeGrayscale(List<dynamic> args) async {
  final bytes = args[0] as Uint8List;
  final quality = args[1] as int;
  final decoded = img.decodeJpg(bytes);
  if (decoded == null) throw Exception('Cannot decode JPEG for grayscale');
  final gray = img.grayscale(decoded);
  return Uint8List.fromList(img.encodeJpg(gray, quality: quality));
}

// ── Compression presets ──────────────────────────────────────────────────────
enum CompressQuality {
  low, // maximum size reduction (smaller output, lower fidelity)
  recommended, // balanced quality / size
  high, // best fidelity (lighter compression)
}

extension CompressQualityX on CompressQuality {
  String get label {
    switch (this) {
      case CompressQuality.low:
        return 'Extreme Compression';
      case CompressQuality.recommended:
        return 'Recommended Compression';
      case CompressQuality.high:
        return 'Less Compression';
    }
  }

  String get subtitle {
    switch (this) {
      case CompressQuality.low:
        return 'Smallest file size, good for sharing';
      case CompressQuality.recommended:
        return 'Good quality, good compression';
      case CompressQuality.high:
        return 'High quality, moderate size reduction';
    }
  }

  IconData get icon {
    switch (this) {
      case CompressQuality.low:
        return Icons.compress_rounded;
      case CompressQuality.recommended:
        return Icons.balance_rounded;
      case CompressQuality.high:
        return Icons.high_quality_rounded;
    }
  }

  Color get color {
    switch (this) {
      case CompressQuality.low:
        return const Color(0xFFFF8C42); // orange
      case CompressQuality.recommended:
        return const Color(0xFF5E89FC); // blue
      case CompressQuality.high:
        return const Color(0xFF36C404); // green
    }
  }

  // JPEG quality used when re-encoding page images (0-100)
  int get jpegQuality {
    switch (this) {
      case CompressQuality.low:
        return 35;
      case CompressQuality.recommended:
        return 50;
      case CompressQuality.high:
        return 65;
    }
  }

  // Effective DPI of rendered page (pdfx render size = dpi * page inches)
  int get dpi {
    switch (this) {
      case CompressQuality.low:
        return 72;
      case CompressQuality.recommended:
        return 110;
      case CompressQuality.high:
        return 150;
    }
  }

  // progressively weaker settings used by the fallback ladder
  CompressQuality get nextWeaker {
    switch (this) {
      case CompressQuality.high:
        return CompressQuality.recommended;
      case CompressQuality.recommended:
      case CompressQuality.low:
        return CompressQuality.low;
    }
  }
}

// ── Result item ──────────────────────────────────────────────────────────────
class PdfCompressResult {
  final String path;
  final String name;
  final int originalSize;
  final int compressedSize;

  // true when we could not make it smaller and are returning the original file
  final bool isAlreadyOptimized;

  PdfCompressResult({
    required this.path,
    required this.name,
    required this.originalSize,
    required this.compressedSize,
    this.isAlreadyOptimized = false,
  });

  double get reductionPercent {
    if (originalSize <= 0) return 0;
    final saved = originalSize - compressedSize;
    return (saved / originalSize) * 100;
  }

  String get formattedOriginalSize => _fmt(originalSize);
  String get formattedCompressedSize => _fmt(compressedSize);

  static String _fmt(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ── Controller ───────────────────────────────────────────────────────────────
class PdfCompressController extends GetxController {
  final selectedPdfPath = RxnString();
  final selectedPdfName = RxnString();
  final fileSizeInBytes = 0.obs;
  final pageCount = 0.obs;

  final isPicking = false.obs;
  final isProcessing = false.obs;
  final compressProgress = 0.0.obs;
  final progressLabel = ''.obs;

  final selectedQuality = CompressQuality.recommended.obs;

  final result = Rxn<PdfCompressResult>();

  // cancellation flag — set to true to abort mid-compression
  final isCancelled = false.obs;

  String get formattedFileSize {
    final bytes = fileSizeInBytes.value;
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

      // user cancelled the dialog — list will be empty
      if (result.isEmpty) return;
      final path = result.first.path;
      if (path == null) return;

      await loadPdf(path, fileName: result.first.name);
    } catch (e) {
      log('[PdfCompress] pickPdfFile error: $e');
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

      // clear previous result when a new file is loaded
      result.value = null;

      selectedPdfPath.value = path;
      selectedPdfName.value =
          fileName ?? path.split(Platform.pathSeparator).last;
      fileSizeInBytes.value = await file.length();

      // just read page count
      final doc = await PdfDocument.openFile(path);
      pageCount.value = doc.pagesCount;
      await doc.close();
    } catch (e) {
      log('[PdfCompress] loadPdf error: $e');
      Get.snackbar(
        'Error',
        'Could not read PDF: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  // ── Core Compress Operation ───────────────────────────────────────────────
  // Strategy: rasterize every page with pdfx (PDFium) into a JPEG at the
  // chosen settings, then rebuild the PDF embedding those JPEGs.
  //
  // Rasterizing a lightweight vector/text PDF can INCREASE its size, so:
  //  1. We try the chosen preset, then progressively stronger ones.
  //  2. If even the strongest preset does not shrink the file meaningfully,
  //     we keep the ORIGINAL file and report it as already optimized.
  Future<void> executeCompress() async {
    final srcPath = selectedPdfPath.value;
    if (srcPath == null || !File(srcPath).existsSync()) {
      Get.snackbar('Error', 'Please select a valid PDF file first');
      return;
    }

    final originalSize = fileSizeInBytes.value;
    final total = pageCount.value;

    // ── Smart pre-check 1: Text / vector PDF detection ───────────────────────
    // If the file is < 8 KB per page it is almost certainly a text/vector PDF.
    // Rasterizing text pages to JPEG always makes the file LARGER, so skip
    // rasterization entirely and report it as already optimized instantly.
    final bytesPerPage = total > 0 ? (originalSize / total) : originalSize;
    if (bytesPerPage < 8000 && total > 5) {
      result.value = PdfCompressResult(
        path: srcPath,
        name: selectedPdfName.value ?? 'document.pdf',
        originalSize: originalSize,
        compressedSize: originalSize,
        isAlreadyOptimized: true,
      );
      return;
    }

    // ── Smart pre-check 2: Large PDF confirmation ────────────────────────────
    // For image-heavy PDFs with many pages the rasterization takes a long time.
    // Warn the user and let them decide before committing.
    if (total > 100) {
      final estimatedMin = (total / 12).ceil(); // ~12 pages / minute on device
      final proceed = await Get.dialog<bool>(
        AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Large PDF',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: Text(
            'This PDF has $total pages.\n\n'
            'Estimated compression time: ~$estimatedMin minute${estimatedMin > 1 ? 's' : ''}.\n\n'
            'For very large PDFs a desktop tool (e.g. Smallpdf, iLovePDF) will be much faster.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Continue Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    try {
      isProcessing.value = true;
      isCancelled.value = false;
      compressProgress.value = 0.0;
      progressLabel.value = 'Opening PDF...';
      result.value = null;

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final workDir = Directory('${tempDir.path}/compress_$timestamp');
      if (!await workDir.exists()) {
        await workDir.create(recursive: true);
      }

      // fallback ladder: chosen preset first, then stronger ones
      final ladder = <CompressQuality>[
        selectedQuality.value,
        selectedQuality.value.nextWeaker,
        CompressQuality.low,
      ];
      // dedupe while preserving order
      final presets = ladder.toSet().toList();

      String? bestPath;
      int bestSize = originalSize; // must beat this to count as compressed
      CompressQuality? bestPreset;

      final baseName =
          (selectedPdfName.value ?? 'document').replaceAll('.pdf', '');

      // grayscale-only final attempt: text documents compress far better
      // without color data; appended after the preset ladder
      final grayscaleRun = <MapEntry<CompressQuality, bool>>[
        for (final p in presets) MapEntry(p, false),
        MapEntry(CompressQuality.low, true),
      ];

      for (var attempt = 0; attempt < grayscaleRun.length; attempt++) {
        final preset = grayscaleRun[attempt].key;
        final useGrayscale = grayscaleRun[attempt].value;
        final attemptShare = 1.0 / grayscaleRun.length;
        final base = attempt * attemptShare;

        progressLabel.value = useGrayscale
            ? 'Trying maximum compression...'
            : (attempt == 0
                ? 'Compressing (${preset.label})...'
                : 'Trying stronger compression...');

        // unique path per attempt to avoid overwriting a previous result
        final outPath =
            '${workDir.path}/${baseName}_attempt${attempt}_$timestamp.pdf';
        final outSize = await _compressWithPreset(
          srcPath: srcPath,
          total: total,
          preset: preset,
          outPath: outPath,
          progressBase: base,
          progressSpan: attemptShare,
          grayscale: useGrayscale,
        );

        if (outSize == null) continue; // attempt failed, try next

        // check if user cancelled
        if (isCancelled.value) break;

        // meaningful win: at least 10% smaller than original
        if (outSize < originalSize * 0.9 && outSize < bestSize) {
          // delete previous best if it was an attempt file
          if (bestPath != null) {
            try {
              final f = File(bestPath);
              if (await f.exists()) await f.delete();
            } catch (_) {}
          }
          bestPath = outPath;
          bestSize = outSize;
          bestPreset = preset;
          break; // good enough with the user's chosen level
        }
      }

      if (bestPath != null && bestPreset != null) {
        compressProgress.value = 1.0;
        progressLabel.value = 'Done!';
        result.value = PdfCompressResult(
          path: bestPath,
          name: bestPath.split(Platform.pathSeparator).last,
          originalSize: originalSize,
          compressedSize: bestSize,
        );
        AdHelper.showInterstitialAd(onComplete: () {});
        return;
      }

      // Could not shrink it or was cancelled
      if (isCancelled.value) {
        progressLabel.value = 'Cancelled';
        return;
      }

      // Could not shrink it — report honestly and keep the original file
      result.value = PdfCompressResult(
        path: srcPath,
        name: selectedPdfName.value ?? 'document.pdf',
        originalSize: originalSize,
        compressedSize: originalSize,
        isAlreadyOptimized: true,
      );
      compressProgress.value = 1.0;
      progressLabel.value = 'Done!';
      AdHelper.showInterstitialAd(onComplete: () {});
    } catch (e) {
      log('[PdfCompress] executeCompress error: $e');
      Get.snackbar(
        'Compression Failed',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } finally {
      isProcessing.value = false;
    }
  }

  // Cancel an in-progress compression
  void cancelCompress() {
    if (isProcessing.value) {
      isCancelled.value = true;
      progressLabel.value = 'Cancelling...';
    }
  }

  // Rasterize + rebuild at one preset.
  // ✅ Fully in-memory – no temp JPEG files written to disk.
  // ✅ Grayscale conversion runs in an isolate via compute().
  // Returns output file size in bytes, or null on failure / cancellation.
  Future<int?> _compressWithPreset({
    required String srcPath,
    required int total,
    required CompressQuality preset,
    required String outPath,
    required double progressBase,
    required double progressSpan,
    bool grayscale = false,
  }) async {
    // Keep JPEG bytes in memory — no disk round-trip needed
    final jpegPageBytes = <Uint8List>[];
    final pageDims = <(double w, double h)>[];
    PdfDocument? doc;

    try {
      doc = await PdfDocument.openFile(srcPath);

      // Step 1: rasterize every page → collect JPEG bytes
      for (var i = 0; i < total; i++) {
        // honour cancellation before every page
        if (isCancelled.value) return null;

        progressLabel.value = 'Processing page ${i + 1} of $total...';
        compressProgress.value =
            progressBase + ((i / total) * progressSpan * 0.85);

        final page = await doc.getPage(i + 1);
        try {
          final renderW = (page.width / 72.0) * preset.dpi;
          final renderH = (page.height / 72.0) * preset.dpi;

          final image = await page.render(
            width: renderW,
            height: renderH,
            format: PdfPageImageFormat.jpeg,
            quality: preset.jpegQuality,
            backgroundColor: '#FFFFFF',
          );

          if (image == null) throw Exception('Failed to render page ${i + 1}');

          final Uint8List bytes;
          if (grayscale) {
            // Off-load CPU-heavy grayscale encoding to an isolate
            bytes = await compute(
              _computeGrayscale,
              [image.bytes, preset.jpegQuality],
            );
          } else {
            bytes = image.bytes;
          }

          jpegPageBytes.add(bytes);
          pageDims.add((image.width!.toDouble(), image.height!.toDouble()));
        } finally {
          await page.close();
        }
      }

      if (isCancelled.value) return null;

      // Step 2: rebuild PDF embedding JPEG bytes directly (no disk round-trip)
      progressLabel.value = 'Rebuilding compressed PDF...';
      compressProgress.value = progressBase + (progressSpan * 0.9);

      final pdf = pw.Document();
      for (var i = 0; i < jpegPageBytes.length; i++) {
        final image = pw.MemoryImage(jpegPageBytes[i]);
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat(pageDims[i].$1, pageDims[i].$2),
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.fill),
          ),
        ));
      }

      final outFile = File(outPath);
      await outFile.writeAsBytes(await pdf.save());
      return await outFile.length();
    } catch (e) {
      log('[PdfCompress] preset ${preset.name} failed: $e');
      return null;
    } finally {
      doc?.close();
      // No temp JPEG files to clean up — all processing was in-memory ✅
    }
  }

  // ── Actions on result ─────────────────────────────────────────────────────
  Future<void> shareResult() async {
    final r = result.value;
    if (r == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(r.path)], text: 'Compressed PDF'),
      );
    } catch (e) {
      log('[PdfCompress] shareResult error: $e');
      Get.snackbar('Error', 'Failed to share: $e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void reset() {
    selectedPdfPath.value = null;
    selectedPdfName.value = null;
    pageCount.value = 0;
    fileSizeInBytes.value = 0;
    result.value = null;
    compressProgress.value = 0.0;
    progressLabel.value = '';
    isCancelled.value = false;
  }
}
