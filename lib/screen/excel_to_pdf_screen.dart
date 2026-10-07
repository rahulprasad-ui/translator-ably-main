// lib/screen/excel_to_pdf_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../ads/widget/bottom_native_ad.dart';
import '../controllers/excel_to_pdf_controller.dart';
import 'pdf_editor_screen.dart';

class ExcelToPdfScreen extends StatefulWidget {
  final String? initialFilePath;
  const ExcelToPdfScreen({super.key, this.initialFilePath});

  @override
  State<ExcelToPdfScreen> createState() => _ExcelToPdfScreenState();
}

class _ExcelToPdfScreenState extends State<ExcelToPdfScreen> {
  final ExcelToPdfController _c = Get.put(ExcelToPdfController());

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _excelGreen = Color(0xFF107C41); // Microsoft Excel Green
  static const Color _excelGreenDark = Color(0xFF0D5F31);

  @override
  void initState() {
    super.initState();
    if (widget.initialFilePath != null &&
        File(widget.initialFilePath!).existsSync()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _c.loadExcelFile(widget.initialFilePath!);
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
            Icon(Icons.table_chart_rounded, color: _excelGreen, size: 22),
            SizedBox(width: 8),
            Text(
              'Excel to PDF',
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
            if (_c.selectedFilePath.value == null) return const SizedBox.shrink();
            return TextButton.icon(
              onPressed: _c.isConverting.value ? null : _c.reset,
              icon: const Icon(Icons.refresh_rounded, size: 18, color: _excelGreen),
              label: const Text(
                'Change',
                style: TextStyle(
                  color: _excelGreen,
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
        if (_c.selectedFilePath.value == null) {
          return _buildEmptyState();
        }
        return _buildWorkspace();
      }),
      bottomNavigationBar: Obx(() {
        if (_c.selectedFilePath.value == null ||
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
            // Hero Graphic
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _excelGreen.withValues(alpha: 0.18),
                    const Color(0xFF0D9488).withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _excelGreen.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.table_chart_rounded,
                    size: 52,
                    color: _excelGreen,
                  ),
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: _excelGreenDark,
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
              'Convert Excel to PDF',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Transform spreadsheets (.xlsx, .xls, .csv) into clean,\nprintable, perfectly formatted PDF documents.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 32),

            // Select Excel Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _c.isPicking.value ? null : _c.pickExcelFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _excelGreen,
                  elevation: 3,
                  shadowColor: _excelGreen.withValues(alpha: 0.4),
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
                  _c.isPicking.value ? 'Loading Spreadsheet...' : 'Choose Excel File (.xlsx, .csv)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ).animate().slideY(begin: 0.2, end: 0, duration: 300.ms),

            const SizedBox(height: 36),

            // Feature Highlights
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
            Icons.view_column_rounded,
            'Auto-Scaled Landscape Tables',
            'Columns and headers are dynamically scaled to prevent awkward horizontal page cuts.',
          ),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),
          _buildPointerRow(
            Icons.tab_rounded,
            'Multi-Sheet Workbook Support',
            'Converts all worksheets or lets you select the exact sheet you need to export.',
          ),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),
          _buildPointerRow(
            Icons.security_rounded,
            '100% Offline & Financial Privacy',
            'Sensitive business sheets, accounting, and payroll data never leave your mobile device.',
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
            color: _excelGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: _excelGreen),
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

          // Workbook Info Card
          _buildWorkbookInfoCard(),

          const SizedBox(height: 18),

          // Layout Settings Card
          if (_c.convertedPdfPath.value == null) ...[
            _buildSettingsCard(),
            const SizedBox(height: 18),
            _buildSheetPreviewCard(),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  // ── Workbook Info Card ────────────────────────────────────────────────────
  Widget _buildWorkbookInfoCard() {
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_excelGreen, _excelGreenDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.table_chart_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _c.selectedFileName.value ?? 'Spreadsheet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
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
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _c.isXlsxFormat.value ? 'XLSX' : 'SPREADSHEET',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _excelGreenDark,
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
                Icons.tab_rounded,
                '${_c.sheets.length}',
                'Sheets',
              ),
              const SizedBox(width: 8),
              _buildStatPill(
                Icons.grid_4x4_rounded,
                '${_c.totalCellsCount.value}',
                'Data Cells',
              ),
              const SizedBox(width: 8),
              _buildStatPill(
                Icons.view_column_rounded,
                _c.sheets.isNotEmpty ? '${_c.sheets.first.totalCols}' : '0',
                'Columns',
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
                Icon(icon, size: 13, color: _excelGreen),
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
              Icon(Icons.tune_rounded, color: _excelGreen, size: 20),
              SizedBox(width: 8),
              Text(
                'Spreadsheet Page & Table Settings',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 1. Orientation
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
            children: ExcelPdfPageOrientation.values.map((opt) {
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
                        color: isSel ? _excelGreen : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? _excelGreen : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        opt.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
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

          // 2. Paper Size
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
            children: ExcelPdfPageSize.values.map((opt) {
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
                        color: isSel ? _excelGreen : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? _excelGreen : const Color(0xFFE2E8F0),
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

          // 3. Table Styling
          const Text(
            'Table Style Theme',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: ExcelPdfTableTheme.values.map((opt) {
              final isSel = _c.selectedTheme.value == opt;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _c.selectedTheme.value = opt,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSel ? _excelGreen : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? _excelGreen : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        opt.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
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

          // 4. Switches
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _c.printGridlines.value,
            onChanged: (val) => _c.printGridlines.value = val,
            activeColor: _excelGreen,
            title: const Text(
              'Print Cell Gridlines',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            subtitle: const Text(
              'Show visible borders around every table cell',
              style: TextStyle(fontSize: 11.5, color: _textSecondary),
            ),
          ),

          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _c.convertAllSheets.value,
            onChanged: (val) => _c.convertAllSheets.value = val,
            activeColor: _excelGreen,
            title: const Text(
              'Convert All Worksheets',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            subtitle: const Text(
              'Includes every sheet tab in the output PDF document',
              style: TextStyle(fontSize: 11.5, color: _textSecondary),
            ),
          ),

          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _c.includePageNumbers.value,
            onChanged: (val) => _c.includePageNumbers.value = val,
            activeColor: _excelGreen,
            title: const Text(
              'Page Numbers & Footer',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            subtitle: const Text(
              'Show "Page X of Y" and timestamp in the bottom footer',
              style: TextStyle(fontSize: 11.5, color: _textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sheet Preview Card ────────────────────────────────────────────────────
  Widget _buildSheetPreviewCard() {
    if (_c.sheets.isEmpty) return const SizedBox.shrink();
    final sheet = _c.sheets[_c.selectedSheetIndex.value.clamp(0, _c.sheets.length - 1)];

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.preview_rounded, size: 18, color: _textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Preview: ${sheet.name}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '${sheet.rowCount} rows • ${sheet.totalCols} cols',
                style: const TextStyle(fontSize: 11, color: _textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scrollable table snippet (first 5 rows)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 32,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFDCFCE7)),
                columns: sheet.rows.isNotEmpty
                    ? sheet.rows.first
                        .map((c) => DataColumn(
                              label: Text(
                                c.isNotEmpty ? c : 'Col',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _excelGreenDark,
                                ),
                              ),
                            ))
                        .toList()
                    : const [],
                rows: sheet.rows.length > 1
                    ? sheet.rows.skip(1).take(5).map((row) {
                        return DataRow(
                          cells: row
                              .map((cell) => DataCell(
                                    Text(
                                      cell,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _textPrimary,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        );
                      }).toList()
                    : const [],
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
                      'Spreadsheet PDF Ready!',
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
                constraints: const BoxConstraints(maxHeight: 200),
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

          // Primary Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _c.shareConvertedPdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _excelGreen,
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
                    side: const BorderSide(color: _excelGreen, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded,
                      color: _excelGreen, size: 18),
                  label: const Text(
                    'Open PDF',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _excelGreen,
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
                valueColor: const AlwaysStoppedAnimation(_excelGreen),
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
                backgroundColor: _excelGreen,
                elevation: 3,
                shadowColor: _excelGreen.withValues(alpha: 0.4),
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
                _c.isConverting.value ? 'Converting Spreadsheet...' : 'Convert Excel to PDF Now',
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
