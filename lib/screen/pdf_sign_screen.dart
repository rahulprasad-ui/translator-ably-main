// lib/screen/pdf_sign_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../ads/widget/bottom_native_ad.dart';
import '../controllers/pdf_sign_controller.dart';
import '../helper/my_dialogs.dart';

class PdfSignScreen extends StatefulWidget {
  final String? initialPdfPath;
  const PdfSignScreen({super.key, this.initialPdfPath});

  @override
  State<PdfSignScreen> createState() => _PdfSignScreenState();
}

class _PdfSignScreenState extends State<PdfSignScreen> {
  final PdfSignController _c = Get.put(PdfSignController());

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _brandPurple = Color(0xFF7C3AED);
  static const Color _brandPurpleDark = Color(0xFF6D28D9);
  static const Color _brandIndigo = Color(0xFF4F46E5);
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
            Icon(Icons.draw_rounded, color: _brandPurple, size: 22),
            SizedBox(width: 8),
            Text(
              'Sign PDF Document',
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
            child: CircularProgressIndicator(color: _brandPurple),
          );
        }
        if (!_c.hasDocument) {
          return _buildEmptyState();
        }
        return _buildSigningWorkspace();
      }),
      bottomNavigationBar: Obx(() {
        if (!_c.hasDocument || _c.isExporting.value) {
          return const BottomNativeAd();
        }
        return _buildBottomToolbar();
      }),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1. EMPTY STATE (Hero upload banner & features)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hero Icon
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _brandPurple.withValues(alpha: 0.18),
                    _brandIndigo.withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _brandPurple.withValues(alpha: 0.35),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _brandPurple.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.draw_rounded,
                size: 50,
                color: _brandPurple,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Digital PDF Signer',
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
              'Sign legal contracts, forms and documents with realistic\nhandwritten digital signatures or elegant cursive fonts.',
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
                  backgroundColor: _brandPurple,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: _brandPurple.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 22),
                label: const Text(
                  'Select PDF Document to Sign',
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
              icon: Icons.gesture_rounded,
              title: 'Smooth Handwritten Signature Pad',
              subtitle: 'Draw with finger or stylus in Black, Blue or Navy ink',
            ),
            const SizedBox(height: 12),
            _buildFeaturePill(
              icon: Icons.text_fields_rounded,
              title: 'Type Cursive Calligraphy Signatures',
              subtitle: 'Type your name and choose from legal signature styles',
            ),
            const SizedBox(height: 12),
            _buildFeaturePill(
              icon: Icons.calendar_today_rounded,
              title: '1-Tap Date Stamp & Initials',
              subtitle: 'Add formal date marks and initials anywhere on document',
            ),
            const SizedBox(height: 12),
            _buildFeaturePill(
              icon: Icons.lock_outline_rounded,
              title: '100% Offline, Secure & Tamper-Proof',
              subtitle: 'Signatures are permanently flattened into native PDF',
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
              color: _brandPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _brandPurple, size: 20),
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
  // 2. SIGNING WORKSPACE
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildSigningWorkspace() {
    return Column(
      children: [
        // Top Document & Control Strip
        _buildDocumentHeaderBar(),

        // Page Navigator
        _buildPageNavigator(),

        // Main Document Canvas with Drag-and-Drop Signatures
        Expanded(
          child: Container(
            color: const Color(0xFF1E293B), // Dark slate canvas background
            child: Center(
              child: Obx(() {
                if (_c.isRenderingPage.value ||
                    _c.currentPageBytes.value == null) {
                  return const CircularProgressIndicator(color: _brandPurple);
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  '${_c.pageCount.value} Pages • ${_c.formattedFileSize}',
                  style: const TextStyle(fontSize: 11, color: _textSecondary),
                ),
              ],
            ),
          ),
          // Undo
          IconButton(
            onPressed: _c.canUndo ? _c.undo : null,
            icon: const Icon(Icons.undo_rounded, size: 20),
            color: _c.canUndo ? _textPrimary : Colors.grey.withValues(alpha: 0.4),
            tooltip: 'Undo',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
          const SizedBox(width: 4),
          // Redo
          IconButton(
            onPressed: _c.canRedo ? _c.redo : null,
            icon: const Icon(Icons.redo_rounded, size: 20),
            color: _c.canRedo ? _textPrimary : Colors.grey.withValues(alpha: 0.4),
            tooltip: 'Redo',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
          const SizedBox(width: 8),
          // Clear page signatures
          IconButton(
            onPressed: _c.clearCurrentPageSignatures,
            icon: const Icon(Icons.cleaning_services_rounded, size: 19),
            color: const Color(0xFFEF4444),
            tooltip: 'Clear page signatures',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
        ],
      ),
    );
  }

  Widget _buildPageNavigator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
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
                  size: 15, color: _brandPurple),
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
        final signaturesOnThisPage =
            _c.placedSignatures.where((e) => e.pageIndex == pageIndex).toList();

        return GestureDetector(
          onTap: () => _c.selectSignature(null),
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

                // Placed Signatures & Stamps
                for (final item in signaturesOnThisPage)
                  _buildPlacedSignatureWidget(
                    item: item,
                    scaleX: scaleX,
                    scaleY: scaleY,
                    renderedW: renderedW,
                    renderedH: renderedH,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlacedSignatureWidget({
    required PlacedSignatureItem item,
    required double scaleX,
    required double scaleY,
    required double renderedW,
    required double renderedH,
  }) {
    final isSelected = _c.selectedSignatureId.value == item.id;
    final l = item.position.dx * scaleX;
    final t = item.position.dy * scaleY;
    final w = item.width * scaleX;
    final h = item.height * scaleY;

    return Positioned(
      left: l,
      top: t,
      width: w,
      height: h,
      child: GestureDetector(
        onTap: () => _c.selectSignature(item.id),
        onPanUpdate: (details) {
          final newDx = item.position.dx + (details.delta.dx / scaleX);
          final newDy = item.position.dy + (details.delta.dy / scaleY);
          final clampedX = newDx.clamp(0.0, _c.currentPageWidth.value - item.width);
          final clampedY = newDy.clamp(0.0, _c.currentPageHeight.value - item.height);
          _c.updateSignaturePosition(item.id, Offset(clampedX, clampedY));
        },
        onPanEnd: (_) => _c.commitSignaturePosition(item.id),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Signature Image Box
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? _brandPurple : Colors.transparent,
                  width: 1.8,
                ),
                color: isSelected
                    ? _brandPurple.withValues(alpha: 0.05)
                    : Colors.transparent,
              ),
              child: Image.memory(
                item.signatureBytes,
                fit: BoxFit.contain,
              ),
            ),

            // Controls when selected
            if (isSelected) ...[
              // Floating quick action bar above signature
              Positioned(
                top: -38,
                left: 0,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF1E293B),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Duplicate
                      InkWell(
                        onTap: () => _c.duplicateSignature(item.id),
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(10)),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: Icon(Icons.copy_rounded,
                              size: 15, color: Colors.white),
                        ),
                      ),
                      Container(width: 1, height: 16, color: Colors.white24),
                      // Delete
                      InkWell(
                        onTap: () => _c.deleteSignature(item.id),
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

              // Bottom-Right Corner Resize Handle
              Positioned(
                right: -10,
                bottom: -10,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    final newW = item.width + (details.delta.dx / scaleX);
                    final newH = item.height + (details.delta.dy / scaleY);
                    _c.updateSignatureSize(item.id, newW, newH);
                  },
                  onPanEnd: (_) => _c.commitSignatureSize(item.id),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _brandPurple,
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
  // 3. BOTTOM TOOLBAR (Sign, Initials, Date, Finish)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildBottomToolbar() {
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
            // Sign Tool
            _buildToolItem(
              icon: Icons.draw_rounded,
              label: 'Sign',
              color: _brandPurple,
              onTap: _showSignatureCreationModal,
            ),
            const SizedBox(width: 8),

            // Initials Tool
            _buildToolItem(
              icon: Icons.badge_outlined,
              label: 'Initials',
              color: const Color(0xFF0284C7),
              onTap: _showInitialsDialog,
            ),
            const SizedBox(width: 8),

            // Date Stamp Tool
            _buildToolItem(
              icon: Icons.calendar_today_rounded,
              label: 'Date Stamp',
              color: const Color(0xFF0D9488),
              onTap: _c.addDateStamp,
            ),
            const SizedBox(width: 12),

            // Save & Finish Button
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _handleExportSignedPdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandPurple,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text(
                    'Save Signed',
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

  Widget _buildToolItem({
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
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
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

  // ════════════════════════════════════════════════════════════════════════════
  // 4. SIGNATURE CREATION MODAL (Draw, Type, Saved)
  // ════════════════════════════════════════════════════════════════════════════
  void _showSignatureCreationModal() {
    Get.bottomSheet(
      const _SignatureModalSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _showInitialsDialog() {
    final textC = TextEditingController();
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.badge_rounded, color: Color(0xFF0284C7)),
            SizedBox(width: 8),
            Text('Enter Initials', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: TextField(
          controller: textC,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 4,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            hintText: 'e.g. RP',
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (textC.text.trim().isNotEmpty) {
                Get.back();
                _c.addInitials(textC.text.trim());
              }
            },
            child: const Text('Add Initials'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExportSignedPdf() async {
    final signedPath = await _c.exportSignedPdf();
    if (signedPath != null) {
      _showExportSuccessModal(signedPath);
    }
  }

  void _showExportSuccessModal(String signedPath) {
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
                'Document Officially Signed!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'All signatures, initials and date stamps have been permanently baked and flattened onto your document.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _textSecondary, height: 1.4),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _brandPurple,
                        side: const BorderSide(color: _brandPurple),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Get.back();
                        MyDialogs.success(msg: 'Saved to $signedPath');
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Done'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _c.shareSignedPdf(signedPath),
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

// ════════════════════════════════════════════════════════════════════════════
// 5. SIGNATURE CREATION MODAL SHEET (Draw / Type / Wallet)
// ════════════════════════════════════════════════════════════════════════════
class _SignatureModalSheet extends StatefulWidget {
  const _SignatureModalSheet();

  @override
  State<_SignatureModalSheet> createState() => _SignatureModalSheetState();
}

class _SignatureModalSheetState extends State<_SignatureModalSheet> {
  final PdfSignController _c = Get.find<PdfSignController>();
  int _activeTab = 0; // 0 = Draw, 1 = Type, 2 = Wallet

  // Draw State
  final List<List<Offset>> _strokes = [];
  Color _drawColor = const Color(0xFF0F172A); // Midnight Black
  double _drawStrokeWidth = 3.2;

  // Type State
  final TextEditingController _typeTextController =
      TextEditingController(text: 'John Doe');
  int _selectedStyleIndex = 0;
  Color _typeColor = const Color(0xFF0F172A);

  @override
  void dispose() {
    _typeTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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

            // Header & Tabs
            Row(
              children: [
                _buildTabButton(0, 'Draw Signature', Icons.gesture_rounded),
                const SizedBox(width: 8),
                _buildTabButton(1, 'Type Signature', Icons.text_fields_rounded),
                if (_c.savedSignatures.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildTabButton(
                      2, 'Saved (${_c.savedSignatures.length})', Icons.bookmark_rounded),
                ],
              ],
            ),
            const SizedBox(height: 16),

            if (_activeTab == 0) _buildDrawTab(),
            if (_activeTab == 1) _buildTypeTab(),
            if (_activeTab == 2) _buildWalletTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSel = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFF7C3AED) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSel ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSel ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab 1: Draw Signature ──────────────────────────────────────────────────
  Widget _buildDrawTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls: Ink Colors & Clear
        Row(
          children: [
            _buildInkColorDot(const Color(0xFF0F172A), 'Black'),
            const SizedBox(width: 8),
            _buildInkColorDot(const Color(0xFF1D4ED8), 'Blue'),
            const SizedBox(width: 8),
            _buildInkColorDot(const Color(0xFF0F2942), 'Navy'),
            const Spacer(),
            TextButton.icon(
              onPressed: _strokes.isEmpty
                  ? null
                  : () => setState(() => _strokes.clear()),
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 16, color: Color(0xFFEF4444)),
              label: const Text('Clear',
                  style: TextStyle(
                      color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Drawing Box
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned(
                  bottom: 38,
                  left: 20,
                  right: 20,
                  child: Container(height: 1.2, color: const Color(0xFFCBD5E1)),
                ),
                Positioned(
                  bottom: 16,
                  left: 20,
                  child: Text(
                    'Sign with finger or stylus above the line',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withValues(alpha: 0.35),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
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
                    painter: _DrawSignaturePainter(
                      strokes: _strokes,
                      color: _drawColor,
                      strokeWidth: _drawStrokeWidth,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _strokes.isEmpty ? null : _saveDrawnSignature,
            icon: const Icon(Icons.check_rounded, size: 20),
            label: const Text('Place Signature on PDF',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildInkColorDot(Color color, String label) {
    final isSel = _drawColor == color;
    return GestureDetector(
      onTap: () => setState(() => _drawColor = color),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
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

  Future<void> _saveDrawnSignature() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(400, 200);

    final painter = _DrawSignaturePainter(
      strokes: _strokes,
      color: _drawColor,
      strokeWidth: _drawStrokeWidth * 1.5,
    );
    painter.paint(canvas, size);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      Get.back();
      _c.addSignature(byteData.buffer.asUint8List(), saveToWallet: true);
    }
  }

  // ── Tab 2: Type Signature ──────────────────────────────────────────────────
  Widget _buildTypeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _typeTextController,
          decoration: InputDecoration(
            labelText: 'Type Full Name',
            hintText: 'e.g. John Doe',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        const Text(
          'Choose Calligraphy Style',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 8),

        // Style selector
        Row(
          children: [
            _buildTypeStyleCard(0, 'Cursive Script'),
            const SizedBox(width: 8),
            _buildTypeStyleCard(1, 'Elegant Script'),
            const SizedBox(width: 8),
            _buildTypeStyleCard(2, 'Classic Legal'),
          ],
        ),
        const SizedBox(height: 14),

        // Preview Box
        Container(
          width: double.infinity,
          height: 110,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Center(
            child: Text(
              _typeTextController.text.trim().isEmpty
                  ? 'Your Signature'
                  : _typeTextController.text.trim(),
              style: _getTypeTextStyle(_selectedStyleIndex, _typeColor, 34),
            ),
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _typeTextController.text.trim().isEmpty
                ? null
                : _saveTypedSignature,
            icon: const Icon(Icons.check_rounded, size: 20),
            label: const Text('Place Typed Signature on PDF',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeStyleCard(int idx, String name) {
    final isSel = _selectedStyleIndex == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStyleIndex = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFFEDE9FE) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSel ? const Color(0xFF7C3AED) : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                color: isSel ? const Color(0xFF7C3AED) : const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _getTypeTextStyle(int styleIdx, Color color, double fontSize) {
    switch (styleIdx) {
      case 0:
        return TextStyle(
          fontSize: fontSize,
          color: color,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w400,
          letterSpacing: 2.0,
        );
      case 1:
        return TextStyle(
          fontSize: fontSize,
          color: color,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        );
      case 2:
      default:
        return TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.5,
        );
    }
  }

  Future<void> _saveTypedSignature() async {
    final text = _typeTextController.text.trim();
    if (text.isEmpty) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(400, 150);

    final textStyle = _getTypeTextStyle(_selectedStyleIndex, _typeColor, 44);
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: size.width);

    final offset = Offset(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      Get.back();
      _c.addSignature(
        byteData.buffer.asUint8List(),
        width: 170.0,
        height: 65.0,
        label: 'Typed Signature',
        saveToWallet: true,
      );
    }
  }

  // ── Tab 3: Signature Wallet ────────────────────────────────────────────────
  Widget _buildWalletTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select a saved signature to place immediately on this page:',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _c.savedSignatures.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final bytes = _c.savedSignatures[i];
              return GestureDetector(
                onTap: () {
                  Get.back();
                  _c.addSignature(bytes, saveToWallet: false);
                },
                child: Container(
                  width: 160,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 16, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _c.savedSignatures.removeAt(i);
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
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
}

// ── Drawing Signature CustomPainter ─────────────────────────────────────────
class _DrawSignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;

  _DrawSignaturePainter({
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
  bool shouldRepaint(covariant _DrawSignaturePainter oldDelegate) => true;
}
