// lib/controllers/compress_image_controller.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../ads/ad_helper.dart';
import '../helper/my_dialogs.dart';

// ── Compression Presets ───────────────────────────────────────────────────────
enum ImageCompressPreset {
  extreme, // Max compression (Smallest file size)
  recommended, // Balanced quality and size
  highQuality, // Best visual fidelity, moderate compression
  custom, // Custom quality & dimension sliders
}

extension ImageCompressPresetX on ImageCompressPreset {
  String get title {
    switch (this) {
      case ImageCompressPreset.extreme:
        return 'Extreme';
      case ImageCompressPreset.recommended:
        return 'Recommended';
      case ImageCompressPreset.highQuality:
        return 'High Quality';
      case ImageCompressPreset.custom:
        return 'Custom';
    }
  }

  String get subtitle {
    switch (this) {
      case ImageCompressPreset.extreme:
        return '70-90% smaller • Ideal for email & messaging';
      case ImageCompressPreset.recommended:
        return '50-70% smaller • Best balance of quality & size';
      case ImageCompressPreset.highQuality:
        return '20-40% smaller • Crystal clear detail';
      case ImageCompressPreset.custom:
        return 'Manually adjust quality & resolution';
    }
  }

  IconData get icon {
    switch (this) {
      case ImageCompressPreset.extreme:
        return Icons.compress_rounded;
      case ImageCompressPreset.recommended:
        return Icons.auto_awesome_rounded;
      case ImageCompressPreset.highQuality:
        return Icons.high_quality_rounded;
      case ImageCompressPreset.custom:
        return Icons.tune_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ImageCompressPreset.extreme:
        return const Color(0xFFFF8C42); // Orange
      case ImageCompressPreset.recommended:
        return const Color(0xFF0D9488); // Teal
      case ImageCompressPreset.highQuality:
        return const Color(0xFF6366F1); // Indigo
      case ImageCompressPreset.custom:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  int get defaultQuality {
    switch (this) {
      case ImageCompressPreset.extreme:
        return 35;
      case ImageCompressPreset.recommended:
        return 65;
      case ImageCompressPreset.highQuality:
        return 82;
      case ImageCompressPreset.custom:
        return 65;
    }
  }

  int? get defaultMaxWidth {
    switch (this) {
      case ImageCompressPreset.extreme:
        return 1280;
      case ImageCompressPreset.recommended:
        return 1920;
      case ImageCompressPreset.highQuality:
        return 2560;
      case ImageCompressPreset.custom:
        return null;
    }
  }
}

// ── Image Item Model ──────────────────────────────────────────────────────────
class CompressImageItem {
  final String id;
  final String originalPath;
  final String name;
  final int originalSizeBytes;
  String? compressedPath;
  int? compressedSizeBytes;
  Uint8List? thumbnailBytes;
  bool isProcessing;
  bool isCompleted;
  String? errorMessage;

  CompressImageItem({
    required this.id,
    required this.originalPath,
    required this.name,
    required this.originalSizeBytes,
    this.compressedPath,
    this.compressedSizeBytes,
    this.thumbnailBytes,
    this.isProcessing = false,
    this.isCompleted = false,
    this.errorMessage,
  });

  String get formattedOriginalSize => _formatBytes(originalSizeBytes);

  String get formattedCompressedSize {
    if (compressedSizeBytes == null) return '--';
    return _formatBytes(compressedSizeBytes!);
  }

  int get savingsPercentage {
    if (compressedSizeBytes == null || originalSizeBytes == 0) return 0;
    final diff = originalSizeBytes - compressedSizeBytes!;
    if (diff <= 0) return 0;
    return ((diff / originalSizeBytes) * 100).round();
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

// ── Top-Level Isolate Function for Heavy Image Processing ─────────────────────
Uint8List _isolateCompressImage(Map<String, dynamic> args) {
  final Uint8List inputBytes = args['bytes'] as Uint8List;
  final int quality = args['quality'] as int;
  final int? maxWidth = args['maxWidth'] as int?;

  final decoded = img.decodeImage(inputBytes);
  if (decoded == null) {
    throw Exception('Failed to decode image');
  }

  img.Image processed = decoded;
  if (maxWidth != null && decoded.width > maxWidth) {
    processed = img.copyResize(
      decoded,
      width: maxWidth,
      interpolation: img.Interpolation.linear,
    );
  }

  // Encode as optimized high-quality JPEG
  final encodedJpg = img.encodeJpg(processed, quality: quality);
  return Uint8List.fromList(encodedJpg);
}

// ── Controller ────────────────────────────────────────────────────────────────
class CompressImageController extends GetxController {
  final images = <CompressImageItem>[].obs;
  final ImagePicker _picker = ImagePicker();

  // Settings
  final selectedPreset = ImageCompressPreset.recommended.obs;
  final customQuality = 65.obs;
  final customMaxWidth = 1920.obs;
  final resizeEnabled = false.obs;

  // Process State
  final isPicking = false.obs;
  final isCompressing = false.obs;
  final isCancelling = false.obs;
  final progress = 0.0.obs;
  final currentStep = 'Ready'.obs;
  final isFinished = false.obs;

  // Metrics
  int get totalOriginalBytes =>
      images.fold<int>(0, (sum, item) => sum + item.originalSizeBytes);

  int get totalCompressedBytes {
    return images.fold<int>(0, (sum, item) {
      return sum + (item.compressedSizeBytes ?? item.originalSizeBytes);
    });
  }

  int get totalSavedBytes {
    final diff = totalOriginalBytes - totalCompressedBytes;
    return diff > 0 ? diff : 0;
  }

  int get overallSavingsPercentage {
    if (totalOriginalBytes == 0 || totalSavedBytes <= 0) return 0;
    return ((totalSavedBytes / totalOriginalBytes) * 100).round();
  }

  String get formattedTotalOriginalSize =>
      CompressImageItem._formatBytes(totalOriginalBytes);

  String get formattedTotalCompressedSize =>
      CompressImageItem._formatBytes(totalCompressedBytes);

  String get formattedTotalSavedSize =>
      CompressImageItem._formatBytes(totalSavedBytes);

  // ── Image Picking ───────────────────────────────────────────────────────────
  Future<void> pickFromGallery({bool append = false}) async {
    try {
      isPicking.value = true;
      if (!append) {
        images.clear();
        isFinished.value = false;
      }

      List<String> paths = [];
      try {
        final pickedList = await _picker.pickMultiImage();
        if (pickedList.isNotEmpty) {
          paths = pickedList.map((e) => e.path).toList();
        }
      } catch (_) {
        // Fallback to FilePicker
        final result = await FilePicker.pickFiles(
          type: FileType.image,
        );
        if (result.isNotEmpty) {
          paths = result.map((e) => e.path).whereType<String>().toList();
        }
      }

      if (paths.isEmpty) return;

      for (final p in paths) {
        final file = File(p);
        if (await file.exists()) {
          final size = await file.length();
          final name = file.uri.pathSegments.last;
          Uint8List? thumb;
          try {
            thumb = await file.readAsBytes();
          } catch (_) {}

          images.add(
            CompressImageItem(
              id: DateTime.now().microsecondsSinceEpoch.toString() +
                  name.hashCode.toString(),
              originalPath: p,
              name: name,
              originalSizeBytes: size,
              thumbnailBytes: thumb,
            ),
          );
        }
      }
    } catch (e) {
      log('[CompressImage] pick error: $e');
      MyDialogs.info(msg: 'Error selecting images: $e');
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> captureFromCamera() async {
    try {
      isPicking.value = true;
      final photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) return;

      final file = File(photo.path);
      if (await file.exists()) {
        final size = await file.length();
        final name = file.uri.pathSegments.last;
        Uint8List? thumb;
        try {
          thumb = await file.readAsBytes();
        } catch (_) {}

        images.add(
          CompressImageItem(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            originalPath: photo.path,
            name: name,
            originalSizeBytes: size,
            thumbnailBytes: thumb,
          ),
        );
      }
    } catch (e) {
      log('[CompressImage] camera error: $e');
      MyDialogs.info(msg: 'Camera error: $e');
    } finally {
      isPicking.value = false;
    }
  }

  void removeImage(String id) {
    images.removeWhere((e) => e.id == id);
    if (images.isEmpty) {
      isFinished.value = false;
    }
  }

  void reset() {
    images.clear();
    isCompressing.value = false;
    isCancelling.value = false;
    isFinished.value = false;
    progress.value = 0.0;
    currentStep.value = 'Ready';
  }

  // ── Compression Execution ───────────────────────────────────────────────────
  Future<void> startCompression() async {
    if (images.isEmpty) {
      MyDialogs.info(msg: 'Please select at least one image to compress');
      return;
    }

    try {
      isCompressing.value = true;
      isCancelling.value = false;
      isFinished.value = false;
      progress.value = 0.0;

      final preset = selectedPreset.value;
      final quality = preset == ImageCompressPreset.custom
          ? customQuality.value
          : preset.defaultQuality;
      final maxWidth = preset == ImageCompressPreset.custom
          ? (resizeEnabled.value ? customMaxWidth.value : null)
          : preset.defaultMaxWidth;

      final total = images.length;
      final tempDir = await getTemporaryDirectory();

      for (int i = 0; i < total; i++) {
        if (isCancelling.value) {
          log('[CompressImage] Compression cancelled.');
          break;
        }

        final item = images[i];
        final indexDisplay = i + 1;

        currentStep.value = 'Compressing image $indexDisplay of $total (${item.name})...';
        progress.value = i / total;
        item.isProcessing = true;
        images.refresh();

        try {
          final rawBytes = await File(item.originalPath).readAsBytes();

          // Run CPU-heavy image compression in separate isolate via compute()
          final compressedBytes = await compute(_isolateCompressImage, {
            'bytes': rawBytes,
            'quality': quality,
            'maxWidth': maxWidth,
          });

          final outPath =
              '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}_${item.name.replaceAll(RegExp(r'\.[^.]+$'), '')}.jpg';
          final outFile = File(outPath);
          await outFile.writeAsBytes(compressedBytes);

          item.compressedPath = outPath;
          item.compressedSizeBytes = compressedBytes.length;
          item.isCompleted = true;
          item.isProcessing = false;
        } catch (err) {
          log('[CompressImage] item error: $err');
          item.errorMessage = err.toString();
          item.isProcessing = false;
        }

        images.refresh();
        progress.value = (i + 1.0) / total;
      }

      if (isCancelling.value) {
        currentStep.value = 'Cancelled';
        MyDialogs.info(msg: 'Compression stopped.');
      } else {
        isFinished.value = true;
        currentStep.value = 'All images compressed successfully!';
        MyDialogs.success(
          msg:
              'Done! Saved $formattedTotalSavedSize ($overallSavingsPercentage% smaller)',
        );
        AdHelper.showInterstitialAd(onComplete: () {});
      }
    } catch (e) {
      log('[CompressImage] global error: $e');
      MyDialogs.info(msg: 'Compression failed: $e');
    } finally {
      isCompressing.value = false;
      isCancelling.value = false;
    }
  }

  void cancelCompression() {
    isCancelling.value = true;
    currentStep.value = 'Cancelling...';
  }

  // ── Share Actions ───────────────────────────────────────────────────────────
  Future<void> shareAllCompressed() async {
    final completedPaths = images
        .where((e) => e.isCompleted && e.compressedPath != null)
        .map((e) => e.compressedPath!)
        .toList();

    if (completedPaths.isEmpty) {
      MyDialogs.info(msg: 'No compressed images to share');
      return;
    }

    try {
      final xFiles =
          completedPaths.map((p) => XFile(p, mimeType: 'image/jpeg')).toList();
      await Share.shareXFiles(
        xFiles,
        text: 'Compressed Images ($overallSavingsPercentage% reduced size)',
      );
    } catch (e) {
      MyDialogs.info(msg: 'Share failed: $e');
    }
  }

  Future<void> shareSingleImage(CompressImageItem item) async {
    final path = item.compressedPath ?? item.originalPath;
    try {
      await Share.shareXFiles(
        [XFile(path, mimeType: 'image/jpeg')],
        text: 'Compressed Image: ${item.name}',
      );
    } catch (e) {
      MyDialogs.info(msg: 'Share failed: $e');
    }
  }
}
