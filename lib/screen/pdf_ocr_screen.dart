// lib/screen/pdf_ocr_screen.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../ads/widget/bottom_native_ad.dart';
import '../controllers/pdf_ocr_controller.dart';
import '../widget/ocr_document_layer_view.dart';

class PdfOcrScreen extends StatefulWidget {
  final String? initialPdfPath;
  const PdfOcrScreen({super.key, this.initialPdfPath});

  @override
  State<PdfOcrScreen> createState() => _PdfOcrScreenState();
}

class _PdfOcrScreenState extends State<PdfOcrScreen> {
  final PdfOcrController _c = Get.put(PdfOcrController());

  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _cardBg = Colors.white;
  static const Color _textPrimary = Color(0xFF1A1D2E);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _brandOrange = Color(0xFFFF8C42);
  static const Color _brandOrangeDark = Color(0xFFF96D15);
  static const Color _accentTeal = Color(0xFF06B6D4);

  // Tab view for results: 0 = Full Text, 1 = Page by Page
  int _resultViewTab = 0;

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
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _textPrimary, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.document_scanner_rounded,
                color: _brandOrange, size: 22),
            SizedBox(width: 8),
            Text(
              'AI OCR Text Scanner',
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
            if (!_c.hasContent) return const SizedBox.shrink();
            return TextButton.icon(
              onPressed: _c.isProcessing.value ? null : _c.reset,
              icon: const Icon(Icons.refresh_rounded,
                  size: 20, color: _brandOrange),
              label: const Text(
                'Change',
                style: TextStyle(
                  color: _brandOrange,
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
        if (_c.isProcessing.value) {
          return _buildProcessingView();
        }
        if (!_c.hasContent) {
          return _buildEmptyState();
        }
        if (_c.isOcrCompleted.value) {
          return _buildResultsWorkspace();
        }
        return _buildConfigurationWorkspace();
      }),
      bottomNavigationBar: Obx(() {
        if (!_c.hasContent || _c.isProcessing.value) {
          return const BottomNativeAd();
        }
        return _buildBottomBar();
      }),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1. EMPTY STATE (Choose Camera, Gallery Images or PDF)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing Scanner Hero Icon
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _brandOrange.withValues(alpha: 0.18),
                    _accentTeal.withValues(alpha: 0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _brandOrange.withValues(alpha: 0.35),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _brandOrange.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                size: 52,
                color: _brandOrange,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 20),
            const Text(
              'Extract Text with AI OCR',
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
              'Instantly convert images, photos, camera scans & PDFs\ninto editable, translatable text.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 28),

            // Source Option 1: Camera Scan
            _buildSourceCard(
              icon: Icons.camera_alt_rounded,
              color: _brandOrange,
              title: 'Scan with Camera',
              subtitle: 'Take a live photo of notes, books, signs or receipts',
              onTap: _c.captureImageFromCamera,
            ),
            const SizedBox(height: 12),

            // Source Option 2: Gallery Images
            _buildSourceCard(
              icon: Icons.photo_library_rounded,
              color: const Color(0xFF6366F1),
              title: 'From Photos / Gallery',
              subtitle: 'Select one or multiple images from your device',
              onTap: () => _c.pickImagesFromGallery(append: false),
            ),
            const SizedBox(height: 12),

            // Source Option 3: PDF Document
            _buildSourceCard(
              icon: Icons.picture_as_pdf_rounded,
              color: const Color(0xFFEF4444),
              title: 'From PDF Document',
              subtitle: 'Extract text from scanned or digital PDF files',
              onTap: _c.pickPdfFile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _c.isPicking.value ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
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
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2. CONFIGURATION WORKSPACE (Images or PDF)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildConfigurationWorkspace() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Overview Card (Images Grid or PDF Info)
        _c.sourceType.value == OcrSourceType.images
            ? _buildImagesInputList()
            : _buildPdfCard(),

        if (_c.sourceType.value == OcrSourceType.pdf) ...[
          const SizedBox(height: 20),
          _buildOcrModeSelector(),
          const SizedBox(height: 16),
          _buildModeContent(),
        ],
      ],
    );
  }

  Widget _buildImagesInputList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.collections_rounded,
                      color: _brandOrange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Selected Images (${_c.pickedImages.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _c.captureImageFromCamera,
                    icon: const Icon(Icons.camera_alt_rounded,
                        size: 20, color: _brandOrange),
                    tooltip: 'Take Photo',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () => _c.pickImagesFromGallery(append: true),
                    icon: const Icon(Icons.add_photo_alternate_rounded,
                        size: 22, color: _brandOrange),
                    tooltip: 'Add Images',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Grid of Selected Images
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.82,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _c.pickedImages.length,
            itemBuilder: (context, index) {
              final item = _c.pickedImages[index];
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(item.path),
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Delete Button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _c.removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                  // Image Number Pill
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPdfCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_brandOrange, _brandOrangeDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _brandOrange.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _c.selectedPdfName.value ?? 'document.pdf',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _brandOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_c.pageCount.value} Pages',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _brandOrange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _c.formattedFileSize,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildOcrModeSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAEFF8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Obx(() {
        return Row(
          children: [
            _buildModeTab('All Pages', OcrMode.allPages),
            _buildModeTab('Select Pages', OcrMode.selectedPages),
            _buildModeTab('Page Range', OcrMode.pageRange),
          ],
        );
      }),
    );
  }

  Widget _buildModeTab(String label, OcrMode mode) {
    final isSelected = _c.ocrMode.value == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _c.ocrMode.value = mode,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? _brandOrange : _textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeContent() {
    return Obx(() {
      switch (_c.ocrMode.value) {
        case OcrMode.allPages:
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: _brandOrange, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All ${_c.pageCount.value} pages will be processed sequentially with high-resolution neural OCR.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: _textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          );

        case OcrMode.selectedPages:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected ${_c.selectedPages.length} of ${_c.pageCount.value} pages',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _c.selectAllPages,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Select All',
                            style: TextStyle(
                                color: _brandOrange,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _c.deselectAllPages,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Clear',
                            style: TextStyle(
                                color: _textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 12,
                ),
                itemCount: _c.pageCount.value,
                itemBuilder: (context, index) {
                  return _buildPageSelectThumbnail(index);
                },
              ),
            ],
          );

        case OcrMode.pageRange:
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Define Page Range for OCR',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberInput(
                        'From Page',
                        _c.rangeStart.value,
                        (val) => _c.rangeStart.value =
                            val.clamp(1, _c.pageCount.value),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('to',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _textSecondary)),
                    ),
                    Expanded(
                      child: _buildNumberInput(
                        'To Page',
                        _c.rangeEnd.value,
                        (val) => _c.rangeEnd.value =
                            val.clamp(1, _c.pageCount.value),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
      }
    });
  }

  Widget _buildPageSelectThumbnail(int pageIndex) {
    return Obx(() {
      final isSelected = _c.selectedPages.contains(pageIndex);
      return GestureDetector(
        onTap: () => _c.togglePageSelection(pageIndex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _brandOrange : Colors.grey.withValues(alpha: 0.2),
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? _brandOrange.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Positioned.fill(
                  child: FutureBuilder<Uint8List?>(
                    future: _c.getThumbnail(pageIndex),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done &&
                          snapshot.data != null) {
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                        );
                      }
                      return Container(
                        color: const Color(0xFFF0F2F7),
                        child: const Center(
                          child: Icon(Icons.description_outlined,
                              color: Colors.black26, size: 28),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? _brandOrange : Colors.white70,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      isSelected ? Icons.check_rounded : Icons.add_rounded,
                      color: isSelected ? Colors.white : Colors.black45,
                      size: 16,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Page ${pageIndex + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildNumberInput(
      String label, int value, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: _textSecondary)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => onChanged(value - 1),
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: _brandOrange,
              ),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              IconButton(
                onPressed: () => onChanged(value + 1),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: _brandOrange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 3. PROCESSING VIEW (Live scanning animation, detailed page progress & Cancel)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildProcessingView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _brandOrange.withValues(alpha: 0.25),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 104,
                    height: 104,
                    child: Obx(() => CircularProgressIndicator(
                          value: _c.progress.value > 0 ? _c.progress.value : null,
                          strokeWidth: 6,
                          color: _brandOrange,
                          backgroundColor:
                              _brandOrange.withValues(alpha: 0.15),
                        )),
                  ),
                  const Icon(
                    Icons.document_scanner_rounded,
                    size: 46,
                    color: _brandOrange,
                  ),
                ],
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                  begin: const Offset(0.96, 0.96),
                  end: const Offset(1.04, 1.04),
                  duration: 800.ms,
                  curve: Curves.easeInOut,
                ),

            const SizedBox(height: 28),

            // Item/Page Counter Pill
            Obx(() {
              final curr = _c.currentProcessingPage.value;
              final total = _c.totalProcessingPages.value;
              final isImages = _c.sourceType.value == OcrSourceType.images;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _brandOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _brandOrange.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  total > 0
                      ? 'Processing ${isImages ? "Image" : "Page"} $curr of $total'
                      : 'Scanning with AI OCR...',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _brandOrange,
                  ),
                ),
              );
            }),

            const SizedBox(height: 14),

            // Percentage Text
            Obx(() {
              final pct = (_c.progress.value * 100).toInt().clamp(0, 100);
              return Text(
                '$pct%',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: _textPrimary,
                  letterSpacing: -0.5,
                ),
              );
            }),

            const SizedBox(height: 8),

            // Current Step description
            Obx(() => Text(
                  _c.currentStep.value.isNotEmpty
                      ? _c.currentStep.value
                      : _c.statusMessage.value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary,
                    height: 1.35,
                  ),
                )),

            const SizedBox(height: 20),

            // Linear Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Obx(() => LinearProgressIndicator(
                    value: _c.progress.value > 0 ? _c.progress.value : null,
                    minHeight: 8,
                    color: _brandOrange,
                    backgroundColor: Colors.grey.withValues(alpha: 0.15),
                  )),
            ),

            const SizedBox(height: 36),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _c.isCancelling.value ? null : _c.cancelOcr,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(
                    color: Colors.redAccent.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: Obx(() => _c.isCancelling.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.redAccent,
                        ),
                      )
                    : const Icon(Icons.stop_circle_outlined, size: 20)),
                label: Obx(() => Text(
                      _c.isCancelling.value
                          ? 'Aborting & skipping...'
                          : 'Cancel OCR',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 4. RESULTS WORKSPACE (Full text editor, page/image browser, actions)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildResultsWorkspace() {
    return Column(
      children: [
        // Summary Stats Banner
        _buildStatsBanner(),

        // Tab Selector (Document Layer vs Full Text vs Page by Page)
        _buildResultTabSelector(),

        // Content Area
        Expanded(
          child: _resultViewTab == 0
              ? _buildDocumentLayerView()
              : _resultViewTab == 1
                  ? _buildFullTextDocumentView()
                  : _buildPageByPageView(),
        ),
      ],
    );
  }

  Widget _buildStatsBanner() {
    final isImages = _c.sourceType.value == OcrSourceType.images;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            isImages ? 'Images' : 'Pages',
            '${_c.ocrPages.length}',
            isImages ? Icons.collections_rounded : Icons.pages_rounded,
          ),
          Container(width: 1, height: 28, color: Colors.grey.withValues(alpha: 0.2)),
          _buildStatItem('Words', '${_c.totalWords}', Icons.text_fields_rounded),
          Container(width: 1, height: 28, color: Colors.grey.withValues(alpha: 0.2)),
          _buildStatItem(
              'Read Time', '~${_c.readingTimeMinutes} min', Icons.schedule_rounded),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _brandOrange, size: 18),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultTabSelector() {
    final isImages = _c.sourceType.value == OcrSourceType.images;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFEAEFF8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildResultTabItem(
              tabIndex: 0,
              icon: Icons.layers_rounded,
              title: 'Doc Layer',
            ),
            _buildResultTabItem(
              tabIndex: 1,
              icon: Icons.article_rounded,
              title: 'Full Text',
            ),
            _buildResultTabItem(
              tabIndex: 2,
              icon: isImages
                  ? Icons.collections_rounded
                  : Icons.view_carousel_rounded,
              title: isImages ? 'Images' : 'Pages',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTabItem({
    required int tabIndex,
    required IconData icon,
    required String title,
  }) {
    final isSelected = _resultViewTab == tabIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _resultViewTab = tabIndex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
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
                size: 15,
                color: isSelected ? _brandOrange : _textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? _brandOrange : _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 4A. Visual Document Layer View (Overlay directly on image)
  Widget _buildDocumentLayerView() {
    if (_c.ocrPages.isEmpty) {
      return const Center(child: Text('No scanned document available'));
    }

    return Obx(() {
      final index =
          _c.currentViewPageIndex.value.clamp(0, _c.ocrPages.length - 1);
      final page = _c.ocrPages[index];
      final isImages = _c.sourceType.value == OcrSourceType.images;

      return Column(
        children: [
          // If multiple items, show page navigator strip
          if (_c.ocrPages.length > 1)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: index > 0
                        ? () => _c.currentViewPageIndex.value--
                        : null,
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                  Text(
                    '${isImages ? "Image" : "Page"} ${page.pageNumber} of ${_c.ocrPages.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: index < _c.ocrPages.length - 1
                        ? () => _c.currentViewPageIndex.value++
                        : null,
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                ],
              ),
            ),

          // Main Interactive Document Layer Overlay Viewer
          Expanded(
            child: OcrDocumentLayerView(
              page: page,
              onCopy: () => _c.copyCurrentPageText(index),
              onTranslate: () => _c.translatePageText(index),
            ),
          ),
        ],
      );
    });
  }

  // 4A. Full Text Document View
  Widget _buildFullTextDocumentView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'Extracted Text Layer',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _c.copyAllText,
                    icon: const Icon(Icons.copy_rounded,
                        size: 18, color: _brandOrange),
                    tooltip: 'Copy all',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                  const SizedBox(width: 6),
                  Obx(() {
                    final isPlaying = _c.isTtsPlaying.value;
                    return IconButton(
                      onPressed: _c.toggleTts,
                      icon: Icon(
                        isPlaying
                            ? Icons.stop_circle_rounded
                            : Icons.volume_up_rounded,
                        size: 20,
                        color: isPlaying ? Colors.redAccent : _accentTeal,
                      ),
                      tooltip: isPlaying ? 'Stop TTS' : 'Read Aloud',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: SelectableText(
                  _c.combinedText.value,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.7,
                    color: _textPrimary,
                    letterSpacing: 0.3,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 4B. Page/Image by Page View
  Widget _buildPageByPageView() {
    if (_c.ocrPages.isEmpty) {
      return const Center(child: Text('No items available'));
    }

    return Obx(() {
      final index = _c.currentViewPageIndex.value.clamp(0, _c.ocrPages.length - 1);
      final page = _c.ocrPages[index];
      final isImages = _c.sourceType.value == OcrSourceType.images;

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: index > 0
                        ? () => _c.currentViewPageIndex.value--
                        : null,
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                  Text(
                    '${isImages ? "Image" : "Page"} ${page.pageNumber} (${index + 1} of ${_c.ocrPages.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: index < _c.ocrPages.length - 1
                        ? () => _c.currentViewPageIndex.value++
                        : null,
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _brandOrange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${page.wordCount} words',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _brandOrange,
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _c.copyCurrentPageText(index),
                            icon: const Icon(Icons.copy_rounded,
                                size: 16, color: _brandOrange),
                            label: Text(
                              isImages ? 'Copy Image Text' : 'Copy Page',
                              style: const TextStyle(
                                  color: _brandOrange,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        child: SelectableText(
                          page.text,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.7,
                            color: _textPrimary,
                            letterSpacing: 0.3,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 5. BOTTOM BAR
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
        child: _c.isOcrCompleted.value
            ? _buildResultsActionBar()
            : _buildStartOcrButton(),
      ),
    );
  }

  Widget _buildStartOcrButton() {
    final isImages = _c.sourceType.value == OcrSourceType.images;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _c.startOcr,
        style: ElevatedButton.styleFrom(
          backgroundColor: _brandOrange,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: _brandOrange.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.document_scanner_rounded, size: 22),
        label: Text(
          isImages ? 'Extract Text from Images' : 'Start OCR Extraction',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildResultsActionBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _c.translateText,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.translate_rounded, size: 20),
                  label: const Text(
                    'Translate',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _showExportModal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandOrange,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.file_download_rounded, size: 20),
                  label: const Text(
                    'Export & Save',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F4F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                onPressed: _c.shareExtractedText,
                icon: const Icon(Icons.share_rounded,
                    color: _textPrimary, size: 20),
                tooltip: 'Share',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 6. EXPORT MODAL BOTTOM SHEET
  // ════════════════════════════════════════════════════════════════════════════
  void _showExportModal() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Export Recognized Text',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose format to save or share your OCR text',
                style: TextStyle(fontSize: 13, color: _textSecondary),
              ),
              const SizedBox(height: 20),

              _buildExportOption(
                icon: Icons.text_snippet_rounded,
                color: const Color(0xFF10B981),
                title: 'Plain Text (.txt)',
                subtitle: 'Simple UTF-8 text file compatible everywhere',
                onTap: () {
                  Get.back();
                  _c.exportAsTxt();
                },
              ),
              const SizedBox(height: 12),

              _buildExportOption(
                icon: Icons.description_rounded,
                color: const Color(0xFF2B579A),
                title: 'Microsoft Word (.docx)',
                subtitle: 'Formatted document with pages & headers',
                onTap: () {
                  Get.back();
                  _c.exportAsDocx();
                },
              ),
              const SizedBox(height: 12),

              _buildExportOption(
                icon: Icons.picture_as_pdf_rounded,
                color: _brandOrange,
                title: 'PDF Document (.pdf)',
                subtitle: 'Clean formatted document with standard margins',
                onTap: () {
                  Get.back();
                  _c.exportAsPdf();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
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
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}
