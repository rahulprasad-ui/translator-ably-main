// lib/widget/ocr_document_layer_view.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../controllers/pdf_ocr_controller.dart';
import '../helper/my_dialogs.dart';
import '../helper/pref.dart';
import '../model/home.dart';
import '../screen/tab/text_translate_tab.dart';

/// Interactive Document Layer Overlay Viewer
/// Shows the original scanned image with a high-precision blue document boundary layer
/// and optional individual text block bounding boxes.
class OcrDocumentLayerView extends StatefulWidget {
  final OcrPageItem page;
  final VoidCallback? onTranslate;
  final VoidCallback? onCopy;

  const OcrDocumentLayerView({
    super.key,
    required this.page,
    this.onTranslate,
    this.onCopy,
  });

  @override
  State<OcrDocumentLayerView> createState() => _OcrDocumentLayerViewState();
}

class _OcrDocumentLayerViewState extends State<OcrDocumentLayerView> {
  final TransformationController _transController =
      TransformationController();

  bool _showDocLayer = true;
  bool _showBlockBoxes = false;
  int? _selectedBlockIndex;

  static const Color _highlightAmber = Color(0xFFFFB300);

  @override
  void dispose() {
    _transController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transController.value = Matrix4.identity();
  }

  void _onBlockTapped(int index) {
    setState(() {
      _selectedBlockIndex = index;
    });

    final block = widget.page.blockInfos[index];
    _showBlockDetailsSheet(block);
  }

  void _showBlockDetailsSheet(OcrBlockInfo block) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.highlight_rounded,
                      color: Color(0xFF1E88E5),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Selected Text Block',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1D2E),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Get.back(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    block.text,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF1A1D2E),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: block.text));
                        HapticFeedback.lightImpact();
                        MyDialogs.success(msg: 'Text block copied!');
                        Get.back();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E88E5),
                        side: const BorderSide(color: Color(0xFF1E88E5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Text'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Get.back();
                        Pref.pdfText = block.text;
                        Get.to(() => const TextTranslateTab(hType: HomeType.pdf_translator));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.translate_rounded, size: 16),
                      label: const Text('Translate'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    ).then((_) {
      if (mounted) {
        setState(() {
          _selectedBlockIndex = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Interactive Control Strip
        _buildControlStrip(),

        // 2. Main Visual Document Layer Viewer
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A), // Dark slate canvas background
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Zoomable & Pannable Document View
                InteractiveViewer(
                  transformationController: _transController,
                  minScale: 0.7,
                  maxScale: 4.5,
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return _buildImageWithOverlay(constraints);
                      },
                    ),
                  ),
                ),

                // Floating Overlay Hint & Controls
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.crop_free_rounded,
                          color: Color(0xFF60A5FA),
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.page.documentBoundingBox != null
                              ? 'Doc Area Layer Active'
                              : 'Scanned Document',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Floating Reset Zoom Button
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _resetZoom,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        child: const Icon(
                          Icons.zoom_out_map_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. Quick Bottom Actions
        _buildBottomDocSummary(),
      ],
    );
  }

  Widget _buildControlStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Doc Layer Toggle Chip
          GestureDetector(
            onTap: () => setState(() => _showDocLayer = !_showDocLayer),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _showDocLayer
                    ? const Color(0xFF1E88E5)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _showDocLayer
                      ? const Color(0xFF1E88E5)
                      : Colors.grey.withValues(alpha: 0.25),
                ),
                boxShadow: _showDocLayer
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1E88E5).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showDocLayer
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 16,
                    color: _showDocLayer ? Colors.white : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Doc Layer',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          _showDocLayer ? Colors.white : const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Blocks Toggle Chip
          GestureDetector(
            onTap: () => setState(() => _showBlockBoxes = !_showBlockBoxes),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _showBlockBoxes
                    ? const Color(0xFF06B6D4)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _showBlockBoxes
                      ? const Color(0xFF06B6D4)
                      : Colors.grey.withValues(alpha: 0.25),
                ),
                boxShadow: _showBlockBoxes
                    ? [
                        BoxShadow(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showBlockBoxes
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 16,
                    color: _showBlockBoxes ? Colors.white : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Text Blocks (${widget.page.blockInfos.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          _showBlockBoxes ? Colors.white : const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Word Count Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8C42).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.text_fields_rounded,
                  size: 14,
                  color: Color(0xFFFF8C42),
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.page.wordCount} words',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF8C42),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWithOverlay(BoxConstraints constraints) {
    final double contW = constraints.maxWidth;
    final double contH = constraints.maxHeight;

    if (contW <= 0 || contH <= 0) return const SizedBox.shrink();

    // Determine base image dimensions
    double imgW = widget.page.imageWidth;
    double imgH = widget.page.imageHeight;

    if (imgW <= 0 || imgH <= 0) {
      imgW = 1000.0;
      imgH = 1400.0;
    }

    final double imageAspect = imgW / imgH;
    final double containerAspect = contW / contH;

    double renderedWidth;
    double renderedHeight;

    if (containerAspect > imageAspect) {
      // Height-constrained
      renderedHeight = contH;
      renderedWidth = contH * imageAspect;
    } else {
      // Width-constrained
      renderedWidth = contW;
      renderedHeight = contW / imageAspect;
    }

    final double scaleX = renderedWidth / imgW;
    final double scaleY = renderedHeight / imgH;

    return Center(
      child: SizedBox(
        width: renderedWidth,
        height: renderedHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. The Scanned Image
            _buildBaseImage(),

            // 2. Custom Painted Document Layer & Block Highlights
            CustomPaint(
              size: Size(renderedWidth, renderedHeight),
              painter: _DocLayerPainter(
                page: widget.page,
                scaleX: scaleX,
                scaleY: scaleY,
                showDocLayer: _showDocLayer,
                showBlockBoxes: _showBlockBoxes,
                selectedBlockIndex: _selectedBlockIndex,
              ),
            ),

            // 3. Interactive Touch Targets for Text Blocks
            if (_showBlockBoxes)
              ...List.generate(widget.page.blockInfos.length, (idx) {
                final block = widget.page.blockInfos[idx];
                final box = block.boundingBox;
                final l = box.left * scaleX;
                final t = box.top * scaleY;
                final w = box.width * scaleX;
                final h = box.height * scaleY;

                return Positioned(
                  left: l,
                  top: t,
                  width: math.max(w, 24.0),
                  height: math.max(h, 24.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onBlockTapped(idx),
                      borderRadius: BorderRadius.circular(4),
                      splashColor: _highlightAmber.withValues(alpha: 0.3),
                      highlightColor: _highlightAmber.withValues(alpha: 0.15),
                      child: const SizedBox.expand(),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildBaseImage() {
    if (widget.page.thumbnailBytes != null &&
        widget.page.thumbnailBytes!.isNotEmpty) {
      return Image.memory(
        widget.page.thumbnailBytes!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    } else if (widget.page.imagePath != null &&
        File(widget.page.imagePath!).existsSync()) {
      return Image.file(
        File(widget.page.imagePath!),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    } else {
      return Container(
        color: Colors.white,
        child: const Center(
          child: Icon(
            Icons.broken_image_rounded,
            color: Colors.grey,
            size: 48,
          ),
        ),
      );
    }
  }

  Widget _buildBottomDocSummary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.document_scanner_rounded,
              color: Color(0xFF1E88E5),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Document Layer Aligned',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D2E),
                  ),
                ),
                Text(
                  '${widget.page.wordCount} words detected • ${widget.page.charCount} characters',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onCopy,
            icon: const Icon(Icons.copy_rounded, size: 18),
            color: const Color(0xFFFF8C42),
            tooltip: 'Copy all',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            onPressed: widget.onTranslate,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.translate_rounded, size: 14),
            label: const Text(
              'Translate',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for drawing the blue Document Overlay Layer and Text Block bounds
class _DocLayerPainter extends CustomPainter {
  final OcrPageItem page;
  final double scaleX;
  final double scaleY;
  final bool showDocLayer;
  final bool showBlockBoxes;
  final int? selectedBlockIndex;

  // Cached Paint objects for 60/120 FPS zero-allocation hardware acceleration
  static final Paint _docFillPaint = Paint()
    ..color = const Color(0x352196F3)
    ..style = PaintingStyle.fill;

  static final Paint _docBorderPaint = Paint()
    ..color = const Color(0xFF1E88E5)
    ..strokeWidth = 2.4
    ..style = PaintingStyle.stroke;

  static final Paint _cornerPaint = Paint()
    ..color = const Color(0xFF0D47A1)
    ..strokeWidth = 3.6
    ..strokeCap = StrokeCap.square
    ..style = PaintingStyle.stroke;

  static final Paint _selectedBlockFill = Paint()
    ..color = const Color(0x60FFB300)
    ..style = PaintingStyle.fill;

  static final Paint _selectedBlockBorder = Paint()
    ..color = const Color(0xFFFFB300)
    ..strokeWidth = 2.2
    ..style = PaintingStyle.stroke;

  static final Paint _blockFill = Paint()
    ..color = const Color(0x1806B6D4)
    ..style = PaintingStyle.fill;

  static final Paint _blockBorder = Paint()
    ..color = const Color(0x8006B6D4)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  _DocLayerPainter({
    required this.page,
    required this.scaleX,
    required this.scaleY,
    required this.showDocLayer,
    required this.showBlockBoxes,
    this.selectedBlockIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Document Boundary Layer (Matching User's Reference Image)
    if (showDocLayer && page.documentBoundingBox != null) {
      final docRect = Rect.fromLTWH(
        page.documentBoundingBox!.left * scaleX,
        page.documentBoundingBox!.top * scaleY,
        page.documentBoundingBox!.width * scaleX,
        page.documentBoundingBox!.height * scaleY,
      );

      // A. Semi-transparent blue fill
      canvas.drawRect(docRect, _docFillPaint);

      // B. Blue outline border
      canvas.drawRect(docRect, _docBorderPaint);

      // C. L-shaped Scanner Target Corner Brackets
      const double cLen = 16.0;

      // Top-Left Corner
      canvas.drawLine(
        Offset(docRect.left, docRect.top),
        Offset(docRect.left + cLen, docRect.top),
        _cornerPaint,
      );
      canvas.drawLine(
        Offset(docRect.left, docRect.top),
        Offset(docRect.left, docRect.top + cLen),
        _cornerPaint,
      );

      // Top-Right Corner
      canvas.drawLine(
        Offset(docRect.right, docRect.top),
        Offset(docRect.right - cLen, docRect.top),
        _cornerPaint,
      );
      canvas.drawLine(
        Offset(docRect.right, docRect.top),
        Offset(docRect.right, docRect.top + cLen),
        _cornerPaint,
      );

      // Bottom-Left Corner
      canvas.drawLine(
        Offset(docRect.left, docRect.bottom),
        Offset(docRect.left + cLen, docRect.bottom),
        _cornerPaint,
      );
      canvas.drawLine(
        Offset(docRect.left, docRect.bottom),
        Offset(docRect.left, docRect.bottom - cLen),
        _cornerPaint,
      );

      // Bottom-Right Corner
      canvas.drawLine(
        Offset(docRect.right, docRect.bottom),
        Offset(docRect.right - cLen, docRect.bottom),
        _cornerPaint,
      );
      canvas.drawLine(
        Offset(docRect.right, docRect.bottom),
        Offset(docRect.right, docRect.bottom - cLen),
        _cornerPaint,
      );
    }

    // 2. Draw Individual Text Block Outlines (if enabled)
    if (showBlockBoxes && page.blockInfos.isNotEmpty) {
      for (int i = 0; i < page.blockInfos.length; i++) {
        final b = page.blockInfos[i];
        final isSelected = selectedBlockIndex == i;

        final blockRect = Rect.fromLTWH(
          b.boundingBox.left * scaleX,
          b.boundingBox.top * scaleY,
          b.boundingBox.width * scaleX,
          b.boundingBox.height * scaleY,
        );

        if (isSelected) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(blockRect, const Radius.circular(4)),
            _selectedBlockFill,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(blockRect, const Radius.circular(4)),
            _selectedBlockBorder,
          );
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(blockRect, const Radius.circular(3)),
            _blockFill,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(blockRect, const Radius.circular(3)),
            _blockBorder,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DocLayerPainter oldDelegate) {
    return oldDelegate.scaleX != scaleX ||
        oldDelegate.scaleY != scaleY ||
        oldDelegate.showDocLayer != showDocLayer ||
        oldDelegate.showBlockBoxes != showBlockBoxes ||
        oldDelegate.selectedBlockIndex != selectedBlockIndex ||
        oldDelegate.page != page;
  }
}
