// lib/controllers/pdf_unlock_controller.dart
import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../ads/ad_helper.dart';
import '../helper/my_dialogs.dart';

enum UnlockStatus {
  idle,
  checkingEncryption,
  passwordRequired,
  alreadyUnlocked,
  unlocking,
  unlockedSuccess,
  error,
}

// ── LRU Page Image Cache for Preview ─────────────────────────────────────────
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

class PdfUnlockController extends GetxController {
  // ── Document State ────────────────────────────────────────────────────────
  final selectedPdfPath = RxnString();
  final selectedPdfName = RxnString();
  final fileSizeInBytes = 0.obs;
  final pageCount = 0.obs;
  final currentPageIndex = 0.obs;

  final unlockStatus = UnlockStatus.idle.obs;
  final isPicking = false.obs;
  final isProcessing = false.obs;
  final isExporting = false.obs;
  final exportProgress = 0.0.obs;
  final exportStatus = ''.obs;

  final passwordController = TextEditingController();
  final isPasswordVisible = false.obs;
  final errorMessage = RxnString();

  final unlockedPdfPath = RxnString();
  final previewPageBytes = Rxn<Uint8List>();

  PdfDocument? _pdfDoc;
  final _previewCache = _LruCache<int, Uint8List>(6);

  bool get hasDocument => selectedPdfPath.value != null;
  bool get isLocked => unlockStatus.value == UnlockStatus.passwordRequired;
  bool get isSuccess => unlockStatus.value == UnlockStatus.unlockedSuccess;

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
    _previewCache.clear();
    passwordController.dispose();
    super.onClose();
  }

  // ── 1. Document Picking & Inspection ───────────────────────────────────────
  Future<void> pickPdfFile() async {
    try {
      isPicking.value = true;
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isNotEmpty && result.first.path != null) {
        await inspectAndLoadPdf(result.first.path!);
      }
    } catch (e) {
      log('[PdfUnlock] pickPdfFile error: $e');
      MyDialogs.info(msg: 'Failed to pick PDF: $e');
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> inspectAndLoadPdf(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        MyDialogs.info(msg: 'Selected PDF file does not exist');
        return;
      }

      await _pdfDoc?.close();
      _previewCache.clear();
      previewPageBytes.value = null;
      unlockedPdfPath.value = null;
      errorMessage.value = null;
      passwordController.clear();

      selectedPdfPath.value = path;
      selectedPdfName.value = path.split(Platform.pathSeparator).last;
      fileSizeInBytes.value = await file.length();
      unlockStatus.value = UnlockStatus.checkingEncryption;

      // 1. Try to open without password
      try {
        _pdfDoc = await PdfDocument.openFile(path);
        pageCount.value = _pdfDoc!.pagesCount;
        currentPageIndex.value = 0;

        // Check if PDF has /Encrypt dictionary in raw bytes
        final hasEncryptionHeader = await _checkIfEncryptedInBytes(path);

        if (hasEncryptionHeader) {
          // Has owner encryption or permission lock that opens without user password
          unlockStatus.value = UnlockStatus.passwordRequired;
        } else {
          unlockStatus.value = UnlockStatus.alreadyUnlocked;
          await renderPreviewPage(1);
        }
      } catch (openError) {
        // Failed without password -> definitely requires user password
        log('[PdfUnlock] Document is password protected: $openError');
        unlockStatus.value = UnlockStatus.passwordRequired;
      }
    } catch (e) {
      log('[PdfUnlock] inspectAndLoadPdf error: $e');
      unlockStatus.value = UnlockStatus.error;
      errorMessage.value = 'Failed to analyze PDF: $e';
    }
  }

  Future<bool> _checkIfEncryptedInBytes(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return false;

      // Search for /Encrypt in header and trailer chunks
      final headerChunk =
          String.fromCharCodes(bytes.take(math.min(bytes.length, 30000)));
      if (headerChunk.contains('/Encrypt')) return true;

      if (bytes.length > 5000) {
        final trailerChunk =
            String.fromCharCodes(bytes.sublist(bytes.length - 5000));
        if (trailerChunk.contains('/Encrypt')) return true;
      }
    } catch (_) {}
    return false;
  }

  // ── 2. Decrypt & Validate Password ─────────────────────────────────────────
  Future<void> unlockWithPassword() async {
    final password = passwordController.text;
    final path = selectedPdfPath.value;
    if (path == null) return;

    if (password.isEmpty) {
      errorMessage.value = 'Please enter the PDF password';
      return;
    }

    try {
      isProcessing.value = true;
      errorMessage.value = null;
      unlockStatus.value = UnlockStatus.unlocking;

      await _pdfDoc?.close();
      _previewCache.clear();

      try {
        _pdfDoc = await PdfDocument.openFile(path, password: password);
        pageCount.value = _pdfDoc!.pagesCount;
        currentPageIndex.value = 0;

        // Render first page to confirm decryption key validity
        await renderPreviewPage(1);

        // Permanently strip encryption and build unlocked PDF
        await removePasswordAndExport(password: password);
      } catch (authError) {
        log('[PdfUnlock] Invalid password: $authError');
        unlockStatus.value = UnlockStatus.passwordRequired;
        errorMessage.value =
            'Incorrect password. Please verify and try again.';
        MyDialogs.info(msg: 'Incorrect password. Please try again.');
      }
    } catch (e) {
      log('[PdfUnlock] unlockWithPassword error: $e');
      unlockStatus.value = UnlockStatus.passwordRequired;
      errorMessage.value = 'Decryption failed: $e';
    } finally {
      isProcessing.value = false;
    }
  }

  // ── 3. Render Decrypted Preview Page ───────────────────────────────────────
  Future<void> renderPreviewPage(int pageNumber) async {
    if (_pdfDoc == null) return;

    final cached = _previewCache.get(pageNumber);
    if (cached != null) {
      previewPageBytes.value = cached;
      return;
    }

    try {
      final page = await _pdfDoc!.getPage(pageNumber);
      final scale = (1200.0 / page.width).clamp(1.5, 2.5);
      final rendered = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: PdfPageImageFormat.jpeg,
        quality: 85,
      );
      await page.close();

      if (rendered != null) {
        _previewCache.put(pageNumber, rendered.bytes);
        previewPageBytes.value = rendered.bytes;
      }
    } catch (e) {
      log('[PdfUnlock] renderPreviewPage error: $e');
    }
  }

  // ── 4. Permanently Remove Password & Export Clean PDF ─────────────────────
  Future<String?> removePasswordAndExport({String? password}) async {
    final path = selectedPdfPath.value;
    if (path == null) return null;

    try {
      isExporting.value = true;
      exportProgress.value = 0.0;
      exportStatus.value = 'Initializing unencrypted PDF builder...';

      PdfDocument? doc = _pdfDoc;
      if (doc == null) {
        doc = await PdfDocument.openFile(path, password: password);
        _pdfDoc = doc;
      }

      final totalPages = doc.pagesCount;
      final pwDoc = pw.Document();

      for (int i = 0; i < totalPages; i++) {
        final pageNum = i + 1;
        exportProgress.value = (i / totalPages) * 0.88;
        exportStatus.value =
            'Decrypting and baking page $pageNum of $totalPages...';

        final page = await doc.getPage(pageNum);
        final double nativeWidth = page.width.toDouble();
        final double nativeHeight = page.height.toDouble();

        // High quality unencrypted rendering
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

        pwDoc.addPage(
          pw.Page(
            pageFormat: pw_pdf.PdfPageFormat(nativeWidth, nativeHeight),
            margin: pw.EdgeInsets.zero,
            build: (pw.Context ctx) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(basePdfImage, fit: pw.BoxFit.fill),
              );
            },
          ),
        );
      }

      exportProgress.value = 0.95;
      exportStatus.value = 'Finalizing unlocked document...';

      final outputBytes = await pwDoc.save();
      final tempDir = await getTemporaryDirectory();
      final baseName =
          selectedPdfName.value?.replaceAll('.pdf', '') ?? 'document';
      final outPath =
          '${tempDir.path}/${baseName}_unlocked_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outFile = File(outPath);
      await outFile.writeAsBytes(outputBytes, flush: true);

      unlockedPdfPath.value = outPath;
      unlockStatus.value = UnlockStatus.unlockedSuccess;
      exportProgress.value = 1.0;
      exportStatus.value = 'PDF successfully unlocked and password removed!';
      AdHelper.showInterstitialAd(onComplete: () {});
      return outPath;
    } catch (e) {
      log('[PdfUnlock] removePasswordAndExport error: $e');
      MyDialogs.info(msg: 'Failed to export unlocked PDF: $e');
      return null;
    } finally {
      isExporting.value = false;
    }
  }

  void shareUnlockedPdf() {
    final path = unlockedPdfPath.value;
    if (path == null) return;

    Share.shareXFiles(
      [XFile(path)],
      subject: 'Unlocked PDF: ${selectedPdfName.value}',
      text: 'Here is your permanently unlocked and password-free PDF document.',
    );
  }
}
