// lib/screen/pdf_fill_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../ads/widget/bottom_native_ad.dart';
import '../controllers/pdf_fill_controller.dart';
import '../helper/my_dialogs.dart';

class PdfFillScreen extends StatefulWidget {
  final String? initialPdfPath;
  const PdfFillScreen({super.key, this.initialPdfPath});

  @override
  State<PdfFillScreen> createState() => _PdfFillScreenState();
}

class _PdfFillScreenState extends State<PdfFillScreen> {
  final PdfFillController _c = Get.put(PdfFillController());

  static const Color _bg = Color(0xFFF1F5F9);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _brandTeal = Color(0xFF0D9488);
  static const Color _accentOrange = Color(0xFFFF8C42);

  // Zoom / Pan lock toggle
  bool _isPanZoomEnabled = false;
  final TransformationController _transformController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    if (widget.initialPdfPath != null &&
        File(widget.initialPdfPath!).existsSync()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _c.loadPdf(widget.initialPdfPath!);
      });
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _textPrimary, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Obx(() {
          if (!_c.hasDocument) {
            return const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_note_rounded, color: _brandTeal, size: 24),
                SizedBox(width: 8),
                Text(
                  'Fill & Sign PDF',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              Text(
                _c.selectedPdfName.value ?? 'Document',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Page ${_c.currentPageIndex.value + 1} of ${_c.pageCount.value}',
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        }),
        centerTitle: true,
        actions: [
          Obx(() {
            if (!_c.hasDocument) return const SizedBox.shrink();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Undo Button
                IconButton(
                  icon: Icon(
                    Icons.undo_rounded,
                    size: 22,
                    color: _c.canUndo.value ? _textPrimary : Colors.black26,
                  ),
                  tooltip: 'Undo',
                  onPressed: _c.canUndo.value ? _c.undo : null,
                ),
                // Redo Button
                IconButton(
                  icon: Icon(
                    Icons.redo_rounded,
                    size: 22,
                    color: _c.canRedo.value ? _textPrimary : Colors.black26,
                  ),
                  tooltip: 'Redo',
                  onPressed: _c.canRedo.value ? _c.redo : null,
                ),
                // Pan / Edit Mode toggle
                IconButton(
                  icon: Icon(
                    _isPanZoomEnabled
                        ? Icons.pan_tool_rounded
                        : Icons.touch_app_rounded,
                    size: 22,
                    color: _isPanZoomEnabled ? _brandTeal : _textSecondary,
                  ),
                  tooltip: _isPanZoomEnabled
                      ? 'Pan/Zoom Mode: Drag page'
                      : 'Edit Mode: Move & Place fields',
                  onPressed: () {
                    setState(() {
                      _isPanZoomEnabled = !_isPanZoomEnabled;
                    });
                    MyDialogs.info(
                      msg: _isPanZoomEnabled
                          ? 'Zoom/Pan Mode Active: Pinch to zoom or drag page'
                          : 'Edit Mode Active: Touch and smoothly drag fields anywhere',
                    );
                  },
                ),
                // Save / Export button
                Padding(
                  padding: const EdgeInsets.only(right: 8, left: 4),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _onExportPressed,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
      body: Obx(() {
        if (!_c.hasDocument) {
          return _buildEmptyState();
        }
        return _buildEditorCanvas();
      }),
      bottomNavigationBar: Obx(() {
        if (!_c.hasDocument) return const BottomNativeAd();
        return _buildBottomToolbar();
      }),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1. EMPTY STATE
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing Form Icon
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _brandTeal.withValues(alpha: 0.2),
                    _accentOrange.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _brandTeal.withValues(alpha: 0.35),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _brandTeal.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.edit_document,
                size: 50,
                color: _brandTeal,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 20),
            const Text(
              'PDF Form Filler & Signer',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Fill in text blanks, checkboxes, checkmarks (✓),\ndates, and draw digital signatures effortlessly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 28),

            // Select PDF Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandTeal,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: _brandTeal.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _c.isPicking.value ? null : _c.pickPdfFile,
                icon: const Icon(Icons.folder_open_rounded, size: 22),
                label: const Text(
                  'Select PDF Document',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Features Grid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildFeatureRow(
                    icon: Icons.text_fields_rounded,
                    color: const Color(0xFF3B82F6),
                    title: 'Fill Text Anywhere',
                    desc: 'Type names, addresses, numbers with smooth drag & placement',
                  ),
                  const Divider(height: 18, color: Color(0xFFF1F5F9)),
                  _buildFeatureRow(
                    icon: Icons.check_circle_outline_rounded,
                    color: _brandTeal,
                    title: 'Checkmarks & Crosses',
                    desc: 'Easily place and position (✓) or (✕) in form boxes',
                  ),
                  const Divider(height: 18, color: Color(0xFFF1F5F9)),
                  _buildFeatureRow(
                    icon: Icons.draw_rounded,
                    color: const Color(0xFF8B5CF6),
                    title: 'Draw & Sign',
                    desc: 'Sign contracts & agreements with smooth handwritten digital signature',
                  ),
                  const Divider(height: 18, color: Color(0xFFF1F5F9)),
                  _buildFeatureRow(
                    icon: Icons.calendar_today_rounded,
                    color: _accentOrange,
                    title: 'Auto Date Stamp',
                    desc: 'Insert formatted date with a single tap and move into place',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2. EDITOR CANVAS & INTERACTION
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildEditorCanvas() {
    final pageIndex = _c.currentPageIndex.value;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        return Stack(
          children: [
            // Smooth Canvas without SingleChildScrollView conflict
            InteractiveViewer(
              transformationController: _transformController,
              panEnabled: _isPanZoomEnabled,
              scaleEnabled: _isPanZoomEnabled,
              boundaryMargin: const EdgeInsets.all(100),
              minScale: 0.6,
              maxScale: 3.5,
              child: SizedBox(
                width: availableWidth,
                height: availableHeight,
                child: Center(
                  child: FutureBuilder<Uint8List?>(
                    future: _c.renderPageImage(pageIndex,
                        targetWidth: availableWidth * 1.5),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return Container(
                          width: availableWidth - 32,
                          height: (availableWidth - 32) * 1.414,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: _brandTeal,
                            ),
                          ),
                        );
                      }

                      final imageBytes = snapshot.data;
                      if (imageBytes == null) {
                        return const Center(
                            child: Text('Failed to render page image'));
                      }

                      return FutureBuilder<Size>(
                        future: _c.getPageSize(pageIndex),
                        builder: (context, sizeSnapshot) {
                          final pageSize =
                              sizeSnapshot.data ?? const Size(595, 842);
                          final aspectRatio =
                              pageSize.width / pageSize.height;

                          // Compute optimal fit inside screen bounds
                          double displayWidth = availableWidth - 28;
                          double displayHeight = displayWidth / aspectRatio;

                          if (displayHeight > availableHeight - 32) {
                            displayHeight = availableHeight - 32;
                            displayWidth = displayHeight * aspectRatio;
                          }

                          _c.registerPageDisplaySize(
                              pageIndex, Size(displayWidth, displayHeight));

                          return GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              _c.selectItem(null);
                            },
                            child: Container(
                              width: displayWidth,
                              height: displayHeight,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.14),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // 1. Rendered PDF Background Image
                                  Image.memory(
                                    imageBytes,
                                    width: displayWidth,
                                    height: displayHeight,
                                    fit: BoxFit.fill,
                                  ),

                                  // 2. Interactive Overlay Elements for Current Page
                                  ..._buildOverlayElements(
                                      displayWidth, displayHeight),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

            // Mode Badge Pill (Edit vs Pan Mode)
            Positioned(
              top: 12,
              left: 16,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isPanZoomEnabled = !_isPanZoomEnabled;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isPanZoomEnabled
                        ? _accentOrange
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(
                      color: _isPanZoomEnabled
                          ? _accentOrange
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPanZoomEnabled
                            ? Icons.pan_tool_rounded
                            : Icons.touch_app_rounded,
                        size: 14,
                        color: _isPanZoomEnabled ? Colors.white : _brandTeal,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isPanZoomEnabled ? 'Zoom Mode' : 'Move/Edit Mode',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _isPanZoomEnabled
                              ? Colors.white
                              : _textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Page Nav Pill on Top-Right
            Positioned(
              top: 12,
              right: 16,
              child: _buildPageJumpPill(),
            ),

            // Quick Element Properties Bar (Floating above when an item is selected)
            Obx(() {
              final sel = _c.selectedItem;
              if (sel == null || sel.pageIndex != _c.currentPageIndex.value) {
                return const SizedBox.shrink();
              }
              return Positioned(
                bottom: 12,
                left: 16,
                right: 16,
                child: Center(
                  child: _buildElementPropertiesBar(sel),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 3. ULTRA-SMOOTH OVERLAY ELEMENTS (DRAGGABLE & RESIZABLE)
  // ════════════════════════════════════════════════════════════════════════════
  List<Widget> _buildOverlayElements(
      double canvasWidth, double canvasHeight) {
    final pageIndex = _c.currentPageIndex.value;
    final items = _c.fillItems.where((e) => e.pageIndex == pageIndex).toList();

    return items.map((item) {
      final isSelected = _c.selectedItemId.value == item.id;

      return _DraggableOverlayItem(
        key: ValueKey(item.id),
        item: item,
        isSelected: isSelected,
        canvasWidth: canvasWidth,
        canvasHeight: canvasHeight,
        isPanZoomActive: _isPanZoomEnabled,
        onSelect: () => _c.selectItem(item.id),
        onDoubleTap: () {
          if (item.type == PdfFillType.text || item.type == PdfFillType.date) {
            _showTextEditDialog(item);
          }
        },
        onPositionChanged: (newPos) {
          _c.updateItemPosition(item.id, newPos);
        },
        onPositionCommit: () {
          _c.commitItemPosition(item.id);
        },
        onSizeChanged: (w, h) {
          _c.updateItemSize(item.id, w, h);
        },
        onSizeCommit: () {
          _c.commitItemSize(item.id);
        },
      );
    }).toList();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 4. QUICK ELEMENT PROPERTIES BAR
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildElementPropertiesBar(PdfFillItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edit Text action
            if (item.type == PdfFillType.text || item.type == PdfFillType.date)
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18, color: _textPrimary),
                tooltip: 'Edit Text',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                onPressed: () => _showTextEditDialog(item),
              ),

            // Decrease Font Size
            if (item.type != PdfFillType.signature) ...[
              IconButton(
                icon: const Icon(Icons.remove_rounded,
                    size: 16, color: _textPrimary),
                tooltip: 'Smaller',
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                onPressed: () =>
                    _c.updateItemFontSize(item.id, item.fontSize - 2),
              ),
              Text(
                '${item.fontSize.toInt()}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary),
              ),
              IconButton(
                icon:
                    const Icon(Icons.add_rounded, size: 16, color: _textPrimary),
                tooltip: 'Larger',
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                onPressed: () =>
                    _c.updateItemFontSize(item.id, item.fontSize + 2),
              ),
              const SizedBox(width: 4),
              // Bold toggle
              InkWell(
                onTap: () => _c.toggleItemBold(item.id),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: item.isBold
                        ? _brandTeal.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.format_bold_rounded,
                    size: 18,
                    color: item.isBold ? _brandTeal : _textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],

            // Color Picker Quick Dot
            _buildColorDot(item, Colors.black),
            _buildColorDot(item, const Color(0xFF1D4ED8)), // Blue
            _buildColorDot(item, const Color(0xFFDC2626)), // Red
            _buildColorDot(item, const Color(0xFF0D9488)), // Teal

            const SizedBox(width: 6),
            const SizedBox(
              height: 20,
              child: VerticalDivider(
                  width: 8, thickness: 1, color: Color(0xFFE2E8F0)),
            ),

            // Duplicate
            IconButton(
              icon: const Icon(Icons.copy_rounded,
                  size: 16, color: _textSecondary),
              tooltip: 'Duplicate',
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              onPressed: () => _c.duplicateItem(item.id),
            ),

            // Delete
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: Color(0xFFEF4444)),
              tooltip: 'Delete',
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              onPressed: () => _c.deleteItem(item.id),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 180.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildColorDot(PdfFillItem item, Color col) {
    final isSel = item.color == col;
    return GestureDetector(
      onTap: () => _c.updateItemColor(item.id, col),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: col,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSel ? _brandTeal : Colors.black12,
            width: isSel ? 2.5 : 1,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 5. BOTTOM TOOLS DOCK
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildBottomToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row of Tools
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildToolButton(
                  icon: Icons.text_fields_rounded,
                  label: 'Text',
                  color: const Color(0xFF3B82F6),
                  onTap: () => _c.addTextField(),
                ),
                _buildToolButton(
                  icon: Icons.check_rounded,
                  label: 'Check',
                  color: const Color(0xFF0D9488),
                  onTap: () => _c.addCheckmark(),
                ),
                _buildToolButton(
                  icon: Icons.close_rounded,
                  label: 'Cross',
                  color: const Color(0xFFDC2626),
                  onTap: () => _c.addCross(),
                ),
                _buildToolButton(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  color: _accentOrange,
                  onTap: _showDatePickerDialog,
                ),
                _buildToolButton(
                  icon: Icons.draw_rounded,
                  label: 'Signature',
                  color: const Color(0xFF8B5CF6),
                  onTap: _showSignaturePadDialog,
                ),
                _buildToolButton(
                  icon: Icons.circle,
                  label: 'Dot',
                  color: const Color(0xFF475569),
                  onTap: () => _c.addRadioDot(),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Page Navigation Strip (< Page 1 of 4 >)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Clear Page Button
                TextButton.icon(
                  onPressed: _c.clearCurrentPage,
                  icon: const Icon(Icons.clear_all_rounded,
                      size: 16, color: Color(0xFFEF4444)),
                  label: const Text(
                    'Clear Page',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Page Switcher
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 24),
                      onPressed: _c.currentPageIndex.value > 0
                          ? () {
                              _c.selectItem(null);
                              _c.currentPageIndex.value--;
                            }
                          : null,
                    ),
                    Text(
                      'Page ${_c.currentPageIndex.value + 1} / ${_c.pageCount.value}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 24),
                      onPressed: _c.currentPageIndex.value <
                              _c.pageCount.value - 1
                          ? () {
                              _c.selectItem(null);
                              _c.currentPageIndex.value++;
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        // Ensure edit mode is active when tapping a tool
        if (_isPanZoomEnabled) {
          setState(() {
            _isPanZoomEnabled = false;
          });
        }
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _textPrimary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageJumpPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pages_rounded, size: 14, color: _brandTeal),
          const SizedBox(width: 4),
          Text(
            '${_c.currentPageIndex.value + 1}/${_c.pageCount.value}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 6. DIALOGS (TEXT EDIT, DATE PICKER, SIGNATURE PAD)
  // ════════════════════════════════════════════════════════════════════════════
  void _showTextEditDialog(PdfFillItem item) {
    final textController = TextEditingController(text: item.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Edit Field Text',
          style: TextStyle(
              color: _textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(color: _textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter text...',
            hintStyle: const TextStyle(color: _textSecondary),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              _c.updateItemText(item.id, textController.text);
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDatePickerDialog() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _brandTeal,
              onPrimary: Colors.white,
              onSurface: _textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      _c.addDateStamp(customDate: formatted);
    }
  }

  void _showSignaturePadDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SignaturePadSheet(
        onSignatureSaved: (bytes) {
          _c.addSignature(bytes);
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 7. EXPORT & SHARE FLOW
  // ════════════════════════════════════════════════════════════════════════════
  Future<void> _onExportPressed() async {
    // Show saving dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: Obx(() {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const CircularProgressIndicator(
                  strokeWidth: 3,
                  color: _brandTeal,
                ),
                const SizedBox(height: 18),
                Text(
                  _c.exportStatus.value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _c.exportProgress.value,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(_brandTeal),
                ),
              ],
            );
          }),
        ),
      ),
    );

    final result = await _c.exportFilledPdf();
    if (mounted) Navigator.pop(context); // Close loading dialog

    if (result != null) {
      _showExportSuccessSheet(result);
    }
  }

  void _showExportSuccessSheet(String filePath) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _brandTeal.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: _brandTeal, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Filled PDF Ready!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'All fields, checkmarks and signatures have been permanently flattened onto the document.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _c.shareFilledPdf();
                    },
                    icon: const Icon(Icons.share_rounded, size: 20),
                    label: const Text(
                      'Share PDF',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 8. DEDICATED ULTRA-SMOOTH DRAGGABLE & RESIZABLE OVERLAY ITEM
// ══════════════════════════════════════════════════════════════════════════════
class _DraggableOverlayItem extends StatefulWidget {
  final PdfFillItem item;
  final bool isSelected;
  final double canvasWidth;
  final double canvasHeight;
  final bool isPanZoomActive;
  final VoidCallback onSelect;
  final VoidCallback onDoubleTap;
  final Function(Offset) onPositionChanged;
  final VoidCallback onPositionCommit;
  final Function(double, double) onSizeChanged;
  final VoidCallback onSizeCommit;

  const _DraggableOverlayItem({
    super.key,
    required this.item,
    required this.isSelected,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.isPanZoomActive,
    required this.onSelect,
    required this.onDoubleTap,
    required this.onPositionChanged,
    required this.onPositionCommit,
    required this.onSizeChanged,
    required this.onSizeCommit,
  });

  @override
  State<_DraggableOverlayItem> createState() => _DraggableOverlayItemState();
}

class _DraggableOverlayItemState extends State<_DraggableOverlayItem> {
  late Offset _pos;
  late double _width;
  late double _height;
  bool _isDragging = false;
  bool _isResizing = false;

  @override
  void initState() {
    super.initState();
    _pos = widget.item.position;
    _width = widget.item.width;
    _height = widget.item.height;
  }

  @override
  void didUpdateWidget(covariant _DraggableOverlayItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      _pos = widget.item.position;
    }
    if (!_isResizing) {
      _width = widget.item.width;
      _height = widget.item.height;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    // Minimum touch area for checkmark, dot, cross so finger can easily grab it
    final touchWidth = _width.clamp(36.0, widget.canvasWidth);
    final touchHeight = _height.clamp(32.0, widget.canvasHeight);

    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.onSelect();
        },
        onDoubleTap: widget.onDoubleTap,
        onPanStart: widget.isPanZoomActive
            ? null
            : (details) {
                widget.onSelect();
                setState(() {
                  _isDragging = true;
                });
              },
        onPanUpdate: widget.isPanZoomActive
            ? null
            : (details) {
                final maxX = widget.canvasWidth - 20;
                final maxY = widget.canvasHeight - 20;

                final newX = (_pos.dx + details.delta.dx).clamp(0.0, maxX);
                final newY = (_pos.dy + details.delta.dy).clamp(0.0, maxY);

                setState(() {
                  _pos = Offset(newX, newY);
                });
                widget.onPositionChanged(_pos);
              },
        onPanEnd: widget.isPanZoomActive
            ? null
            : (details) {
                setState(() {
                  _isDragging = false;
                });
                widget.onPositionCommit();
              },
        onPanCancel: () {
          setState(() {
            _isDragging = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: touchWidth,
          height: touchHeight,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0D9488).withValues(alpha: 0.12)
                : Colors.transparent,
            border: isSelected
                ? Border.all(color: const Color(0xFF0D9488), width: 1.8)
                : Border.all(
                    color: Colors.black.withValues(alpha: 0.08), width: 0.8),
            borderRadius: BorderRadius.circular(6),
            boxShadow: _isDragging
                ? [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Content
              Center(
                child: _buildItemContent(widget.item),
              ),

              // Move Grip Handle (Top-Left corner indicator when selected)
              if (isSelected)
                Positioned(
                  top: -8,
                  left: -8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D9488),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.drag_indicator_rounded,
                        color: Colors.white, size: 12),
                  ),
                ),

              // Corner Resize Handle (Bottom-Right corner when selected)
              if (isSelected)
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) {
                      setState(() {
                        _isResizing = true;
                      });
                    },
                    onPanUpdate: (details) {
                      final newW = (_width + details.delta.dx).clamp(24.0, 500.0);
                      final newH = (_height + details.delta.dy).clamp(20.0, 500.0);
                      setState(() {
                        _width = newW;
                        _height = newH;
                      });
                      widget.onSizeChanged(newW, newH);
                    },
                    onPanEnd: (details) {
                      setState(() {
                        _isResizing = false;
                      });
                      widget.onSizeCommit();
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.open_in_full_rounded,
                          color: Colors.white, size: 10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemContent(PdfFillItem item) {
    if (item.type == PdfFillType.signature && item.signaturePngBytes != null) {
      return Image.memory(
        item.signaturePngBytes!,
        fit: BoxFit.contain,
      );
    }

    return Text(
      item.text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: item.color,
        fontSize: item.fontSize,
        fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: item.isItalic ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 9. SIGNATURE PAD BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _SignaturePadSheet extends StatefulWidget {
  final void Function(Uint8List) onSignatureSaved;
  const _SignaturePadSheet({required this.onSignatureSaved});

  @override
  State<_SignaturePadSheet> createState() => _SignaturePadSheetState();
}

class _SignaturePadSheetState extends State<_SignaturePadSheet> {
  final List<List<Offset>> _strokes = [];
  Color _strokeColor = const Color(0xFF1E293B);
  static const double _strokeWidth = 3.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Draw Signature',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1D2E),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Color & Stroke controls
          Row(
            children: [
              _buildColorChip(const Color(0xFF1E293B), 'Black'),
              const SizedBox(width: 8),
              _buildColorChip(const Color(0xFF1D4ED8), 'Blue'),
              const SizedBox(width: 8),
              _buildColorChip(const Color(0xFFDC2626), 'Red'),
              const Spacer(),
              TextButton.icon(
                onPressed: _strokes.isEmpty
                    ? null
                    : () {
                        setState(() {
                          _strokes.clear();
                        });
                      },
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: Color(0xFFEF4444)),
                label: const Text(
                  'Clear',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Signature Canvas Box
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFCBD5E1),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Signature Line indicator
                  Positioned(
                    bottom: 40,
                    left: 24,
                    right: 24,
                    child: Container(
                      height: 1.5,
                      color: const Color(0xFFCBD5E1),
                    ),
                  ),
                  Positioned(
                    bottom: 18,
                    left: 24,
                    child: Text(
                      'Sign above the line',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Gesture area
                  GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        _strokes.add([details.localPosition]);
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        if (_strokes.isNotEmpty) {
                          _strokes.last.add(details.localPosition);
                        }
                      });
                    },
                    child: CustomPaint(
                      painter: _SignaturePainter(
                        strokes: _strokes,
                        color: _strokeColor,
                        strokeWidth: _strokeWidth,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Place Signature Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _strokes.isEmpty ? null : _saveAndApplySignature,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text(
                'Place Signature on PDF',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorChip(Color color, String label) {
    final isSel = _strokeColor == color;
    return GestureDetector(
      onTap: () => setState(() => _strokeColor = color),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSel ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAndApplySignature() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(400, 220);

    final painter = _SignaturePainter(
      strokes: _strokes,
      color: _strokeColor,
      strokeWidth: _strokeWidth * 1.5,
    );
    painter.paint(canvas, size);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      widget.onSignatureSaved(byteData.buffer.asUint8List());
      if (mounted) Navigator.pop(context);
    }
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;

  _SignaturePainter({
    required this.strokes,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
