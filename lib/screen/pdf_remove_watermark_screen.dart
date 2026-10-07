// lib/screen/pdf_remove_watermark_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../ads/widget/bottom_native_ad.dart';
import '../controllers/pdf_remove_watermark_controller.dart';
import '../helper/my_dialogs.dart';

class PdfRemoveWatermarkScreen extends StatefulWidget {
  final String? initialPdfPath;
  const PdfRemoveWatermarkScreen({super.key, this.initialPdfPath});

  @override
  State<PdfRemoveWatermarkScreen> createState() =>
      _PdfRemoveWatermarkScreenState();
}

class _PdfRemoveWatermarkScreenState extends State<PdfRemoveWatermarkScreen> {
  final PdfRemoveWatermarkController _c =
      Get.put(PdfRemoveWatermarkController());

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _brandPurple = Color(0xFF7C3AED);
  static const Color _brandPink = Color(0xFFEC4899);
  static const Color _brandRose = Color(0xFFF43F5E);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _textPrimary, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_drop_rounded, color: _brandRose, size: 22),
            SizedBox(width: 8),
            Text(
              'Remove Watermark',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Obx(() {
            if (!_c.hasDocument) return const SizedBox.shrink();
            return TextButton.icon(
              onPressed: _c.isExporting.value ? null : _c.pickPdfFile,
              icon: const Icon(Icons.folder_open_rounded,
                  size: 18, color: _brandPurple),
              label: const Text(
                'Change',
                style: TextStyle(
                  color: _brandPurple,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        if (_c.isPicking.value) {
          return const Center(
            child: CircularProgressIndicator(color: _brandRose),
          );
        }
        if (!_c.hasDocument) {
          return _buildEmptyState();
        }
        return _buildWatermarkWorkspace();
      }),
      bottomNavigationBar: Obx(() {
        if (!_c.hasDocument || _c.isExporting.value) {
          return const BottomNativeAd();
        }
        return _buildBottomActionToolbar();
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
            // Glowing Hero Icon
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _brandRose.withValues(alpha: 0.18),
                    _brandPurple.withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _brandRose.withValues(alpha: 0.35),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _brandRose.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.water_drop_rounded,
                size: 52,
                color: _brandRose,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Remove PDF Watermark',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Erase CamScanner branding, draft logos, confidential stamps\nand unwanted text watermarks cleanly across all pages.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 32),

            // Select PDF Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _c.pickPdfFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandRose,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: _brandRose.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 22),
                label: const Text(
                  'Select PDF to Clean',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Highlights
            _buildFeaturePill(
              icon: Icons.cleaning_services_rounded,
              title: '1-Tap CamScanner & Footer Remover',
              subtitle: 'Instantly clean bottom scanner bands across all pages',
            ),
            const SizedBox(height: 12),
            _buildFeaturePill(
              icon: Icons.filter_center_focus_rounded,
              title: 'Center Diagonal Watermark Remover',
              subtitle: 'Erase large draft or confidential watermark stamps',
            ),
            const SizedBox(height: 12),
            _buildFeaturePill(
              icon: Icons.auto_awesome_rounded,
              title: 'AI Smart Auto-Detection',
              subtitle: 'Detects watermark keywords and targets them automatically',
            ),
            const SizedBox(height: 12),
            _buildFeaturePill(
              icon: Icons.layers_rounded,
              title: 'Batch Apply to All Pages',
              subtitle: 'Set once, removes from every page in the entire document',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePill({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _brandRose.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _brandRose, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2. WATERMARK CLEANING WORKSPACE
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildWatermarkWorkspace() {
    return Column(
      children: [
        // Top Document Header Bar
        _buildDocumentHeaderBar(),

        // Page Navigator & Presets Strip
        _buildPageNavigatorAndPresets(),

        // Main Document Canvas
        Expanded(
          child: Container(
            color: const Color(0xFF1E293B),
            child: Center(
              child: Obx(() {
                if (_c.isRenderingPage.value ||
                    _c.currentPageBytes.value == null) {
                  return const CircularProgressIndicator(color: _brandRose);
                }
                return _buildInteractivePageCanvas();
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _c.selectedPdfName.value ?? 'document.pdf',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  '${_c.pageCount.value} Pages • ${_c.eraseBoxes.length} Erase Zone(s)',
                  style: const TextStyle(fontSize: 11, color: _textSecondary),
                ),
              ],
            ),
          ),

          // Live Preview Toggle
          Obx(() {
            final isClean = _c.isLivePreviewClean.value;
            return GestureDetector(
              onTap: () => _c.isLivePreviewClean.value = !isClean,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isClean
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      isClean
                          ? Icons.visibility_rounded
                          : Icons.visibility_outlined,
                      size: 14,
                      color: isClean ? Colors.white : const Color(0xFF475569),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isClean ? 'Clean Preview' : 'Show Boxes',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isClean ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(width: 8),

          // Undo
          IconButton(
            onPressed: _c.canUndo ? _c.undo : null,
            icon: const Icon(Icons.undo_rounded, size: 20),
            color:
                _c.canUndo ? _textPrimary : Colors.grey.withValues(alpha: 0.4),
            tooltip: 'Undo',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
          const SizedBox(width: 4),

          // Redo
          IconButton(
            onPressed: _c.canRedo ? _c.redo : null,
            icon: const Icon(Icons.redo_rounded, size: 20),
            color:
                _c.canRedo ? _textPrimary : Colors.grey.withValues(alpha: 0.4),
            tooltip: 'Redo',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
          const SizedBox(width: 6),

          // Clear All
          IconButton(
            onPressed: _c.clearAllBoxes,
            icon: const Icon(Icons.delete_sweep_rounded, size: 20),
            color: const Color(0xFFEF4444),
            tooltip: 'Clear All Erase Boxes',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
        ],
      ),
    );
  }

  Widget _buildPageNavigatorAndPresets() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
        ),
      ),
      child: Column(
        children: [
          // Navigator Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _c.currentPageIndex.value > 0
                    ? () => _c.goToPage(_c.currentPageIndex.value - 1)
                    : null,
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Row(
                children: [
                  const Icon(Icons.menu_book_rounded,
                      size: 15, color: _brandRose),
                  const SizedBox(width: 6),
                  Text(
                    'Page ${_c.currentPageIndex.value + 1} of ${_c.pageCount.value}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _c.currentPageIndex.value < _c.pageCount.value - 1
                    ? () => _c.goToPage(_c.currentPageIndex.value + 1)
                    : null,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Quick 1-Tap Presets Strip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetChip(
                  icon: Icons.border_bottom_rounded,
                  label: 'CamScanner / Footer',
                  onTap: _c.addFooterWatermarkPreset,
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  icon: Icons.crop_portrait_rounded,
                  label: 'Center Diagonal',
                  onTap: _c.addCenterWatermarkPreset,
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  icon: Icons.border_top_rounded,
                  label: 'Header Stamp',
                  onTap: _c.addHeaderWatermarkPreset,
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  icon: Icons.auto_fix_high_rounded,
                  label: 'AI Auto-Detect',
                  color: _brandPurple,
                  onTap: () => _c.autoDetectWatermarks(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFF0F172A),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractivePageCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double contW = constraints.maxWidth - 24;
        final double contH = constraints.maxHeight - 24;

        final double docW = _c.currentPageWidth.value;
        final double docH = _c.currentPageHeight.value;
        final double docAspect = docW / docH;
        final double contAspect = contW / contH;

        double renderedW;
        double renderedH;

        if (contAspect > docAspect) {
          renderedH = contH;
          renderedW = contH * docAspect;
        } else {
          renderedW = contW;
          renderedH = contW / docAspect;
        }

        final double scaleX = renderedW / docW;
        final double scaleY = renderedH / docH;

        final pageIndex = _c.currentPageIndex.value;
        final boxesOnThisPage = _c.eraseBoxes
            .where((e) => e.applyToAllPages || e.pageIndex == pageIndex)
            .toList();

        return GestureDetector(
          onTap: () => _c.selectBox(null),
          child: Container(
            width: renderedW,
            height: renderedH,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Base PDF Page Image
                Positioned.fill(
                  child: Image.memory(
                    _c.currentPageBytes.value!,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                  ),
                ),

                // Erase Boxes
                for (final item in boxesOnThisPage)
                  _buildEraseBoxWidget(
                    item: item,
                    scaleX: scaleX,
                    scaleY: scaleY,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEraseBoxWidget({
    required WatermarkEraseBox item,
    required double scaleX,
    required double scaleY,
  }) {
    final isSelected = _c.selectedBoxId.value == item.id;
    final isCleanPreview = _c.isLivePreviewClean.value;

    final l = item.rect.left * scaleX;
    final t = item.rect.top * scaleY;
    final w = item.rect.width * scaleX;
    final h = item.rect.height * scaleY;

    if (isCleanPreview) {
      // Live clean preview: draws solid background to hide the watermark seamlessly
      return Positioned(
        left: l,
        top: t,
        width: w,
        height: h,
        child: Container(color: item.fillColor),
      );
    }

    return Positioned(
      left: l,
      top: t,
      width: w,
      height: h,
      child: GestureDetector(
        onTap: () => _c.selectBox(item.id),
        onPanUpdate: (details) {
          final newDx = item.rect.left + (details.delta.dx / scaleX);
          final newDy = item.rect.top + (details.delta.dy / scaleY);
          _c.updateBoxPosition(item.id, Offset(newDx, newDy));
        },
        onPanEnd: (_) => _c.commitBoxPosition(item.id),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Erase Box Highlight
            Container(
              decoration: BoxDecoration(
                color: item.fillColor.withValues(alpha: 0.65),
                border: Border.all(
                  color: isSelected ? _brandRose : const Color(0xFFEF4444),
                  width: isSelected ? 2.0 : 1.2,
                ),
              ),
              child: Center(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade900,
                  ),
                ),
              ),
            ),

            // Controls when selected
            if (isSelected) ...[
              // Floating Action Capsule Above Box
              Positioned(
                top: -36,
                left: 0,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF0F172A),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Toggle all pages
                      InkWell(
                        onTap: () => _c.toggleApplyToAllPages(item.id),
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                item.applyToAllPages
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                size: 14,
                                color: item.applyToAllPages
                                    ? const Color(0xFF10B981)
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.applyToAllPages
                                    ? 'All Pages'
                                    : 'This Page',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(width: 1, height: 16, color: Colors.white24),
                      // Delete
                      InkWell(
                        onTap: () => _c.deleteBox(item.id),
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(10)),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: Icon(Icons.delete_outline_rounded,
                              size: 15, color: Color(0xFFF87171)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Corner Resize Handle
              Positioned(
                right: -10,
                bottom: -10,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    final newW = item.rect.width + (details.delta.dx / scaleX);
                    final newH =
                        item.rect.height + (details.delta.dy / scaleY);
                    _c.updateBoxSize(item.id, newW, newH);
                  },
                  onPanEnd: (_) => _c.commitBoxSize(item.id),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _brandRose,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: const Icon(
                      Icons.aspect_ratio_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 3. BOTTOM ACTION TOOLBAR
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildBottomActionToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
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
        top: false,
        child: Row(
          children: [
            // Add Custom Box Tool
            _buildToolbarIconBtn(
              icon: Icons.crop_free_rounded,
              label: 'Add Box',
              color: const Color(0xFF475569),
              onTap: _c.addCustomBox,
            ),
            const SizedBox(width: 8),

            // AI Keyword search dialog
            _buildToolbarIconBtn(
              icon: Icons.search_rounded,
              label: 'Search Word',
              color: _brandPurple,
              onTap: _showKeywordSearchDialog,
            ),
            const SizedBox(width: 12),

            // Export Clean PDF Button
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _handleExportCleanPdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandRose,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.cleaning_services_rounded, size: 20),
                  label: const Text(
                    'Remove & Save PDF',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarIconBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showKeywordSearchDialog() {
    final textC = TextEditingController();
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.search_rounded, color: _brandPurple),
            SizedBox(width: 8),
            Text('Auto-Detect Keyword',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter watermark word to detect & target (e.g. CamScanner, Draft, Sample):',
              style: TextStyle(fontSize: 12, color: _textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textC,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. CamScanner',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Get.back();
              _c.autoDetectWatermarks(customKeyword: textC.text.trim());
            },
            child: const Text('Find & Erase'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExportCleanPdf() async {
    final cleanPath = await _c.exportWatermarkFreePdf();
    if (cleanPath != null) {
      _showExportSuccessModal(cleanPath);
    }
  }

  void _showExportSuccessModal(String cleanPath) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF10B981),
                  size: 40,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Watermark Removed Successfully!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'All selected watermarks have been permanently erased and your PDF document is clean.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: _textSecondary, height: 1.4),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _brandRose,
                        side: const BorderSide(color: _brandRose),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Get.back();
                        MyDialogs.success(msg: 'Saved to $cleanPath');
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Done'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandRose,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _c.shareCleanPdf(cleanPath),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share PDF'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
