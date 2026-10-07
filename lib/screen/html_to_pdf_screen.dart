// lib/screen/html_to_pdf_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../ads/widget/bottom_native_ad.dart';
import '../controllers/html_to_pdf_controller.dart';
import 'pdf_editor_screen.dart';

class HtmlToPdfScreen extends StatefulWidget {
  final String? initialFilePath;
  final String? initialUrl;
  final String? initialHtmlCode;

  const HtmlToPdfScreen({
    super.key,
    this.initialFilePath,
    this.initialUrl,
    this.initialHtmlCode,
  });

  @override
  State<HtmlToPdfScreen> createState() => _HtmlToPdfScreenState();
}

class _HtmlToPdfScreenState extends State<HtmlToPdfScreen> {
  final HtmlToPdfController _c = Get.put(HtmlToPdfController());
  late final TextEditingController _codeController;
  late final TextEditingController _urlController;

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _htmlOrange = Color(0xFFE44D26); // HTML5 Brand Orange
  static const Color _htmlOrangeDark = Color(0xFFC23616);
  static const Color _accentBlue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: _c.htmlCodeInput.value);
    _urlController = TextEditingController(text: _c.webUrlInput.value);

    // Sync external inputs if provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialFilePath != null && widget.initialFilePath!.isNotEmpty) {
        _c.activeSource.value = HtmlInputSource.file;
        _c.loadHtmlFromFile(widget.initialFilePath!);
      } else if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
        _c.activeSource.value = HtmlInputSource.url;
        _urlController.text = widget.initialUrl!;
        _c.fetchHtmlFromUrl(widget.initialUrl!);
      } else if (widget.initialHtmlCode != null && widget.initialHtmlCode!.isNotEmpty) {
        _c.activeSource.value = HtmlInputSource.code;
        _codeController.text = widget.initialHtmlCode!;
        _c.onCodeChanged(widget.initialHtmlCode!);
      }
    });

    // Listen to code changes from controller (e.g. when loading templates)
    ever(_c.htmlCodeInput, (val) {
      if (_codeController.text != val) {
        _codeController.text = val;
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Obx(() {
        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source Mode Tabs (File / Code / URL)
                  _buildSourceModeTabs(),
                  const SizedBox(height: 16),

                  // Active Source Input Area
                  _buildActiveSourceInputCard(),
                  const SizedBox(height: 18),

                  // Document Info & Stats (if HTML content available)
                  if (_c.rawHtmlContent.value.trim().isNotEmpty) ...[
                    _buildDocumentSummaryCard(),
                    const SizedBox(height: 18),
                  ],

                  // PDF Page & Formatting Settings
                  _buildPdfSettingsCard(),
                  const SizedBox(height: 20),

                  // Conversion Result Card (if converted)
                  if (_c.convertedPdfPath.value != null) ...[
                    _buildResultSuccessCard(),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),

            // Sticky Bottom Convert Button
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomActionBar(),
            ),

            // Loading / Progress Overlay
            if (_c.isConverting.value) _buildConvertingOverlay(),
          ],
        );
      }),
      bottomNavigationBar: const BottomNativeAd(),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: _textPrimary, size: 20),
        onPressed: () => Get.back(),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_htmlOrange, _htmlOrangeDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.html_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'HTML to PDF',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Files, Webpages & Raw Code',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Reset Form',
          icon: const Icon(Icons.refresh_rounded, color: _textSecondary, size: 22),
          onPressed: () {
            _c.selectedFilePath.value = null;
            _c.selectedFileName.value = null;
            _c.selectedFileSize.value = 0;
            _c.convertedPdfPath.value = null;
            _c.loadSample(HtmlSampleTemplate.modernInvoice);
          },
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  // ── Source Mode Tabs ──────────────────────────────────────────────────────

  Widget _buildSourceModeTabs() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: HtmlInputSource.values.map((source) {
          final isSelected = _c.activeSource.value == source;
          return Expanded(
            child: GestureDetector(
              onTap: () => _c.activeSource.value = source,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [_htmlOrange, _htmlOrangeDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      source.icon,
                      size: 16,
                      color: isSelected ? Colors.white : _textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      source.title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Active Source Input Area ──────────────────────────────────────────────

  Widget _buildActiveSourceInputCard() {
    switch (_c.activeSource.value) {
      case HtmlInputSource.file:
        return _buildFileInputCard();
      case HtmlInputSource.code:
        return _buildCodeInputCard();
      case HtmlInputSource.url:
        return _buildUrlInputCard();
    }
  }

  // ── 1. File Input Card ────────────────────────────────────────────────────

  Widget _buildFileInputCard() {
    final hasFile = _c.selectedFilePath.value != null;

    if (!hasFile) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1EB),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD8C7)),
              ),
              child: const Icon(
                Icons.upload_file_rounded,
                size: 38,
                color: _htmlOrange,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Select an HTML Document',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Supports .html, .htm, .xhtml and .txt files',
              style: TextStyle(
                fontSize: 12,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _c.pickHtmlFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: _htmlOrange,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: const Text(
                'Browse Files',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.insert_drive_file_rounded,
                color: _htmlOrange, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _c.selectedFileName.value ?? 'HTML Document',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1EB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'HTML',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _htmlOrange,
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
          IconButton(
            tooltip: 'Pick another file',
            icon: const Icon(Icons.swap_horiz_rounded, color: _accentBlue),
            onPressed: _c.pickHtmlFile,
          ),
        ],
      ),
    );
  }

  // ── 2. Code Input Card ────────────────────────────────────────────────────

  Widget _buildCodeInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.terminal_rounded, size: 18, color: _htmlOrange),
                  SizedBox(width: 8),
                  Text(
                    'HTML Source Markup',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      _codeController.clear();
                      _c.onCodeChanged('');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Code Text Area
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A), // Dark IDE style
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: TextField(
              controller: _codeController,
              onChanged: _c.onCodeChanged,
              maxLines: 12,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: Color(0xFFE2E8F0),
                height: 1.45,
              ),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.all(14),
                border: InputBorder.none,
                hintText: 'Paste or write your HTML tags here...',
                hintStyle: TextStyle(
                  color: Color(0xFF64748B),
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Sample Template Chips
          const Text(
            'Load Quick Sample Template:',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: HtmlSampleTemplate.values.map((tmpl) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    backgroundColor: const Color(0xFFFFF7ED),
                    side: const BorderSide(color: Color(0xFFFFEDD5)),
                    label: Text(
                      tmpl.name,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _htmlOrangeDark,
                      ),
                    ),
                    avatar: const Icon(Icons.flash_on_rounded,
                        size: 14, color: _htmlOrange),
                    onPressed: () => _c.loadSample(tmpl),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Web URL Input Card ─────────────────────────────────────────────────

  Widget _buildUrlInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          Row(
            children: const [
              Icon(Icons.public_rounded, size: 18, color: _htmlOrange),
              SizedBox(width: 8),
              Text(
                'Convert Webpage URL',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter any webpage link to download HTML and render it to PDF',
            style: TextStyle(fontSize: 12, color: _textSecondary),
          ),
          const SizedBox(height: 14),

          // URL Text Field & Fetch Button
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    style: const TextStyle(fontSize: 13, color: _textPrimary),
                    decoration: const InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: InputBorder.none,
                      hintText: 'https://example.com/page.html',
                      hintStyle:
                          TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.link_rounded,
                          size: 18, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _c.isFetchingUrl.value
                      ? null
                      : () => _c.fetchHtmlFromUrl(_urlController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _htmlOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _c.isFetchingUrl.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Fetch',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),

          if (_c.fetchedUrlStatus.value != null) ...[
            const SizedBox(height: 10),
            Text(
              _c.fetchedUrlStatus.value!,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _c.fetchedUrlStatus.value!.contains('error') ||
                        _c.fetchedUrlStatus.value!.contains('Failed')
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF16A34A),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Document Summary & Stats Card ─────────────────────────────────────────

  Widget _buildDocumentSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              const Icon(Icons.analytics_outlined,
                  size: 18, color: _htmlOrangeDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _c.documentTitle.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stat Pills
          Row(
            children: [
              _buildStatPill(
                Icons.text_fields_rounded,
                '${_c.wordCount.value}',
                'Words',
                const Color(0xFFEFF6FF),
                _accentBlue,
              ),
              const SizedBox(width: 8),
              _buildStatPill(
                Icons.title_rounded,
                '${_c.headingCount.value}',
                'Headings',
                const Color(0xFFFFF7ED),
                _htmlOrange,
              ),
              const SizedBox(width: 8),
              _buildStatPill(
                Icons.table_chart_rounded,
                '${_c.tableCount.value}',
                'Tables',
                const Color(0xFFECFDF5),
                const Color(0xFF059669),
              ),
              const SizedBox(width: 8),
              _buildStatPill(
                Icons.image_outlined,
                '${_c.imageCount.value}',
                'Images',
                const Color(0xFFF5F3FF),
                const Color(0xFF7C3AED),
              ),
            ],
          ),

          if (_c.extractedTextSnippet.value.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                _c.extractedTextSnippet.value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatPill(
    IconData icon,
    String value,
    String label,
    Color bgColor,
    Color accentColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: accentColor),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: accentColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PDF Settings Card ─────────────────────────────────────────────────────

  Widget _buildPdfSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tune_rounded, size: 18, color: _htmlOrange),
              SizedBox(width: 8),
              Text(
                'PDF Layout & Formatting',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Page Format & Orientation Row
          Row(
            children: [
              // Page Format Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Page Size',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<HtmlPdfPageSize>(
                          value: _c.selectedPageSize.value,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded,
                              color: _textSecondary),
                          onChanged: (val) {
                            if (val != null) _c.selectedPageSize.value = val;
                          },
                          items: HtmlPdfPageSize.values.map((sz) {
                            return DropdownMenuItem(
                              value: sz,
                              child: Text(
                                sz.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Orientation Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Orientation',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<HtmlPdfOrientation>(
                          value: _c.selectedOrientation.value,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded,
                              color: _textSecondary),
                          onChanged: (val) {
                            if (val != null) {
                              _c.selectedOrientation.value = val;
                            }
                          },
                          items: HtmlPdfOrientation.values.map((or) {
                            return DropdownMenuItem(
                              value: or,
                              child: Text(
                                or.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Margins & Typography Row
          Row(
            children: [
              // Margins Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Margins',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<HtmlPdfMargin>(
                          value: _c.selectedMargin.value,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded,
                              color: _textSecondary),
                          onChanged: (val) {
                            if (val != null) _c.selectedMargin.value = val;
                          },
                          items: HtmlPdfMargin.values.map((mg) {
                            return DropdownMenuItem(
                              value: mg,
                              child: Text(
                                mg.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Font Style Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Typography',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<HtmlPdfFontFamily>(
                          value: _c.selectedFont.value,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded,
                              color: _textSecondary),
                          onChanged: (val) {
                            if (val != null) _c.selectedFont.value = val;
                          },
                          items: HtmlPdfFontFamily.values.map((fn) {
                            return DropdownMenuItem(
                              value: fn,
                              child: Text(
                                fn.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Toggles
          _buildSwitchRow('Show Document Title in Header', _c.showHeader),
          const Divider(height: 14, color: Color(0xFFF1F5F9)),
          _buildSwitchRow('Show Page Numbers in Footer', _c.showFooter),
          const Divider(height: 14, color: Color(0xFFF1F5F9)),
          _buildSwitchRow('Render Table Borders', _c.enableTableBorders),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(String label, RxBool rxBool) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        SizedBox(
          height: 30,
          child: Switch(
            value: rxBool.value,
            activeColor: _htmlOrange,
            onChanged: (val) => rxBool.value = val,
          ),
        ),
      ],
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

          // Action Buttons: Share & Open
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _c.shareConvertedPdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _htmlOrange,
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
                    side: const BorderSide(color: _htmlOrange, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded,
                      color: _htmlOrange, size: 18),
                  label: const Text(
                    'Open PDF',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _htmlOrange,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom Action Bar ─────────────────────────────────────────────────────

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _c.isConverting.value ? null : _c.convertToPdf,
            style: ElevatedButton.styleFrom(
              backgroundColor: _htmlOrange,
              disabledBackgroundColor: _htmlOrange.withValues(alpha: 0.6),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: _htmlOrange.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.picture_as_pdf_rounded,
                    size: 20, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Convert to PDF',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
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

  // ── Converting Overlay ────────────────────────────────────────────────────

  Widget _buildConvertingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.4),
      child: Center(
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  color: _htmlOrange,
                  strokeWidth: 3.5,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Generating PDF...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _c.conversionStatusText.value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _c.conversionProgress.value,
                  backgroundColor: const Color(0xFFF1F5F9),
                  color: _htmlOrange,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
