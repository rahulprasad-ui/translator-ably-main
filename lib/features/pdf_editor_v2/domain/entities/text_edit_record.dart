// lib/features/pdf_editor_v2/domain/entities/text_edit_record.dart
import 'package:flutter/material.dart';
import '../../data/models/pdf_font_metadata.dart';
import '../../data/models/pdf_text_item.dart';

/// Replacement strategy applied for a specific edit
enum ReplacementStrategy {
  genuineStreamModification, // Surgical content stream token replacement / operator purge
  matchedVectorInsertion,    // Remove old text token & insert vector text with matched font metrics
  coverAndRewriteFallback,   // Background-aware redaction covering
}

/// Represents an active or committed text modification on a PDF page
class TextEditRecord {
  final String id;
  final int pageIndex;
  final PdfTextItem originalItem;
  final String replacementText;
  final PdfFontMetadata appliedFont;
  final Rect targetRect;
  final ReplacementStrategy strategy;
  final DateTime timestamp;

  TextEditRecord({
    required this.id,
    required this.pageIndex,
    required this.originalItem,
    required this.replacementText,
    required this.appliedFont,
    Rect? targetRect,
    this.strategy = ReplacementStrategy.genuineStreamModification,
    DateTime? timestamp,
  })  : targetRect = targetRect ?? originalItem.boundingBox,
        timestamp = timestamp ?? DateTime.now();

  /// Converts this edit record into the modification payload for the native/Dart PDF modification engine
  Map<String, dynamic> toModificationPayload({required double pageHeight}) {
    // In native bottom-up PDF coordinates:
    final nativePdfY = pageHeight - targetRect.top - targetRect.height;

    return {
      'type': 'text',
      'strategy': strategy.name,
      'pageIndex': pageIndex,
      'originalText': originalItem.text,
      'replacementText': replacementText,
      'text': replacementText,
      'x': targetRect.left,
      'y': targetRect.top, // top-down
      'pdfY': nativePdfY,  // bottom-up
      'width': targetRect.width,
      'height': targetRect.height,
      'fontSize': appliedFont.fontSize,
      'fontName': appliedFont.fontName,
      'color': appliedFont.textColor,
      'isBold': appliedFont.isBold,
      'isItalic': appliedFont.isItalic,
      'coverOriginal': strategy == ReplacementStrategy.coverAndRewriteFallback,
    };
  }

  TextEditRecord copyWith({
    String? id,
    int? pageIndex,
    PdfTextItem? originalItem,
    String? replacementText,
    PdfFontMetadata? appliedFont,
    Rect? targetRect,
    ReplacementStrategy? strategy,
  }) {
    return TextEditRecord(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      originalItem: originalItem ?? this.originalItem,
      replacementText: replacementText ?? this.replacementText,
      appliedFont: appliedFont ?? this.appliedFont,
      targetRect: targetRect ?? this.targetRect,
      strategy: strategy ?? this.strategy,
      timestamp: timestamp,
    );
  }
}
