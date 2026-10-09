// lib/features/pdf_editor_v2/data/models/pdf_page_model.dart
import 'dart:typed_data';
import 'pdf_text_item.dart';

/// Represents a single page in a PDF document with its dimensions, text items, and render state
class PdfPageModel {
  final int pageIndex;
  final double width; // in PDF points (e.g. 595.0 for A4)
  final double height; // in PDF points (e.g. 842.0 for A4)
  final int rotation; // 0, 90, 180, 270
  final List<PdfTextItem> textItems;
  final Uint8List? renderedImageBytes;
  final bool isTextExtracted;
  final bool isRendering;

  const PdfPageModel({
    required this.pageIndex,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.textItems = const [],
    this.renderedImageBytes,
    this.isTextExtracted = false,
    this.isRendering = false,
  });

  /// Aspect ratio: width / height
  double get aspectRatio => height > 0 ? width / height : 1.0;

  PdfPageModel copyWith({
    int? pageIndex,
    double? width,
    double? height,
    int? rotation,
    List<PdfTextItem>? textItems,
    Uint8List? renderedImageBytes,
    bool? isTextExtracted,
    bool? isRendering,
  }) {
    return PdfPageModel(
      pageIndex: pageIndex ?? this.pageIndex,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      textItems: textItems ?? this.textItems,
      renderedImageBytes: renderedImageBytes ?? this.renderedImageBytes,
      isTextExtracted: isTextExtracted ?? this.isTextExtracted,
      isRendering: isRendering ?? this.isRendering,
    );
  }

  Map<String, dynamic> toJson() => {
    'pageIndex': pageIndex,
    'width': width,
    'height': height,
    'rotation': rotation,
    'textItems': textItems.map((e) => e.toJson()).toList(),
    'isTextExtracted': isTextExtracted,
  };
}
