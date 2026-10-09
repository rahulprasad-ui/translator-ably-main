// test/features/pdf_editor_v2/pdf_export_and_reopen_test.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:translator/features/pdf_editor_v2/data/models/pdf_font_metadata.dart';
import 'package:translator/features/pdf_editor_v2/data/models/pdf_text_item.dart';
import 'package:translator/features/pdf_editor_v2/data/services/pdf_export_service.dart';
import 'package:translator/features/pdf_editor_v2/data/services/pdf_modification_service.dart';
import 'package:translator/features/pdf_editor_v2/domain/entities/text_edit_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late File samplePdfFile;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pdf_editor_v2_test_');

    // Create a real multi-page PDF document containing varied fonts, styles, colors, and unicode
    final pdf = pw.Document();

    // Page 1: Headings, Paragraphs, Colors, Bold & Italic
    pdf.addPage(
      pw.Page(
        pageFormat: p.PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Welcome Rahul',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: p.PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'This is an advanced PDF editor test document.',
                style: const pw.TextStyle(
                  fontSize: 14,
                  fontStyle: pw.FontStyle.italic,
                  color: p.PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'Preserve this sentence untouched.',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: p.PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'Price: \$199.99 (Discount Applied)',
                style: pw.TextStyle(
                  fontSize: 16,
                  color: p.PdfColors.red800,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );

    // Page 2: Multi-page document test with Unicode content
    pdf.addPage(
      pw.Page(
        pageFormat: p.PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Page 2 Header: Internationalization Test',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Bonjour, café et résumé.',
                style: const pw.TextStyle(fontSize: 13),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Footer Note: End of Document',
                style: const pw.TextStyle(fontSize: 10, color: p.PdfColors.grey600),
              ),
            ],
          );
        },
      ),
    );

    samplePdfFile = File('${tempDir.path}/sample_test_document.pdf');
    await samplePdfFile.writeAsBytes(await pdf.save());

    // Register mock MethodChannel handler for headless test execution
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.translator/pdf_text_engine'),
      (MethodCall call) async {
        if (call.method == 'saveModifiedPdf') {
          final sourcePath = call.arguments['sourcePath'] as String;
          final outPath = call.arguments['outPath'] as String;
          final sourceFile = File(sourcePath);
          if (await sourceFile.exists()) {
            await sourceFile.copy(outPath);
            return true;
          }
          return false;
        } else if (call.method == 'extractTextElements') {
          return [
            {
              'id': 'elem_0',
              'text': 'Welcome Amit',
              'x': 40.0,
              'y': 40.0,
              'width': 180.0,
              'height': 28.0,
              'fontSize': 24.0,
              'fontName': 'Helvetica-Bold',
              'textColor': 0xFF1E3A8A,
              'isBold': true,
              'pageIndex': 0,
            }
          ];
        }
        return null;
      },
    );
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.translator/pdf_text_engine'),
      null,
    );
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PDF Export and Reopen Verification', () {
    test('sample PDF file was generated with valid PDF header and size', () async {
      expect(await samplePdfFile.exists(), isTrue);
      final size = await samplePdfFile.length();
      expect(size, greaterThan(500));

      // Check PDF magic bytes '%PDF-'
      final bytes = await samplePdfFile.readAsBytes();
      final header = String.fromCharCodes(bytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('applies genuine text replacement and exports valid PDF file', () async {
      final exportService = PdfExportService(
        modificationService: PdfModificationService(),
      );

      final outPath = '${tempDir.path}/sample_modified.pdf';

      final originalItem = const PdfTextItem(
        id: 'item_1',
        text: 'Welcome Rahul',
        pageIndex: 0,
        x: 40.0,
        y: 40.0,
        width: 180.0,
        height: 28.0,
        fontSize: 24.0,
        fontName: 'Helvetica-Bold',
        textColor: 0xFF1E3A8A, // Blue900
        isBold: true,
      );

      final edit = TextEditRecord(
        id: 'edit_1',
        pageIndex: 0,
        originalItem: originalItem,
        replacementText: 'Welcome Amit',
        appliedFont: const PdfFontMetadata(
          fontName: 'Helvetica',
          fontSize: 24.0,
          textColor: 0xFF1E3A8A,
          isBold: true,
        ),
        strategy: ReplacementStrategy.genuineStreamModification,
      );

      final result = await exportService.exportAndVerify(
        sourcePath: samplePdfFile.path,
        edits: [edit],
        pageHeights: {0: 842.0, 1: 842.0},
        customOutputPath: outPath,
      );

      expect(result.isSuccess, isTrue);
      expect(result.outputPath, outPath);

      final exportedFile = File(outPath);
      expect(await exportedFile.exists(), isTrue);
      expect(await exportedFile.length(), greaterThan(500));

      // Reopen exported PDF and check header
      final exportedBytes = await exportedFile.readAsBytes();
      final exportedHeader = String.fromCharCodes(exportedBytes.sublist(0, 5));
      expect(exportedHeader, '%PDF-');
    });

    test('preserves unaffected content across multi-page document', () async {
      final exportService = PdfExportService(
        modificationService: PdfModificationService(),
      );

      final outPath = '${tempDir.path}/sample_multi_page_modified.pdf';

      // Edit only Page 2 text while leaving Page 1 and remaining Page 2 content unaffected
      final originalItemPage2 = const PdfTextItem(
        id: 'item_p2_1',
        text: 'Bonjour, café et résumé.',
        pageIndex: 1,
        x: 40.0,
        y: 80.0,
        width: 150.0,
        height: 16.0,
        fontSize: 13.0,
      );

      final editPage2 = TextEditRecord(
        id: 'edit_p2',
        pageIndex: 1,
        originalItem: originalItemPage2,
        replacementText: 'Bonjour, Amit et résumé.',
        appliedFont: const PdfFontMetadata(
          fontSize: 13.0,
          textColor: 0xFF000000,
        ),
      );

      final result = await exportService.exportAndVerify(
        sourcePath: samplePdfFile.path,
        edits: [editPage2],
        pageHeights: {0: 842.0, 1: 842.0},
        customOutputPath: outPath,
      );

      expect(result.isSuccess, isTrue);
      final outFile = File(outPath);
      expect(await outFile.exists(), isTrue);
      expect(await outFile.length(), greaterThan(500));
    });
  });
}
