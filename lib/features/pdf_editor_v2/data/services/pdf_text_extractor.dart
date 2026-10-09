// lib/features/pdf_editor_v2/data/services/pdf_text_extractor.dart
import 'dart:developer';
import 'package:flutter/services.dart';
import '../models/pdf_text_item.dart';

/// Service responsible for extracting text items and typography metadata from PDF pages
class PdfTextExtractorService {
  static const MethodChannel _channel = MethodChannel('com.translator/pdf_text_engine');
  final Map<int, List<PdfTextItem>> _pageTextCache = {};

  /// Clears cache
  void clearCache() {
    _pageTextCache.clear();
  }

  /// Extracts structured text items from the specified page
  Future<List<PdfTextItem>> extractPageText({
    required String pdfPath,
    required int pageIndex,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _pageTextCache.containsKey(pageIndex)) {
      return _pageTextCache[pageIndex]!;
    }

    try {
      final result = await _channel.invokeMethod<List<dynamic>>('extractTextElements', {
        'pdfPath': pdfPath,
        'pageIndex': pageIndex,
      });

      if (result == null || result.isEmpty) {
        _pageTextCache[pageIndex] = [];
        return [];
      }

      final List<PdfTextItem> items = [];
      for (var i = 0; i < result.length; i++) {
        final raw = Map<String, dynamic>.from(result[i] as Map);
        final text = (raw['text'] as String?)?.trim() ?? '';
        if (text.isEmpty) continue;

        final item = PdfTextItem(
          id: (raw['id'] as String?) ?? 'elem_${pageIndex}_${i}_${text.hashCode}',
          text: text,
          pageIndex: pageIndex,
          x: (raw['x'] as num).toDouble(),
          y: (raw['y'] as num).toDouble(),
          width: (raw['width'] as num).toDouble(),
          height: (raw['height'] as num).toDouble(),
          fontSize: (raw['fontSize'] as num?)?.toDouble() ?? 14.0,
          fontName: raw['fontName'] as String?,
          textColor: (raw['textColor'] as num?)?.toInt() ?? (raw['color'] as num?)?.toInt(),
          isBold: raw['isBold'] as bool?,
          isItalic: raw['isItalic'] as bool?,
          rotation: (raw['rotation'] as num?)?.toDouble(),
          isFontEmbedded: raw['isFontEmbedded'] as bool?,
          characterSpacing: (raw['characterSpacing'] as num?)?.toDouble(),
          wordSpacing: (raw['wordSpacing'] as num?)?.toDouble(),
          baseline: (raw['baseline'] as num?)?.toDouble(),
        );

        items.add(item);
      }

      _pageTextCache[pageIndex] = items;
      return items;
    } on MissingPluginException {
      log('[PdfTextExtractorService] Native channel missing - running in test/fallback mode');
      return _pageTextCache[pageIndex] ?? [];
    } catch (e) {
      log('[PdfTextExtractorService] extractPageText error: $e');
      return [];
    }
  }

  /// Sets mock text data for unit tests and headless environments
  void setMockPageText(int pageIndex, List<PdfTextItem> items) {
    _pageTextCache[pageIndex] = items;
  }
}
