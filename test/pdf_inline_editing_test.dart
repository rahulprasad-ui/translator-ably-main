import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translator/controllers/pdf_editor_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3: Inline PDF Text Editing State & Lifecycle Tests', () {
    late PdfEditorController controller;

    setUp(() {
      controller = PdfEditorController();
    });

    test('1 & 2: Select a word and open editor, verify original text is initialized', () {
      final elem = PdfDetectedTextElement(
        id: 'elem_word_adobe',
        text: 'Tech Mahindra',
        boundingBox: const Rect.fromLTWH(80, 160, 120, 24),
        sourceWidth: 600.0,
        sourceHeight: 800.0,
        pageIndex: 0,
        textColor: Colors.black,
        fontSize: 16.0,
        isBold: true,
      );

      controller.detectedPageTexts[0] = [elem];
      const pageSize = Size(300.0, 400.0);

      // Select and prepare text overlay
      final overlay = controller.selectOrStartEditingText(
        pageIndex: 0,
        detectedElement: elem,
        pageSize: pageSize,
      );

      expect(overlay, isNotNull);
      expect(overlay.id, 'elem_word_adobe');
      expect(overlay.originalText, 'Tech Mahindra');
      expect(overlay.savedText, 'Tech Mahindra');
      expect(overlay.text, 'Tech Mahindra');
      expect(controller.selectedOverlayId.value, 'elem_word_adobe');
      expect(controller.activeEditingOverlayId.value, isNull);

      // Trigger inline editing action
      controller.startInlineEditing(overlay.id);
      expect(controller.isOverlayEditing(overlay.id), isTrue);
      expect(controller.activeEditingOverlayId.value, 'elem_word_adobe');
    });

    test('3 & 4: Replace text and save, verify updated text appears in-memory and UI state', () {
      final elem = PdfDetectedTextElement(
        id: 'elem_word_title',
        text: 'Software Engineer',
        boundingBox: const Rect.fromLTWH(50, 100, 140, 20),
        sourceWidth: 500.0,
        sourceHeight: 1000.0,
        pageIndex: 0,
      );
      controller.detectedPageTexts[0] = [elem];
      const pageSize = Size(250.0, 500.0);

      final overlay = controller.selectOrStartEditingText(
        pageIndex: 0,
        detectedElement: elem,
        pageSize: pageSize,
      );

      controller.startInlineEditing(overlay.id);

      // Save updated text
      controller.saveInlineEditing(overlay.id, 'Senior Flutter Architect');

      expect(controller.activeEditingOverlayId.value, isNull);
      expect(overlay.text, 'Senior Flutter Architect');
      expect(overlay.savedText, 'Senior Flutter Architect');
      expect(overlay.originalText, 'Software Engineer'); // Original raw PDF text remains preserved
      expect(controller.selectedOverlayId.value, overlay.id); // Item remains selected
    });

    test('5: Cancel edit discards unsaved draft and restores previous saved text', () {
      final elem = PdfDetectedTextElement(
        id: 'elem_word_cancel',
        text: 'Initial Text',
        boundingBox: const Rect.fromLTWH(60, 120, 100, 20),
        sourceWidth: 500.0,
        sourceHeight: 500.0,
        pageIndex: 0,
      );
      controller.detectedPageTexts[0] = [elem];
      const pageSize = Size(250.0, 250.0);

      final overlay = controller.selectOrStartEditingText(
        pageIndex: 0,
        detectedElement: elem,
        pageSize: pageSize,
      );

      controller.startInlineEditing(overlay.id);

      // Simulating unsaved changes being cancelled
      controller.cancelInlineEditing(overlay.id);

      expect(controller.activeEditingOverlayId.value, isNull);
      expect(overlay.text, 'Initial Text');
      expect(overlay.savedText, 'Initial Text');
      expect(overlay.originalText, 'Initial Text');
    });

    test('6: Multi-line and multi-page text editing retains page-isolated state', () {
      // Element on Page 0
      final elemPage0 = PdfDetectedTextElement(
        id: 'page0_elem',
        text: 'Line 1\nLine 2',
        boundingBox: const Rect.fromLTWH(40, 60, 100, 40),
        sourceWidth: 500.0,
        sourceHeight: 800.0,
        pageIndex: 0,
      );

      // Element on Page 1
      final elemPage1 = PdfDetectedTextElement(
        id: 'page1_elem',
        text: 'Second Page Content',
        boundingBox: const Rect.fromLTWH(40, 80, 160, 25),
        sourceWidth: 500.0,
        sourceHeight: 800.0,
        pageIndex: 1,
      );

      controller.detectedPageTexts[0] = [elemPage0];
      controller.detectedPageTexts[1] = [elemPage1];
      const pageSize = Size(250.0, 400.0);

      // Edit Page 0
      final o0 = controller.selectOrStartEditingText(
        pageIndex: 0,
        detectedElement: elemPage0,
        pageSize: pageSize,
      );
      controller.startInlineEditing(o0.id);
      controller.saveInlineEditing(o0.id, 'Updated Line 1\nUpdated Line 2');

      // Edit Page 1
      final o1 = controller.selectOrStartEditingText(
        pageIndex: 1,
        detectedElement: elemPage1,
        pageSize: pageSize,
      );
      controller.startInlineEditing(o1.id);
      controller.saveInlineEditing(o1.id, 'Page 1 Edited Successfully');

      // Verify page isolation
      final page0Overlays = controller.overlaysForPage(0);
      final page1Overlays = controller.overlaysForPage(1);

      expect(page0Overlays.length, 1);
      expect(page0Overlays.first.text, 'Updated Line 1\nUpdated Line 2');
      expect(page0Overlays.first.originalText, 'Line 1\nLine 2');

      expect(page1Overlays.length, 1);
      expect(page1Overlays.first.text, 'Page 1 Edited Successfully');
      expect(page1Overlays.first.originalText, 'Second Page Content');
    });

    test('7 & 8: Coordinate alignment matches verified transformation across zoom scales', () {
      final elem = PdfDetectedTextElement(
        id: 'elem_coords',
        text: 'Aligned Text',
        boundingBox: const Rect.fromLTWH(100, 200, 150, 30),
        sourceWidth: 500.0,
        sourceHeight: 1000.0,
        pageIndex: 0,
        fontSize: 14.0,
      );

      // Zoom Scale 1.0 (500 x 1000)
      const size1 = Size(500.0, 1000.0);
      final rect1 = elem.getScaledRect(size1);
      expect(rect1.left, 100.0);
      expect(rect1.top, 200.0);
      expect(rect1.width, 150.0);
      expect(rect1.height, 30.0);

      // Zoom Scale 2.0 (1000 x 2000)
      const size2 = Size(1000.0, 2000.0);
      final rect2 = elem.getScaledRect(size2);
      expect(rect2.left, 200.0);
      expect(rect2.top, 400.0);
      expect(rect2.width, 300.0);
      expect(rect2.height, 60.0);

      final overlay = controller.selectOrStartEditingText(
        pageIndex: 0,
        detectedElement: elem,
        pageSize: size2,
      );

      expect(overlay.position.dx, closeTo(rect2.left - 1.0, 0.01));
      expect(overlay.position.dy, closeTo(rect2.top - 1.0, 0.01));
      expect(overlay.size.width, greaterThanOrEqualTo(rect2.width));
    });

    test('9: Switching selections does not lose previously saved in-memory edits', () {
      final elemA = PdfDetectedTextElement(
        id: 'elem_A',
        text: 'Item A',
        boundingBox: const Rect.fromLTWH(20, 20, 60, 20),
        sourceWidth: 400.0,
        sourceHeight: 400.0,
        pageIndex: 0,
      );

      final elemB = PdfDetectedTextElement(
        id: 'elem_B',
        text: 'Item B',
        boundingBox: const Rect.fromLTWH(20, 80, 60, 20),
        sourceWidth: 400.0,
        sourceHeight: 400.0,
        pageIndex: 0,
      );

      controller.detectedPageTexts[0] = [elemA, elemB];
      const pageSize = Size(400.0, 400.0);

      // Step 1: Edit Item A and save
      final oA = controller.selectOrStartEditingText(
        pageIndex: 0,
        detectedElement: elemA,
        pageSize: pageSize,
      );
      controller.startInlineEditing(oA.id);
      controller.saveInlineEditing(oA.id, 'Saved Change for Item A');

      expect(oA.savedText, 'Saved Change for Item A');
      expect(oA.text, 'Saved Change for Item A');

      // Step 2: Switch to Item B, start editing, but cancel
      final oB = controller.selectOrStartEditingText(
        pageIndex: 0,
        detectedElement: elemB,
        pageSize: pageSize,
      );
      controller.startInlineEditing(oB.id);
      // Simulate draft change then cancel
      controller.cancelInlineEditing(oB.id);

      expect(oB.text, 'Item B');

      // Step 3: Switch back to Item A
      controller.selectOverlay(oA.id);

      // Confirm Item A's saved edit is completely retained
      expect(oA.savedText, 'Saved Change for Item A');
      expect(oA.text, 'Saved Change for Item A');
      expect(oA.originalText, 'Item A');
    });

    test('Empty text handling: saving empty string acts as text clear/redaction', () {
      final elem = PdfDetectedTextElement(
        id: 'elem_redact',
        text: 'Redacted Secret',
        boundingBox: const Rect.fromLTWH(50, 50, 100, 20),
        sourceWidth: 400.0,
        sourceHeight: 400.0,
        pageIndex: 0,
      );
      controller.detectedPageTexts[0] = [elem];
      const pageSize = Size(400.0, 400.0);

      final overlay = controller.selectOrStartEditingText(
        pageIndex: 0,
        detectedElement: elem,
        pageSize: pageSize,
      );

      controller.startInlineEditing(overlay.id);
      controller.saveInlineEditing(overlay.id, '');

      expect(overlay.text, '');
      expect(overlay.savedText, '');
      expect(overlay.originalText, 'Redacted Secret');
      expect(overlay.backgroundColor, Colors.white); // Seamlessly covers original PDF content
    });
  });
}
