// lib/features/pdf_editor_v2/data/models/pdf_font_metadata.dart
import 'package:flutter/material.dart';

/// Supported standard font families for PDF editing & export
enum PdfStandardFontFamily {
  helvetica('Helvetica', 'sans-serif'),
  timesRoman('Times-Roman', 'serif'),
  courier('Courier', 'monospace'),
  roboto('Roboto', 'sans-serif'),
  arial('Arial', 'sans-serif');

  final String pdfName;
  final String genericFamily;

  const PdfStandardFontFamily(this.pdfName, this.genericFamily);

  static PdfStandardFontFamily fromName(String? name) {
    if (name == null || name.isEmpty) return PdfStandardFontFamily.helvetica;
    final lower = name.toLowerCase();
    if (lower.contains('times')) return PdfStandardFontFamily.timesRoman;
    if (lower.contains('courier') || lower.contains('mono')) return PdfStandardFontFamily.courier;
    if (lower.contains('roboto')) return PdfStandardFontFamily.roboto;
    if (lower.contains('arial')) return PdfStandardFontFamily.arial;
    return PdfStandardFontFamily.helvetica;
  }
}

/// Represents extracted and editable typography metadata for a text item
class PdfFontMetadata {
  final String fontName;
  final double fontSize;
  final int textColor; // ARGB integer, e.g. 0xFF1E293B
  final int? backgroundColor; // Optional ARGB background color
  final bool isBold;
  final bool isItalic;
  final bool isFontEmbedded;
  final double characterSpacing;
  final double wordSpacing;
  final double lineHeight;
  final double rotation;
  final TextAlign textAlign;
  final String? originalFontFamily;

  const PdfFontMetadata({
    this.fontName = 'Helvetica',
    this.fontSize = 14.0,
    this.textColor = 0xFF000000,
    this.backgroundColor,
    this.isBold = false,
    this.isItalic = false,
    this.isFontEmbedded = false,
    this.characterSpacing = 0.0,
    this.wordSpacing = 0.0,
    this.lineHeight = 1.2,
    this.rotation = 0.0,
    this.textAlign = TextAlign.left,
    this.originalFontFamily,
  });

  Color get color => Color(textColor);

  PdfStandardFontFamily get standardFamily => PdfStandardFontFamily.fromName(fontName);

  /// Converts PDF typography into a matching Flutter TextStyle for UI preview
  TextStyle toFlutterTextStyle({double scale = 1.0}) {
    FontWeight weight = isBold ? FontWeight.bold : FontWeight.normal;
    FontStyle style = isItalic ? FontStyle.italic : FontStyle.normal;

    final String family = switch (standardFamily) {
      PdfStandardFontFamily.timesRoman => 'serif',
      PdfStandardFontFamily.courier => 'monospace',
      PdfStandardFontFamily.roboto ||
      PdfStandardFontFamily.arial ||
      PdfStandardFontFamily.helvetica => 'sans-serif',
    };

    return TextStyle(
      fontSize: fontSize * scale,
      color: Color(textColor),
      fontWeight: weight,
      fontStyle: style,
      fontFamily: family,
      letterSpacing: characterSpacing != 0.0 ? characterSpacing * scale : null,
      wordSpacing: wordSpacing != 0.0 ? wordSpacing * scale : null,
      height: lineHeight,
    );
  }

  PdfFontMetadata copyWith({
    String? fontName,
    double? fontSize,
    int? textColor,
    int? backgroundColor,
    bool? isBold,
    bool? isItalic,
    bool? isFontEmbedded,
    double? characterSpacing,
    double? wordSpacing,
    double? lineHeight,
    double? rotation,
    TextAlign? textAlign,
    String? originalFontFamily,
  }) {
    return PdfFontMetadata(
      fontName: fontName ?? this.fontName,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isFontEmbedded: isFontEmbedded ?? this.isFontEmbedded,
      characterSpacing: characterSpacing ?? this.characterSpacing,
      wordSpacing: wordSpacing ?? this.wordSpacing,
      lineHeight: lineHeight ?? this.lineHeight,
      rotation: rotation ?? this.rotation,
      textAlign: textAlign ?? this.textAlign,
      originalFontFamily: originalFontFamily ?? this.originalFontFamily,
    );
  }

  Map<String, dynamic> toJson() => {
    'fontName': fontName,
    'fontSize': fontSize,
    'textColor': textColor,
    'backgroundColor': backgroundColor,
    'isBold': isBold,
    'isItalic': isItalic,
    'isFontEmbedded': isFontEmbedded,
    'characterSpacing': characterSpacing,
    'wordSpacing': wordSpacing,
    'lineHeight': lineHeight,
    'rotation': rotation,
    'textAlign': textAlign.index,
    'originalFontFamily': originalFontFamily,
  };

  factory PdfFontMetadata.fromJson(Map<String, dynamic> json) => PdfFontMetadata(
    fontName: json['fontName'] as String? ?? 'Helvetica',
    fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14.0,
    textColor: (json['textColor'] as num?)?.toInt() ?? 0xFF000000,
    backgroundColor: (json['backgroundColor'] as num?)?.toInt(),
    isBold: json['isBold'] as bool? ?? false,
    isItalic: json['isItalic'] as bool? ?? false,
    isFontEmbedded: json['isFontEmbedded'] as bool? ?? false,
    characterSpacing: (json['characterSpacing'] as num?)?.toDouble() ?? 0.0,
    wordSpacing: (json['wordSpacing'] as num?)?.toDouble() ?? 0.0,
    lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.2,
    rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
    textAlign: TextAlign.values[(json['textAlign'] as int?) ?? 0],
    originalFontFamily: json['originalFontFamily'] as String?,
  );

  @override
  String toString() =>
      'PdfFontMetadata(font: $fontName, size: $fontSize, bold: $isBold, italic: $isItalic, color: 0x${textColor.toRadixString(16).padLeft(8, '0')})';
}
