// test/features/pdf_editor_v2/pdf_editor_state_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translator/features/pdf_editor_v2/data/models/pdf_document_model.dart';
import 'package:translator/features/pdf_editor_v2/data/models/pdf_page_model.dart';
import 'package:translator/features/pdf_editor_v2/data/models/pdf_text_item.dart';
import 'package:translator/features/pdf_editor_v2/data/services/pdf_export_service.dart';
import 'package:translator/features/pdf_editor_v2/data/services/pdf_modification_service.dart';
import 'package:translator/features/pdf_editor_v2/data/services/pdf_renderer.dart';
import 'package:translator/features/pdf_editor_v2/data/services/pdf_text_extractor.dart';
import 'package:translator/features/pdf_editor_v2/presentation/providers/pdf_editor_provider.dart';

void main() {
  group('PdfEditorNotifier - State & Selection & Text Replacement', () {
    late PdfEditorNotifier notifier;
    late PdfTextItem itemRahul;
    late PdfTextItem itemWelcome;
    late PdfTextItem itemFooter;

    setUp(() {
      final renderer = PdfRendererService();
      final extractor = PdfTextExtractorService();
      final modification = PdfModificationService();
      final export = PdfExportService(
        modificationService: modification,
        rendererService: renderer,
        textExtractorService: extractor,
      );

      notifier = PdfEditorNotifier(
        rendererService: renderer,
        textExtractorService: extractor,
        exportService: export,
      );

      itemWelcome = const PdfTextItem(
        id: 'item_welcome',
        text: 'Welcome',
        pageIndex: 0,
        x: 50.0,
        y: 100.0,
        width: 80.0,
        height: 20.0,
        fontSize: 16.0,
        fontName: 'Helvetica',
        textColor: 0xFF000000,
      );

      itemRahul = const PdfTextItem(
        id: 'item_rahul',
        text: 'Rahul',
        pageIndex: 0,
        x: 140.0,
        y: 100.0,
        width: 60.0,
        height: 20.0,
        fontSize: 16.0,
        fontName: 'Helvetica',
        textColor: 0xFF000000,
      );

      itemFooter = const PdfTextItem(
        id: 'item_footer',
        text: 'Confidential Document 2026',
        pageIndex: 0,
        x: 50.0,
        y: 800.0,
        width: 200.0,
        height: 14.0,
        fontSize: 10.0,
        fontName: 'Times-Roman',
        textColor: 0xFF64748B,
      );

      // Seed state with a mock document
      final page0 = PdfPageModel(
        pageIndex: 0,
        width: 595.0,
        height: 842.0,
        textItems: [itemWelcome, itemRahul, itemFooter],
        isTextExtracted: true,
      );

      notifier.state = notifier.state.copyWith(
        document: PdfDocumentModel(
          filePath: '/mock/test.pdf',
          fileName: 'test.pdf',
          pageCount: 1,
          pages: [page0],
          isLoaded: true,
        ),
        currentPageIndex: 0,
      );
    });

    test('tapping on "Rahul" selects it and initializes typography controls', () {
      // Tap at center of itemRahul (170, 110)
      notifier.onPageTapped(const Offset(170.0, 110.0));

      final state = notifier.state;
      expect(state.selectedTextItem, isNotNull);
      expect(state.selectedTextItem!.id, 'item_rahul');
      expect(state.selectedTextItem!.text, 'Rahul');
      expect(state.editingText, 'Rahul');
      expect(state.currentFont.fontName, 'Helvetica');
      expect(state.currentFont.fontSize, 16.0);
    });

    test('genuine text replacement: "Rahul" -> "Amit"', () {
      // 1. Select Rahul
      notifier.selectTextItem(itemRahul);
      expect(notifier.state.selectedTextItem!.text, 'Rahul');

      // 2. Start inline editing and type "Amit"
      notifier.startInlineEditing();
      expect(notifier.state.isEditingInline, isTrue);

      notifier.updateEditingText('Amit');
      expect(notifier.state.editingText, 'Amit');

      // 3. Commit edit
      notifier.commitTextEdit();

      final state = notifier.state;
      expect(state.isEditingInline, isFalse);
      expect(state.editRecords.length, 1);

      final record = state.editRecords.first;
      expect(record.originalItem.id, 'item_rahul');
      expect(record.originalItem.text, 'Rahul');
      expect(record.replacementText, 'Amit');
      expect(record.pageIndex, 0);

      // Unaffected content preserved: itemWelcome and itemFooter are intact
      final page = state.currentPage!;
      expect(page.textItems.firstWhere((i) => i.id == 'item_welcome').text, 'Welcome');
      expect(page.textItems.firstWhere((i) => i.id == 'item_footer').text, 'Confidential Document 2026');
    });

    test('font formatting toolbar modifies font, size, bold, italic, and color', () {
      notifier.selectTextItem(itemRahul);

      notifier.updateFontFamily('Times-Roman');
      expect(notifier.state.currentFont.fontName, 'Times-Roman');

      notifier.updateFontSize(22.0);
      expect(notifier.state.currentFont.fontSize, 22.0);

      notifier.toggleBold();
      expect(notifier.state.currentFont.isBold, isTrue);

      notifier.toggleItalic();
      expect(notifier.state.currentFont.isItalic, isTrue);

      notifier.updateTextColor(const Color(0xFFE11D48));
      expect(notifier.state.currentFont.color, const Color(0xFFE11D48));

      notifier.updateEditingText('Amit');
      notifier.commitTextEdit();

      final record = notifier.state.editRecords.first;
      expect(record.appliedFont.fontName, 'Times-Roman');
      expect(record.appliedFont.fontSize, 22.0);
      expect(record.appliedFont.isBold, isTrue);
      expect(record.appliedFont.isItalic, isTrue);
      expect(record.appliedFont.color, const Color(0xFFE11D48));
    });

    test('undo and redo revert and reapply edits accurately', () {
      // Perform first edit: Rahul -> Amit
      notifier.selectTextItem(itemRahul);
      notifier.updateEditingText('Amit');
      notifier.commitTextEdit();
      expect(notifier.state.editRecords.length, 1);
      expect(notifier.state.canUndo, isTrue);
      expect(notifier.state.canRedo, isFalse);

      // Perform second edit: Welcome -> Hello
      notifier.selectTextItem(itemWelcome);
      notifier.updateEditingText('Hello');
      notifier.commitTextEdit();
      expect(notifier.state.editRecords.length, 2);

      // Undo second edit
      notifier.undo();
      expect(notifier.state.editRecords.length, 1);
      expect(notifier.state.editRecords.first.replacementText, 'Amit');
      expect(notifier.state.canRedo, isTrue);

      // Undo first edit
      notifier.undo();
      expect(notifier.state.editRecords.isEmpty, isTrue);

      // Redo first edit
      notifier.redo();
      expect(notifier.state.editRecords.length, 1);
      expect(notifier.state.editRecords.first.replacementText, 'Amit');

      // Redo second edit
      notifier.redo();
      expect(notifier.state.editRecords.length, 2);
      expect(notifier.state.editRecords[1].replacementText, 'Hello');
    });
  });
}
