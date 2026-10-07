// lib/controllers/merge_images_controller.dart
import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_combiner/models/merge_input.dart';
import 'package:pdf_combiner/models/pdf_from_multiple_image_config.dart';
import 'package:pdf_combiner/pdf_combiner.dart';
import 'package:share_plus/share_plus.dart';

import '../ads/ad_helper.dart';
import '../screen/pdf_editor_screen.dart';

enum MergeImagesFormat {
  pdf, // Merges images as pages into a PDF
  longImage, // Stitches images vertically into a single long image
}

class MergeImageItem {
  final String id;
  final String path;
  final String name;
  final int sizeInBytes;

  MergeImageItem({
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

class MergeImagesController extends GetxController {
  final pickedImages = <MergeImageItem>[].obs;
  final isPicking = false.obs;
  final isMerging = false.obs;
  final mergeProgress = 0.0.obs;

  final selectedFormat = MergeImagesFormat.pdf.obs;
  final mergedFilePath = RxnString();
  final mergedFileSize = 0.obs;

  int get totalSizeBytes =>
      pickedImages.fold<int>(0, (sum, item) => sum + item.sizeInBytes);

  String get formattedTotalSize {
    final bytes = totalSizeBytes;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedMergedSize {
    final bytes = mergedFileSize.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Pick Images ───────────────────────────────────────────────────────────
  Future<void> pickImages({bool append = true}) async {
    try {
      isPicking.value = true;
      final result = await FilePicker.pickFiles(
        type: FileType.image,
      );

      if (result.isEmpty) return;

      if (!append) {
        pickedImages.clear();
      }

      for (final pf in result) {
        final path = pf.path;
        if (path == null) continue;

        // Skip duplicates
        if (pickedImages.any((e) => e.path == path)) continue;

        final file = File(path);
        if (!await file.exists()) continue;

        final size = await file.length();
        final name = pf.name.isNotEmpty
            ? pf.name
            : path.split(Platform.pathSeparator).last;

        pickedImages.add(MergeImageItem(
          id: '${DateTime.now().microsecondsSinceEpoch}_${pickedImages.length}',
          path: path,
          name: name,
          sizeInBytes: size,
        ));
      }
    } catch (e) {
      log('[MergeImages] pickImages error: $e');
      Get.snackbar(
        'Error',
        'Failed to pick images: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
    } finally {
      isPicking.value = false;
    }
  }

  // ── List Management ───────────────────────────────────────────────────────
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = pickedImages.removeAt(oldIndex);
    pickedImages.insert(newIndex, item);
  }

  void removeAt(int index) {
    if (index >= 0 && index < pickedImages.length) {
      pickedImages.removeAt(index);
    }
  }

  void clearAll() {
    pickedImages.clear();
    mergedFilePath.value = null;
    mergedFileSize.value = 0;
  }

  // ── Execute Merge ─────────────────────────────────────────────────────────
  Future<String?> executeMerge() async {
    if (pickedImages.length < 2) {
      Get.snackbar(
        'Insufficient Images',
        'Please select at least 2 images to merge',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orangeAccent,
        colorText: Colors.white,
      );
      return null;
    }

    try {
      isMerging.value = true;
      mergeProgress.value = 0.1;
      mergedFilePath.value = null;

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      if (selectedFormat.value == MergeImagesFormat.pdf) {
        // Merge into multi-page PDF
        final outputPath = '${tempDir.path}/merged_images_$timestamp.pdf';
        mergeProgress.value = 0.4;

        final inputs = pickedImages
            .map((item) => MergeInput.path(item.path))
            .toList();

        final result = await PdfCombiner.createPDFFromMultipleImages(
          inputs: inputs,
          outputPath: outputPath,
          config: const PdfFromMultipleImageConfig(
            keepAspectRatio: true,
          ),
        );

        mergeProgress.value = 1.0;
        final outFile = File(result);
        if (await outFile.exists()) {
          mergedFilePath.value = result;
          mergedFileSize.value = await outFile.length();
          AdHelper.showInterstitialAd(onComplete: () {});
          return result;
        } else {
          throw Exception('Merged PDF file was not created');
        }
      } else {
        // Merge into vertically stitched long image
        mergeProgress.value = 0.3;
        final outputPath = '${tempDir.path}/stitched_image_$timestamp.png';
        final imagePaths = pickedImages.map((e) => e.path).toList();

        final result = await _stitchImagesVertically(imagePaths, outputPath);
        mergeProgress.value = 1.0;

        final outFile = File(result);
        if (await outFile.exists()) {
          mergedFilePath.value = result;
          mergedFileSize.value = await outFile.length();
          AdHelper.showInterstitialAd(onComplete: () {});
          return result;
        } else {
          throw Exception('Stitched image was not created');
        }
      }
    } catch (e) {
      log('[MergeImages] executeMerge error: $e');
      Get.snackbar(
        'Merge Failed',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return null;
    } finally {
      isMerging.value = false;
    }
  }

  // ── Vertical Image Stitcher ───────────────────────────────────────────────
  Future<String> _stitchImagesVertically(
      List<String> paths, String outputPath) async {
    final images = <ui.Image>[];

    for (final p in paths) {
      final bytes = await File(p).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      images.add(frame.image);
    }

    int maxWidth = 0;
    int totalHeight = 0;

    for (final img in images) {
      if (img.width > maxWidth) maxWidth = img.width;
      totalHeight += img.height;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, maxWidth.toDouble(), totalHeight.toDouble()),
    );

    // White background
    canvas.drawColor(Colors.white, BlendMode.src);

    double currentY = 0;
    for (final img in images) {
      final double offsetX = (maxWidth - img.width) / 2.0;
      canvas.drawImage(img, Offset(offsetX, currentY), Paint());
      currentY += img.height;
    }

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(maxWidth, totalHeight);
    final byteData =
        await finalImage.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Failed to encode merged image to PNG');
    }

    final pngBytes = byteData.buffer.asUint8List();
    final file = File(outputPath);
    await file.writeAsBytes(pngBytes);

    return outputPath;
  }

  // ── Share and Preview ─────────────────────────────────────────────────────
  Future<void> shareResult() async {
    final path = mergedFilePath.value;
    if (path == null || !File(path).existsSync()) return;

    try {
      final xfile = XFile(path);
      await Share.shareXFiles([xfile], text: 'Merged Image File');
    } catch (e) {
      log('[MergeImages] shareResult error: $e');
      Get.snackbar('Error', 'Failed to share: $e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void openResult() {
    final path = mergedFilePath.value;
    if (path == null) return;

    if (path.endsWith('.pdf')) {
      Get.to(
        () => const PdfEditorScreen(),
        arguments: path,
        transition: Transition.rightToLeft,
        duration: const Duration(milliseconds: 280),
      );
    } else {
      // Show full screen image dialog
      Get.dialog(
        Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(File(path)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Get.back(),
              ),
            ],
          ),
        ),
      );
    }
  }
}
