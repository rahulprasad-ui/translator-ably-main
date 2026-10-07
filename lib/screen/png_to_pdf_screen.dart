// lib/screen/png_to_pdf_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../ads/widget/bottom_native_ad.dart';
import '../controllers/png_to_pdf_controller.dart';
import 'pdf_editor_screen.dart';

class PngToPdfScreen extends StatefulWidget {
  final List<String>? initialPngPaths;
  const PngToPdfScreen({super.key, this.initialPngPaths});

  @override
  State<PngToPdfScreen> createState() => _PngToPdfScreenState();
}

class _PngToPdfScreenState extends State<PngToPdfScreen> {
  final PngToPdfController _c = Get.put(PngToPdfController());

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _brandGreen = Color(0xFF10B981); // Emerald / PDF Green
  static const Color _brandGreenDark = Color(0xFF047857);

  @override
  void initState() {
    super.initState();
    if (widget.initialPngPaths != null && widget.initialPngPaths!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        for (final p in widget.initialPngPaths!) {
          final f = File(p);
          if (await f.exists()) {
            final bytes = await f.readAsBytes();
            _c.imageItems.add(
              PngImageItem(
                id: '${DateTime.now().microsecondsSinceEpoch}_${_c.imageItems.length}',
                path: p,
                name: p.split(Platform.pathSeparator).last,
                sizeInBytes: bytes.length,
                width: 800,
                height: 600,
                thumbnailBytes: bytes,
              ),
            );
          }
        }
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
            Icon(Icons.image_rounded, color: _brandGreen, size: 22),
            SizedBox(width: 8),
            Text(
              'PNG to PDF',
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
            if (_c.imageItems.isEmpty) return const SizedBox.shrink();
            return TextButton.icon(
              onPressed: _c.isConverting.value ? null : _c.reset,
              icon: const Icon(Icons.refresh_rounded, size: 18, color: _brandGreen),
              label: const Text(
                'Reset',
                style: TextStyle(
                  color: _brandGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            );
          }),
          const SizedBox(width: 6),
        ],
      ),
      body: Obx(() {
        if (_c.imageItems.isEmpty) {
          return _buildEmptyState();
        }
        return _buildWorkspace();
      }),
      bottomNavigationBar: Obx(() {
        if (_c.imageItems.isEmpty || _c.convertedPdfPath.value != null) {
          return const BottomNativeAd();
        }
        return _buildBottomConvertBar();
      }),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1. EMPTY STATE
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hero Icon Graphic
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _brandGreen.withValues(alpha: 0.18),
                    const Color(0xFF3B82F6).withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _brandGreen.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.image_rounded,
                    size: 52,
                    color: _brandGreen,
                  ),
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: _brandGreenDark,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().scale(duration: 350.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 24),

            const Text(
              'Convert PNG to PDF',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Select one or multiple PNG images and combine them\ninto a clean, sharp, high-resolution PDF file.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 32),

            // Select PNGs Button (File Picker)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _c.isPicking.value ? null : () => _c.pickPngImages(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandGreen,
                  elevation: 3,
                  shadowColor: _brandGreen.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _c.isPicking.value
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.add_photo_alternate_rounded,
                        color: Colors.white, size: 22),
                label: Text(
                  _c.isPicking.value ? 'Loading Images...' : 'Choose PNG Images',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ).animate().slideY(begin: 0.2, end: 0, duration: 300.ms),

            const SizedBox(height: 12),

            // Gallery Alternative Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _c.isPicking.value ? null : _c.pickFromGallery,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.photo_library_rounded,
                    color: _textPrimary, size: 18),
                label: const Text(
                  'Pick from Photo Gallery',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Feature Highlights Card
            _buildFeaturePointers(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePointers() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          _buildPointerRow(
            Icons.high_quality_rounded,
            'Lossless Image Sharpness',
            'PNG transparency and crisp text/diagram details are preserved with zero compression loss.',
          ),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),
          _buildPointerRow(
            Icons.swap_vert_rounded,
            'Reorder & Rotate Pages',
            'Easily arrange image order and rotate individual images clockwise before conversion.',
          ),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),
          _buildPointerRow(
            Icons.aspect_ratio_rounded,
            'Flexible Page Layouts',
            'Choose "Fit to Image" for exact borderless sizes, or standard A4 / US Letter pages.',
          ),
        ],
      ),
    );
  }

  Widget _buildPointerRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _brandGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: _brandGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2. WORKSPACE STATE
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildWorkspace() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Converted Result Banner (if ready)
          if (_c.convertedPdfPath.value != null) ...[
            _buildResultSuccessCard(),
            const SizedBox(height: 20),
          ],

          // Batch Summary Card with "Add More" Button
          _buildBatchSummaryBar(),

          const SizedBox(height: 16),

          // Images Reorderable List
          _buildImagesListSection(),

          const SizedBox(height: 20),

          // Layout Settings Card
          if (_c.convertedPdfPath.value == null) ...[
            _buildSettingsCard(),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  // ── Batch Summary Bar ─────────────────────────────────────────────────────
  Widget _buildBatchSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_c.imageItems.length} PNG ${_c.imageItems.length == 1 ? 'Image' : 'Images'} Selected',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Total Size: ${_c.formattedTotalSize}',
                style: const TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _c.pickPngImages(append: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _brandGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_photo_alternate_rounded,
                      size: 16, color: _brandGreen),
                  SizedBox(width: 6),
                  Text(
                    'Add More',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _brandGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Images List Section ───────────────────────────────────────────────────
  Widget _buildImagesListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Pages Order (Tap buttons to rotate or reorder)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _textSecondary,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _c.imageItems.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final item = _c.imageItems[i];
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Page index chip
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Image Thumbnail with live rotation
                  RotatedBox(
                    quarterTurns: (item.rotationDegrees / 90).round(),
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          item.thumbnailBytes,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.width} × ${item.height} • ${item.formattedSize}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions: Rotate, Move, Delete
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.rotate_right_rounded,
                            size: 20, color: _textSecondary),
                        tooltip: 'Rotate 90°',
                        onPressed: () => _c.rotateImage(i),
                      ),
                      if (i > 0)
                        IconButton(
                          icon: const Icon(Icons.arrow_upward_rounded,
                              size: 18, color: _textSecondary),
                          tooltip: 'Move Up',
                          onPressed: () => _c.reorderImages(i, i - 1),
                        ),
                      if (i < _c.imageItems.length - 1)
                        IconButton(
                          icon: const Icon(Icons.arrow_downward_rounded,
                              size: 18, color: _textSecondary),
                          tooltip: 'Move Down',
                          onPressed: () => _c.reorderImages(i, i + 2),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: Color(0xFFEF4444)),
                        tooltip: 'Remove',
                        onPressed: () => _c.removeImage(i),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Settings Card ─────────────────────────────────────────────────────────
  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: _brandGreen, size: 20),
              SizedBox(width: 8),
              Text(
                'PDF Page & Layout Settings',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 1. Page Size
          const Text(
            'Page Dimensions',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: PngPageSize.values.map((opt) {
              final isSel = _c.selectedPageSize.value == opt;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _c.selectedPageSize.value = opt,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSel ? _brandGreen : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? _brandGreen : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        opt.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSel ? Colors.white : _textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // 2. Orientation (if not fit to image)
          if (_c.selectedPageSize.value != PngPageSize.fitImage) ...[
            const Text(
              'Page Orientation',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: PngPageOrientation.values.map((opt) {
                final isSel = _c.selectedOrientation.value == opt;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _c.selectedOrientation.value = opt,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSel ? _brandGreen : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? _brandGreen : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          opt.title,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isSel ? Colors.white : _textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // 3. Margin
          const Text(
            'Page Margins',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: PngPageMargin.values.map((opt) {
              final isSel = _c.selectedMargin.value == opt;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _c.selectedMargin.value = opt,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSel ? _brandGreen : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? _brandGreen : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        opt.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSel ? Colors.white : _textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Result Success Card ───────────────────────────────────────────────────
  Widget _buildResultSuccessCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF86EFAC)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF16A34A), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PDF Successfully Generated!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_c.convertedPageCount.value} Pages • ${_c.formattedConvertedSize}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Thumbnail Preview
          if (_c.previewThumbnailBytes.value != null)
            Center(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _c.previewThumbnailBytes.value!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Primary Actions: Share & Open
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _c.shareConvertedPdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandGreen,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.share_rounded,
                      color: Colors.white, size: 18),
                  label: const Text(
                    'Share PDF',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final path = _c.convertedPdfPath.value;
                    if (path != null) {
                      Get.to(() => PdfEditorScreen(initialPdfPath: path));
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: _brandGreen, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded,
                      color: _brandGreen, size: 18),
                  label: const Text(
                    'Open PDF',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _brandGreen,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 3. BOTTOM CONVERT BAR
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildBottomConvertBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_c.isConverting.value) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _c.conversionProgress.value,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation(_brandGreen),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _c.statusMessage.value,
              style: const TextStyle(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _c.isConverting.value ? null : _c.convertToPdf,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandGreen,
                elevation: 3,
                shadowColor: _brandGreen.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _c.isConverting.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded,
                      color: Colors.white, size: 20),
              label: Text(
                _c.isConverting.value
                    ? 'Creating PDF...'
                    : 'Convert ${_c.imageItems.length} PNG${_c.imageItems.length == 1 ? '' : 's'} to PDF',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
