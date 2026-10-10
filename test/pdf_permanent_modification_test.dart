import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:translator/controllers/pdf_editor_controller.dart';
import 'package:translator/services/pdf_native_text_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4: Permanent PDF Text Modification Tests', () {
    late PdfEditorController controller;
    final List<MethodCall> channelCalls = [];

    late Directory tempDir;

    setUp(() {
      Get.reset();
      channelCalls.clear();
      tempDir = Directory.systemTemp.createTempSync('pdf_perm_test_');

      final dummyPdf = File('${tempDir.path}/test_document.pdf');
      dummyPdf.writeAsBytesSync(utf8.encode('%PDF-1.4\n%mock pdf with 100+ bytes padding 012345678901234567890123456789012345678901234567890123456789012345678901234567890\n%%EOF\n'));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async {
          if (call.method == 'getTemporaryDirectory') {
            return tempDir.path;
          }
          return null;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.translator/pdf_text_engine'),
        (MethodCall call) async {
          channelCalls.add(call);
          if (call.method == 'saveModifiedPdf') {
            final args = call.arguments as Map?;
            final out = args?['outPath'] as String?;
            if (out != null) {
              final f = File(out);
              f.parent.createSync(recursive: true);
              f.writeAsBytesSync(utf8.encode('%PDF-1.4\n%mock modified vector pdf with 100+ bytes padding 012345678901234567890123456789012345678901234567890\n%%EOF\n'));
            }
            return true;
          }
          if (call.method == 'extractTextElements') {
            return [];
          }
          return null;
        },
      );

      controller = PdfEditorController();
      controller.pdfPath = dummyPdf.path;
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.translator/pdf_text_engine'),
        null,
      );
    });

    test('1: Verify modification payload contains exact PDF coordinates and original text', () async {
      final detected = PdfDetectedTextElement(
        id: 'elem_test_1',
        text: 'Tech Mahindra',
        boundingBox: const Rect.fromLTWH(72.0, 100.0, 120.0, 18.0),
        sourceWidth: 595.0,
        sourceHeight: 842.0,
        fontSize: 14.0,
        fontName: 'Helvetica',
        baseline: 114.0,
        isNativePdfText: true,
        pageIndex: 0,
      );

      final overlay = controller.selectOrStartEditingText(
        pageIndex: 0,
        detectedElement: detected,
        pageSize: const Size(595.0, 842.0),
      );

      // User performs inline edit in Phase 3
      controller.saveInlineEditing(overlay.id, 'Tata Consultancy Services');

      expect(overlay.savedText, 'Tata Consultancy Services');
      expect(overlay.originalText, 'Tech Mahindra');

      // Export in Phase 4
      final exportPath = await controller.exportWithOverlays();
      expect(exportPath, isNotNull);

      // Verify MethodChannel call was dispatched to native vector engine
      final saveCall = channelCalls.firstWhere(
        (c) => c.method == 'saveModifiedPdf',
        orElse: () => throw Exception('saveModifiedPdf was not invoked'),
      );

      final args = saveCall.arguments as Map;
      expect(args['sourcePath'], controller.pdfPath);
      expect(args['outPath'], contains('.pdf'));

      final mods = (args['modifications'] as List).cast<Map>();
      expect(mods.length, 1);

      final mod = mods.first;
      expect(mod['pageIndex'], 0);
      expect(mod['originalText'], 'Tech Mahindra');
      expect(mod['text'], 'Tata Consultancy Services');
      expect(mod['originalX'], 72.0);
      expect(mod['originalY'], 100.0);
      expect(mod['originalWidth'], 120.0);
      expect(mod['originalHeight'], 18.0);
      expect(mod['baseline'], 114.0);
      expect(mod['fontName'], 'Helvetica');
      expect(mod['fontSize'], 14.0);
    });

    test('2: Multipage modifications map correctly to respective pages', () async {
      final page0Elem = PdfDetectedTextElement(
        id: 'elem_page_0',
        text: 'Invoice Title',
        boundingBox: const Rect.fromLTWH(50.0, 80.0, 100.0, 16.0),
        sourceWidth: 595.0,
        sourceHeight: 842.0,
        fontSize: 12.0,
        baseline: 92.0,
        isNativePdfText: true,
        pageIndex: 0,
      );

      final page1Elem = PdfDetectedTextElement(
        id: 'elem_page_1',
        text: 'Page 2 Footer',
        boundingBox: const Rect.fromLTWH(50.0, 800.0, 80.0, 14.0),
        sourceWidth: 595.0,
        sourceHeight: 842.0,
        fontSize: 10.0,
        baseline: 810.0,
        isNativePdfText: true,
        pageIndex: 1,
      );

      final ov0 = controller.selectOrStartEditingText(
        pageIndex: 0,
        detectedElement: page0Elem,
        pageSize: const Size(595.0, 842.0),
      );
      controller.saveInlineEditing(ov0.id, 'Receipt Title');

      final ov1 = controller.selectOrStartEditingText(
        pageIndex: 1,
        detectedElement: page1Elem,
        pageSize: const Size(595.0, 842.0),
      );
      controller.saveInlineEditing(ov1.id, 'Page 2 Final Footer');

      final exportPath = await controller.exportWithOverlays();
      expect(exportPath, isNotNull);

      final saveCall = channelCalls.firstWhere((c) => c.method == 'saveModifiedPdf');
      final mods = (saveCall.arguments['modifications'] as List).cast<Map>();
      expect(mods.length, 2);

      final mod0 = mods.firstWhere((m) => m['pageIndex'] == 0);
      expect(mod0['originalText'], 'Invoice Title');
      expect(mod0['text'], 'Receipt Title');

      final mod1 = mods.firstWhere((m) => m['pageIndex'] == 1);
      expect(mod1['originalText'], 'Page 2 Footer');
      expect(mod1['text'], 'Page 2 Final Footer');
    });

    test('3: Unedited selection overlays do not generate false text modification streams', () async {
      final detected = PdfDetectedTextElement(
        id: 'elem_unchanged',
        text: 'Unchanged Original Text',
        boundingBox: const Rect.fromLTWH(100.0, 200.0, 150.0, 20.0),
        sourceWidth: 595.0,
        sourceHeight: 842.0,
        isNativePdfText: true,
        pageIndex: 0,
      );

      // Selected but not edited
      controller.selectOrStartEditingText(
        pageIndex: 0,
        detectedElement: detected,
        pageSize: const Size(595.0, 842.0),
      );

      final exportPath = await controller.exportWithOverlays();
      expect(exportPath, isNotNull);

      final saveCall = channelCalls.firstWhere((c) => c.method == 'saveModifiedPdf');
      final mods = (saveCall.arguments['modifications'] as List).cast<Map>();

      expect(mods.length, 1);
      expect(mods.first['originalText'], 'Unchanged Original Text');
      expect(mods.first['text'], 'Unchanged Original Text');
    });

    test('4: Safe export guarantees original source file is untouched', () async {
      const originalPath = '/safe/original_document.pdf';
      controller.pdfPath = originalPath;

      final detected = PdfDetectedTextElement(
        id: 'elem_test_safe',
        text: 'Original Text',
        boundingBox: const Rect.fromLTWH(72.0, 100.0, 120.0, 18.0),
        sourceWidth: 595.0,
        sourceHeight: 842.0,
        fontSize: 14.0,
        isNativePdfText: true,
        pageIndex: 0,
      );

      final ov = controller.selectOrStartEditingText(
        pageIndex: 0,
        detectedElement: detected,
        pageSize: const Size(595.0, 842.0),
      );
      controller.saveInlineEditing(ov.id, 'New Replaced Text');

      final outPath = await controller.exportWithOverlays();

      expect(outPath, isNotNull);
      // Ensure outPath is different from original source path
      expect(outPath, isNot(equals(originalPath)));

      final saveCall = channelCalls.firstWhere((c) => c.method == 'saveModifiedPdf');
      expect(saveCall.arguments['sourcePath'], originalPath);
      expect(saveCall.arguments['outPath'], isNot(equals(originalPath)));
    });
  });
}
