// lib/screen/pdf_to_html_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../ads/widget/bottom_native_ad.dart';
import '../controllers/pdf_to_html_controller.dart';

class PdfToHtmlScreen extends StatefulWidget {
  final String? initialPdfPath;
  final String? initialPdfName;

  const PdfToHtmlScreen({
    super.key,
    this.initialPdfPath,
    this.initialPdfName,
  });

  @override
  State<PdfToHtmlScreen> createState() => _PdfToHtmlScreenState();
}

class _PdfToHtmlScreenState extends State<PdfToHtmlScreen> {
  final PdfToHtmlController _c = Get.put(PdfToHtmlController());
  late final TextEditingController _titleController;

  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _textPrimary = Color(0xFF1A1D2E);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _brandHtmlOrange = Color(0xFFE44D26); // HTML5 Orange
  static const Color _brandBlue = Color(0xFF2563EB);
  static const Color _accentGreen = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();

    ever(_c.pageTitle, (val) {
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
            Icon(Icons.html_rounded, color: _brandHtmlOrange, size: 26),
            SizedBox(width: 8),
            Text(
              'PDF to HTML5 Webpage',
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
              icon: const Icon(Icons.refresh_rounded, color: _brandHtmlOrange),
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
        if (_c.convertedHtmlPath.value != null && !_c.isConverting.value) {
          return _buildResultsView();
        }
        return _buildWorkspace();
      }),
      bottomNavigationBar: Obx(() {
        if (_c.selectedPdfPath.value == null ||
            _c.convertedHtmlPath.value != null ||
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
                    _brandHtmlOrange.withValues(alpha: 0.2),
                    _brandBlue.withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _brandHtmlOrange.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.code_rounded,
                size: 50,
                color: _brandHtmlOrange,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 24),

            const Text(
              'Convert PDF to Responsive HTML5',
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
              'Turn your PDF documents into modern, mobile-friendly HTML5 webpages with clean semantic markup, embedded visuals, and sidebar table of contents.',
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
                  backgroundColor: _brandHtmlOrange,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: _brandHtmlOrange.withValues(alpha: 0.4),
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
                  icon: Icons.smartphone_rounded,
                  title: 'Mobile First',
                  desc: 'Responsive layout',
                ),
                const SizedBox(width: 12),
                _buildFeatureBadge(
                  icon: Icons.language_rounded,
                  title: 'Any Browser',
                  desc: 'Chrome, Safari & Edge',
                ),
                const SizedBox(width: 12),
                _buildFeatureBadge(
                  icon: Icons.folder_zip_rounded,
                  title: 'Web Bundle',
                  desc: 'HTML + CSS package',
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
            Icon(icon, color: _brandHtmlOrange, size: 24),
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
          CircularProgressIndicator(color: _brandHtmlOrange, strokeWidth: 3),
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
          _buildPageTitleCard(),
          const SizedBox(height: 16),
          _buildExportFormatCard(),
          const SizedBox(height: 16),
          _buildPageSelectionSection(),
          const SizedBox(height: 16),
          _buildThemeStyleCard(),
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
        border: Border.all(color: _brandHtmlOrange.withValues(alpha: 0.2)),
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
              color: _brandHtmlOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: _brandHtmlOrange, size: 28),
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
                        color: _brandHtmlOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_c.pageCount.value} Pages',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _brandHtmlOrange,
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
              foregroundColor: _brandHtmlOrange,
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

  Widget _buildPageTitleCard() {
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
              Icon(Icons.title_rounded, color: _brandHtmlOrange, size: 20),
              SizedBox(width: 8),
              Text(
                'Webpage Document Title',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Enter webpage title...',
              hintStyle: const TextStyle(fontSize: 13, color: _textSecondary),
              prefixIcon: const Icon(Icons.language_rounded, color: _brandHtmlOrange, size: 20),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _brandHtmlOrange, width: 1.5),
              ),
            ),
            onChanged: (val) => _c.pageTitle.value = val,
          ),
        ],
      ),
    );
  }

  Widget _buildExportFormatCard() {
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
              Icon(Icons.output_rounded, color: _brandHtmlOrange, size: 20),
              SizedBox(width: 8),
              Text(
                'HTML Package Format',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ...HtmlExportFormat.values.map((format) {
            final isSelected = _c.exportFormat.value == format;
            return GestureDetector(
              onTap: () => _c.exportFormat.value = format,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _brandHtmlOrange.withValues(alpha: 0.08)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _brandHtmlOrange : Colors.grey.shade200,
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
                          color: isSelected ? _brandHtmlOrange : Colors.grey.shade400,
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
                                  color: _brandHtmlOrange,
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
                            format.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            format.subtitle,
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
              Icon(Icons.layers_rounded, color: _brandHtmlOrange, size: 20),
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

          Row(
            children: [
              _buildSelectionTab(
                mode: HtmlPageSelectionMode.all,
                label: 'All Pages (${_c.pageCount.value})',
              ),
              const SizedBox(width: 8),
              _buildSelectionTab(
                mode: HtmlPageSelectionMode.custom,
                label: 'Custom',
              ),
              const SizedBox(width: 8),
              _buildSelectionTab(
                mode: HtmlPageSelectionMode.range,
                label: 'Range',
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_c.selectionMode.value == HtmlPageSelectionMode.all) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _brandHtmlOrange.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: _brandHtmlOrange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All ${_c.pageCount.value} pages will be rendered into the HTML document.',
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
          ] else if (_c.selectionMode.value == HtmlPageSelectionMode.custom) ...[
            _buildCustomPageGrid(),
          ] else if (_c.selectionMode.value == HtmlPageSelectionMode.range) ...[
            _buildPageRangeControls(),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectionTab({
    required HtmlPageSelectionMode mode,
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
            color: isSelected ? _brandHtmlOrange : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _brandHtmlOrange.withValues(alpha: 0.3),
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
                    foregroundColor: _brandHtmlOrange,
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
                      color: isChecked ? _brandHtmlOrange : Colors.grey.shade300,
                      width: isChecked ? 2 : 1,
                    ),
                    boxShadow: isChecked
                        ? [
                            BoxShadow(
                              color: _brandHtmlOrange.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Stack(
                    children: [
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
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isChecked ? _brandHtmlOrange : Colors.white70,
                            border: Border.all(
                              color: isChecked ? _brandHtmlOrange : Colors.grey,
                              width: 1.5,
                            ),
                          ),
                          child: isChecked
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                      ),
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
            color: _brandHtmlOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeStyleCard() {
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
              Icon(Icons.palette_rounded, color: _brandHtmlOrange, size: 20),
              SizedBox(width: 8),
              Text(
                'Webpage Theme & Typography',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ...HtmlThemeStyle.values.map((theme) {
            final isSelected = _c.themeStyle.value == theme;
            return GestureDetector(
              onTap: () => _c.themeStyle.value = theme,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _brandHtmlOrange.withValues(alpha: 0.08)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _brandHtmlOrange : Colors.grey.shade200,
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
                          color: isSelected ? _brandHtmlOrange : Colors.grey.shade400,
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
                                  color: _brandHtmlOrange,
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
                  color: _brandHtmlOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image_outlined,
                    color: _brandHtmlOrange, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Embed Page Graphics & Diagrams',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      'Includes rendered visuals alongside text',
                      style: TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _c.embedVisualImages.value,
                activeTrackColor: _brandHtmlOrange,
                onChanged: (val) => _c.embedVisualImages.value = val,
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
                  color: _brandBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.menu_open_rounded,
                    color: _brandBlue, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sidebar Table of Contents',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      'Adds quick jump links for every page',
                      style: TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _c.includeInteractiveNav.value,
                activeTrackColor: _brandHtmlOrange,
                onChanged: (val) => _c.includeInteractiveNav.value = val,
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
              onPressed: count > 0 ? _c.convertPdfToHtml : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandHtmlOrange,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: _brandHtmlOrange.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.code_rounded, size: 20),
              label: Text(
                'Generate HTML5 ($count ${count == 1 ? 'Page' : 'Pages'})',
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
                    color: _brandHtmlOrange,
                    backgroundColor: Colors.grey.shade200,
                    strokeWidth: 6,
                  ),
                ),
                Text(
                  '${(_c.conversionProgress.value * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _brandHtmlOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Compiling HTML5 Webpage...',
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
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _brandHtmlOrange.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _brandHtmlOrange.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.language_rounded,
                          color: _brandHtmlOrange, size: 52),
                      const SizedBox(height: 6),
                      Text(
                        '${_c.totalPagesConverted.value} Pages',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _brandHtmlOrange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'HTML5',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 24),

            Text(
              _c.pageTitle.value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_c.totalPagesConverted.value} Pages • HTML5 Responsive Webpage',
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
                    'Size: ${_c.formattedHtmlSize}',
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

            // Share Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _c.shareHtml,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandHtmlOrange,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shadowColor: _brandHtmlOrange.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.share_rounded, size: 20),
                label: const Text(
                  'Share HTML Webpage',
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

            TextButton.icon(
              onPressed: () => _c.convertedHtmlPath.value = null,
              icon: const Icon(Icons.tune_rounded, size: 18, color: _brandHtmlOrange),
              label: const Text(
                'Reconfigure Settings',
                style: TextStyle(
                  color: _brandHtmlOrange,
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
