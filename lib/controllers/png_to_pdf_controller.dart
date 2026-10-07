// lib/controllers/png_to_pdf_controller.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../ads/ad_helper.dart';
import '../helper/my_dialogs.dart';

// ── Models & Enums ──────────────────────────────────────────────────────────

enum PngPageOrientation {
  auto('Auto (Match Image)', 'Orient each page based on image aspect ratio'),
  portrait('Portrait', 'Standard vertical page orientation'),
  landscape('Landscape', 'Horizontal wide page orientation');

  final String title;
  final String subtitle;
  const PngPageOrientation(this.title, this.subtitle);
}

enum PngPageSize {
  fitImage('Fit to Image', 'Page size matches image exactly (Lossless, Zero Border)'),
  a4('A4', 'Standard international document (210 × 297 mm)'),
  letter('US Letter', 'Standard US document (8.5 × 11 in)');

  final String title;
  final String subtitle;
  const PngPageSize(this.title, this.subtitle);
}

enum PngPageMargin {
  none('No Margin', 'Full bleed edge-to-edge layout', 0.0),
  small('Small', '12 pt clean border', 12.0),
  big('Spacious', '28 pt framed border', 28.0);

  final String title;
  final String subtitle;
  final double marginPoints;
  const PngPageMargin(this.title, this.subtitle, this.marginPoints);
}

class PngImageItem {
  final String id;
  final String path;
  final String name;
  final int sizeInBytes;
  final int width;
  final int height;
  final Uint8List thumbnailBytes;
  int rotationDegrees; // 0, 90, 180, 270

  PngImageItem({
    required this.id,
    required this.path,
    required this.name,
    required this.sizeInBytes,
    required this.width,
    required this.height,
    required this.thumbnailBytes,
    this.rotationDegrees = 0,
  });

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

// ── Controller Implementation ───────────────────────────────────────────────

class PngToPdfController extends GetxController {
  // Selected PNG images list
  final imageItems = <PngImageItem>[].obs;

  // Settings
  final selectedPageSize = PngPageSize.fitImage.obs;
  final selectedOrientation = PngPageOrientation.auto.obs;
  final selectedMargin = PngPageMargin.none.obs;

  // UI state
  final isPicking = false.obs;
  final isConverting = false.obs;
  final conversionProgress = 0.0.obs;
  final statusMessage = 'Ready'.obs;

  // Result state
  final convertedPdfPath = RxnString();
  final convertedPdfSize = 0.obs;
  final convertedPageCount = 0.obs;
  final previewThumbnailBytes = Rxn<Uint8List>();

  int get totalSizeBytes =>
      imageItems.fold<int>(0, (sum, item) => sum + item.sizeInBytes);

  String get formattedTotalSize {
    final bytes = totalSizeBytes;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedConvertedSize {
    final bytes = convertedPdfSize.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  // ── 1. Pick Multiple PNG Images ───────────────────────────────────────────
  Future<void> pickPngImages({bool append = false}) async {
    try {
      isPicking.value = true;
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'PNG'],
      );

      if (result.isEmpty) return;

      final newItems = <PngImageItem>[];
      for (final file in result) {
        if (file.path == null) continue;
        final f = File(file.path!);
        if (!await f.exists()) continue;

        final bytes = await f.readAsBytes();
        final size = bytes.length;
        final fileName = file.name;

        // Extract dimensions fast via UI Codec
        int w = 800;
        int h = 600;
        try {
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          w = frame.image.width;
          h = frame.image.height;
          frame.image.dispose();
        } catch (_) {}

        newItems.add(
          PngImageItem(
            id: '${DateTime.now().microsecondsSinceEpoch}_${newItems.length}',
            path: file.path!,
            name: fileName,
            sizeInBytes: size,
            width: w,
            height: h,
            thumbnailBytes: bytes,
          ),
        );
      }

      if (newItems.isNotEmpty) {
        if (append) {
          imageItems.addAll(newItems);
        } else {
          imageItems.value = newItems;
        }
        // Reset previous conversion result
        convertedPdfPath.value = null;
        convertedPdfSize.value = 0;
        convertedPageCount.value = 0;
        previewThumbnailBytes.value = null;
      }
    } catch (e) {
      log('[PngToPdf] pickPngImages error: $e');
      MyDialogs.info(msg: 'Failed to pick PNG images: $e');
    } finally {
      isPicking.value = false;
    }
  }

  // Pick from Gallery
  Future<void> pickFromGallery() async {
    try {
      isPicking.value = true;
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage();

      if (pickedFiles.isEmpty) return;

      final newItems = <PngImageItem>[];
      for (final xfile in pickedFiles) {
        final f = File(xfile.path);
        if (!await f.exists()) continue;

        final bytes = await f.readAsBytes();
        int w = 800;
        int h = 600;
        try {
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          w = frame.image.width;
          h = frame.image.height;
          frame.image.dispose();
        } catch (_) {}

        newItems.add(
          PngImageItem(
            id: '${DateTime.now().microsecondsSinceEpoch}_${newItems.length}',
            path: xfile.path,
            name: xfile.name,
            sizeInBytes: bytes.length,
            width: w,
            height: h,
            thumbnailBytes: bytes,
          ),
        );
      }

      if (newItems.isNotEmpty) {
        imageItems.addAll(newItems);
        convertedPdfPath.value = null;
        convertedPdfSize.value = 0;
        convertedPageCount.value = 0;
        previewThumbnailBytes.value = null;
      }
    } catch (e) {
      log('[PngToPdf] pickFromGallery error: $e');
      MyDialogs.info(msg: 'Failed to select images: $e');
    } finally {
      isPicking.value = false;
    }
  }

  // ── 2. List Management ────────────────────────────────────────────────────
  void removeImage(int index) {
    if (index >= 0 && index < imageItems.length) {
      imageItems.removeAt(index);
    }
  }

  void rotateImage(int index) {
    if (index >= 0 && index < imageItems.length) {
      final item = imageItems[index];
      item.rotationDegrees = (item.rotationDegrees + 90) % 360;
      imageItems.refresh();
    }
  }

  void reorderImages(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = imageItems.removeAt(oldIndex);
    imageItems.insert(newIndex, item);
  }

  // ── 3. Convert PNGs to PDF ────────────────────────────────────────────────
  Future<String?> convertToPdf() async {
    if (imageItems.isEmpty) {
      MyDialogs.info(msg: 'Please add at least one PNG image first');
      return null;
    }

    try {
      isConverting.value = true;
      conversionProgress.value = 0.10;
      statusMessage.value = 'Preparing PDF document...';

      final pdfDoc = pw.Document(
        title: 'PNG to PDF Document',
        author: 'Translator Ably',
        creator: 'PNG to PDF Converter',
      );

      final total = imageItems.length;

      for (int i = 0; i < total; i++) {
        final item = imageItems[i];
        final progressVal = 0.15 + (0.65 * (i / total));
        conversionProgress.value = progressVal;
        statusMessage.value = 'Processing image ${i + 1} of $total...';

        final file = File(item.path);
        if (!await file.exists()) continue;
        final rawBytes = await file.readAsBytes();

        // Calculate page dimension
        pw_pdf.PdfPageFormat pageFormat;
        final imgW = item.width.toDouble();
        final imgH = item.height.toDouble();
        final isRotated90or270 = item.rotationDegrees == 90 || item.rotationDegrees == 270;
        final effectiveW = isRotated90or270 ? imgH : imgW;
        final effectiveH = isRotated90or270 ? imgW : imgH;

        switch (selectedPageSize.value) {
          case PngPageSize.fitImage:
            // Custom page size matching image dimensions with 72 dpi scaling
            pageFormat = pw_pdf.PdfPageFormat(effectiveW, effectiveH, marginAll: selectedMargin.value.marginPoints);
            break;

          case PngPageSize.a4:
            if (selectedOrientation.value == PngPageOrientation.auto) {
              pageFormat = effectiveW > effectiveH
                  ? pw_pdf.PdfPageFormat.a4.landscape
                  : pw_pdf.PdfPageFormat.a4;
            } else if (selectedOrientation.value == PngPageOrientation.landscape) {
              pageFormat = pw_pdf.PdfPageFormat.a4.landscape;
            } else {
              pageFormat = pw_pdf.PdfPageFormat.a4;
            }
            break;

          case PngPageSize.letter:
            if (selectedOrientation.value == PngPageOrientation.auto) {
              pageFormat = effectiveW > effectiveH
                  ? pw_pdf.PdfPageFormat.letter.landscape
                  : pw_pdf.PdfPageFormat.letter;
            } else if (selectedOrientation.value == PngPageOrientation.landscape) {
              pageFormat = pw_pdf.PdfPageFormat.letter.landscape;
            } else {
              pageFormat = pw_pdf.PdfPageFormat.letter;
            }
            break;
        }

        final marginPts = selectedMargin.value.marginPoints;
        final pwImg = pw.MemoryImage(rawBytes);

        pdfDoc.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.all(marginPts),
            build: (pw.Context ctx) {
              pw.Widget content = pw.Center(
                child: pw.Image(
                  pwImg,
                  fit: selectedPageSize.value == PngPageSize.fitImage && marginPts == 0
                      ? pw.BoxFit.fill
                      : pw.BoxFit.contain,
                ),
              );

              // Apply rotation if needed
              if (item.rotationDegrees == 90) {
                content = pw.Transform.rotateBox(
                  angle: 1.57079632679, // 90 deg in rad
                  child: content,
                );
              } else if (item.rotationDegrees == 180) {
                content = pw.Transform.rotateBox(
                  angle: 3.14159265359, // 180 deg in rad
                  child: content,
                );
              } else if (item.rotationDegrees == 270) {
                content = pw.Transform.rotateBox(
                  angle: 4.71238898038, // 270 deg in rad
                  child: content,
                );
              }

              return content;
            },
          ),
        );
      }

      conversionProgress.value = 0.85;
      statusMessage.value = 'Writing PDF file...';

      final outputBytes = await pdfDoc.save();
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/png_to_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outFile = File(outputPath);
      await outFile.writeAsBytes(outputBytes, flush: true);

      convertedPdfPath.value = outputPath;
      convertedPdfSize.value = outputBytes.length;

      // Render page 1 preview thumbnail
      try {
        final pdfViewDoc = await PdfDocument.openFile(outputPath);
        convertedPageCount.value = pdfViewDoc.pagesCount;
        final pageOne = await pdfViewDoc.getPage(1);
        final pageImg = await pageOne.render(
          width: pageOne.width * 1.2,
          height: pageOne.height * 1.2,
          format: PdfPageImageFormat.png,
        );
        previewThumbnailBytes.value = pageImg?.bytes;
        await pageOne.close();
        await pdfViewDoc.close();
      } catch (e) {
        log('[PngToPdf] thumbnail render error: $e');
        convertedPageCount.value = total;
      }

      conversionProgress.value = 1.0;
      statusMessage.value = 'Done!';
      MyDialogs.success(msg: 'PNG to PDF converted successfully!');
      AdHelper.showInterstitialAd(onComplete: () {});
      return outputPath;
    } catch (e) {
      log('[PngToPdf] convertToPdf error: $e');
      MyDialogs.info(msg: 'Conversion failed: $e');
      return null;
    } finally {
      isConverting.value = false;
    }
  }

  // ── 4. Share and Reset ────────────────────────────────────────────────────
  Future<void> shareConvertedPdf() async {
    final path = convertedPdfPath.value;
    if (path == null) return;
    try {
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'PDF Document from PNG Images',
        text: 'Created with Translator Ably (PNG to PDF)',
      );
    } catch (e) {
      log('[PngToPdf] share error: $e');
      MyDialogs.info(msg: 'Failed to share PDF: $e');
    }
  }

  void reset() {
    imageItems.clear();
    convertedPdfPath.value = null;
    convertedPdfSize.value = 0;
    convertedPageCount.value = 0;
    previewThumbnailBytes.value = null;
    conversionProgress.value = 0.0;
    statusMessage.value = 'Ready';
  }
}
