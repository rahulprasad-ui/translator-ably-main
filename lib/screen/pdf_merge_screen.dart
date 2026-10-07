// lib/screen/pdf_merge_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ads/widget/bottom_native_ad.dart';
import '../controllers/pdf_merge_controller.dart';
import '../helper/global.dart';

class PdfMergeScreen extends StatefulWidget {
  const PdfMergeScreen({super.key});

  @override
  State<PdfMergeScreen> createState() => _PdfMergeScreenState();
}

class _PdfMergeScreenState extends State<PdfMergeScreen> {
  final PdfMergeController _c = Get.put(PdfMergeController());

  static const Color _bg = Color(0xFFF5F6FA);
  static const Color _cardBg = Colors.white;
  static const Color _textPrimary = Color(0xFF1E2238);
  static const Color _textSecondary = Color(0xFF757D8A);

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
          'Merge PDF',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          Obx(() {
            if (_c.pickedFiles.isEmpty) return const SizedBox.shrink();
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
        if (_c.pickedFiles.isEmpty) {
          return _buildEmptyState();
        }
        return _buildFileList();
      }),
      bottomNavigationBar: Obx(() {
        if (_c.pickedFiles.isEmpty) return const BottomNativeAd();
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
            // Icon Illustration
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    pColor.withValues(alpha: 0.15),
                    pColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: pColor.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.call_merge_rounded,
                size: 54,
                color: pColor,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Combine Multiple PDFs',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),

            const Text(
              'Select 2 or more PDF documents to merge them into one organized file. You can easily reorder pages before merging.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),

            // Features Pill Row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildFeatureTag(Icons.offline_bolt_outlined, '100% Offline'),
                _buildFeatureTag(Icons.speed_rounded, 'Native Engine'),
                _buildFeatureTag(Icons.reorder_rounded, 'Custom Order'),
              ],
            ),
            const SizedBox(height: 36),

            // Select Files Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _c.isPicking.value ? null : _c.pickFiles,
                icon: _c.isPicking.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_circle_outline_rounded, size: 22),
                label: Text(
                  _c.isPicking.value ? 'Opening Explorer...' : 'Select PDF Files',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: pColor.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: pColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Populated List ─────────────────────────────────────────────────────────
  Widget _buildFileList() {
    return Column(
      children: [
        // Header Bar: Count + Add More button
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Selected Files (${_c.pickedFiles.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _c.isMerging.value ? null : _c.pickFiles,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add More'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: pColor,
                  side: const BorderSide(color: pColor, width: 1.2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),

        // Reorder tip banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: pColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pColor.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.swap_vert_rounded, size: 20, color: pColor),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Drag and drop items to reorder the final document sequence.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Reorderable list
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
            physics: const BouncingScrollPhysics(),
            itemCount: _c.pickedFiles.length,
            onReorder: _c.reorder,
            itemBuilder: (context, index) {
              final item = _c.pickedFiles[index];
              return _buildFileItemCard(item, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileItemCard(PdfMergeItem item, int index) {
    return Container(
      key: ValueKey(item.path),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Index number badge
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _bg,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // PDF file icon
            Container(
              width: 40,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.redAccent,
                  size: 24,
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
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(
                '${item.pageCount} ${item.pageCount == 1 ? 'page' : 'pages'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: pColor,
                ),
              ),
              const Text(' • ',
                  style: TextStyle(color: _textSecondary, fontSize: 12)),
              Text(
                item.formattedSize,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 20, color: Colors.black45),
              onPressed:
                  _c.isMerging.value ? null : () => _c.removeAt(index),
              tooltip: 'Remove',
            ),
            const Icon(Icons.drag_indicator_rounded,
                size: 24, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  // ── Bottom Action Bar ──────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final canMerge = _c.pickedFiles.length >= 2;

    return Container(
      padding: EdgeInsets.fromLTRB(
          18, 14, 18, 14 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Summary text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_c.pickedFiles.length} files • ${_c.totalPages} pages',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              Text(
                _c.formattedTotalSize,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Merge button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_c.isMerging.value || !canMerge)
                  ? null
                  : () async {
                      final path = await _c.mergePdfs();
                      if (path != null && mounted) {
                        _showSuccessSheet(path);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: pColor,
                disabledBackgroundColor: pColor.withValues(alpha: 0.4),
                foregroundColor: Colors.white,
                elevation: canMerge ? 3 : 0,
                shadowColor: pColor.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _c.isMerging.value
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 14),
                        Text(
                          'Merging PDFs...',
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
                        const Icon(Icons.call_merge_rounded,
                            size: 22, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          canMerge
                              ? 'Merge ${_c.pickedFiles.length} PDFs'
                              : 'Select at least 2 files',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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

  // ── Success BottomSheet ────────────────────────────────────────────────────
  void _showSuccessSheet(String outputPath) {
    final file = File(outputPath);
    final sizeKb = (file.existsSync() ? file.lengthSync() : 0) / 1024;
    final sizeStr = sizeKb > 1024
        ? '${(sizeKb / 1024).toStringAsFixed(1)} MB'
        : '${sizeKb.toStringAsFixed(1)} KB';

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 44,
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'PDFs Merged Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 6),

            Text(
              'Output: $sizeStr • ${_c.totalPages} total pages',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // View Merged PDF button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Get.back(); // close sheet
                  _c.openMergedFile();
                },
                icon: const Icon(Icons.visibility_rounded, size: 20),
                label: const Text(
                  'View Merged PDF',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Share button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  _c.shareMergedFile();
                },
                icon: const Icon(Icons.share_outlined, size: 20),
                label: const Text(
                  'Share Document',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textPrimary,
                  side: const BorderSide(color: Colors.black12, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
