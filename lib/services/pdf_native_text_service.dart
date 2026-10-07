import 'dart:developer';
import 'package:flutter/services.dart';

class NativePdfTextService {
  static const MethodChannel _channel = MethodChannel('com.translator/pdf_text_engine');

  /// Extracts true selectable text elements from the PDF using native PDFBox.
  /// Returns an empty list if the page is scanned or contains no vector text.
  static Future<List<Map<String, dynamic>>> extractTextElements({
    required String pdfPath,
    required int pageIndex,
  }) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('extractTextElements', {
        'pdfPath': pdfPath,
        'pageIndex': pageIndex,
      });

      if (result == null) return [];
      return result.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (e) {
      log('[NativePdfTextService] extractTextElements error: $e');
      return [];
    }
  }

  /// Saves the modified PDF using native PDFBox, retaining the vector format,
  /// original document structure, fonts, and clean vector overlays without full rasterization.
  static Future<bool> saveModifiedPdf({
    required String sourcePath,
    required String outPath,
    required List<Map<String, dynamic>> modifications,
  }) async {
    try {
      final success = await _channel.invokeMethod<bool>('saveModifiedPdf', {
        'sourcePath': sourcePath,
        'outPath': outPath,
        'modifications': modifications,
      });
      return success ?? false;
    } catch (e) {
      log('[NativePdfTextService] saveModifiedPdf error: $e');
      return false;
    }
  }
}
