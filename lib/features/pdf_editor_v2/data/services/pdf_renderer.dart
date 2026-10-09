// lib/features/pdf_editor_v2/data/services/pdf_renderer.dart
import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// LRU Cache for rendered PDF page image bytes
class _PageLruCache {
  final int capacity;
  final LinkedHashMap<int, Uint8List> _cache = LinkedHashMap<int, Uint8List>();

  _PageLruCache({this.capacity = 4});

  Uint8List? get(int pageIndex) {
    final bytes = _cache.remove(pageIndex);
    if (bytes != null) {
      _cache[pageIndex] = bytes;
    }
    return bytes;
  }

  void put(int pageIndex, Uint8List bytes) {
    _cache.remove(pageIndex);
    _cache[pageIndex] = bytes;
    if (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
  }

  void clear() {
    _cache.clear();
  }
}

/// Service responsible for high-performance PDF page rasterization and render caching
class PdfRendererService {
  PdfDocument? _document;
  String? _loadedPath;
  final _PageLruCache _cache = _PageLruCache(capacity: 6);
  Completer<void>? _renderLock;

  bool get isDocumentOpen => _document != null;
  String? get loadedPath => _loadedPath;

  /// Opens a PDF file for rendering
  Future<int> openDocument(String filePath) async {
    try {
      if (_document != null && _loadedPath == filePath) {
        return _document!.pagesCount;
      }

      await dispose();

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('PDF file does not exist at path: $filePath');
      }

      _document = await PdfDocument.openFile(filePath);
      _loadedPath = filePath;
      return _document!.pagesCount;
    } catch (e) {
      log('[PdfRendererService] openDocument error: $e');
      rethrow;
    }
  }

  /// Renders a specific page to PNG image bytes
  /// [pageIndex] is 0-indexed.
  /// [scale] controls the resolution multiplier (1.0 = 72 DPI, 2.0 = 144 DPI for Retina/Zoom)
  Future<Uint8List?> renderPage({
    required int pageIndex,
    double scale = 2.0,
  }) async {
    // Check LRU cache first
    final cached = _cache.get(pageIndex);
    if (cached != null) {
      return cached;
    }

    if (_document == null) {
      log('[PdfRendererService] Document is not open');
      return null;
    }

    // Serialize page renders to avoid concurrent PDFium engine collisions
    while (_renderLock != null) {
      await _renderLock!.future;
    }
    _renderLock = Completer<void>();

    try {
      // pdfx page numbers are 1-indexed
      final pageNumber = pageIndex + 1;
      if (pageNumber < 1 || pageNumber > _document!.pagesCount) {
        return null;
      }

      final page = await _document!.getPage(pageNumber);
      try {
        final renderWidth = page.width * scale;
        final renderHeight = page.height * scale;

        final pageImage = await page.render(
          width: renderWidth,
          height: renderHeight,
          format: PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );

        if (pageImage != null && pageImage.bytes.isNotEmpty) {
          _cache.put(pageIndex, pageImage.bytes);
          return pageImage.bytes;
        }
        return null;
      } finally {
        await page.close();
      }
    } catch (e) {
      log('[PdfRendererService] renderPage error on page $pageIndex: $e');
      return null;
    } finally {
      final lock = _renderLock;
      _renderLock = null;
      lock?.complete();
    }
  }

  /// Retrieves the physical dimensions (in PDF points) of a page
  Future<Size?> getPageDimensions(int pageIndex) async {
    if (_document == null) return null;
    try {
      final pageNumber = pageIndex + 1;
      final page = await _document!.getPage(pageNumber);
      final size = Size(page.width, page.height);
      await page.close();
      return size;
    } catch (e) {
      log('[PdfRendererService] getPageDimensions error: $e');
      return null;
    }
  }

  /// Disposes active document and clears caches
  Future<void> dispose() async {
    _cache.clear();
    if (_document != null) {
      try {
        await _document!.close();
      } catch (e) {
        log('[PdfRendererService] dispose document error: $e');
      }
      _document = null;
      _loadedPath = null;
    }
  }
}
