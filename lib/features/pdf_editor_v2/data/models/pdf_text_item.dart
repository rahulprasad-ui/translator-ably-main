// lib/features/pdf_editor_v2/data/models/pdf_text_item.dart
import 'package:flutter/material.dart';
import 'pdf_font_metadata.dart';

/// Represents a single extracted or editable text element on a PDF page
class PdfTextItem {
  final String id;
  final String text;
  final int pageIndex;
  final double x; // PDF page points from top-left
  final double y; // PDF page points from top-left
  final double width;
  final double height;
  final double fontSize;
  final String? fontName;
  final int? textColor;
  final bool? isBold;
  final bool? isItalic;
  final double? rotation;
  final bool? isFontEmbedded;
  final double? characterSpacing;
  final double? wordSpacing;
  final double? baseline;

  const PdfTextItem({
    required this.id,
    required this.text,
    required this.pageIndex,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.fontSize,
    this.fontName,
    this.textColor,
    this.isBold,
    this.isItalic,
    this.rotation,
    this.isFontEmbedded,
    this.characterSpacing,
    this.wordSpacing,
    this.baseline,
  });

  /// Bounding box in PDF page coordinates (top-left origin)
  Rect get boundingBox => Rect.fromLTWH(x, y, width, height);

  /// Convenient getter for font metadata
  PdfFontMetadata get fontMetadata => PdfFontMetadata(
    fontName: fontName ?? 'Helvetica',
    fontSize: fontSize,
    textColor: textColor ?? 0xFF000000,
    isBold: isBold ?? false,
    isItalic: isItalic ?? false,
    isFontEmbedded: isFontEmbedded ?? false,
    characterSpacing: characterSpacing ?? 0.0,
    wordSpacing: wordSpacing ?? 0.0,
    rotation: rotation ?? 0.0,
    lineHeight: height > 0 && fontSize > 0 ? (height / fontSize).clamp(0.8, 2.0) : 1.2,
  );

  /// Check whether a point (in PDF page coordinates) hits this text item
  bool containsPoint(Offset point, {double slop = 4.0}) {
    final inflated = boundingBox.inflate(slop);
    return inflated.contains(point);
  }

  /// Calculates squared distance from a point to the center of this item
  double distanceSquaredTo(Offset point) {
    final center = boundingBox.center;
    final dx = center.dx - point.dx;
    final dy = center.dy - point.dy;
    return dx * dx + dy * dy;
  }

  PdfTextItem copyWith({
    String? id,
    String? text,
    int? pageIndex,
    double? x,
    double? y,
    double? width,
    double? height,
    double? fontSize,
    String? fontName,
    int? textColor,
    bool? isBold,
    bool? isItalic,
    double? rotation,
    bool? isFontEmbedded,
    double? characterSpacing,
    double? wordSpacing,
    double? baseline,
  }) {
    return PdfTextItem(
      id: id ?? this.id,
      text: text ?? this.text,
      pageIndex: pageIndex ?? this.pageIndex,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      fontSize: fontSize ?? this.fontSize,
      fontName: fontName ?? this.fontName,
      textColor: textColor ?? this.textColor,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      rotation: rotation ?? this.rotation,
      isFontEmbedded: isFontEmbedded ?? this.isFontEmbedded,
      characterSpacing: characterSpacing ?? this.characterSpacing,
      wordSpacing: wordSpacing ?? this.wordSpacing,
      baseline: baseline ?? this.baseline,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'pageIndex': pageIndex,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'fontSize': fontSize,
    'fontName': fontName,
    'textColor': textColor,
    'isBold': isBold,
    'isItalic': isItalic,
    'rotation': rotation,
    'isFontEmbedded': isFontEmbedded,
    'characterSpacing': characterSpacing,
    'wordSpacing': wordSpacing,
    'baseline': baseline,
  };

  factory PdfTextItem.fromJson(Map<String, dynamic> json) => PdfTextItem(
    id: json['id'] as String? ?? 'item_${json['text'].hashCode}',
    text: json['text'] as String? ?? '',
    pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
    x: (json['x'] as num?)?.toDouble() ?? 0.0,
    y: (json['y'] as num?)?.toDouble() ?? 0.0,
    width: (json['width'] as num?)?.toDouble() ?? 10.0,
    height: (json['height'] as num?)?.toDouble() ?? 10.0,
    fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14.0,
    fontName: json['fontName'] as String?,
    textColor: (json['textColor'] as num?)?.toInt(),
    isBold: json['isBold'] as bool?,
    isItalic: json['isItalic'] as bool?,
    rotation: (json['rotation'] as num?)?.toDouble(),
    isFontEmbedded: json['isFontEmbedded'] as bool?,
    characterSpacing: (json['characterSpacing'] as num?)?.toDouble(),
    wordSpacing: (json['wordSpacing'] as num?)?.toDouble(),
    baseline: (json['baseline'] as num?)?.toDouble(),
  );

  @override
  String toString() =>
      'PdfTextItem(id: $id, text: "$text", bounds: [${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}, ${width.toStringAsFixed(1)}, ${height.toStringAsFixed(1)}], font: $fontName, size: $fontSize)';
}
