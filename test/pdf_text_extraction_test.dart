import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:translator/controllers/pdf_editor_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF Text Extraction Models & Verification Tests', () {
    test('PdfDetectedTextElement calculates scaling and bounding boxes accurately', () {
      final elem = PdfDetectedTextElement(
        id: 'test_1',
        text: 'Hello Adobe PDF',
        boundingBox: const Rect.fromLTWH(50, 100, 200, 30),
        sourceWidth: 595.0,
        sourceHeight: 842.0,
        fontSize: 18.0,
        fontName: 'Helvetica',
        textColor: const Color(0xFFFF0000),
        isBold: true,
        isItalic: false,
        isNativePdfText: true,
        pageIndex: 0,
      );

      expect(elem.id, 'test_1');
      expect(elem.text, 'Hello Adobe PDF');
      expect(elem.fontSize, 18.0);
      expect(elem.fontName, 'Helvetica');
      expect(elem.textColor, const Color(0xFFFF0000));
      expect(elem.isBold, isTrue);
      expect(elem.isItalic, isFalse);
      expect(elem.isNativePdfText, isTrue);

      // Verify scaling onto screen target size
      final targetScreenSize = const Size(1190.0, 1684.0); // 2x scale
      final scaledRect = elem.getScaledRect(targetScreenSize);

      expect(scaledRect.left, 100.0);
      expect(scaledRect.top, 200.0);
      expect(scaledRect.width, 400.0);
      expect(scaledRect.height, 60.0);
    });

    test('Generates synthetic multi-page PDF with known text and coordinates', () async {
      final pdf = pw.Document();

      // Page 1: Standard portrait page with known text
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Title: Invoice Document', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Text('Customer: Rahul Kumar', style: const pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 10),
                pw.Text('Total Amount: \$500.00', style: const pw.TextStyle(fontSize: 16)),
              ],
            );
          },
        ),
      );

      // Page 2: Rotated/Landscape page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text('Page 2: Landscape Text', style: const pw.TextStyle(fontSize: 20)),
            );
          },
        ),
      );

      final tempDir = Directory.systemTemp.createTempSync('pdf_test_');
      final testPdfFile = File('${tempDir.path}/test_sample.pdf');
      await testPdfFile.writeAsBytes(await pdf.save());

      expect(testPdfFile.existsSync(), isTrue);
      expect(testPdfFile.lengthSync(), greaterThan(0));

      // Clean up temp
      testPdfFile.deleteSync();
      tempDir.deleteSync();
    });

    test('findDetectedTextAtPosition correctly identifies tapped text using scaled coordinates', () {
      final controller = PdfEditorController();

      final elem1 = PdfDetectedTextElement(
        id: 'elem_title',
        text: 'Document Title',
        boundingBox: const Rect.fromLTWH(40, 50, 200, 30),
        sourceWidth: 500.0,
        sourceHeight: 800.0,
        pageIndex: 0,
      );

      final elem2 = PdfDetectedTextElement(
        id: 'elem_footer',
        text: 'Page 1 Footer',
        boundingBox: const Rect.fromLTWH(40, 750, 150, 20),
        sourceWidth: 500.0,
        sourceHeight: 800.0,
        pageIndex: 0,
      );

      controller.detectedPageTexts[0] = [elem1, elem2];

      const renderScreenSize = Size(250.0, 400.0); // 0.5x scale

      // Tap at Title position on screen: (20 + 50, 25 + 7) -> around (70, 32)
      final matchTitle = controller.findDetectedTextAtPosition(
        pageIndex: 0,
        tapPos: const Offset(70, 32),
        pageSize: renderScreenSize,
      );

      expect(matchTitle, isNotNull);
      expect(matchTitle!.id, 'elem_title');
      expect(matchTitle.text, 'Document Title');

      // Tap at Footer position on screen: (20 + 30, 375 + 5) -> around (50, 380)
      final matchFooter = controller.findDetectedTextAtPosition(
        pageIndex: 0,
        tapPos: const Offset(50, 380),
        pageSize: renderScreenSize,
      );

      expect(matchFooter, isNotNull);
      expect(matchFooter!.id, 'elem_footer');
      expect(matchFooter.text, 'Page 1 Footer');

      // Tap at empty space
      final matchEmpty = controller.findDetectedTextAtPosition(
        pageIndex: 0,
        tapPos: const Offset(200, 200),
        pageSize: renderScreenSize,
      );

      expect(matchEmpty, isNull);
    });
  });
}
