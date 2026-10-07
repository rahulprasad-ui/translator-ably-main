// lib/controllers/pdf_split_controller.dart
import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_combiner/models/merge_input.dart';
import 'package:pdf_combiner/pdf_combiner.dart';
import 'package:pdf_splitern/pdf_splitern.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../screen/pdf_editor_screen.dart';

enum SplitMode {
  extractSelected, // Extract specific pages into one combined PDF or multiple PDFs
  splitAll, // Split all pages into individual single-page PDFs
  range, // Split by a range (e.g. pages 2 to 5)
}

class PdfSplitResultItem {
  final String path;
  final String name;
  final int sizeInBytes;
  final int pageCount;

  PdfSplitResultItem({
    required this.path,
    required this.name,
    required this.sizeInBytes,
    required this.pageCount,
  });

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ── LRU Cache ─────────────────────────────────────────────────────────────
// Evicts the least-recently-used entry when capacity is exceeded.
class _LruCache<K, V> {
  final int capacity;
  final void Function(V)? onEvict;
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  _LruCache(this.capacity, {this.onEvict});

  V? get(K key) {
    final v = _map.remove(key);
    if (v != null) _map[key] = v; // move to end (most-recently-used)
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

class PdfSplitController extends GetxController {
  final selectedPdfPath = RxnString();
  final selectedPdfName = RxnString();
  final fileSizeInBytes = 0.obs;
  final pageCount = 0.obs;

  final isPicking = false.obs;
  final isProcessing = false.obs;
  final splitProgress = 0.0.obs;

  // Selected mode
  final splitMode = SplitMode.extractSelected.obs;

  // Selected pages for extract mode (0-indexed)
  final selectedPages = <int>{}.obs;

  // Range mode values (1-indexed for user display)
  final rangeStart = 1.obs;
  final rangeEnd = 1.obs;

  // Results
  final generatedFiles = <PdfSplitResultItem>[].obs;

  // Internal PDF rendering for thumbnails
  PdfDocument? _pdfDoc;
  final _renderLock = _AsyncLock();

  // LRU thumbnail cache – max 50 entries; evicts least-recently-used automatically
  final _thumbCache = _LruCache<int, Uint8List>(50);
  final thumbnailReadyPages = RxSet<int>({});

  String get formattedFileSize {
    final bytes = fileSizeInBytes.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  void onClose() {
    _closeDoc();
    super.onClose();
  }

  void _closeDoc() {
    try {
      _pdfDoc?.close();
      _pdfDoc = null;
    } catch (_) {}
    _thumbCache.clear();
    thumbnailReadyPages.clear();
  }

  // ── Pick PDF File ─────────────────────────────────────────────────────────
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

      await loadPdf(path, fileName: result.first.name);
    } catch (e) {
      log('[PdfSplit] pickPdfFile error: $e');
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

      _closeDoc();
      selectedPdfPath.value = path;
      selectedPdfName.value =
          fileName ?? path.split(Platform.pathSeparator).last;
      fileSizeInBytes.value = await file.length();

      _pdfDoc = await PdfDocument.openFile(path);
      pageCount.value = _pdfDoc!.pagesCount;

      // Reset selection defaults
      selectedPages.clear();
      // By default select all pages
      for (int i = 0; i < pageCount.value; i++) {
        selectedPages.add(i);
      }

      rangeStart.value = 1;
      rangeEnd.value = pageCount.value.clamp(1, 99999);
      generatedFiles.clear();
      // Thumbnails are loaded on-demand by GridView items – no eager preload
    } catch (e) {
      log('[PdfSplit] loadPdf error: $e');
      Get.snackbar(
        'Error',
        'Could not read PDF: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
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
          width: 200.0,
          height: (200.0 * (page.height / page.width)),
          format: PdfPageImageFormat.jpeg,
          quality: 60, // low-res thumbnail
        );
        await page.close();

        if (pageImage != null) {
          _thumbCache.put(pageIndex, pageImage.bytes); // LRU put
          thumbnailReadyPages.add(pageIndex);
          return pageImage.bytes;
        }
      } catch (e) {
        log('[PdfSplit] _loadThumbnail page $pageIndex error: $e');
      }
      return null;
    });
  }

  // ── Selection helpers ─────────────────────────────────────────────────────
  void togglePage(int index) {
    if (selectedPages.contains(index)) {
      selectedPages.remove(index);
    } else {
      selectedPages.add(index);
    }
  }

  void selectAll() {
    selectedPages.clear();
    for (int i = 0; i < pageCount.value; i++) {
      selectedPages.add(i);
    }
  }

  void clearSelection() {
    selectedPages.clear();
  }

  void invertSelection() {
    final current = Set<int>.from(selectedPages);
    selectedPages.clear();
    for (int i = 0; i < pageCount.value; i++) {
      if (!current.contains(i)) {
        selectedPages.add(i);
      }
    }
  }

  void selectOddPages() {
    selectedPages.clear();
    for (int i = 0; i < pageCount.value; i++) {
      if (i % 2 == 0) selectedPages.add(i); // Page 1, 3, 5... (0-indexed 0, 2, 4...)
    }
  }

  void selectEvenPages() {
    selectedPages.clear();
    for (int i = 0; i < pageCount.value; i++) {
      if (i % 2 != 0) selectedPages.add(i); // Page 2, 4, 6... (0-indexed 1, 3, 5...)
    }
  }

  void setRangeStart(int val) {
    rangeStart.value = val.clamp(1, rangeEnd.value);
  }

  void setRangeEnd(int val) {
    rangeEnd.value = val.clamp(rangeStart.value, pageCount.value);
  }

  // ── Core Split Operation ──────────────────────────────────────────────────
  Future<List<PdfSplitResultItem>> executeSplit() async {
    final srcPath = selectedPdfPath.value;
    if (srcPath == null || !File(srcPath).existsSync()) {
      Get.snackbar('Error', 'Please select a valid PDF file first');
      return [];
    }

    try {
      isProcessing.value = true;
      splitProgress.value = 0.1;
      generatedFiles.clear();

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outDir = Directory('${tempDir.path}/split_$timestamp');
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }

      // Step 1: Split into individual single pages using PdfSplitern
      final args = PdfSpliternArgs(
        srcPath,
        outDir.path,
        outFilePrefix: 'page_',
      );

      splitProgress.value = 0.3;
      final splitResult = await PdfSplitern.split(args);
      final singlePagePaths = splitResult.pagePaths;

      if (singlePagePaths.isEmpty) {
        throw Exception('Native PDF splitter did not return any pages');
      }

      splitProgress.value = 0.6;
      final baseName = selectedPdfName.value?.replaceAll('.pdf', '') ?? 'document';
      final results = <PdfSplitResultItem>[];

      // Handle according to chosen mode
      switch (splitMode.value) {
        case SplitMode.splitAll:
          // User wants every page as a separate PDF
          for (int i = 0; i < singlePagePaths.length; i++) {
            final p = singlePagePaths[i];
            final f = File(p);
            if (await f.exists()) {
              final newName = '${baseName}_page_${i + 1}.pdf';
              final finalPath = '${outDir.path}/$newName';
              await f.rename(finalPath);

              results.add(PdfSplitResultItem(
                path: finalPath,
                name: newName,
                sizeInBytes: await File(finalPath).length(),
                pageCount: 1,
              ));
            }
          }
          break;

        case SplitMode.extractSelected:
          if (selectedPages.isEmpty) {
            throw Exception('Please select at least one page to extract');
          }

          final sortedSelected = selectedPages.toList()..sort();
          final selectedSinglePaths = <String>[];
          for (final idx in sortedSelected) {
            if (idx >= 0 && idx < singlePagePaths.length) {
              selectedSinglePaths.add(singlePagePaths[idx]);
            }
          }

          if (selectedSinglePaths.length == 1) {
            // Only 1 page extracted
            final singleFile = File(selectedSinglePaths.first);
            final pageNum = sortedSelected.first + 1;
            final finalName = '${baseName}_extracted_page_$pageNum.pdf';
            final finalPath = '${outDir.path}/$finalName';
            await singleFile.rename(finalPath);

            results.add(PdfSplitResultItem(
              path: finalPath,
              name: finalName,
              sizeInBytes: await File(finalPath).length(),
              pageCount: 1,
            ));
          } else {
            // Multiple pages extracted into one consolidated document
            final finalName =
                '${baseName}_extracted_${selectedSinglePaths.length}pages.pdf';
            final finalPath = '${outDir.path}/$finalName';

            final mergedOutput = await PdfCombiner.mergeMultiplePDFs(
              inputs: selectedSinglePaths.map((p) => MergeInput.path(p)).toList(),
              outputPath: finalPath,
            );

            results.add(PdfSplitResultItem(
              path: mergedOutput,
              name: finalName,
              sizeInBytes: await File(mergedOutput).length(),
              pageCount: selectedSinglePaths.length,
            ));
          }
          break;

        case SplitMode.range:
          final startIdx = rangeStart.value - 1; // 0-indexed
          final endIdx = rangeEnd.value - 1; // 0-indexed
          if (startIdx < 0 || endIdx >= singlePagePaths.length || startIdx > endIdx) {
            throw Exception('Invalid page range selected: ${rangeStart.value} to ${rangeEnd.value}');
          }

          final rangePaths = <String>[];
          for (int i = startIdx; i <= endIdx; i++) {
            rangePaths.add(singlePagePaths[i]);
          }

          final finalName =
              '${baseName}_pages_${rangeStart.value}_to_${rangeEnd.value}.pdf';
          final finalPath = '${outDir.path}/$finalName';

          if (rangePaths.length == 1) {
            final f = File(rangePaths.first);
            await f.rename(finalPath);
            results.add(PdfSplitResultItem(
              path: finalPath,
              name: finalName,
              sizeInBytes: await File(finalPath).length(),
              pageCount: 1,
            ));
          } else {
            final mergedOutput = await PdfCombiner.mergeMultiplePDFs(
              inputs: rangePaths.map((p) => MergeInput.path(p)).toList(),
              outputPath: finalPath,
            );

            results.add(PdfSplitResultItem(
              path: mergedOutput,
              name: finalName,
              sizeInBytes: await File(mergedOutput).length(),
              pageCount: rangePaths.length,
            ));
          }
          break;
      }

      splitProgress.value = 1.0;
      generatedFiles.assignAll(results);
      return results;
    } catch (e) {
      log('[PdfSplit] executeSplit error: $e');
      Get.snackbar(
        'Split Failed',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return [];
    } finally {
      isProcessing.value = false;
    }
  }

  // ── Actions on results ────────────────────────────────────────────────────
  Future<void> shareFile(String path) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: 'Split PDF'),
      );
    } catch (e) {
      log('[PdfSplit] shareFile error: $e');
      Get.snackbar('Error', 'Failed to share: $e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> shareAllResults() async {
    if (generatedFiles.isEmpty) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: generatedFiles.map((item) => XFile(item.path)).toList(),
          text: 'Split PDF Files',
        ),
      );
    } catch (e) {
      log('[PdfSplit] shareAllResults error: $e');
      Get.snackbar('Error', 'Failed to share files: $e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void openInEditor(String path) {
    Get.to(
      () => const PdfEditorScreen(),
      arguments: path,
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 280),
    );
  }

  void reset() {
    selectedPdfPath.value = null;
    selectedPdfName.value = null;
    pageCount.value = 0;
    fileSizeInBytes.value = 0;
    selectedPages.clear();
    generatedFiles.clear();
    _closeDoc();
  }
}
