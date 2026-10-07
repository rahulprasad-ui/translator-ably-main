// lib/widget/document_overlay_painter.dart
//
// Paints the Adobe-Scan-style overlay: everything outside the *detected*
// document is dimmed, and the document itself is outlined in blue along its
// real four corners — never a fixed rectangle.

import 'dart:math' as math;

import 'package:document_scan/document_scan.dart';
import 'package:flutter/material.dart';

class DocumentOverlayPainter extends CustomPainter {
  DocumentOverlayPainter({
    required this.corners,
    required this.frameSize,
    required this.pulse,
    this.steady = false,
  });

  /// Detected quad, normalized 0..1 over the upright frame. `null` = no
  /// document in view.
  final DocumentCorners? corners;

  /// Upright size of the camera frame the corners are relative to.
  final Size? frameSize;

  /// 0..1 loop driving the idle "searching" hint.
  final double pulse;

  /// When true the border switches to the "locked / keep steady" tint.
  final bool steady;

  static const Color borderColor = Color(0xFF2979FF);
  static const Color steadyColor = Color(0xFF00E676);

  /// Where a camera frame of [frame] lands inside a [box] when rendered with
  /// `BoxFit.cover` — the exact mapping used to place the preview, so the
  /// painted quad sits on top of the paper.
  static Rect coverRect(Size frame, Size box) {
    if (frame.width <= 0 || frame.height <= 0) return Offset.zero & box;
    final scale = math.max(box.width / frame.width, box.height / frame.height);
    final w = frame.width * scale;
    final h = frame.height * scale;
    return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final frame = frameSize;
    if (frame == null || !frame.isFinite || frame.isEmpty) return;

    final display = coverRect(frame, size);
    final quad = corners;
    final points = quad == null ? null : _mapPoints(quad, display);

    _paintScrim(canvas, size, points);
    if (points == null) {
      _paintIdleHint(canvas, size);
    } else {
      _paintDocumentOutline(canvas, points);
    }
  }

  void _paintScrim(Canvas canvas, Size size, List<Offset>? points) {
    final path = Path()..fillType = PathFillType.evenOdd;
    path.addRect(Offset.zero & size);
    if (points != null) {
      path.addPolygon(points, true); // punched out by even-odd
    }
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: points == null ? 0.34 : 0.44),
    );
  }

  void _paintDocumentOutline(Canvas canvas, List<Offset> points) {
    final path = _quadPath(points);
    final color = steady ? steadyColor : borderColor;

    // Soft glow so the outline reads against busy backgrounds.
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );

    // Four corner handles, so the detected points are explicit.
    for (final point in points) {
      canvas.drawCircle(
        point,
        9,
        Paint()..color = Colors.black.withValues(alpha: 0.25),
      );
      canvas.drawCircle(point, 7, Paint()..color = Colors.white);
      canvas.drawCircle(
        point,
        7,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _paintIdleHint(Canvas canvas, Size size) {
    final inset = Rect.fromLTRB(
      size.width * 0.12,
      size.height * 0.20,
      size.width * 0.88,
      size.height * 0.74,
    );

    final alpha = 0.30 + 0.45 * pulse;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const armLength = 30.0;
    // Top-left
    canvas.drawLine(inset.topLeft, inset.topLeft.translate(armLength, 0), paint);
    canvas.drawLine(inset.topLeft, inset.topLeft.translate(0, armLength), paint);
    // Top-right
    canvas.drawLine(inset.topRight, inset.topRight.translate(-armLength, 0), paint);
    canvas.drawLine(inset.topRight, inset.topRight.translate(0, armLength), paint);
    // Bottom-left
    canvas.drawLine(inset.bottomLeft, inset.bottomLeft.translate(armLength, 0), paint);
    canvas.drawLine(inset.bottomLeft, inset.bottomLeft.translate(0, -armLength), paint);
    // Bottom-right
    canvas.drawLine(inset.bottomRight, inset.bottomRight.translate(-armLength, 0), paint);
    canvas.drawLine(inset.bottomRight, inset.bottomRight.translate(0, -armLength), paint);
  }

  List<Offset> _mapPoints(DocumentCorners quad, Rect display) {
    return quad.toList().map((p) {
      return Offset(
        display.left + p.x * display.width,
        display.top + p.y * display.height,
      );
    }).toList();
  }

  Path _quadPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant DocumentOverlayPainter oldDelegate) {
    return oldDelegate.corners != corners ||
        oldDelegate.frameSize != frameSize ||
        oldDelegate.pulse != pulse ||
        oldDelegate.steady != steady;
  }
}
