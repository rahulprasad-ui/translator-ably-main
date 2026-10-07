// lib/controllers/pdf_merge_controller.dart
import 'dart:developer';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_combiner/models/merge_input.dart';
import 'package:pdf_combiner/pdf_combiner.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../ads/ad_helper.dart';
import '../screen/pdf_editor_screen.dart';

class PdfMergeItem {
  final String path;
  final String name;
  final int sizeInBytes;
  final int pageCount;

  PdfMergeItem({
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

class PdfMergeController extends GetxController {
  final pickedFiles = <PdfMergeItem>[].obs;
  final isMerging = false.obs;
  final isPicking = false.obs;
  final mergedFilePath = RxnString();

  int get totalPages =>
      pickedFiles.fold<int>(0, (sum, item) => sum + item.pageCount);

  int get totalSizeBytes =>
      pickedFiles.fold<int>(0, (sum, item) => sum + item.sizeInBytes);

  String get formattedTotalSize {
    final bytes = totalSizeBytes;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> pickFiles() async {
    try {
      isPicking.value = true;
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isEmpty) return;

      for (final platformFile in result) {
        final filePath = platformFile.path;
        if (filePath == null) continue;

        // Check if already in list
        if (pickedFiles.any((e) => e.path == filePath)) continue;

        final file = File(filePath);
        if (!await file.exists()) continue;

        int pageCount = 1;
        try {
          final doc = await PdfDocument.openFile(filePath);
          pageCount = doc.pagesCount;
          await doc.close();
        } catch (e) {
          log('[PdfMerge] Error getting page count for $filePath: $e');
        }

        final size = await file.length();
        final name = platformFile.name.isNotEmpty
            ? platformFile.name
            : filePath.split(Platform.pathSeparator).last;

        pickedFiles.add(PdfMergeItem(
          path: filePath,
          name: name,
          sizeInBytes: size,
          pageCount: pageCount,
        ));
      }
    } catch (e) {
      log('[PdfMerge] pickFiles error: $e');
      Get.snackbar(
        'Error',
        'Could not select files. Please try again.',
        backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
    } finally {
      isPicking.value = false;
    }
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = pickedFiles.removeAt(oldIndex);
    pickedFiles.insert(newIndex, item);
  }

  void removeAt(int index) {
    if (index >= 0 && index < pickedFiles.length) {
      pickedFiles.removeAt(index);
    }
  }

  void clearAll() {
    pickedFiles.clear();
    mergedFilePath.value = null;
  }

  Future<String?> mergePdfs() async {
    if (pickedFiles.length < 2) {
      Get.snackbar(
        'Need more files',
        'Please select at least 2 PDF files to merge.',
        backgroundColor: Colors.amber.shade700.withValues(alpha: 0.95),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
        borderRadius: 14,
      );
      return null;
    }

    try {
      isMerging.value = true;
      final tempDir = await getTemporaryDirectory();
      final outPath =
          '${tempDir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Ensure directory exists
      final outFile = File(outPath);
      if (!await outFile.parent.exists()) {
        await outFile.parent.create(recursive: true);
      }

      final inputs = pickedFiles.map((f) => MergeInput.path(f.path)).toList();

      final result = await PdfCombiner.mergeMultiplePDFs(
        inputs: inputs,
        outputPath: outPath,
      );

      mergedFilePath.value = result;
      log('[PdfMerge] Successfully merged to: $result');
      AdHelper.showInterstitialAd(onComplete: () {});
      return result;
    } catch (e, stack) {
      log('[PdfMerge] merge error: $e', stackTrace: stack);

      String errorMsg = e.toString();
      if (errorMsg.contains('MissingPluginException') ||
          errorMsg.contains('No implementation found')) {
        errorMsg =
            'Native plugin load nahi hua. Terminal me app band karein (q press karein) aur dobara "flutter run" karein taaki naya native plugin compile ho sake.';
      }

      Get.snackbar(
        'Merge Failed',
        errorMsg,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.95),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
        borderRadius: 14,
        duration: const Duration(seconds: 5),
      );
      return null;
    } finally {
      isMerging.value = false;
    }
  }

  void openMergedFile() {
    final path = mergedFilePath.value;
    if (path == null) return;
    Get.to(
      () => PdfEditorScreen(initialPdfPath: path),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 280),
    );
  }

  Future<void> shareMergedFile() async {
    final path = mergedFilePath.value;
    if (path == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: 'Merged PDF Document'),
      );
    } catch (e) {
      log('[PdfMerge] share error: $e');
    }
  }
}
