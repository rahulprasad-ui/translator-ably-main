// test/features/pdf_editor_v2/edit_text_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translator/features/pdf_editor_v2/data/models/pdf_font_metadata.dart';
import 'package:translator/features/pdf_editor_v2/data/models/pdf_text_item.dart';
import 'package:translator/features/pdf_editor_v2/presentation/widgets/edit_text_dialog.dart';

void main() {
  testWidgets('EditTextDialog renders prefilled text and triggers onApply callback', (tester) async {
    String? appliedText;
    PdfFontMetadata? appliedFont;

    const originalItem = PdfTextItem(
      id: 'item_1',
      text: 'Original PDF Text',
      pageIndex: 0,
      x: 20.0,
      y: 30.0,
      width: 100.0,
      height: 20.0,
      fontSize: 16.0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditTextDialog(
            initialText: 'Original PDF Text',
            font: const PdfFontMetadata(fontName: 'Helvetica', fontSize: 16.0),
            originalItem: originalItem,
            onApply: (newText, newFont) {
              appliedText = newText;
              appliedFont = newFont;
            },
          ),
        ),
      ),
    );

    // Verify dialog elements exist
    expect(find.text('Edit PDF Text'), findsOneWidget);
    expect(find.textContaining('Original: "Original PDF Text"'), findsOneWidget);
    expect(find.text('Apply Changes'), findsOneWidget);

    // Enter replacement text
    await tester.enterText(find.byType(TextField), 'Modified Name');
    await tester.pump();

    // Tap Apply Changes
    await tester.tap(find.text('Apply Changes'));
    await tester.pumpAndSettle();

    expect(appliedText, 'Modified Name');
    expect(appliedFont, isNotNull);
  });
}
