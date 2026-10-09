// lib/features/pdf_editor_v2/presentation/widgets/pdf_canvas.dart
import 'package:flutter/material.dart';
import '../../data/models/pdf_text_item.dart';
import '../../domain/entities/text_edit_record.dart';

/// CustomPainter that renders text selection rectangles, handles, and live preview overlays
class PdfCanvasPainter extends CustomPainter {
  final List<PdfTextItem> textItems;
  final PdfTextItem? selectedItem;
  final List<TextEditRecord> activeEdits;
  final bool showAllTextBounds;

  PdfCanvasPainter({
    required this.textItems,
    this.selectedItem,
    this.activeEdits = const [],
    this.showAllTextBounds = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw subtle guide rectangles for all selectable text if enabled
    if (showAllTextBounds) {
      final guidePaint = Paint()
        ..color = const Color(0x223B82F6) // subtle blue highlight
        ..style = PaintingStyle.fill;

      final guideStroke = Paint()
        ..color = const Color(0x443B82F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      for (final item in textItems) {
        if (item.id != selectedItem?.id) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(item.boundingBox, const Radius.circular(2)),
            guidePaint,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(item.boundingBox, const Radius.circular(2)),
            guideStroke,
          );
        }
      }
    }

    // 2. Render live preview of committed edits (draw over canvas so user sees modifications in real time)
    for (final edit in activeEdits) {
      // Clear original text area with clean background
      final bgPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRect(edit.targetRect.inflate(1.0), bgPaint);

      // Draw replacement text using its typography style
      final textStyle = edit.appliedFont.toFlutterTextStyle();
      final textSpan = TextSpan(text: edit.replacementText, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );
      textPainter.layout(maxWidth: edit.targetRect.width.clamp(50.0, 800.0));
      textPainter.paint(canvas, Offset(edit.targetRect.left, edit.targetRect.top));
    }

    // 3. Draw STRICT RED selection rectangle around selected text item
    if (selectedItem != null) {
      final rect = selectedItem!.boundingBox;

      // Soft red background highlight
      final fillPaint = Paint()
        ..color = const Color(0x1AE11D48) // Red with ~10% opacity
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), fillPaint);

      // Distinct RED bounding outline
      final borderPaint = Paint()
        ..color = const Color(0xFFE11D48) // Vibrant Red (Acrobat-style)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), borderPaint);

      // Draw corner selection handles
      _drawCornerHandles(canvas, rect);
    }
  }

  void _drawCornerHandles(Canvas canvas, Rect rect) {
    const double handleSize = 6.0;
    final handlePaint = Paint()
      ..color = const Color(0xFFE11D48)
      ..style = PaintingStyle.fill;

    final handleBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];

    for (final corner in corners) {
      final handleRect = Rect.fromCenter(
        center: corner,
        width: handleSize,
        height: handleSize,
      );
      canvas.drawRect(handleRect, handlePaint);
      canvas.drawRect(handleRect, handleBorder);
    }
  }

  @override
  bool shouldRepaint(covariant PdfCanvasPainter oldDelegate) {
    return oldDelegate.selectedItem?.id != selectedItem?.id ||
        oldDelegate.activeEdits.length != activeEdits.length ||
        oldDelegate.showAllTextBounds != showAllTextBounds ||
        oldDelegate.textItems.length != textItems.length;
  }
}
