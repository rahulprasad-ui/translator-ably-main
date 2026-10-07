// lib/controllers/enhance_image_controller.dart
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

import '../helper/my_dialogs.dart';

// ── Enhancement Presets ───────────────────────────────────────────────────────
enum EnhancePreset {
  magicAuto, // Auto AI contrast, brightness & sharpness
  docClean, // Document scan mode: cleans paper shadow & clarifies text
  hdrVivid, // HDR Color punch & vibrancy
  portraitHd, // Crisp facial detail & sharpness
  lowLight, // Shadow recovery & brighten underexposed photos
  bwPro, // Studio monochrome black & white
  custom, // Manual slider adjustments
}

extension EnhancePresetX on EnhancePreset {
  String get title {
    switch (this) {
      case EnhancePreset.magicAuto:
        return 'Magic AI';
      case EnhancePreset.docClean:
        return 'Scan Doc';
      case EnhancePreset.hdrVivid:
        return 'Vivid HDR';
      case EnhancePreset.portraitHd:
        return 'HD Clarity';
      case EnhancePreset.lowLight:
        return 'Low Light';
      case EnhancePreset.bwPro:
        return 'B&W Pro';
      case EnhancePreset.custom:
        return 'Custom';
    }
  }

  String get subtitle {
    switch (this) {
      case EnhancePreset.magicAuto:
        return 'Auto contrast, sharpness & tone fix';
      case EnhancePreset.docClean:
        return 'Remove background shadows & sharpen text';
      case EnhancePreset.hdrVivid:
        return 'Punchy colors, rich tones & saturation';
      case EnhancePreset.portraitHd:
        return 'Edge sharpening & detail boost';
      case EnhancePreset.lowLight:
        return 'Brighten dark areas & reduce shadows';
      case EnhancePreset.bwPro:
        return 'Deep blacks, crisp white highlights';
      case EnhancePreset.custom:
        return 'Fine-tune brightness, contrast & sharpness';
    }
  }

  IconData get icon {
    switch (this) {
      case EnhancePreset.magicAuto:
        return Icons.auto_awesome_rounded;
      case EnhancePreset.docClean:
        return Icons.document_scanner_rounded;
      case EnhancePreset.hdrVivid:
        return Icons.filter_vintage_rounded;
      case EnhancePreset.portraitHd:
        return Icons.face_retouching_natural_rounded;
      case EnhancePreset.lowLight:
        return Icons.brightness_6_rounded;
      case EnhancePreset.bwPro:
        return Icons.tonality_rounded;
      case EnhancePreset.custom:
        return Icons.tune_rounded;
    }
  }

  Color get color {
    switch (this) {
      case EnhancePreset.magicAuto:
        return const Color(0xFFFF8C42); // Orange
      case EnhancePreset.docClean:
        return const Color(0xFF0D9488); // Teal
      case EnhancePreset.hdrVivid:
        return const Color(0xFFEC4899); // Pink
      case EnhancePreset.portraitHd:
        return const Color(0xFF6366F1); // Indigo
      case EnhancePreset.lowLight:
        return const Color(0xFFF59E0B); // Amber
      case EnhancePreset.bwPro:
        return const Color(0xFF475569); // Slate
      case EnhancePreset.custom:
        return const Color(0xFF3B82F6); // Blue
    }
  }
}

// ── Downsample Helper for Fast Preview ────────────────────────────────────────
Uint8List _isolateCreatePreview(Uint8List rawBytes) {
  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) return rawBytes;

  const int maxDim = 1200;
  if (decoded.width <= maxDim && decoded.height <= maxDim) {
    return rawBytes;
  }

  final resized = img.copyResize(
    decoded,
    width: decoded.width > decoded.height ? maxDim : null,
    height: decoded.height >= decoded.width ? maxDim : null,
    interpolation: img.Interpolation.linear,
  );

  return Uint8List.fromList(img.encodeJpg(resized, quality: 88));
}

// ── Ultra-Fast Enhancement Processing Isolate Function ───────────────────────
Uint8List _isolateProcessEnhance(Map<String, dynamic> args) {
  final Uint8List inputBytes = args['bytes'] as Uint8List;
  final String presetName = args['preset'] as String;
  final double brightness = (args['brightness'] as num).toDouble(); // -50..+50
  final double contrast = (args['contrast'] as num).toDouble(); // 0.5..2.0
  final double sharpness = (args['sharpness'] as num).toDouble(); // 0..100
  final double saturation = (args['saturation'] as num).toDouble(); // -50..+50
  final int rotationDegrees = args['rotation'] as int; // 0, 90, 180, 270
  final bool isHighResExport = (args['isHighResExport'] as bool?) ?? false;

  img.Image? decoded = img.decodeImage(inputBytes);
  if (decoded == null) {
    throw Exception('Failed to decode image for enhancement');
  }

  // Handle Rotation
  if (rotationDegrees != 0) {
    decoded = img.copyRotate(decoded, angle: rotationDegrees);
  }

  img.Image processed = decoded;

  if (presetName == EnhancePreset.magicAuto.name) {
    // 1. Auto Magic: Contrast stretch + Crisp detail + Saturation
    processed = img.adjustColor(
      processed,
      brightness: 1.05,
      contrast: 1.16,
      saturation: 1.12,
      gamma: 0.96,
    );
    processed = img.convolution(
      processed,
      filter: [
        0, -0.35, 0,
        -0.35, 2.4, -0.35,
        0, -0.35, 0,
      ],
      div: 1,
    );
  } else if (presetName == EnhancePreset.docClean.name) {
    // 2. Document Clean: High contrast, shadow cleanup
    processed = img.grayscale(processed);
    processed = img.adjustColor(
      processed,
      contrast: 1.40,
      brightness: 1.14,
      gamma: 0.88,
    );
    processed = img.convolution(
      processed,
      filter: [
        0, -0.4, 0,
        -0.4, 2.6, -0.4,
        0, -0.4, 0,
      ],
      div: 1,
    );
  } else if (presetName == EnhancePreset.hdrVivid.name) {
    // 3. Vivid HDR: Deep saturation & dynamic range
    processed = img.adjustColor(
      processed,
      contrast: 1.22,
      saturation: 1.32,
      brightness: 1.02,
    );
  } else if (presetName == EnhancePreset.portraitHd.name) {
    // 4. Portrait Clarity: Sharpening & fine contrast
    processed = img.adjustColor(
      processed,
      contrast: 1.08,
      brightness: 1.03,
      saturation: 1.05,
    );
    processed = img.convolution(
      processed,
      filter: [
        0, -0.4, 0,
        -0.4, 2.6, -0.4,
        0, -0.4, 0,
      ],
      div: 1,
    );
  } else if (presetName == EnhancePreset.lowLight.name) {
    // 5. Low Light Boost: Gamma lift & shadow recovery
    processed = img.adjustColor(
      processed,
      brightness: 1.20,
      contrast: 1.08,
      gamma: 1.18,
    );
  } else if (presetName == EnhancePreset.bwPro.name) {
    // 6. B&W Pro: Rich tonal monochrome
    processed = img.grayscale(processed);
    processed = img.adjustColor(
      processed,
      contrast: 1.28,
      brightness: 1.04,
    );
  } else {
    // 7. Custom manual sliders
    final factorB = 1.0 + (brightness / 100.0);
    final factorS = 1.0 + (saturation / 100.0);

    processed = img.adjustColor(
      processed,
      brightness: factorB,
      contrast: contrast,
      saturation: factorS,
    );

    if (sharpness > 10) {
      final w = (sharpness / 100.0) * 0.6;
      processed = img.convolution(
        processed,
        filter: [
          0, -w, 0,
          -w, 1.0 + (4 * w), -w,
          0, -w, 0,
        ],
        div: 1,
      );
    }
  }

  final quality = isHighResExport ? 94 : 86;
  return Uint8List.fromList(img.encodeJpg(processed, quality: quality));
}

// ── Controller ────────────────────────────────────────────────────────────────
class EnhanceImageController extends GetxController {
  final originalImagePath = RxnString();
  final originalImageName = RxnString();
  final originalSizeBytes = 0.obs;

  // Processed Output
  final enhancedImagePath = RxnString();
  final enhancedSizeBytes = 0.obs;
  final originalImageBytes = Rxn<Uint8List>();
  final previewImageBytes = Rxn<Uint8List>();
  final enhancedImageBytes = Rxn<Uint8List>();

  // Active Settings
  final selectedPreset = EnhancePreset.magicAuto.obs;
  final brightness = 0.0.obs; // -50 to +50
  final contrast = 1.0.obs; // 0.5 to 2.0
  final sharpness = 40.0.obs; // 0 to 100
  final saturation = 0.0.obs; // -50 to +50
  final rotationDegrees = 0.obs; // 0, 90, 180, 270

  // Fast in-memory cache for instant switching
  final Map<String, Uint8List> _presetCache = {};

  // State
  final isPicking = false.obs;
  final isProcessing = false.obs;
  final isCompleted = false.obs;

  final ImagePicker _picker = ImagePicker();
  Timer? _debounceTimer;

  bool get hasImage => originalImagePath.value != null;

  String get formattedOriginalSize =>
      _formatBytes(originalSizeBytes.value);

  String get formattedEnhancedSize =>
      _formatBytes(enhancedSizeBytes.value);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  // ── Image Picking ───────────────────────────────────────────────────────────
  Future<void> pickFromGallery() async {
    try {
      isPicking.value = true;
      String? path;
      try {
        final photo = await _picker.pickImage(source: ImageSource.gallery);
        if (photo != null) path = photo.path;
      } catch (_) {
        final result = await FilePicker.pickFiles(type: FileType.image);
        if (result.isNotEmpty && result.first.path != null) {
          path = result.first.path;
        }
      }

      if (path != null) {
        await loadImage(path);
      }
    } catch (e) {
      log('[EnhanceImage] pick error: $e');
      MyDialogs.info(msg: 'Failed to select image: $e');
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> captureFromCamera() async {
    try {
      isPicking.value = true;
      final photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        await loadImage(photo.path);
      }
    } catch (e) {
      log('[EnhanceImage] camera error: $e');
      MyDialogs.info(msg: 'Failed to capture photo: $e');
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> loadImage(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      MyDialogs.info(msg: 'Selected file does not exist');
      return;
    }

    try {
      isProcessing.value = true;
      _presetCache.clear();

      originalImagePath.value = path;
      originalImageName.value = file.uri.pathSegments.last;
      originalSizeBytes.value = await file.length();
      final bytes = await file.readAsBytes();
      originalImageBytes.value = bytes;

      // Downsample in background isolate once for ultra-fast 60fps real-time preview
      final preview = await compute(_isolateCreatePreview, bytes);
      previewImageBytes.value = preview;

      rotationDegrees.value = 0;
      selectedPreset.value = EnhancePreset.magicAuto;
      brightness.value = 0.0;
      contrast.value = 1.0;
      sharpness.value = 40.0;
      saturation.value = 0.0;

      // Fast instant enhancement
      await applyEnhancement();
    } catch (e) {
      log('[EnhanceImage] load error: $e');
      MyDialogs.info(msg: 'Error loading image: $e');
      reset();
    } finally {
      isProcessing.value = false;
    }
  }

  void reset() {
    _presetCache.clear();
    originalImagePath.value = null;
    originalImageName.value = null;
    originalSizeBytes.value = 0;
    enhancedImagePath.value = null;
    enhancedSizeBytes.value = 0;
    originalImageBytes.value = null;
    previewImageBytes.value = null;
    enhancedImageBytes.value = null;
    isCompleted.value = false;
    isProcessing.value = false;
  }

  // ── Fast Enhancement Execution ──────────────────────────────────────────────
  void selectPreset(EnhancePreset preset) {
    selectedPreset.value = preset;

    // Check fast in-memory cache first (0ms instant)
    final cacheKey = '${preset.name}_${rotationDegrees.value}';
    if (_presetCache.containsKey(cacheKey)) {
      enhancedImageBytes.value = _presetCache[cacheKey];
      enhancedSizeBytes.value = _presetCache[cacheKey]!.length;
      isCompleted.value = true;
      return;
    }

    applyEnhancement();
  }

  void onSliderChanged() {
    selectedPreset.value = EnhancePreset.custom;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 90), () {
      applyEnhancement();
    });
  }

  void rotate90() {
    rotationDegrees.value = (rotationDegrees.value + 90) % 360;
    _presetCache.clear();
    applyEnhancement();
  }

  Future<void> applyEnhancement() async {
    final inputBytes = previewImageBytes.value ?? originalImageBytes.value;
    if (inputBytes == null) return;

    try {
      isProcessing.value = true;

      // Run fast preview enhancement in background isolate
      final processedBytes = await compute(_isolateProcessEnhance, {
        'bytes': inputBytes,
        'preset': selectedPreset.value.name,
        'brightness': brightness.value,
        'contrast': contrast.value,
        'sharpness': sharpness.value,
        'saturation': saturation.value,
        'rotation': rotationDegrees.value,
        'isHighResExport': false,
      });

      enhancedImageBytes.value = processedBytes;
      enhancedSizeBytes.value = processedBytes.length;

      // Cache preset for 0ms instant switching
      if (selectedPreset.value != EnhancePreset.custom) {
        final cacheKey =
            '${selectedPreset.value.name}_${rotationDegrees.value}';
        _presetCache[cacheKey] = processedBytes;
      }

      isCompleted.value = true;
    } catch (e) {
      log('[EnhanceImage] apply error: $e');
      MyDialogs.info(msg: 'Enhancement error: $e');
    } finally {
      isProcessing.value = false;
    }
  }

  // ── High-Res Export & Share Actions ───────────────────────────────────────
  Future<void> shareEnhancedImage() async {
    if (originalImageBytes.value == null) {
      MyDialogs.info(msg: 'No image to share');
      return;
    }

    try {
      MyDialogs.info(msg: 'Preparing high-resolution photo...');

      // Render full original resolution in isolate for final export
      final fullProcessedBytes = await compute(_isolateProcessEnhance, {
        'bytes': originalImageBytes.value!,
        'preset': selectedPreset.value.name,
        'brightness': brightness.value,
        'contrast': contrast.value,
        'sharpness': sharpness.value,
        'saturation': saturation.value,
        'rotation': rotationDegrees.value,
        'isHighResExport': true,
      });

      final tempDir = await getTemporaryDirectory();
      final baseName =
          originalImageName.value?.replaceAll(RegExp(r'\.[^.]+$'), '') ??
              'Enhanced';
      final outPath =
          '${tempDir.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}_$baseName.jpg';
      final outFile = File(outPath);
      await outFile.writeAsBytes(fullProcessedBytes);

      enhancedImagePath.value = outPath;

      await Share.shareXFiles(
        [XFile(outPath, mimeType: 'image/jpeg')],
        text: 'Enhanced Photo: $baseName',
      );
    } catch (e) {
      MyDialogs.info(msg: 'Share error: $e');
    }
  }
}
