import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translator/controllers/pdf_editor_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2: PDF Text Hit-Testing & Selection Verification', () {
    late PdfEditorController controller;

    setUp(() {
      controller = PdfEditorController();
    });

    test('Hit-testing taps at exact center and near edges of a text item', () {
      final elem = PdfDetectedTextElement(
        id: 'elem_word_1',
        text: 'Flutter',
        boundingBox: const Rect.fromLTWH(100, 200, 80, 24),
        sourceWidth: 500.0,
        sourceHeight: 1000.0,
        pageIndex: 0,
      );

      controller.detectedPageTexts[0] = [elem];
      // Screen target size: 250 x 500 (0.5x scale)
      // Scaled rect: left=50, top=100, right=90, bottom=112 (width=40, height=12)
      const pageSize = Size(250.0, 500.0);

      // 1. Center tap: (70, 106)
      final centerHit = controller.findDetectedTextAtPosition(
        pageIndex: 0,
        tapPos: const Offset(70.0, 106.0),
        pageSize: pageSize,
      );
      expect(centerHit, isNotNull);
      expect(centerHit!.id, 'elem_word_1');

      // 2. Exact edge tap (top-left inside edge: 50.5, 100.5)
      final edgeHit = controller.findDetectedTextAtPosition(
        pageIndex: 0,
        tapPos: const Offset(50.5, 100.5),
        pageSize: pageSize,
      );
      expect(edgeHit, isNotNull);
      expect(edgeHit!.id, 'elem_word_1');

      // 3. Near-edge tap within tolerance (2pt to the right: 92.0, 106.0)
      final nearEdgeHit = controller.findDetectedTextAtPosition(
        pageIndex: 0,
        tapPos: const Offset(92.0, 106.0),
        pageSize: pageSize,
        tolerance: 4.0,
      );
      expect(nearEdgeHit, isNotNull);
      expect(nearEdgeHit!.id, 'elem_word_1');
    });

    test('Hit-testing taps on empty space returns null', () {
      final elem = PdfDetectedTextElement(
        id: 'elem_word_1',
        text: 'Flutter',
        boundingBox: const Rect.fromLTWH(100, 200, 80, 24),
        sourceWidth: 500.0,
        sourceHeight: 1000.0,
        pageIndex: 0,
      );

      controller.detectedPageTexts[0] = [elem];
      const pageSize = Size(250.0, 500.0);

      // Tap far outside tolerance (e.g. 150, 250)
      final emptyHit = controller.findDetectedTextAtPosition(
        pageIndex: 0,
        tapPos: const Offset(150.0, 250.0),
        pageSize: pageSize,
      );
      expect(emptyHit, isNull);
    });

    test('Hit-testing between two adjacent items selects the closest item without merging', () {
      // Line with two words side-by-side
      final word1 = PdfDetectedTextElement(
        id: 'word_first',
        text: 'First',
        boundingBox: const Rect.fromLTWH(50, 100, 60, 20),
        sourceWidth: 500.0,
        sourceHeight: 500.0,
        pageIndex: 0,
      );

      final word2 = PdfDetectedTextElement(
        id: 'word_second',
        text: 'Second',
        boundingBox: const Rect.fromLTWH(130, 100, 70, 20),
        sourceWidth: 500.0,
        sourceHeight: 500.0,
        pageIndex: 0,
      );

      controller.detectedPageTexts[0] = [word1, word2];
      const pageSize = Size(500.0, 500.0); // 1:1 scale

      // Between words (word1 ends at 110, word2 starts at 130)
      // Tap at x=114 (4pt from word1, 16pt from word2) -> should select word1
      final hitNearWord1 = controller.findDetectedTextAtPosition(
        pageIndex: 0,
        tapPos: const Offset(114.0, 110.0),
        pageSize: pageSize,
        tolerance: 6.0,
      );
      expect(hitNearWord1, isNotNull);
      expect(hitNearWord1!.id, 'word_first');

      // Tap at x=126 (4pt from word2, 16pt from word1) -> should select word2
      final hitNearWord2 = controller.findDetectedTextAtPosition(
        pageIndex: 0,
        tapPos: const Offset(126.0, 110.0),
        pageSize: pageSize,
        tolerance: 6.0,
      );
      expect(hitNearWord2, isNotNull);
      expect(hitNearWord2!.id, 'word_second');
    });

    test('Multipage isolation: hit-testing on page 0 does not return text on page 1', () {
      final elemPage0 = PdfDetectedTextElement(
        id: 'elem_page0',
        text: 'Page Zero Text',
        boundingBox: const Rect.fromLTWH(50, 100, 100, 20),
        sourceWidth: 500.0,
        sourceHeight: 500.0,
        pageIndex: 0,
      );

      final elemPage1 = PdfDetectedTextElement(
        id: 'elem_page1',
        text: 'Page One Text',
        boundingBox: const Rect.fromLTWH(50, 100, 100, 20),
        sourceWidth: 500.0,
        sourceHeight: 500.0,
        pageIndex: 1,
      );

      controller.detectedPageTexts[0] = [elemPage0];
      controller.detectedPageTexts[1] = [elemPage1];
      const pageSize = Size(500.0, 500.0);

      // Hit-test on page 1 with tap coordinates matching page 0's location
      final matchPage1 = controller.findDetectedTextAtPosition(
        pageIndex: 1,
        tapPos: const Offset(70.0, 110.0),
        pageSize: pageSize,
      );

      expect(matchPage1, isNotNull);
      expect(matchPage1!.pageIndex, 1);
      expect(matchPage1.id, 'elem_page1');
    });

    test('selectTextElement updates selection and deselects properly', () {
      final elem = PdfDetectedTextElement(
        id: 'elem_select',
        text: 'Selected Text',
        boundingBox: const Rect.fromLTWH(20, 20, 100, 20),
        sourceWidth: 400.0,
        sourceHeight: 600.0,
        pageIndex: 0,
      );

      expect(controller.selectedTextElement.value, isNull);

      // Select element
      controller.selectTextElement(elem);
      expect(controller.selectedTextElement.value, isNotNull);
      expect(controller.selectedTextElement.value!.id, 'elem_select');

      // Deselect element
      controller.selectTextElement(null);
      expect(controller.selectedTextElement.value, isNull);
    });
  });
}
