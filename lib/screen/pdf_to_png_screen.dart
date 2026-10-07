// lib/screen/pdf_to_png_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../ads/widget/bottom_native_ad.dart';
import '../controllers/pdf_to_png_controller.dart';

class PdfToPngScreen extends StatefulWidget {
  final String? initialPdfPath;
  final String? initialPdfName;

  const PdfToPngScreen({
    super.key,
    this.initialPdfPath,
    this.initialPdfName,
  });

  @override
  State<PdfToPngScreen> createState() => _PdfToPngScreenState();
}

class _PdfToPngScreenState extends State<PdfToPngScreen> {
  final PdfToPngController _c = Get.put(PdfToPngController());

  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _textPrimary = Color(0xFF1A1D2E);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _brandOrange = Color(0xFFFD8838);
  static const Color _brandDeepOrange = Color(0xFFFF6B4A);
  static const Color _accentTeal = Color(0xFF0D9488);
  static const Color _accentGreen = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    if (widget.initialPdfPath != null && widget.initialPdfPath!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _c.loadPdf(widget.initialPdfPath!, fileName: widget.initialPdfName);
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
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _textPrimary, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_rounded, color: _brandOrange, size: 24),
            SizedBox(width: 8),
            Text(
              'PDF to PNG Converter',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Obx(() {
            if (_c.selectedPdfPath.value == null) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _brandOrange),
              tooltip: 'Reset',
              onPressed: _c.isConverting.value ? null : _c.reset,
            );
          }),
          const SizedBox(width: 4),
        ],
      ),
      body: Obx(() {
        if (_c.isPicking.value || _c.isLoadingDoc.value) {
          return _buildLoadingState();
        }
        if (_c.selectedPdfPath.value == null) {
          return _buildEmptyPickerState();
        }
        if (_c.convertedImages.isNotEmpty && !_c.isConverting.value) {
          return _buildResultsView();
        }
        return _buildWorkspace();
      }),
      bottomNavigationBar: Obx(() {
        if (_c.selectedPdfPath.value == null ||
            _c.convertedImages.isNotEmpty ||
            _c.isConverting.value) {
          return const BottomNativeAd();
        }
        return _buildBottomConvertBar();
      }),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1. EMPTY / PICKER STATE
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildEmptyPickerState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _brandOrange.withValues(alpha: 0.2),
                    _brandDeepOrange.withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _brandOrange.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                size: 50,
                color: _brandOrange,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 24),

            const Text(
              'Convert PDF to Crisp PNG Images',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Render all or selected PDF pages to high-resolution PNGs with customizable DPI and transparent background support.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 32),

            // Pick Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _c.pickPdfFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandOrange,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: _brandOrange.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.upload_file_rounded, size: 22),
                label: const Text(
                  'Select PDF Document',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ).animate().slideY(begin: 0.15, duration: 350.ms),

            const SizedBox(height: 28),

            // Feature Highlights Grid
            Row(
              children: [
                _buildFeatureBadge(
                  icon: Icons.high_quality_rounded,
                  title: 'Lossless PNG',
                  desc: 'Up to 600 DPI',
                ),
                const SizedBox(width: 12),
                _buildFeatureBadge(
                  icon: Icons.select_all_rounded,
                  title: 'Page Selection',
                  desc: 'All, range, or custom',
                ),
                const SizedBox(width: 12),
                _buildFeatureBadge(
                  icon: Icons.folder_zip_rounded,
                  title: 'ZIP Export',
                  desc: '1-tap archive bundle',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBadge({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: _brandOrange, size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _brandOrange, strokeWidth: 3),
          SizedBox(height: 16),
          Text(
            'Reading PDF document...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2. CONFIGURATION WORKSPACE
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildWorkspace() {
    if (_c.isConverting.value) {
      return _buildConversionProgressOverlay();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── PDF File Card ────────────────────────────────────────────────
          _buildDocumentSummaryCard(),

          const SizedBox(height: 16),

          // ── Page Selection Mode ──────────────────────────────────────────
          _buildPageSelectionSection(),

          const SizedBox(height: 16),

          // ── Quality / DPI & Options ──────────────────────────────────────
          _buildSettingsCard(),
        ],
      ),
    );
  }

  Widget _buildDocumentSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _brandOrange.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _brandOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: _brandOrange, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _c.selectedPdfName.value ?? 'Document.pdf',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_c.pageCount.value} Pages',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _c.formattedPdfSize,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _c.pickPdfFile,
            style: TextButton.styleFrom(
              foregroundColor: _brandOrange,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text(
              'Change',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageSelectionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.layers_rounded, color: _brandOrange, size: 20),
              SizedBox(width: 8),
              Text(
                'Page Selection',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Selection Mode Segmented Chips
          Row(
            children: [
              _buildSelectionTab(
                mode: PageSelectionMode.all,
                label: 'All Pages (${_c.pageCount.value})',
              ),
              const SizedBox(width: 8),
              _buildSelectionTab(
                mode: PageSelectionMode.custom,
                label: 'Select Pages',
              ),
              const SizedBox(width: 8),
              _buildSelectionTab(
                mode: PageSelectionMode.range,
                label: 'Range',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Mode Body
          if (_c.selectionMode.value == PageSelectionMode.all) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _brandOrange.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: _brandOrange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All ${_c.pageCount.value} pages will be rendered as separate PNG images.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_c.selectionMode.value == PageSelectionMode.custom) ...[
            _buildCustomPageGrid(),
          ] else if (_c.selectionMode.value == PageSelectionMode.range) ...[
            _buildPageRangeControls(),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectionTab({
    required PageSelectionMode mode,
    required String label,
  }) {
    final isSelected = _c.selectionMode.value == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _c.selectionMode.value = mode,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _brandOrange : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _brandOrange.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : _textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomPageGrid() {
    final count = _c.pageCount.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Selected: ${_c.selectedPages.length} of $count pages',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: _c.selectAllPages,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: _brandOrange,
                  ),
                  child: const Text('Select All',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _c.deselectAllPages,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: Colors.grey.shade600,
                  ),
                  child: const Text('Clear',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: count,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final isChecked = _c.selectedPages.contains(index);
              final thumb = _c.pageThumbnails[index];

              return GestureDetector(
                onTap: () => _c.togglePageSelection(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 96,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isChecked ? _brandOrange : Colors.grey.shade300,
                      width: isChecked ? 2 : 1,
                    ),
                    boxShadow: isChecked
                        ? [
                            BoxShadow(
                              color: _brandOrange.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Stack(
                    children: [
                      // Thumbnail
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: thumb != null
                              ? Image.memory(thumb, fit: BoxFit.cover)
                              : Container(
                                  color: Colors.white,
                                  child: const Center(
                                    child: Icon(Icons.article_outlined,
                                        color: Colors.grey, size: 28),
                                  ),
                                ),
                        ),
                      ),

                      // Selection overlay
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isChecked ? _brandOrange : Colors.white70,
                            border: Border.all(
                              color: isChecked ? _brandOrange : Colors.grey,
                              width: 1.5,
                            ),
                          ),
                          child: isChecked
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                      ),

                      // Page tag
                      Positioned(
                        bottom: 6,
                        left: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Page ${index + 1}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPageRangeControls() {
    final count = _c.pageCount.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('From Page',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_c.rangeStart.value}',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _c.rangeStart.value > 1
                                  ? () => _c.setRange(_c.rangeStart.value - 1, _c.rangeEnd.value)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _c.rangeStart.value < _c.rangeEnd.value
                                  ? () => _c.setRange(_c.rangeStart.value + 1, _c.rangeEnd.value)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('To Page',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_c.rangeEnd.value}',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _c.rangeEnd.value > _c.rangeStart.value
                                  ? () => _c.setRange(_c.rangeStart.value, _c.rangeEnd.value - 1)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _c.rangeEnd.value < count
                                  ? () => _c.setRange(_c.rangeStart.value, _c.rangeEnd.value + 1)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Pages to convert: ${_c.rangeStart.value} to ${_c.rangeEnd.value} (${_c.effectiveSelectedCount} pages)',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _brandOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: _brandOrange, size: 20),
              SizedBox(width: 8),
              Text(
                'Resolution & Output Quality',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Presets
          ...PngResolutionPreset.values.map((preset) {
            final isSelected = _c.resolutionPreset.value == preset;
            return GestureDetector(
              onTap: () => _c.resolutionPreset.value = preset,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _brandOrange.withValues(alpha: 0.08)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _brandOrange : Colors.grey.shade200,
                    width: isSelected ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Radio<PngResolutionPreset>(
                      value: preset,
                      groupValue: _c.resolutionPreset.value,
                      activeColor: _brandOrange,
                      onChanged: (val) {
                        if (val != null) _c.resolutionPreset.value = val;
                      },
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                preset.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                              ),
                              if (preset == PngResolutionPreset.high300) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: _accentTeal.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Popular',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _accentTeal,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            preset.subtitle,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const Divider(height: 24),

          // Transparent Background Switch
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.opacity_rounded,
                    color: _textPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transparent Background',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      'Preserve PNG alpha channel (great for graphics/stamps)',
                      style: TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _c.isTransparentBackground.value,
                activeTrackColor: _brandOrange,
                onChanged: (val) => _c.isTransparentBackground.value = val,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomConvertBar() {
    final count = _c.effectiveSelectedCount;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: count > 0 ? _c.convertPdfToPng : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandOrange,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: _brandOrange.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.auto_fix_high_rounded, size: 20),
              label: Text(
                'Convert to PNG ($count ${count == 1 ? 'Page' : 'Pages'})',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 3. CONVERSION PROGRESS OVERLAY
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildConversionProgressOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: CircularProgressIndicator(
                    value: _c.conversionProgress.value,
                    color: _brandOrange,
                    backgroundColor: Colors.grey.shade200,
                    strokeWidth: 6,
                  ),
                ),
                Text(
                  '${(_c.conversionProgress.value * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _brandOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Rendering High-Definition PNG...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _c.statusMessage.value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _c.cancelConversion,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Cancel Conversion'),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 4. RESULTS & GALLERY VIEW
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildResultsView() {
    final images = _c.convertedImages;
    final totalSize = images.fold<int>(0, (sum, item) => sum + item.fileSizeInBytes);
    final formattedTotalSize = totalSize < 1024 * 1024
        ? '${(totalSize / 1024).toStringAsFixed(1)} KB'
        : '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';

    return Column(
      children: [
        // ── Top Action & Summary Banner ────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _accentGreen.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: _accentGreen, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${images.length} PNG Images Ready',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          Text(
                            'Total $formattedTotalSize • ${_c.resolutionPreset.value.tag}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _c.convertedImages.clear(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _brandOrange,
                      side: const BorderSide(color: _brandOrange),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Reconfigure', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Batch Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _c.shareAllImages,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandOrange,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share All',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _c.shareAsZip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandDeepOrange,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.folder_zip_rounded, size: 16),
                      label: const Text('ZIP Archive',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _c.saveToDownloads(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textPrimary,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Save All',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Grid of PNG Cards ──────────────────────────────────────────────
        Expanded(
          child: SafeArea(
            top: false,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.68,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final item = images[index];
                return _buildImageCard(item, index);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageCard(ConvertedPngItem item, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preview Thumbnail with Lightbox trigger
          Expanded(
            child: GestureDetector(
              onTap: () => _showFullImageViewer(index),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                      child: Container(
                        color: _c.isTransparentBackground.value
                            ? Colors.grey.shade100
                            : Colors.white,
                        child: item.memoryBytes != null
                            ? Image.memory(
                                item.memoryBytes!,
                                fit: BoxFit.contain,
                              )
                            : Image.file(
                                File(item.filePath),
                                fit: BoxFit.contain,
                              ),
                      ),
                    ),
                  ),

                  // Page Chip
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Page ${item.pageNumber}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // Tap to zoom hint
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.fullscreen_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Meta & Actions Bar
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.dimensions,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  item.formattedSize,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download_rounded,
                          size: 18, color: _textPrimary),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Save to device',
                      onPressed: () => _c.saveToDownloads(singleItem: item),
                    ),
                    const SizedBox(width: 14),
                    IconButton(
                      icon: const Icon(Icons.share_rounded,
                          size: 18, color: _brandOrange),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Share PNG',
                      onPressed: () => _c.shareSingleImage(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 5. INTERACTIVE FULL-SCREEN VIEWER
  // ════════════════════════════════════════════════════════════════════════════
  void _showFullImageViewer(int initialIndex) {
    _c.activePreviewIndex.value = initialIndex;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) {
        return Obx(() {
          final idx = _c.activePreviewIndex.value;
          final item = _c.convertedImages[idx];

          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                'Page ${item.pageNumber} of ${_c.convertedImages.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  onPressed: () => _c.saveToDownloads(singleItem: item),
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: Colors.white),
                  onPressed: () => _c.shareSingleImage(item),
                ),
              ],
            ),
            body: Stack(
              children: [
                // Zoomable Image
                Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5.0,
                    child: item.memoryBytes != null
                        ? Image.memory(item.memoryBytes!, fit: BoxFit.contain)
                        : Image.file(File(item.filePath), fit: BoxFit.contain),
                  ),
                ),

                // Previous page arrow
                if (idx > 0)
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded,
                            color: Colors.white, size: 28),
                        onPressed: () => _c.activePreviewIndex.value = idx - 1,
                      ),
                    ),
                  ),

                // Next page arrow
                if (idx < _c.convertedImages.length - 1)
                  Positioned(
                    right: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.white, size: 28),
                        onPressed: () => _c.activePreviewIndex.value = idx + 1,
                      ),
                    ),
                  ),

                // Bottom Meta
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.dimensions,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        Text(
                          item.formattedSize,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}
