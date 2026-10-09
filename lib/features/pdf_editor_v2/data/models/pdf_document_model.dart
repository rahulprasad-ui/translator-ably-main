// lib/features/pdf_editor_v2/data/models/pdf_document_model.dart
import 'pdf_page_model.dart';

/// Represents a loaded PDF document
class PdfDocumentModel {
  final String filePath;
  final String fileName;
  final int pageCount;
  final List<PdfPageModel> pages;
  final int fileSizeBytes;
  final bool isLoaded;

  const PdfDocumentModel({
    required this.filePath,
    required this.fileName,
    required this.pageCount,
    this.pages = const [],
    this.fileSizeBytes = 0,
    this.isLoaded = false,
  });

  PdfPageModel? getPage(int index) {
    if (index >= 0 && index < pages.length) {
      return pages[index];
    }
    return null;
  }

  PdfDocumentModel copyWith({
    String? filePath,
    String? fileName,
    int? pageCount,
    List<PdfPageModel>? pages,
    int? fileSizeBytes,
    bool? isLoaded,
  }) {
    return PdfDocumentModel(
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      pageCount: pageCount ?? this.pageCount,
      pages: pages ?? this.pages,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}
