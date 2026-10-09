// lib/features/pdf_editor_v2/presentation/pages/pdf_editor_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/pdf_editor_provider.dart';
import '../widgets/pdf_page_view.dart';
import '../widgets/text_formatting_toolbar.dart';

/// Full-featured PDF Editor Page built on Riverpod and Flutter CustomPainter
class PdfEditorPage extends StatelessWidget {
  final String? initialPdfPath;

  const PdfEditorPage({super.key, this.initialPdfPath});

  @override
  Widget build(BuildContext context) {
    // Wrapped in a dedicated ProviderScope so this module is completely decoupled
    return ProviderScope(
      child: _PdfEditorContent(initialPdfPath: initialPdfPath),
    );
  }
}

class _PdfEditorContent extends ConsumerStatefulWidget {
  final String? initialPdfPath;

  const _PdfEditorContent({this.initialPdfPath});

  @override
  ConsumerState<_PdfEditorContent> createState() => _PdfEditorContentState();
}

class _PdfEditorContentState extends ConsumerState<_PdfEditorContent> {
  @override
  void initState() {
    super.initState();
    if (widget.initialPdfPath != null && widget.initialPdfPath!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(pdfEditorProvider.notifier).openPdf(widget.initialPdfPath!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdfEditorProvider);
    final notifier = ref.read(pdfEditorProvider.notifier);
    final doc = state.document;

    // Listen for export results to show verification feedback
    ref.listen(pdfEditorProvider, (previous, next) {
      if (previous?.exportResult == null && next.exportResult != null) {
        _showExportResultDialog(context, next.exportResult!);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate canvas background
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doc?.fileName ?? 'PDF Editor Pro',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (doc != null)
              Text(
                'Page ${state.currentPageIndex + 1} of ${doc.pageCount} • Tap text to edit',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          // Undo Action
          IconButton(
            icon: Icon(
              Icons.undo,
              color: state.canUndo ? Colors.white : Colors.white24,
              size: 20,
            ),
            tooltip: 'Undo',
            onPressed: state.canUndo ? () => notifier.undo() : null,
          ),
          // Redo Action
          IconButton(
            icon: Icon(
              Icons.redo,
              color: state.canRedo ? Colors.white : Colors.white24,
              size: 20,
            ),
            tooltip: 'Redo',
            onPressed: state.canRedo ? () => notifier.redo() : null,
          ),
          const SizedBox(width: 4),

          // Export Button
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              onPressed: state.isExporting || doc == null ? null : () => notifier.exportPdf(),
              icon: state.isExporting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_done_rounded, size: 16),
              label: Text(
                state.isExporting ? 'Saving...' : 'Export PDF',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Body: Document Viewport or Loading/Error State
          if (state.isLoading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFFE11D48)),
                  SizedBox(height: 16),
                  Text('Loading PDF and extracting typography...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          else if (state.errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Color(0xFFE11D48)),
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (widget.initialPdfPath != null) {
                          notifier.openPdf(widget.initialPdfPath!);
                        }
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (state.currentPage != null)
            Positioned.fill(
              child: PdfPageView(page: state.currentPage!),
            )
          else
            const Center(
              child: Text(
                'No PDF document open',
                style: TextStyle(color: Colors.white70),
              ),
            ),

          // Top Floating Formatting Toolbar
          if (state.selectedTextItem != null)
            const Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: TextFormattingToolbar(),
              ),
            ),

          // Bottom Page Switcher Bar
          if (doc != null && doc.pageCount > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: state.currentPageIndex > 0
                            ? () => notifier.loadPage(state.currentPageIndex - 1)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${state.currentPageIndex + 1} / ${doc.pageCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Colors.white),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: state.currentPageIndex < doc.pageCount - 1
                            ? () => notifier.loadPage(state.currentPageIndex + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showExportResultDialog(BuildContext context, dynamic result) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isSuccess = result.isSuccess as bool;
        final path = result.outputPath as String;
        final sizeBytes = result.fileSizeBytes as int;
        final sizeKb = (sizeBytes / 1024).toStringAsFixed(1);
        final isRenderable = result.isRenderable as bool;
        final detected = result.areModificationsDetected as bool;

        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFE11D48),
              ),
              const SizedBox(width: 10),
              Text(
                isSuccess ? 'PDF Exported & Verified' : 'Export Failed',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSuccess) ...[
                _buildVerifyRow('Output file created', '$sizeKb KB'),
                _buildVerifyRow('Engine render verification', isRenderable ? 'Passed' : 'Pending'),
                _buildVerifyRow('Text modifications verified', detected ? 'Passed' : 'Pending'),
                const SizedBox(height: 12),
                Text(
                  'Saved at: $path',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ] else
                Text(
                  result.errorMessage ?? 'An error occurred during export.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.white70)),
            ),
            if (isSuccess && File(path).existsSync())
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  SharePlus.instance.share(path, subject: 'Modified PDF');
                },
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildVerifyRow(String label, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(status, style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
