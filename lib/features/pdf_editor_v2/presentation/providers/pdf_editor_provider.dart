// lib/features/pdf_editor_v2/presentation/providers/pdf_editor_provider.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/pdf_document_model.dart';
import '../../data/models/pdf_font_metadata.dart';
import '../../data/models/pdf_page_model.dart';
import '../../data/models/pdf_text_item.dart';
import '../../data/services/pdf_export_service.dart';
import '../../data/services/pdf_renderer.dart';
import '../../data/services/pdf_text_extractor.dart';
import '../../domain/coordinate_converter.dart';
import '../../domain/entities/text_edit_record.dart';

/// Immutable state holding the full state of the PDF Editor V2
class PdfEditorState {
  final bool isLoading;
  final bool isExporting;
  final String? errorMessage;
  final PdfDocumentModel? document;
  final int currentPageIndex;
  final PdfTextItem? selectedTextItem;
  final PdfFontMetadata currentFont;
  final String editingText;
  final bool isEditingInline;
  final double zoomLevel;
  final Offset panOffset;
  final List<TextEditRecord> editRecords;
  final List<List<TextEditRecord>> undoStack;
  final List<List<TextEditRecord>> redoStack;
  final ExportVerificationResult? exportResult;

  const PdfEditorState({
    this.isLoading = false,
    this.isExporting = false,
    this.errorMessage,
    this.document,
    this.currentPageIndex = 0,
    this.selectedTextItem,
    this.currentFont = const PdfFontMetadata(),
    this.editingText = '',
    this.isEditingInline = false,
    this.zoomLevel = 1.0,
    this.panOffset = Offset.zero,
    this.editRecords = const [],
    this.undoStack = const [],
    this.redoStack = const [],
    this.exportResult,
  });

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
  PdfPageModel? get currentPage => document?.getPage(currentPageIndex);

  /// Returns all active edits for the current page
  List<TextEditRecord> get editsForCurrentPage =>
      editRecords.where((e) => e.pageIndex == currentPageIndex).toList();

  PdfEditorState copyWith({
    bool? isLoading,
    bool? isExporting,
    String? errorMessage,
    PdfDocumentModel? document,
    int? currentPageIndex,
    PdfTextItem? selectedTextItem,
    bool clearSelectedText = false,
    PdfFontMetadata? currentFont,
    String? editingText,
    bool? isEditingInline,
    double? zoomLevel,
    Offset? panOffset,
    List<TextEditRecord>? editRecords,
    List<List<TextEditRecord>>? undoStack,
    List<List<TextEditRecord>>? redoStack,
    ExportVerificationResult? exportResult,
    bool clearExportResult = false,
  }) {
    return PdfEditorState(
      isLoading: isLoading ?? this.isLoading,
      isExporting: isExporting ?? this.isExporting,
      errorMessage: errorMessage,
      document: document ?? this.document,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      selectedTextItem: clearSelectedText ? null : (selectedTextItem ?? this.selectedTextItem),
      currentFont: currentFont ?? this.currentFont,
      editingText: editingText ?? this.editingText,
      isEditingInline: isEditingInline ?? this.isEditingInline,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      panOffset: panOffset ?? this.panOffset,
      editRecords: editRecords ?? this.editRecords,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      exportResult: clearExportResult ? null : (exportResult ?? this.exportResult),
    );
  }
}

/// Service injection providers
final pdfRendererServiceProvider = Provider<PdfRendererService>((ref) {
  final service = PdfRendererService();
  ref.onDispose(() => service.dispose());
  return service;
});

final pdfTextExtractorServiceProvider = Provider<PdfTextExtractorService>((ref) {
  return PdfTextExtractorService();
});

final pdfExportServiceProvider = Provider<PdfExportService>((ref) {
  return PdfExportService(
    rendererService: ref.read(pdfRendererServiceProvider),
    textExtractorService: ref.read(pdfTextExtractorServiceProvider),
  );
});

/// Riverpod StateNotifier managing the PDF Editor logic
class PdfEditorNotifier extends StateNotifier<PdfEditorState> {
  final PdfRendererService rendererService;
  final PdfTextExtractorService textExtractorService;
  final PdfExportService exportService;

  PdfEditorNotifier({
    required this.rendererService,
    required this.textExtractorService,
    required this.exportService,
  }) : super(const PdfEditorState());

  PdfRendererService get _rendererService => rendererService;
  PdfTextExtractorService get _textExtractorService => textExtractorService;
  PdfExportService get _exportService => exportService;

  /// Opens a PDF document and extracts the first page
  Future<void> openPdf(String filePath) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'File not found at: $filePath',
        );
        return;
      }

      final pageCount = await _rendererService.openDocument(filePath);
      final fileName = filePath.split(Platform.pathSeparator).last;
      final fileLength = await file.length();

      // Initialize page placeholders
      final pages = List<PdfPageModel>.generate(
        pageCount,
        (i) => PdfPageModel(
          pageIndex: i,
          width: 595.0, // default A4 points, updated upon render
          height: 842.0,
        ),
      );

      final doc = PdfDocumentModel(
        filePath: filePath,
        fileName: fileName,
        pageCount: pageCount,
        pages: pages,
        fileSizeBytes: fileLength,
        isLoaded: true,
      );

      state = state.copyWith(
        document: doc,
        currentPageIndex: 0,
        isLoading: false,
        clearSelectedText: true,
        editRecords: const [],
        undoStack: const [],
        redoStack: const [],
      );

      // Load initial page
      await loadPage(0);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to open PDF: $e',
      );
    }
  }

  /// Loads rendering and extracted text for the specified page
  Future<void> loadPage(int pageIndex) async {
    final doc = state.document;
    if (doc == null || pageIndex < 0 || pageIndex >= doc.pageCount) return;

    final targetPage = doc.getPage(pageIndex);
    if (targetPage == null) return;

    // 1. Get exact page dimensions & render page raster image
    final dimensions = await _rendererService.getPageDimensions(pageIndex);
    final width = dimensions?.width ?? targetPage.width;
    final height = dimensions?.height ?? targetPage.height;

    final imageBytes = await _rendererService.renderPage(
      pageIndex: pageIndex,
      scale: 2.0,
    );

    // 2. Extract text items & typography
    final textItems = await _textExtractorService.extractPageText(
      pdfPath: doc.filePath,
      pageIndex: pageIndex,
    );

    // Update page in document model
    final updatedPage = targetPage.copyWith(
      width: width,
      height: height,
      textItems: textItems,
      renderedImageBytes: imageBytes,
      isTextExtracted: true,
    );

    final updatedPages = List<PdfPageModel>.from(doc.pages);
    updatedPages[pageIndex] = updatedPage;

    state = state.copyWith(
      currentPageIndex: pageIndex,
      document: doc.copyWith(pages: updatedPages),
      clearSelectedText: true,
      isEditingInline: false,
    );
  }

  /// Handles touch/click on the PDF canvas in page coordinates
  void onPageTapped(Offset pagePoint) {
    final page = state.currentPage;
    if (page == null) return;

    // Detect closest matching text item, accounting for active edits
    final effectiveItems = page.textItems.map((item) {
      final edit = state.editRecords.cast<TextEditRecord?>().firstWhere(
            (e) => e != null && e.pageIndex == state.currentPageIndex && e.originalItem.id == item.id,
            orElse: () => null,
          );
      if (edit != null) {
        if (edit.replacementText.isEmpty) {
          // Erased item: place out of hit area so it's not tapped
          return item.copyWith(width: 0, height: 0, x: -9999, y: -9999);
        }
        return item.copyWith(
          text: edit.replacementText,
          x: edit.targetRect.left,
          y: edit.targetRect.top,
          width: edit.targetRect.width,
          height: edit.targetRect.height,
        );
      }
      return item;
    }).toList();

    final hitItem = CoordinateConverter.hitTest(
      pagePoint,
      effectiveItems,
      hitSlop: 6.0,
    );

    if (hitItem != null) {
      final original = page.textItems.firstWhere((i) => i.id == hitItem.id, orElse: () => hitItem);
      selectTextItem(original);
    } else {
      clearSelection();
    }
  }

  /// Selects a text item, displays the red selection box, and initializes formatting controls
  void selectTextItem(PdfTextItem item) {
    // Check if item has already been edited in active edit records
    final existingEdit = state.editRecords.cast<TextEditRecord?>().firstWhere(
          (e) => e != null && e.originalItem.id == item.id,
          orElse: () => null,
        );

    final fontMeta = existingEdit != null ? existingEdit.appliedFont : item.fontMetadata;
    final activeText = existingEdit != null ? existingEdit.replacementText : item.text;
    final effectiveItem = existingEdit != null
        ? item.copyWith(
            text: existingEdit.replacementText,
            width: existingEdit.targetRect.width,
            height: existingEdit.targetRect.height,
          )
        : item;

    state = state.copyWith(
      selectedTextItem: effectiveItem,
      currentFont: fontMeta,
      editingText: activeText,
      isEditingInline: false,
    );
  }

  /// Clears text selection
  void clearSelection() {
    state = state.copyWith(
      clearSelectedText: true,
      isEditingInline: false,
      editingText: '',
    );
  }

  /// Starts inline text editing over the selected bounding box
  void startInlineEditing() {
    if (state.selectedTextItem == null) return;
    state = state.copyWith(isEditingInline: true);
  }

  /// Updates editing text in real time
  void updateEditingText(String newText) {
    state = state.copyWith(editingText: newText);
  }

  /// Updates font family
  void updateFontFamily(String fontName) {
    final updatedFont = state.currentFont.copyWith(fontName: fontName);
    state = state.copyWith(currentFont: updatedFont);
    _applyLiveFormattingToActiveEdit();
  }

  /// Updates font size
  void updateFontSize(double newSize) {
    final updatedFont = state.currentFont.copyWith(fontSize: newSize.clamp(6.0, 120.0));
    state = state.copyWith(currentFont: updatedFont);
    _applyLiveFormattingToActiveEdit();
  }

  /// Toggles bold
  void toggleBold() {
    final updatedFont = state.currentFont.copyWith(isBold: !state.currentFont.isBold);
    state = state.copyWith(currentFont: updatedFont);
    _applyLiveFormattingToActiveEdit();
  }

  /// Toggles italic
  void toggleItalic() {
    final updatedFont = state.currentFont.copyWith(isItalic: !state.currentFont.isItalic);
    state = state.copyWith(currentFont: updatedFont);
    _applyLiveFormattingToActiveEdit();
  }

  /// Updates text color
  void updateTextColor(Color color) {
    final updatedFont = state.currentFont.copyWith(textColor: color.toARGB32());
    state = state.copyWith(currentFont: updatedFont);
    _applyLiveFormattingToActiveEdit();
  }

  void _applyLiveFormattingToActiveEdit() {
    final selected = state.selectedTextItem;
    if (selected == null) return;

    final existingIndex = state.editRecords.indexWhere((e) => e.originalItem.id == selected.id);
    if (existingIndex != -1) {
      final updatedEdits = List<TextEditRecord>.from(state.editRecords);
      updatedEdits[existingIndex] = updatedEdits[existingIndex].copyWith(
        appliedFont: state.currentFont,
        replacementText: state.editingText,
      );
      state = state.copyWith(editRecords: updatedEdits);
    }
  }

  /// Applies replacement text and typography modifications atomically
  void applyTextEdit({
    required String newText,
    required PdfFontMetadata font,
  }) {
    state = state.copyWith(
      editingText: newText,
      currentFont: font,
    );
    commitTextEdit();
  }

  /// Erases selected text item from the PDF
  void eraseSelectedText() {
    final selected = state.selectedTextItem;
    if (selected == null) return;
    _pushUndoHistory();

    final page = state.currentPage;
    final originalItem = page?.textItems.firstWhere(
          (item) => item.id == selected.id,
          orElse: () => selected,
        ) ?? selected;

    final targetRect = Rect.fromLTWH(originalItem.x, originalItem.y, originalItem.width, originalItem.height);
    final record = TextEditRecord(
      id: 'erase_${originalItem.id}_${DateTime.now().millisecondsSinceEpoch}',
      pageIndex: state.currentPageIndex,
      originalItem: originalItem,
      replacementText: '',
      appliedFont: state.currentFont,
      targetRect: targetRect,
      strategy: ReplacementStrategy.genuineStreamModification,
    );

    final updatedEdits = List<TextEditRecord>.from(state.editRecords);
    final existingIndex = updatedEdits.indexWhere((e) => e.originalItem.id == originalItem.id);
    if (existingIndex != -1) {
      updatedEdits[existingIndex] = record;
    } else {
      updatedEdits.add(record);
    }

    state = state.copyWith(
      editRecords: updatedEdits,
      clearSelectedText: true,
      isEditingInline: false,
      redoStack: const [],
    );
  }

  /// Commits current inline edit to the active edit records list and updates undo history
  void commitTextEdit() {
    final selected = state.selectedTextItem;
    if (selected == null) return;

    final newText = state.editingText.trim();
    if (newText.isEmpty) {
      clearSelection();
      return;
    }

    _pushUndoHistory();

    final page = state.currentPage;
    final originalItem = page?.textItems.firstWhere(
          (item) => item.id == selected.id,
          orElse: () => selected,
        ) ?? selected;

    // Determine precise target bounding box using TextPainter
    final tp = TextPainter(
      text: TextSpan(text: newText, style: state.currentFont.toFlutterTextStyle()),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final double textWidth = tp.width;
    final double textHeight = (tp.height > originalItem.height) ? tp.height : originalItem.height;
    final targetRect = Rect.fromLTWH(
      originalItem.x,
      originalItem.y,
      (textWidth < 12.0) ? 12.0 : textWidth,
      textHeight,
    );

    final record = TextEditRecord(
      id: 'edit_${originalItem.id}_${DateTime.now().millisecondsSinceEpoch}',
      pageIndex: state.currentPageIndex,
      originalItem: originalItem,
      replacementText: newText,
      appliedFont: state.currentFont,
      targetRect: targetRect,
      strategy: ReplacementStrategy.genuineStreamModification,
    );

    // Replace if item was already edited, otherwise append
    final updatedEdits = List<TextEditRecord>.from(state.editRecords);
    final existingIndex = updatedEdits.indexWhere((e) => e.originalItem.id == originalItem.id);
    if (existingIndex != -1) {
      updatedEdits[existingIndex] = record;
    } else {
      updatedEdits.add(record);
    }

    final updatedSelectedItem = originalItem.copyWith(
      text: newText,
      width: targetRect.width,
      height: targetRect.height,
    );

    state = state.copyWith(
      selectedTextItem: updatedSelectedItem,
      editRecords: updatedEdits,
      isEditingInline: false,
      redoStack: const [],
    );
  }

  void _pushUndoHistory() {
    final newUndo = List<List<TextEditRecord>>.from(state.undoStack);
    newUndo.add(List<TextEditRecord>.from(state.editRecords));
    state = state.copyWith(undoStack: newUndo);
  }

  /// Undo last modification
  void undo() {
    if (!state.canUndo) return;

    final newUndo = List<List<TextEditRecord>>.from(state.undoStack);
    final previousEdits = newUndo.removeLast();

    final newRedo = List<List<TextEditRecord>>.from(state.redoStack);
    newRedo.add(List<TextEditRecord>.from(state.editRecords));

    state = state.copyWith(
      editRecords: previousEdits,
      undoStack: newUndo,
      redoStack: newRedo,
      clearSelectedText: true,
      isEditingInline: false,
    );
  }

  /// Redo undone modification
  void redo() {
    if (!state.canRedo) return;

    final newRedo = List<List<TextEditRecord>>.from(state.redoStack);
    final nextEdits = newRedo.removeLast();

    final newUndo = List<List<TextEditRecord>>.from(state.undoStack);
    newUndo.add(List<TextEditRecord>.from(state.editRecords));

    state = state.copyWith(
      editRecords: nextEdits,
      undoStack: newUndo,
      redoStack: newRedo,
      clearSelectedText: true,
      isEditingInline: false,
    );
  }

  /// Sets zoom level
  void setZoom(double zoom) {
    state = state.copyWith(zoomLevel: zoom.clamp(0.5, 5.0));
  }

  /// Exports the modified PDF and verifies that edits persist
  Future<ExportVerificationResult?> exportPdf({String? customOutputPath}) async {
    final doc = state.document;
    if (doc == null) return null;

    state = state.copyWith(isExporting: true, clearExportResult: true);

    try {
      final Map<int, double> pageHeights = {};
      for (final p in doc.pages) {
        pageHeights[p.pageIndex] = p.height;
      }

      final result = await _exportService.exportAndVerify(
        sourcePath: doc.filePath,
        edits: state.editRecords,
        pageHeights: pageHeights,
        customOutputPath: customOutputPath,
      );

      state = state.copyWith(
        isExporting: false,
        exportResult: result,
      );

      return result;
    } catch (e) {
      final fail = ExportVerificationResult(
        isSuccess: false,
        outputPath: '',
        errorMessage: e.toString(),
      );
      state = state.copyWith(isExporting: false, exportResult: fail);
      return fail;
    }
  }

  /// Dismisses export result dialog/banner
  void dismissExportResult() {
    state = state.copyWith(clearExportResult: true);
  }
}

/// Main Riverpod provider for the PDF Editor V2
final pdfEditorProvider = StateNotifierProvider<PdfEditorNotifier, PdfEditorState>((ref) {
  return PdfEditorNotifier(
    rendererService: ref.watch(pdfRendererServiceProvider),
    textExtractorService: ref.watch(pdfTextExtractorServiceProvider),
    exportService: ref.watch(pdfExportServiceProvider),
  );
});
