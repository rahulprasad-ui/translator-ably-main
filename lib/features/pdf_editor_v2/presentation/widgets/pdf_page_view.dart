// lib/features/pdf_editor_v2/presentation/widgets/pdf_page_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/pdf_page_model.dart';
import '../providers/pdf_editor_provider.dart';
import 'editable_text_overlay.dart';
import 'pdf_canvas.dart';

/// Interactive viewer hosting the PDF page rasterization, CustomPainter canvas, tap detection, and inline editor
class PdfPageView extends ConsumerStatefulWidget {
  final PdfPageModel page;
  final TransformationController? transformationController;

  const PdfPageView({
    super.key,
    required this.page,
    this.transformationController,
  });

  @override
  ConsumerState<PdfPageView> createState() => _PdfPageViewState();
}

class _PdfPageViewState extends ConsumerState<PdfPageView> {
  late TransformationController _transformController;

  @override
  void initState() {
    super.initState();
    _transformController = widget.transformationController ?? TransformationController();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdfEditorProvider);
    final notifier = ref.read(pdfEditorProvider.notifier);
    final page = widget.page;

    final pageWidth = page.width > 0 ? page.width : 595.0;
    final pageHeight = page.height > 0 ? page.height : 842.0;

    return Center(
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.5,
        maxScale: 4.0,
        boundaryMargin: const EdgeInsets.all(80.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
            borderRadius: BorderRadius.circular(4),
          ),
          child: SizedBox(
            width: pageWidth,
            height: pageHeight,
            child: Stack(
              children: [
                // Layer 1: Rendered PDF Page image
                if (page.renderedImageBytes != null)
                  Positioned.fill(
                    child: Image.memory(
                      page.renderedImageBytes!,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFE11D48),
                    ),
                  ),

                // Layer 2: CustomPaint for Selection Rectangles, Handles, and Live Preview
                Positioned.fill(
                  child: CustomPaint(
                    painter: PdfCanvasPainter(
                      textItems: page.textItems,
                      selectedItem: state.selectedTextItem,
                      activeEdits: state.editsForCurrentPage,
                      showAllTextBounds: true, // Guides around selectable text
                    ),
                  ),
                ),

                // Layer 3: Touch / Hit-testing Tap Detector
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (details) {
                      notifier.onPageTapped(details.localPosition);
                    },
                  ),
                ),

                // Layer 4: Inline Editable Text Overlay
                if (state.isEditingInline && state.selectedTextItem != null)
                  EditableTextOverlay(
                    item: state.selectedTextItem!,
                    font: state.currentFont,
                    initialText: state.editingText,
                    onCommit: () => notifier.commitTextEdit(),
                    onCancel: () => notifier.clearSelection(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
