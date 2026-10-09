// test/features/pdf_editor_v2/pdf_text_item_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translator/features/pdf_editor_v2/data/models/pdf_font_metadata.dart';
import 'package:translator/features/pdf_editor_v2/data/models/pdf_text_item.dart';

void main() {
  group('PdfTextItem & PdfFontMetadata', () {
    test('instantiates with exact coordinates and bounding box', () {
      final item = PdfTextItem(
        id: 't1',
        text: 'Document Heading',
        pageIndex: 0,
        x: 72.0,
        y: 144.0,
        width: 250.0,
        height: 28.0,
        fontSize: 24.0,
        fontName: 'Helvetica-Bold',
        textColor: 0xFF1E293B,
        isBold: true,
        isItalic: false,
      );

      expect(item.boundingBox.left, 72.0);
      expect(item.boundingBox.top, 144.0);
      expect(item.boundingBox.width, 250.0);
      expect(item.boundingBox.height, 28.0);
      expect(item.fontSize, 24.0);
      expect(item.isBold, isTrue);
      expect(item.isItalic, isFalse);
      expect(item.textColor, 0xFF1E293B);
    });

    test('extracts font metadata correctly', () {
      final item = PdfTextItem(
        id: 't2',
        text: 'Italic Times note',
        pageIndex: 1,
        x: 40.0,
        y: 200.0,
        width: 120.0,
        height: 16.0,
        fontSize: 12.0,
        fontName: 'TimesNewRomanPS-ItalicMT',
        textColor: 0xFFE11D48,
        isBold: false,
        isItalic: true,
      );

      final meta = item.fontMetadata;
      expect(meta.fontSize, 12.0);
      expect(meta.isItalic, isTrue);
      expect(meta.isBold, isFalse);
      expect(meta.color, const Color(0xFFE11D48));
      expect(meta.standardFamily, PdfStandardFontFamily.timesRoman);

      final flutterStyle = meta.toFlutterTextStyle();
      expect(flutterStyle.fontSize, 12.0);
      expect(flutterStyle.fontStyle, FontStyle.italic);
      expect(flutterStyle.fontWeight, FontWeight.normal);
      expect(flutterStyle.color, const Color(0xFFE11D48));
      expect(flutterStyle.fontFamily, 'serif');
    });

    test('maps courier monospace font family accurately', () {
      const meta = PdfFontMetadata(
        fontName: 'CourierNewPS-BoldMT',
        fontSize: 14.0,
        isBold: true,
      );

      expect(meta.standardFamily, PdfStandardFontFamily.courier);
      final style = meta.toFlutterTextStyle();
      expect(style.fontFamily, 'monospace');
      expect(style.fontWeight, FontWeight.bold);
    });

    test('supports Unicode text including multi-byte scripts and accents', () {
      final unicodeItems = [
        'Welcome Rahul',
        'नमस्ते भारत', // Hindi / Devanagari
        '你好世界', // Simplified Chinese
        'Bonjour le monde, café naïve', // French with accents
        'Привет мир', // Russian Cyrillic
      ];

      for (var i = 0; i < unicodeItems.length; i++) {
        final text = unicodeItems[i];
        final item = PdfTextItem(
          id: 'u_$i',
          text: text,
          pageIndex: 0,
          x: 50.0,
          y: 50.0 + i * 30.0,
          width: 150.0,
          height: 20.0,
          fontSize: 14.0,
        );

        expect(item.text, text);
        expect(item.containsPoint(Offset(60.0, 55.0 + i * 30.0)), isTrue);

        final json = item.toJson();
        final reconstructed = PdfTextItem.fromJson(json);
        expect(reconstructed.text, text);
        expect(reconstructed.id, item.id);
      }
    });

    test('serialization and copyWith preserve all properties', () {
      final item = PdfTextItem(
        id: 'orig',
        text: 'Initial text',
        pageIndex: 2,
        x: 10.0,
        y: 20.0,
        width: 80.0,
        height: 15.0,
        fontSize: 12.0,
        fontName: 'Helvetica',
        textColor: 0xFF000000,
        isBold: true,
        isItalic: false,
        rotation: 90.0,
        isFontEmbedded: true,
      );

      final modified = item.copyWith(
        text: 'Updated text',
        fontSize: 16.0,
        textColor: 0xFF2563EB,
      );

      expect(modified.text, 'Updated text');
      expect(modified.fontSize, 16.0);
      expect(modified.textColor, 0xFF2563EB);
      expect(modified.x, 10.0);
      expect(modified.rotation, 90.0);
      expect(modified.isFontEmbedded, isTrue);
    });
  });
}
