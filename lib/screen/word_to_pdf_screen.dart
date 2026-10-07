// lib/screen/word_to_pdf_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../ads/widget/bottom_native_ad.dart';
import '../controllers/word_to_pdf_controller.dart';
import 'pdf_editor_screen.dart';

class WordToPdfScreen extends StatefulWidget {
  final String? initialDocPath;
  const WordToPdfScreen({super.key, this.initialDocPath});

  @override
  State<WordToPdfScreen> createState() => _WordToPdfScreenState();
}

class _WordToPdfScreenState extends State<WordToPdfScreen> {
  final WordToPdfController _c = Get.put(WordToPdfController());

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _wordBlue = Color(0xFF2B579A); // Microsoft Word Blue
  static const Color _wordBlueDark = Color(0xFF183B6C);
  static const Color _pdfRed = Color(0xFFE53935); // Adobe PDF Red

  @override
  void initState() {
    super.initState();
    if (widget.initialDocPath != null &&
        File(widget.initialDocPath!).existsSync()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _c.loadWordFile(widget.initialDocPath!);
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
            Icon(Icons.description_rounded, color: _wordBlue, size: 22),
            SizedBox(width: 8),
            Text(
              'Word to PDF',
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
            if (_c.selectedDocPath.value == null) return const SizedBox.shrink();
            return TextButton.icon(
              onPressed: _c.isConverting.value ? null : _c.reset,
              icon: const Icon(Icons.refresh_rounded, size: 18, color: _wordBlue),
              label: const Text(
                'Change',
                style: TextStyle(
                  color: _wordBlue,
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
        if (_c.selectedDocPath.value == null) {
          return _buildEmptyState();
        }
        return _buildWorkspace();
      }),
      bottomNavigationBar: Obx(() {
        if (_c.selectedDocPath.value == null ||
            _c.convertedPdfPath.value != null) {
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
                    _wordBlue.withValues(alpha: 0.15),
                    _pdfRed.withValues(alpha: 0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _wordBlue.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.description_rounded,
                    size: 52,
                    color: _wordBlue,
                  ),
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: _pdfRed,
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
              'Convert Word to PDF',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Turn Microsoft Word (.docx & .doc) files into clean,\nprintable, high-resolution PDF documents.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 32),

            // Select File Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _c.isPicking.value ? null : _c.pickWordFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _wordBlue,
                  elevation: 3,
                  shadowColor: _wordBlue.withValues(alpha: 0.4),
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
                    : const Icon(Icons.upload_file_rounded,
                        color: Colors.white, size: 22),
                label: Text(
                  _c.isPicking.value ? 'Loading Word File...' : 'Choose Word File (.docx, .doc)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ).animate().slideY(begin: 0.2, end: 0, duration: 300.ms),

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
            Icons.table_chart_rounded,
            'Preserves Tables & Columns',
            'Word tables with cells and borders are automatically mapped to neat PDF tables.',
          ),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),
          _buildPointerRow(
            Icons.format_list_bulleted_rounded,
            'Bullet Lists & Styled Headings',
            'H1, H2, H3 headings, bold texts, and bullet points maintain hierarchical structure.',
          ),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),
          _buildPointerRow(
            Icons.verified_user_rounded,
            '100% Offline & Private',
            'Documents never leave your device. Complete conversion runs on your mobile hardware.',
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
            color: _wordBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: _wordBlue),
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

          // Document Metadata Card
          _buildDocInfoCard(),

          const SizedBox(height: 18),

          // Conversion Settings Card (if not yet converted or modifying)
          if (_c.convertedPdfPath.value == null) ...[
            _buildSettingsCard(),
            const SizedBox(height: 18),
            _buildContentPreviewCard(),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  // ── Document Info Card ────────────────────────────────────────────────────
  Widget _buildDocInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_wordBlue, _wordBlueDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.description_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _c.selectedDocName.value ?? 'Word Document',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _c.isDocxFormat.value
                                ? const Color(0xFFEFF6FF)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _c.isDocxFormat.value ? 'DOCX' : 'DOC',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _c.isDocxFormat.value
                                  ? _wordBlue
                                  : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _c.formattedFileSize,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Statistics Pills
          Row(
            children: [
              _buildStatPill(
                Icons.segment_rounded,
                '${_c.paragraphCount.value}',
                'Paragraphs',
              ),
              const SizedBox(width: 8),
              _buildStatPill(
                Icons.spellcheck_rounded,
                '${_c.wordCount.value}',
                'Words',
              ),
              const SizedBox(width: 8),
              _buildStatPill(
                Icons.table_rows_rounded,
                '${_c.tableCount.value}',
                'Tables',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: _wordBlue),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
              Icon(Icons.tune_rounded, color: _wordBlue, size: 20),
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
            'Page Format',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: PdfPageSizeOption.values.map((opt) {
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
                        color: isSel ? _wordBlue : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? _wordBlue : const Color(0xFFE2E8F0),
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

          // 2. Margins
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
            children: PdfMarginOption.values.map((opt) {
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
                        color: isSel ? _wordBlue : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? _wordBlue : const Color(0xFFE2E8F0),
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

          // 3. Typography
          const Text(
            'Font Typography',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: PdfFontOption.values.map((opt) {
              final isSel = _c.selectedFont.value == opt;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _c.selectedFont.value = opt,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSel ? _wordBlue : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? _wordBlue : const Color(0xFFE2E8F0),
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
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // 4. Header & Footer Toggles
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _c.includeHeader.value,
            onChanged: (val) => _c.includeHeader.value = val,
            activeColor: _wordBlue,
            title: const Text(
              'Document Header',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            subtitle: const Text(
              'Show document title and divider rule at top of pages',
              style: TextStyle(fontSize: 11.5, color: _textSecondary),
            ),
          ),

          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _c.includeFooter.value,
            onChanged: (val) => _c.includeFooter.value = val,
            activeColor: _wordBlue,
            title: const Text(
              'Page Numbers & Footer',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            subtitle: const Text(
              'Show "Page X of Y" and timestamp at the bottom',
              style: TextStyle(fontSize: 11.5, color: _textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Content Preview Card ──────────────────────────────────────────────────
  Widget _buildContentPreviewCard() {
    final sample = _c.extractedSampleText.value;
    if (sample == null || sample.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.visibility_outlined, size: 18, color: _textSecondary),
              SizedBox(width: 8),
              Text(
                'Document Content Preview',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              sample,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF334155),
                height: 1.45,
                fontFamily: 'monospace',
              ),
            ),
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
                      'PDF Successfully Created!',
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

          // Thumbnail Preview (if available)
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
                    backgroundColor: _wordBlue,
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
                    side: const BorderSide(color: _wordBlue, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded,
                      color: _wordBlue, size: 18),
                  label: const Text(
                    'Open PDF',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _wordBlue,
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
                valueColor: const AlwaysStoppedAnimation(_wordBlue),
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
                backgroundColor: _wordBlue,
                elevation: 3,
                shadowColor: _wordBlue.withValues(alpha: 0.4),
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
                _c.isConverting.value ? 'Converting to PDF...' : 'Convert to PDF Now',
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
