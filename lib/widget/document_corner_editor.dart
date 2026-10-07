// lib/widget/document_corner_editor.dart
//
// Shows the captured photo with the detected document outline on top, and lets
// the user drag any of the four corners to correct it before the crop is
// applied. The quad is kept convex while dragging, because a folded quad warps
// to garbage.

import 'dart:io';
import 'dart:math' as math;

import 'package:document_scan/document_scan.dart';
import 'package:flutter/material.dart';

/// Interactive crop-correction surface for one scanned page.
class DocumentCornerEditor extends StatefulWidget {
  const DocumentCornerEditor({
    super.key,
    required this.imagePath,
    required this.imageSize,
    required this.corners,
    required this.onCornersChanged,
  });

  /// The captured still on disk.
  final String imagePath;

  /// Pixel dimensions of [imagePath] (EXIF-oriented), matching the space the
  /// corners are expressed in.
  final Size imageSize;

  /// Current quad, normalized 0..1.
  final DocumentCorners corners;

  final ValueChanged<DocumentCorners> onCornersChanged;

  @override
  State<DocumentCornerEditor> createState() => DocumentCornerEditorState();
}

class DocumentCornerEditorState extends State<DocumentCornerEditor> {
  static const double _hitRadius = 52.0;

  /// Smallest normalized quad area we still accept — below this the four
  /// handles have been dragged onto each other.
  static const double _minArea = 0.01;

  int? _activeCorner;
  Rect _display = Rect.zero;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        _display = _containRect(widget.imageSize, box);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) => _onPanStart(details.localPosition),
          onPanUpdate: (details) => _onPanUpdate(details.localPosition),
          onPanEnd: (_) => _onPanEnd(),
          onPanCancel: _onPanEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: _display,
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Colors.black26,
                    child: Center(
                      child: Icon(Icons.broken_image_rounded,
                          color: Colors.white54),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _CornerEditorPainter(
                    corners: widget.corners,
                    display: _display,
                    activeCorner: _activeCorner,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Gesture handling ──────────────────────────────────────────────────────

  void _onPanStart(Offset local) {
    final hit = _nearestCorner(local);
    if (hit != null) setState(() => _activeCorner = hit);
  }

  void _onPanEnd() {
    if (_activeCorner != null) setState(() => _activeCorner = null);
  }

  void _onPanUpdate(Offset local) {
    final index = _activeCorner;
    if (index == null || _display.isEmpty) return;

    final nx = ((local.dx - _display.left) / _display.width).clamp(0.0, 1.0);
    final ny = ((local.dy - _display.top) / _display.height).clamp(0.0, 1.0);

    final updated = _withCorner(widget.corners, index, (x: nx, y: ny));

    // Stop the handle at the point where the quad would fold in on itself.
    if (!updated.isConvex || updated.area < _minArea) return;

    widget.onCornersChanged(updated);
  }

  int? _nearestCorner(Offset point) {
    final points = _displayPoints();
    int? best;
    var bestDistance = _hitRadius;
    for (var i = 0; i < points.length; i++) {
      final distance = (points[i] - point).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best;
  }

  List<Offset> _displayPoints() =>
      widget.corners.toList().map(_toDisplay).toList();

  Offset _toDisplay(ScanPoint p) => Offset(
        _display.left + p.x * _display.width,
        _display.top + p.y * _display.height,
      );

  static DocumentCorners _withCorner(
    DocumentCorners corners,
    int index,
    ScanPoint point,
  ) {
    switch (index) {
      case 0:
        return corners.copyWith(topLeft: point);
      case 1:
        return corners.copyWith(topRight: point);
      case 2:
        return corners.copyWith(bottomRight: point);
      case 3:
        return corners.copyWith(bottomLeft: point);
      default:
        return corners;
    }
  }

  /// Where an image of [frame] lands inside [box] with `BoxFit.contain`.
  static Rect _containRect(Size frame, Size box) {
    if (frame.width <= 0 || frame.height <= 0) return Offset.zero & box;
    final scale = math.min(box.width / frame.width, box.height / frame.height);
    final w = frame.width * scale;
    final h = frame.height * scale;
    return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
  }
}

class _CornerEditorPainter extends CustomPainter {
  _CornerEditorPainter({
    required this.corners,
    required this.display,
    required this.activeCorner,
  });

  final DocumentCorners corners;
  final Rect display;
  final int? activeCorner;

  static const Color _border = Color(0xFF2979FF);
  static const Color _active = Color(0xFF00E676);

  @override
  void paint(Canvas canvas, Size size) {
    if (display.isEmpty) return;

    final points = corners.toList().map((p) {
      return Offset(
        display.left + p.x * display.width,
        display.top + p.y * display.height,
      );
    }).toList();

    _paintScrim(canvas, size, points);
    _paintThirds(canvas);
    _paintQuad(canvas, points);
    _paintHandles(canvas, points);
  }

  void _paintScrim(Canvas canvas, Size size, List<Offset> points) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPolygon(points, true);
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
  }

  /// Rule-of-thirds guides inside the selection, to help square the page up.
  void _paintThirds(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1;

    for (var i = 1; i <= 2; i++) {
      final dx = display.left + display.width * i / 3;
      final dy = display.top + display.height * i / 3;
      canvas.drawLine(Offset(dx, display.top), Offset(dx, display.bottom), paint);
      canvas.drawLine(Offset(display.left, dy), Offset(display.right, dy), paint);
    }
  }

  void _paintQuad(Canvas canvas, List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = _border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintHandles(Canvas canvas, List<Offset> points) {
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final isActive = i == activeCorner;
      final radius = isActive ? 15.0 : 11.0;
      final accent = isActive ? _active : _border;

      canvas.drawCircle(
        point,
        radius + 2,
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
      canvas.drawCircle(point, radius, Paint()..color = Colors.white);
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawCircle(
        point,
        isActive ? 4.5 : 3,
        Paint()..color = accent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CornerEditorPainter oldDelegate) {
    return oldDelegate.corners != corners ||
        oldDelegate.display != display ||
        oldDelegate.activeCorner != activeCorner;
  }
}
