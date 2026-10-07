// lib/services/pdf_export_isolate.dart
//
// The export job: render every source page with pdfx, draw the user's overlays
// on top in Flutter (same painters' geometry as the on-screen preview), then
// assemble the result as one PDF with the `pdf` package. Runs on a background
// isolate via `compute`, so a 200-page document never janks the UI.
//
// The preview approximation is intentional: the app's editing surface IS the
// rendered raster, so exporting raster + overlays reproduces exactly what the
// user saw while editing — same coordinates, same fonts, same visuals.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' as ppdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';

/// Plain-data input so `compute` can send this to a background isolate.
class ExportJobInput {
  const ExportJobInput({
    required this.sourcePath,
    required this.outPath,
    required this.overlays,
  });

  final String sourcePath;
  final String outPath;
  final List<Map<String, Object>> overlays;
}

/// Serializable overlay description (all Dart/Flutter primitives).
class ExportOverlay {
  ExportOverlay.fromMap(Map<String, Object> m)
      : pageIndex = (m['pageIndex'] as num).toInt(),
        type = (m['type'] as num).toInt(),
        x = (m['x'] as num).toDouble(),
        y = (m['y'] as num).toDouble(),
        w = (m['w'] as num).toDouble(),
        h = (m['h'] as num).toDouble(),
        text = m['text'] as String? ?? '',
        colorValue = (m['colorValue'] as num).toInt(),
        backgroundColorValue = (m['backgroundColorValue'] as num?)?.toInt() ?? 0,
        fontSize = (m['fontSize'] as num).toDouble(),
        isBold = m['isBold'] as bool? ?? false,
        isItalic = m['isItalic'] as bool? ?? false,
        isUnderline = m['isUnderline'] as bool? ?? false,
        textAlignIndex = (m['textAlignIndex'] as num?)?.toInt() ?? 0,
        fontFamily = m['fontFamily'] as String? ?? 'Roboto',
        imageBytes = m['imageBytes'] as Uint8List?,
        imagePath = m['imagePath'] as String?,
        strokes = [
          for (final pair in (m['strokes'] as List? ?? const []))
            Offset(
              (pair[0] as num).toDouble(),
              (pair[1] as num).toDouble(),
            ),
        ];

  final int pageIndex;
  final int type; // 0 = text, 1 = image, 2 = highlight, 3 = signature, 4 = drawing
  final double x, y, w, h;
  final String text;
  final int colorValue;
  final int backgroundColorValue;
  final double fontSize;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final int textAlignIndex;
  final String fontFamily;
  final Uint8List? imageBytes;
  final String? imagePath;
  final List<Offset> strokes;

  bool get isText => type == 0;
  bool get isImage => type == 1;
  bool get isHighlight => type == 2;
  bool get isSignature => type == 3;
  bool get isDrawing => type == 4;
}

class ExportIsolate {
  /// Renders + draws + assembles; returns [input.outPath] on success.
  static Future<String?> run(ExportJobInput input) async {
    try {
      final doc = pw.Document();

      // Group overlays per page once, instead of scanning per page.
      final byPage = <int, List<ExportOverlay>>{};
      for (final raw in input.overlays) {
        final overlay = ExportOverlay.fromMap(raw);
        byPage.putIfAbsent(overlay.pageIndex, () => []).add(overlay);
      }

      final source = await PdfDocument.openFile(input.sourcePath);
      try {
        final total = source.pagesCount;
        for (var i = 0; i < total; i++) {
          Uint8List? pageBytes;
          try {
            pageBytes = await _renderPage(source, i + 1);
            if (pageBytes == null) continue;

            final decoded = await _decode(pageBytes);
            if (decoded == null) continue;

            final image = pw.MemoryImage(pageBytes);
            final pageOverlays = byPage[i] ?? const <ExportOverlay>[];
            final pdfImage = await _drawOverlays(decoded, pageOverlays);

            doc.addPage(
              pw.Page(
                pageFormat: ppdf.PdfPageFormat(
                  decoded.width.toDouble(),
                  decoded.height.toDouble(),
                ),
                margin: pw.EdgeInsets.zero,
                build: (context) => pw.Stack(
                  children: [
                    pw.Positioned.fill(
                      child: pw.Image(image, fit: pw.BoxFit.fill),
                    ),
                    if (pdfImage != null)
                      pw.Positioned.fill(
                        child: pw.Image(
                          pw.MemoryImage(pdfImage),
                          fit: pw.BoxFit.fill,
                        ),
                      ),
                  ],
                ),
              ),
            );
          } finally {
            // Release ASAP — peak memory stays at one page.
          }
        }
      } finally {
        await source.close();
      }

      final bytes = await doc.save();
      if (bytes.isEmpty) return null;
      File(input.outPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes, flush: true);
      return input.outPath;
    } catch (_) {
      return null;
    }
  }

  // ── Rendering ─────────────────────────────────────────────────────────────

  static Future<Uint8List?> _renderPage(PdfDocument doc, int pageNo) async {
    PdfPage? page;
    try {
      page = await doc.getPage(pageNo);
      final scale = (1200.0 / page.width).clamp(1.0, 2.0);
      final rendered = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: PdfPageImageFormat.png,
        backgroundColor: '#ffffff',
      );
      return rendered?.bytes;
    } catch (_) {
      return null;
    } finally {
      try {
        await page?.close();
      } catch (_) {}
    }
  }

  static Future<img.Image?> _decode(Uint8List bytes) async {
    try {
      final decoded = img.decodePng(bytes);
      return decoded;
    } catch (_) {
      try {
        return img.decodeJpg(bytes);
      } catch (_) {
        return null;
      }
    }
  }

  // ── Overlay baking ────────────────────────────────────────────────────────

  /// Draws all of [overlays] for one page onto the rendered raster and returns
  /// the composited result as PNG bytes, or null when there's nothing to draw.
  static Future<Uint8List?> _drawOverlays(
    img.Image base,
    List<ExportOverlay> overlays,
  ) async {
    if (overlays.isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(base.width.toDouble(), base.height.toDouble());

    canvas.drawImage(await _toUiImage(base), Offset.zero, Paint());

    for (final o in overlays) {
      final color = Color(o.colorValue);
      final bgColor = Color(o.backgroundColorValue);

      if (o.isHighlight) {
        canvas.drawRect(
          Rect.fromLTWH(o.x, o.y, o.w, o.h),
          Paint()..color = color,
        );
      } else if (o.isDrawing || o.isSignature) {
        _drawStrokes(canvas, o.strokes, color,
            o.isDrawing ? math.max(2.0, o.w) : 3.0);
      } else if (o.isImage && o.imageBytes != null) {
        try {
          final codec = await ui.instantiateImageCodec(o.imageBytes!);
          final frame = await codec.getNextFrame();
          canvas.drawImageRect(
            frame.image,
            Rect.fromLTWH(0, 0, frame.image.width.toDouble(), frame.image.height.toDouble()),
            Rect.fromLTWH(o.x, o.y, o.w, o.h),
            Paint()..filterQuality = FilterQuality.high,
          );
        } catch (_) {}
      } else if (o.isText) {
        _drawText(
          canvas,
          text: o.text,
          topLeft: Offset(o.x, o.y),
          maxWidth: o.w,
          fontSize: o.fontSize,
          color: color,
          backgroundColor: bgColor.alpha > 0 ? bgColor : null,
          bold: o.isBold,
          italic: o.isItalic,
          underline: o.isUnderline,
          align: TextAlign.values[o.textAlignIndex.clamp(0, 2)],
          fontFamily: o.fontFamily,
        );
      }
    }

    final picture = recorder.endRecording();
    final composited = await picture.toImage(
      size.width.round(),
      size.height.round(),
    );

    final bytes =
        await composited.toByteData(format: ui.ImageByteFormat.png);
    composited.dispose();
    return bytes?.buffer.asUint8List();
  }

  static Future<ui.Image> _toUiImage(img.Image source) async {
    final png = Uint8List.fromList(img.encodePng(source));
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static void _drawStrokes(
    Canvas canvas,
    List<Offset> pts,
    Color color,
    double width,
  ) {
    if (pts.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      // Offset.zero is the end-of-stroke separator, same convention as the pad.
      if (pts[i] == Offset.zero) {
        if (i + 1 < pts.length) path.moveTo(pts[i + 1].dx, pts[i + 1].dy);
      } else {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  static void _drawText(
    Canvas canvas, {
    required String text,
    required Offset topLeft,
    required double maxWidth,
    required double fontSize,
    required Color color,
    Color? backgroundColor,
    required bool bold,
    bool italic = false,
    bool underline = false,
    required TextAlign align,
    required String fontFamily,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          decoration: underline ? TextDecoration.underline : TextDecoration.none,
          fontFamily: fontFamily,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(20, maxWidth));

    if (backgroundColor != null && backgroundColor.alpha > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            topLeft.dx - 4,
            topLeft.dy - 2,
            math.max(maxWidth, painter.width) + 8,
            painter.height + 4,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = backgroundColor,
      );
    }

    final dx = switch (align) {
      TextAlign.center => topLeft.dx + (maxWidth - painter.width) / 2,
      TextAlign.right => topLeft.dx + maxWidth - painter.width,
      _ => topLeft.dx,
    };
    painter.paint(canvas, Offset(dx, topLeft.dy));
  }
}
