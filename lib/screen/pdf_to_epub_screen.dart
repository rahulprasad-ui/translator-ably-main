import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../ads/widget/bottom_native_ad.dart';
import '../controllers/pdf_to_epub_controller.dart';

class PdfToEpubScreen extends StatefulWidget {
  final String? initialPdfPath;
  final String? initialPdfName;

  const PdfToEpubScreen({
    super.key,
    this.initialPdfPath,
    this.initialPdfName,
  });

  @override
  State<PdfToEpubScreen> createState() => _PdfToEpubScreenState();
}

class _PdfToEpubScreenState extends State<PdfToEpubScreen> {
  final PdfToEpubController _c = Get.put(PdfToEpubController());
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;

  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _textPrimary = Color(0xFF1A1D2E);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _brandIndigo = Color(0xFF6366F1);
  static const Color _brandPurple = Color(0xFF8B5CF6);
  static const Color _accentGreen = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _authorController = TextEditingController(text: _c.bookAuthor.value);

    // Sync title controller with observable
    ever(_c.bookTitle, (val) {
      if (_titleController.text != val) {
        _titleController.text = val;
      }
    });

    if (widget.initialPdfPath != null && widget.initialPdfPath!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _c.loadPdf(widget.initialPdfPath!, fileName: widget.initialPdfName);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
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
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, color: _brandIndigo, size: 24),
            SizedBox(width: 8),
            Text(
              'PDF to EPUB Converter',
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
              icon: const Icon(Icons.refresh_rounded, color: _brandIndigo),
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
        if (_c.convertedEpubPath.value != null && !_c.isConverting.value) {
          return _buildResultsView();
        }
        return _buildWorkspace();
      }),
      bottomNavigationBar: Obx(() {
        if (_c.selectedPdfPath.value == null ||
            _c.convertedEpubPath.value != null ||
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
                    _brandIndigo.withValues(alpha: 0.2),
                    _brandPurple.withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _brandIndigo.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                size: 50,
                color: _brandIndigo,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 24),

            const Text(
              'Convert PDF to Standard EPUB E-Book',
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
              'Transform any PDF into a responsive, reflowable EPUB 3.0 e-book with automatic chapters, book cover art, customizable typography, and full Kindle & Apple Books compatibility.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _c.pickPdfFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandIndigo,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: _brandIndigo.withValues(alpha: 0.4),
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

            Row(
              children: [
                _buildFeatureBadge(
                  icon: Icons.menu_book_rounded,
                  title: 'EPUB 3.0 Reflow',
                  desc: 'Adjustable font & size',
                ),
                const SizedBox(width: 12),
                _buildFeatureBadge(
                  icon: Icons.bookmark_added_rounded,
                  title: 'Smart Chapters',
                  desc: 'Auto Table of Contents',
                ),
                const SizedBox(width: 12),
                _buildFeatureBadge(
                  icon: Icons.devices_rounded,
                  title: 'Universal',
                  desc: 'Kindle, Kobo & iBooks',
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
            Icon(icon, color: _brandIndigo, size: 24),
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
          CircularProgressIndicator(color: _brandIndigo, strokeWidth: 3),
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
          _buildDocumentSummaryCard(),
          const SizedBox(height: 16),
          _buildEbookMetadataCard(),
          const SizedBox(height: 16),
          _buildTypographyCard(),
          const SizedBox(height: 16),
          _buildVisualsToggleCard(),
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
        border: Border.all(color: _brandIndigo.withValues(alpha: 0.2)),
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
          // Cover Thumbnail Preview
          Container(
            width: 54,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: _c.coverImageBytes.value != null
                  ? Image.memory(
                      _c.coverImageBytes.value!,
                      fit: BoxFit.cover,
                    )
                  : const Center(
                      child: Icon(Icons.picture_as_pdf_rounded,
                          color: _brandIndigo, size: 28),
                    ),
            ),
          ),
          const SizedBox(width: 14),
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
                        color: _brandIndigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_c.pageCount.value} Chapters / Pages',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _brandIndigo,
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
              foregroundColor: _brandIndigo,
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

  Widget _buildEbookMetadataCard() {
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
              Icon(Icons.edit_note_rounded, color: _brandIndigo, size: 22),
              SizedBox(width: 8),
              Text(
                'E-Book Metadata & Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Title Input
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Book Title',
              labelStyle: const TextStyle(fontSize: 13, color: _textSecondary),
              prefixIcon: const Icon(Icons.title_rounded, color: _brandIndigo, size: 20),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _brandIndigo, width: 1.5),
              ),
            ),
            onChanged: (val) => _c.bookTitle.value = val,
          ),

          const SizedBox(height: 12),

          // Author Input
          TextField(
            controller: _authorController,
            decoration: InputDecoration(
              labelText: 'Author / Creator',
              labelStyle: const TextStyle(fontSize: 13, color: _textSecondary),
              prefixIcon: const Icon(Icons.person_outline_rounded, color: _brandIndigo, size: 20),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _brandIndigo, width: 1.5),
              ),
            ),
            onChanged: (val) => _c.bookAuthor.value = val,
          ),
        ],
      ),
    );
  }

  Widget _buildTypographyCard() {
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
              Icon(Icons.font_download_rounded, color: _brandIndigo, size: 20),
              SizedBox(width: 8),
              Text(
                'Reading Typography Style',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ...EpubFontTheme.values.map((theme) {
            final isSelected = _c.fontTheme.value == theme;
            return GestureDetector(
              onTap: () => _c.fontTheme.value = theme,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _brandIndigo.withValues(alpha: 0.08)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _brandIndigo : Colors.grey.shade200,
                    width: isSelected ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? _brandIndigo : Colors.grey.shade400,
                          width: 2,
                        ),
                        color: Colors.white,
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _brandIndigo,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            theme.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            theme.subtitle,
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
        ],
      ),
    );
  }

  Widget _buildVisualsToggleCard() {
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
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _brandIndigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image_outlined,
                    color: _brandIndigo, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Embed Page Visuals & Diagrams',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      'Preserve illustrations alongside extracted text',
                      style: TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _c.embedPageVisuals.value,
                activeTrackColor: _brandIndigo,
                onChanged: (val) => _c.embedPageVisuals.value = val,
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _brandPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_filter_rounded,
                    color: _brandPurple, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generate Book Cover Art',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      'Use Page 1 as high-res e-reader cover',
                      style: TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _c.includeCover.value,
                activeTrackColor: _brandIndigo,
                onChanged: (val) => _c.includeCover.value = val,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomConvertBar() {
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
              onPressed: _c.convertPdfToEpub,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandIndigo,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: _brandIndigo.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.auto_stories_rounded, size: 20),
              label: Text(
                'Convert to EPUB E-Book (${_c.pageCount.value} Pages)',
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
                    color: _brandIndigo,
                    backgroundColor: Colors.grey.shade200,
                    strokeWidth: 6,
                  ),
                ),
                Text(
                  '${(_c.conversionProgress.value * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _brandIndigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Compiling EPUB 3.0 E-Book...',
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
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 4. RESULTS VIEW
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildResultsView() {
    return Center(
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // E-Book 3D Cover presentation
            Container(
              width: 140,
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: _brandIndigo.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: _c.coverImageBytes.value != null
                    ? Image.memory(
                        _c.coverImageBytes.value!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: _brandIndigo.withValues(alpha: 0.1),
                        child: const Center(
                          child: Icon(Icons.menu_book_rounded,
                              color: _brandIndigo, size: 54),
                        ),
                      ),
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 24),

            // Book Title & Meta
            Text(
              _c.bookTitle.value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'By ${_c.bookAuthor.value} • ${_c.totalChapters.value} Chapters',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: _textSecondary,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _accentGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: _accentGreen, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'EPUB Size: ${_c.formattedEpubSize}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _accentGreen,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Share EPUB Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _c.shareEpub,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandIndigo,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shadowColor: _brandIndigo.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.share_rounded, size: 20),
                label: const Text(
                  'Share EPUB E-Book',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Save to Downloads Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _c.saveToDownloads,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textPrimary,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text(
                  'Save to Device Storage',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Convert another
            TextButton.icon(
              onPressed: () => _c.convertedEpubPath.value = null,
              icon: const Icon(Icons.tune_rounded, size: 18, color: _brandIndigo),
              label: const Text(
                'Reconfigure Settings',
                style: TextStyle(
                  color: _brandIndigo,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
