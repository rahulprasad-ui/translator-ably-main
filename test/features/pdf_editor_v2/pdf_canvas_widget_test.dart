// test/features/pdf_editor_v2/pdf_canvas_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translator/features/pdf_editor_v2/data/models/pdf_text_item.dart';
import 'package:translator/features/pdf_editor_v2/presentation/providers/pdf_editor_provider.dart';
import 'package:translator/features/pdf_editor_v2/presentation/widgets/pdf_canvas.dart';
import 'package:translator/features/pdf_editor_v2/presentation/widgets/text_formatting_toolbar.dart';

void main() {
  testWidgets('PdfCanvasPainter renders without error with selected item and edits', (tester) async {
    final item = const PdfTextItem(
      id: 'sel_1',
      text: 'Selected PDF Text',
      pageIndex: 0,
      x: 30.0,
      y: 40.0,
      width: 140.0,
      height: 22.0,
      fontSize: 16.0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomPaint(
            size: const Size(400, 600),
            painter: PdfCanvasPainter(
              textItems: [item],
              selectedItem: item,
              showAllTextBounds: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('TextFormattingToolbar displays font, size, bold, italic, and color controls when item is selected', (tester) async {
    final selectedItem = const PdfTextItem(
      id: 'sel_item',
      text: 'Sample Header',
      pageIndex: 0,
      x: 50.0,
      y: 80.0,
      width: 120.0,
      height: 20.0,
      fontSize: 16.0,
      fontName: 'Helvetica',
      isBold: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pdfEditorProvider.overrideWith((ref) {
            final notifier = PdfEditorNotifier(
              rendererService: ref.read(pdfRendererServiceProvider),
              textExtractorService: ref.read(pdfTextExtractorServiceProvider),
              exportService: ref.read(pdfExportServiceProvider),
            );
            notifier.state = notifier.state.copyWith(
              selectedTextItem: selectedItem,
            );
            return notifier;
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TextFormattingToolbar(),
            ),
          ),
        ),
      ),
    );

    // Verify presence of formatting controls
    expect(find.text('Helvetica'), findsOneWidget); // Font dropdown
    expect(find.text('14 pt'), findsOneWidget); // Font size label
    expect(find.text('B'), findsOneWidget); // Bold button
    expect(find.text('I'), findsOneWidget); // Italic button
    expect(find.text('Edit Text'), findsOneWidget); // Edit Text action button
    expect(find.byIcon(Icons.add), findsOneWidget); // Increase font size
    expect(find.byIcon(Icons.remove), findsOneWidget); // Decrease font size
  });
}
