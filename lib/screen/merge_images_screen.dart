// lib/screen/merge_images_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ads/widget/bottom_native_ad.dart';
import '../controllers/merge_images_controller.dart';

class MergeImagesScreen extends StatefulWidget {
  const MergeImagesScreen({super.key});

  @override
  State<MergeImagesScreen> createState() => _MergeImagesScreenState();
}

class _MergeImagesScreenState extends State<MergeImagesScreen> {
  final MergeImagesController _c = Get.put(MergeImagesController());

  static const Color _bg = Color(0xFFF5F6FA);
  static const Color _cardBg = Colors.white;
  static const Color _textPrimary = Color(0xFF1E2238);
  static const Color _textSecondary = Color(0xFF757D8A);
  static const Color _brandBlue = Color(0xFF245AE4);
  static const Color _brandCyan = Color(0xFF5E89FC);

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
        title: const Text(
          'Merge Images',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          Obx(() {
            if (_c.pickedImages.isEmpty) return const SizedBox.shrink();
            return TextButton.icon(
              onPressed: _c.isMerging.value ? null : _c.clearAll,
              icon: const Icon(Icons.delete_sweep_outlined,
                  size: 20, color: Colors.redAccent),
              label: const Text(
                'Clear',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        if (_c.pickedImages.isEmpty) {
          return _buildEmptyState();
        }
        return _buildImageList();
      }),
      bottomNavigationBar: Obx(() {
        if (_c.pickedImages.isEmpty) return const BottomNativeAd();
        return _buildBottomBar();
      }),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _brandBlue.withValues(alpha: 0.15),
                    _brandCyan.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _brandBlue.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.collections_rounded,
                size: 50,
                color: _brandBlue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Images to Merge',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Combine multiple photos into a single multi-page PDF\nor stitch them into one continuous long image.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _c.isPicking.value ? null : () => _c.pickImages(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandBlue,
                  elevation: 4,
                  shadowColor: _brandBlue.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _c.isPicking.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.add_photo_alternate_rounded,
                        color: Colors.white, size: 22),
                label: Text(
                  _c.isPicking.value ? 'Selecting...' : 'Choose Images',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),
            _buildFeatureCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildFeatureRow(
            Icons.picture_as_pdf_rounded,
            'Multi-Page PDF',
            'Every selected photo becomes a high quality page in the merged PDF.',
          ),
          const Divider(height: 20),
          _buildFeatureRow(
            Icons.view_day_rounded,
            'Stitched Long Image',
            'Connect all images vertically into a single seamless image.',
          ),
          const Divider(height: 20),
          _buildFeatureRow(
            Icons.swap_vert_rounded,
            'Drag & Drop Reordering',
            'Rearrange images easily by dragging them into your preferred sequence.',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _brandBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: _brandBlue),
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
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Image List & Controls ──────────────────────────────────────────────────
  Widget _buildImageList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              _buildSummaryHeader(),
              const SizedBox(height: 12),
              _buildFormatSelector(),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: _c.pickedImages.length,
            onReorder: _c.reorder,
            itemBuilder: (context, index) {
              final item = _c.pickedImages[index];
              return _buildImageCard(item, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _brandBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_c.pickedImages.length} Images',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _brandBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _c.formattedTotalSize,
                style: const TextStyle(
                  fontSize: 13,
                  color: _textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: () => _c.pickImages(append: true),
            icon: const Icon(Icons.add_photo_alternate_outlined,
                size: 18, color: _brandBlue),
            label: const Text(
              'Add More',
              style: TextStyle(
                color: _brandBlue,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAECEF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildFormatTab(
            'Multi-Page PDF',
            Icons.picture_as_pdf_rounded,
            MergeImagesFormat.pdf,
          ),
          _buildFormatTab(
            'Stitched Long Image',
            Icons.view_day_rounded,
            MergeImagesFormat.longImage,
          ),
        ],
      ),
    );
  }

  Widget _buildFormatTab(
      String label, IconData icon, MergeImagesFormat format) {
    final isSelected = _c.selectedFormat.value == format;
    return Expanded(
      child: GestureDetector(
        onTap: () => _c.selectedFormat.value = format,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: isSelected ? _brandBlue : _textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? _brandBlue : _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard(MergeImageItem item, int index) {
    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _brandBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _brandBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 46,
                height: 46,
                child: Image.file(
                  File(item.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF0F2F5),
                    child: const Icon(Icons.image_not_supported_rounded,
                        color: _textSecondary, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        subtitle: Text(
          item.formattedSize,
          style: const TextStyle(fontSize: 12, color: _textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.redAccent, size: 20),
              tooltip: 'Remove',
              onPressed: () => _c.removeAt(index),
            ),
            const Icon(Icons.drag_handle_rounded,
                color: Color(0xFFB0B6C3), size: 22),
          ],
        ),
      ),
    );
  }

  // ── Bottom Action Bar ──────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final count = _c.pickedImages.length;
    final isPdf = _c.selectedFormat.value == MergeImagesFormat.pdf;
    final buttonText = isPdf
        ? 'Merge $count Images into PDF'
        : 'Stitch $count Images into One';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: (_c.isMerging.value || count < 2)
                ? null
                : () async {
                    final result = await _c.executeMerge();
                    if (result != null && mounted) {
                      _showSuccessBottomSheet(result);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandBlue,
              disabledBackgroundColor: _brandBlue.withValues(alpha: 0.4),
              elevation: 4,
              shadowColor: _brandBlue.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _c.isMerging.value
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Merging Images...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPdf
                            ? Icons.picture_as_pdf_rounded
                            : Icons.view_day_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── Success Bottom Sheet ───────────────────────────────────────────────────
  void _showSuccessBottomSheet(String outputPath) {
    final isPdf = outputPath.endsWith('.pdf');
    final fileName = outputPath.split(Platform.pathSeparator).last;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD6DAE1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 36),
            ),
            const SizedBox(height: 14),
            const Text(
              'Images Merged Successfully!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_c.pickedImages.length} images combined into ${isPdf ? "a PDF document" : "a stitched image"}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _textSecondary),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E6EC)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isPdf
                          ? Colors.redAccent.withValues(alpha: 0.1)
                          : _brandBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.image_rounded,
                      color: isPdf ? Colors.redAccent : _brandBlue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _c.formattedMergedSize,
                          style: const TextStyle(
                              fontSize: 12, color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Get.back();
                        _c.openResult();
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _brandBlue, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.visibility_outlined,
                          color: _brandBlue, size: 20),
                      label: const Text(
                        'Preview',
                        style: TextStyle(
                          color: _brandBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _c.shareResult,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandBlue,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.share_rounded,
                          color: Colors.white, size: 20),
                      label: const Text(
                        'Share',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () => Get.back(),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}
