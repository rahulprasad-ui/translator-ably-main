// lib/features/pdf_editor_v2/presentation/widgets/pdf_page_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/pdf_page_model.dart';
import '../../domain/coordinate_converter.dart';
import '../../domain/entities/text_edit_record.dart';
import '../providers/pdf_editor_provider.dart';
import 'edit_text_dialog.dart';
import 'editable_text_overlay.dart';
import 'pdf_canvas.dart';

/// Interactive viewer hosting the PDF page rasterization, CustomPainter canvas,
/// pinch-to-zoom, floating zoom controls, tap detection, and inline editor.
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
  double _currentScale = 1.0;
  bool _hasAutoFitted = false;

  @override
  void initState() {
    super.initState();
    _transformController = widget.transformationController ?? TransformationController();
    _transformController.addListener(_onTransformationChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformationChanged);
    if (widget.transformationController == null) {
      _transformController.dispose();
    }
    super.dispose();
  }

  void _onTransformationChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.01) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasAutoFitted) {
      _hasAutoFitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final pw = widget.page.width > 0 ? widget.page.width : 595.0;
          _fitWidth(pw);
        }
      });
    }
  }

  void _zoomIn() {
    _zoomBy(1.25);
  }

  void _zoomOut() {
    _zoomBy(0.8);
  }

  void _zoomBy(double factor) {
    final matrix = _transformController.value.clone();
    final current = matrix.getMaxScaleOnAxis();
    final target = (current * factor).clamp(0.3, 5.0);
    final ratio = target / current;

    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? MediaQuery.of(context).size;
    final focalPoint = Offset(size.width / 2, size.height / 2);

    final translation = matrix.getTranslation();
    final newX = focalPoint.dx - (focalPoint.dx - translation.x) * ratio;
    final newY = focalPoint.dy - (focalPoint.dy - translation.y) * ratio;

    setState(() {
      // ignore: deprecated_member_use
      _transformController.value = Matrix4.identity()
        // ignore: deprecated_member_use
        ..translate(newX, newY)
        // ignore: deprecated_member_use
        ..scale(target);
    });
  }

  void _fitWidth(double pageWidth) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? MediaQuery.of(context).size;
    const horizontalMargin = 24.0;
    final targetScale = ((size.width - horizontalMargin) / pageWidth).clamp(0.3, 3.0);
    final xOffset = (size.width - pageWidth * targetScale) / 2;
    const yOffset = 20.0;

    setState(() {
      _transformController.value = Matrix4.identity()
        // ignore: deprecated_member_use
        ..translate(xOffset, yOffset)
        // ignore: deprecated_member_use
        ..scale(targetScale);
    });
  }

  void _resetZoom() {
    setState(() {
      _transformController.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdfEditorProvider);
    final notifier = ref.read(pdfEditorProvider.notifier);
    final page = widget.page;

    final pageWidth = page.width > 0 ? page.width : 595.0;
    final pageHeight = page.height > 0 ? page.height : 842.0;

    return Stack(
      children: [
        // 1. Pinch-to-zoom & pannable InteractiveViewer
        Positioned.fill(
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.3,
            maxScale: 5.0,
            boundaryMargin: const EdgeInsets.symmetric(horizontal: 240.0, vertical: 360.0),
            clipBehavior: Clip.none,
            child: Center(
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
                            showAllTextBounds: false, // Clean Adobe-style presentation
                          ),
                        ),
                      ),

                      // Layer 3: Touch / Hit-testing Tap Detector & Canvas Double-Tap Zoom
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onDoubleTapDown: (details) {
                            final effectiveItems = page.textItems.map((item) {
                              final edit = state.editsForCurrentPage.cast<TextEditRecord?>().firstWhere(
                                    (e) => e != null && e.originalItem.id == item.id,
                                    orElse: () => null,
                                  );
                              if (edit != null) {
                                if (edit.replacementText.isEmpty) {
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

                            final hit = CoordinateConverter.hitTest(
                              details.localPosition,
                              effectiveItems,
                              hitSlop: 8.0,
                            );
                            if (hit != null) {
                              final original = page.textItems.firstWhere((i) => i.id == hit.id, orElse: () => hit);
                              notifier.selectTextItem(original);
                              _openEditDialog(context, ref, original);
                            } else {
                              // Double tap on empty canvas -> Quick zoom toggle
                              if (_currentScale < 1.3) {
                                _zoomBy(1.7);
                              } else {
                                _fitWidth(pageWidth);
                              }
                            }
                          },
                          onTapUp: (details) {
                            final effectiveItems = page.textItems.map((item) {
                              final edit = state.editsForCurrentPage.cast<TextEditRecord?>().firstWhere(
                                    (e) => e != null && e.originalItem.id == item.id,
                                    orElse: () => null,
                                  );
                              if (edit != null) {
                                if (edit.replacementText.isEmpty) {
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

                            final hit = CoordinateConverter.hitTest(
                              details.localPosition,
                              effectiveItems,
                              hitSlop: 8.0,
                            );
                            if (hit != null) {
                              final original = page.textItems.firstWhere((i) => i.id == hit.id, orElse: () => hit);
                              if (state.selectedTextItem?.id == hit.id) {
                                // Second tap on the same text -> open editor directly!
                                _openEditDialog(context, ref, original);
                              } else {
                                notifier.selectTextItem(original);
                              }
                            } else {
                              notifier.clearSelection();
                            }
                          },
                        ),
                      ),

                      // Layer 4: Quick Action Pill directly over selected text
                      if (state.selectedTextItem != null && !state.isEditingInline)
                        Positioned(
                          left: (state.selectedTextItem!.x).clamp(
                            8.0,
                            (pageWidth - 170.0).clamp(8.0, 2000.0),
                          ),
                          top: (state.selectedTextItem!.y - 42.0).clamp(
                            8.0,
                            (pageHeight - 44.0).clamp(8.0, 3000.0),
                          ),
                          child: _buildQuickActionPill(context, ref, state.selectedTextItem!),
                        ),

                      // Layer 5: Inline Editable Text Overlay
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
          ),
        ),

        // 2. Floating Zoom Controls Pill (bottom left)
        Positioned(
          bottom: 20,
          left: 16,
          child: _buildZoomControls(pageWidth),
        ),
      ],
    );
  }

  Widget _buildZoomControls(double pageWidth) {
    final percent = (_currentScale * 100).toInt();

    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(24),
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24, width: 1.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Zoom Out Button (-)
            IconButton(
              icon: const Icon(Icons.remove_rounded, color: Colors.white, size: 18),
              tooltip: 'Zoom Out',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: _zoomOut,
            ),
            const SizedBox(width: 4),

            // Zoom Percentage Chip (tap to toggle 100% / fit)
            InkWell(
              onTap: () {
                if ((_currentScale - 1.0).abs() < 0.15) {
                  _fitWidth(pageWidth);
                } else {
                  _resetZoom();
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$percent%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Zoom In Button (+)
            IconButton(
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
              tooltip: 'Zoom In',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: _zoomIn,
            ),
            const SizedBox(width: 2),

            Container(width: 1, height: 16, color: Colors.white24),
            const SizedBox(width: 2),

            // Fit-to-Width Button
            IconButton(
              icon: const Icon(Icons.fit_screen_rounded, color: Color(0xFFE11D48), size: 18),
              tooltip: 'Fit to Screen',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: () => _fitWidth(pageWidth),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionPill(BuildContext context, WidgetRef ref, dynamic item) {
    final notifier = ref.read(pdfEditorProvider.notifier);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      color: const Color(0xFF1E293B),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE11D48), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _openEditDialog(context, ref, item),
              borderRadius: BorderRadius.circular(12),
              child: const Row(
                children: [
                  Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    'Edit Text',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 1, height: 14, color: Colors.white24),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => notifier.clearSelection(),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(2.0),
                child: Icon(Icons.close, size: 14, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditDialog(BuildContext context, WidgetRef ref, dynamic item) {
    final state = ref.read(pdfEditorProvider);
    final notifier = ref.read(pdfEditorProvider.notifier);

    EditTextDialog.show(
      context: context,
      initialText: state.editingText.isNotEmpty ? state.editingText : item.text,
      font: state.currentFont,
      originalItem: item,
      onApply: (newText, newFont) {
        notifier.applyTextEdit(newText: newText, font: newFont);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated to "$newText"'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      },
      onDelete: () {
        notifier.eraseSelectedText();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Text erased from page'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      },
    );
  }
}
