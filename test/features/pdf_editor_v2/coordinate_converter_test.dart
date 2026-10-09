// test/features/pdf_editor_v2/coordinate_converter_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translator/features/pdf_editor_v2/data/models/pdf_text_item.dart';
import 'package:translator/features/pdf_editor_v2/domain/coordinate_converter.dart';

void main() {
  group('CoordinateConverter - Coordinate Conversion & Transforms', () {
    test('pageToScreen converts 1:1 when scale is 1.0 and offset is zero', () {
      const pagePoint = Offset(100.0, 200.0);
      final screenPoint = CoordinateConverter.pageToScreen(
        pagePoint,
        scale: 1.0,
        panOffset: Offset.zero,
      );

      expect(screenPoint.dx, 100.0);
      expect(screenPoint.dy, 200.0);
    });

    test('pageToScreen applies zoom scale and pan offset correctly', () {
      const pagePoint = Offset(50.0, 80.0);
      final screenPoint = CoordinateConverter.pageToScreen(
        pagePoint,
        scale: 2.5,
        panOffset: const Offset(30.0, 40.0),
      );

      expect(screenPoint.dx, 50.0 * 2.5 + 30.0); // 155.0
      expect(screenPoint.dy, 80.0 * 2.5 + 40.0); // 240.0
    });

    test('screenToPage reverses pageToScreen accurately', () {
      const originalPage = Offset(120.0, 340.0);
      const scale = 1.75;
      const pan = Offset(45.0, -20.0);

      final screenPoint = CoordinateConverter.pageToScreen(
        originalPage,
        scale: scale,
        panOffset: pan,
      );

      final recoveredPage = CoordinateConverter.screenToPage(
        screenPoint,
        scale: scale,
        panOffset: pan,
      );

      expect(recoveredPage.dx, closeTo(originalPage.dx, 0.0001));
      expect(recoveredPage.dy, closeTo(originalPage.dy, 0.0001));
    });

    test('pdfRectToScreen scales rect and translates correctly', () {
      const pdfRect = Rect.fromLTWH(50.0, 100.0, 200.0, 40.0);
      const scale = 2.0;
      const pan = Offset(10.0, 20.0);

      final screenRect = CoordinateConverter.pdfRectToScreen(
        pdfRect,
        scale: scale,
        panOffset: pan,
      );

      expect(screenRect.left, 50.0 * 2.0 + 10.0); // 110.0
      expect(screenRect.top, 100.0 * 2.0 + 20.0); // 220.0
      expect(screenRect.width, 400.0);
      expect(screenRect.height, 80.0);
    });

    test('screenRectToPdf accurately inverts pdfRectToScreen', () {
      const original = Rect.fromLTWH(72.0, 144.0, 300.0, 24.0);
      const scale = 1.5;
      const pan = Offset(15.0, 25.0);

      final screen = CoordinateConverter.pdfRectToScreen(original, scale: scale, panOffset: pan);
      final inverted = CoordinateConverter.screenRectToPdf(screen, scale: scale, panOffset: pan);

      expect(inverted.left, closeTo(original.left, 0.0001));
      expect(inverted.top, closeTo(original.top, 0.0001));
      expect(inverted.width, closeTo(original.width, 0.0001));
      expect(inverted.height, closeTo(original.height, 0.0001));
    });
  });

  group('CoordinateConverter - Page Rotation', () {
    const pageSize = Size(595.0, 842.0); // Standard A4 portrait
    const sampleRect = Rect.fromLTWH(50.0, 100.0, 150.0, 30.0);

    test('0 degrees rotation leaves rect unchanged', () {
      final rotated = CoordinateConverter.applyRotation(
        sampleRect,
        rotationDegrees: 0,
        pageSize: pageSize,
      );
      expect(rotated, equals(sampleRect));
    });

    test('90 degrees rotation maps coordinates correctly', () {
      final rotated = CoordinateConverter.applyRotation(
        sampleRect,
        rotationDegrees: 90,
        pageSize: pageSize,
      );

      // (x, y) -> (pageHeight - y - h, x)
      expect(rotated.left, pageSize.height - sampleRect.bottom); // 842 - 130 = 712
      expect(rotated.top, sampleRect.left); // 50
      expect(rotated.width, sampleRect.height); // 30
      expect(rotated.height, sampleRect.width); // 150
    });

    test('180 degrees rotation maps coordinates correctly', () {
      final rotated = CoordinateConverter.applyRotation(
        sampleRect,
        rotationDegrees: 180,
        pageSize: pageSize,
      );

      expect(rotated.left, pageSize.width - sampleRect.right); // 595 - 200 = 395
      expect(rotated.top, pageSize.height - sampleRect.bottom); // 842 - 130 = 712
      expect(rotated.width, sampleRect.width);
      expect(rotated.height, sampleRect.height);
    });

    test('unapplyRotation reverses 90, 180, 270 rotations back to original', () {
      for (final deg in [90, 180, 270]) {
        final rotated = CoordinateConverter.applyRotation(
          sampleRect,
          rotationDegrees: deg,
          pageSize: pageSize,
        );
        final restored = CoordinateConverter.unapplyRotation(
          rotated,
          rotationDegrees: deg,
          pageSize: pageSize,
        );

        expect(restored.left, closeTo(sampleRect.left, 0.001));
        expect(restored.top, closeTo(sampleRect.top, 0.001));
        expect(restored.width, closeTo(sampleRect.width, 0.001));
        expect(restored.height, closeTo(sampleRect.height, 0.001));
      }
    });
  });

  group('CoordinateConverter - Hit Testing', () {
    final item1 = PdfTextItem(
      id: 'item1',
      text: 'Welcome',
      pageIndex: 0,
      x: 50.0,
      y: 100.0,
      width: 80.0,
      height: 20.0,
      fontSize: 16.0,
    );

    final item2 = PdfTextItem(
      id: 'item2',
      text: 'Rahul',
      pageIndex: 0,
      x: 140.0,
      y: 100.0,
      width: 60.0,
      height: 20.0,
      fontSize: 16.0,
    );

    test('hits item1 directly inside its bounding box', () {
      final hit = CoordinateConverter.hitTest(
        const Offset(60.0, 110.0),
        [item1, item2],
      );

      expect(hit, isNotNull);
      expect(hit!.id, 'item1');
      expect(hit.text, 'Welcome');
    });

    test('hits item2 directly inside its bounding box', () {
      final hit = CoordinateConverter.hitTest(
        const Offset(150.0, 110.0),
        [item1, item2],
      );

      expect(hit, isNotNull);
      expect(hit!.id, 'item2');
      expect(hit.text, 'Rahul');
    });

    test('hits within slop tolerance just outside bounding box', () {
      // item1 bounds: [50, 100, 130, 120]. Tap at (47, 98) is within 6pt slop
      final hit = CoordinateConverter.hitTest(
        const Offset(47.0, 98.0),
        [item1, item2],
        hitSlop: 6.0,
      );

      expect(hit, isNotNull);
      expect(hit!.id, 'item1');
    });

    test('returns null when tapping far away from all items', () {
      final hit = CoordinateConverter.hitTest(
        const Offset(500.0, 700.0),
        [item1, item2],
        hitSlop: 6.0,
      );

      expect(hit, isNull);
    });
  });
}
