// lib/features/pdf_editor_v2/presentation/widgets/pdf_canvas.dart
import 'dart:math' as math;
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
    // 1. Render live preview of committed edits FIRST:
    // Completely wipe the original text area clean with solid background to eliminate
    // any trace, ghosting, or overlapping of original text (Adobe Acrobat in-place replacement).
    for (final edit in activeEdits) {
      // Calculate union bounding box of original text and replacement text
      // with generous margin to cover all font ascenders, descenders (g, j, p, q, y),
      // accents, and raster anti-aliasing fuzz
      final eraseRect = Rect.fromLTRB(
        math.min(edit.originalItem.x, edit.targetRect.left) - 2.5,
        math.min(edit.originalItem.y, edit.targetRect.top) - 2.5,
        math.max(edit.originalItem.x + edit.originalItem.width, edit.targetRect.right) + 3.5,
        math.max(edit.originalItem.y + edit.originalItem.height, edit.targetRect.bottom) + 3.5,
      );

      final bgPaint = Paint()
        ..color = edit.appliedFont.backgroundColor != null
            ? Color(edit.appliedFont.backgroundColor!)
            : Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRect(eraseRect, bgPaint);

      // Draw replacement text using its typography style
      if (edit.replacementText.isNotEmpty) {
        final textStyle = edit.appliedFont.toFlutterTextStyle();
        final textSpan = TextSpan(text: edit.replacementText, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        textPainter.layout();

        // Calculate vertical centering within original line height to align glyphs precisely
        final double vOffset =
            edit.originalItem.y + (edit.originalItem.height - textPainter.height) / 2.0;
        textPainter.paint(canvas, Offset(edit.targetRect.left, vOffset));
      }
    }

    // 2. Draw subtle guide rectangles for selectable text ONLY if enabled and item is not edited
    if (showAllTextBounds) {
      final guidePaint = Paint()
        ..color = const Color(0x143B82F6) // very subtle blue highlight
        ..style = PaintingStyle.fill;

      final guideStroke = Paint()
        ..color = const Color(0x333B82F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      for (final item in textItems) {
        // Skip items that have active edits
        final hasEdit = activeEdits.any((e) => e.originalItem.id == item.id);
        if (hasEdit) continue;

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

    // 3. Draw STRICT RED Adobe-style selection rectangle around selected text item
    if (selectedItem != null) {
      // Find if selected item has an active edit
      final activeEdit = activeEdits.cast<TextEditRecord?>().firstWhere(
            (e) => e != null && e.originalItem.id == selectedItem!.id,
            orElse: () => null,
          );

      final rect = activeEdit != null ? activeEdit.targetRect : selectedItem!.boundingBox;

      // Soft red background highlight
      final fillPaint = Paint()
        ..color = const Color(0x1AE11D48) // Red with ~10% opacity
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), fillPaint);

      // Distinct RED bounding outline (Acrobat-style)
      final borderPaint = Paint()
        ..color = const Color(0xFFE11D48) // Vibrant Red
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
