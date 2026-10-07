// lib/controllers/pdf_to_excel_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:share_plus/share_plus.dart';

import '../helper/my_dialogs.dart';

enum ExcelWorkbookLayout {
  multiSheet(
    title: 'Multi-Sheet (Page by Page)',
    subtitle: 'Each PDF page becomes a separate worksheet tab (Page 1, Page 2...)',
  ),
  singleConsolidated(
    title: 'Single Consolidated Sheet',
    subtitle: 'Merges all extracted tables across all pages into one continuous spreadsheet',
  );

  final String title;
  final String subtitle;

  const ExcelWorkbookLayout({
    required this.title,
    required this.subtitle,
  });
}

enum ExcelTableTheme {
  emerald(
    title: 'Emerald Green',
    subtitle: 'Professional financial style with teal headers',
    headerColor: '0D9488',
    headerTextColor: 'FFFFFF',
    stripeColor: 'F0FDFA',
  ),
  slateNavy(
    title: 'Corporate Slate',
    subtitle: 'Clean dark slate header with crisp borders',
    headerColor: '1E293B',
    headerTextColor: 'FFFFFF',
    stripeColor: 'F8FAFC',
  ),
  minimal(
    title: 'Minimal Plain',
    subtitle: 'Simple grid lines without heavy background fills',
    headerColor: 'E2E8F0',
    headerTextColor: '0F172A',
    stripeColor: 'FFFFFF',
  );

  final String title;
  final String subtitle;
  final String headerColor;
  final String headerTextColor;
  final String stripeColor;

  const ExcelTableTheme({
    required this.title,
    required this.subtitle,
    required this.headerColor,
    required this.headerTextColor,
    required this.stripeColor,
  });
}

enum ExcelPageSelectionMode {
  all,
  custom,
  range,
}

class ParsedTableRow {
  final List<String> cells;
  ParsedTableRow(this.cells);
}

class PdfToExcelController extends GetxController {
  // Document state
  final selectedPdfPath = RxnString();
  final selectedPdfName = RxnString();
  final fileSizeInBytes = 0.obs;
  final pageCount = 0.obs;

  PdfDocument? _pdfDoc;

  // Settings
  final workbookTitle = ''.obs;
  final workbookLayout = ExcelWorkbookLayout.singleConsolidated.obs;
  final tableTheme = ExcelTableTheme.emerald.obs;
  final autoDetectNumbers = true.obs;

  // Page Selection
  final selectionMode = ExcelPageSelectionMode.all.obs;
  final selectedPages = <int>{}.obs; // 0-indexed
  final rangeStart = 1.obs;
  final rangeEnd = 1.obs;

  // UI state
  final isPicking = false.obs;
  final isLoadingDoc = false.obs;
  final isConverting = false.obs;
  final conversionProgress = 0.0.obs;
  final statusMessage = 'Ready'.obs;
  final pageThumbnails = <int, Uint8List>{}.obs;
  final previewRows = <List<String>>[].obs;

  // Results state
  final convertedXlsxPath = RxnString();
  final convertedXlsxSize = 0.obs;
  final totalRowsExtracted = 0.obs;
  final totalSheetsCreated = 0.obs;

  String get formattedPdfSize {
    final bytes = fileSizeInBytes.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedXlsxSize {
    final bytes = convertedXlsxSize.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  int get effectiveSelectedCount {
    if (pageCount.value <= 0) return 0;
    switch (selectionMode.value) {
      case ExcelPageSelectionMode.all:
        return pageCount.value;
      case ExcelPageSelectionMode.custom:
        return selectedPages.length;
      case ExcelPageSelectionMode.range:
        final start = rangeStart.value.clamp(1, pageCount.value);
        final end = rangeEnd.value.clamp(start, pageCount.value);
        return (end - start + 1);
    }
  }

  List<int> get effectiveSelectedPageIndices {
    if (pageCount.value <= 0) return [];
    switch (selectionMode.value) {
      case ExcelPageSelectionMode.all:
        return List.generate(pageCount.value, (i) => i);
      case ExcelPageSelectionMode.custom:
        final sorted = selectedPages.toList()..sort();
        return sorted;
      case ExcelPageSelectionMode.range:
        final start = rangeStart.value.clamp(1, pageCount.value);
        final end = rangeEnd.value.clamp(start, pageCount.value);
        return List.generate(end - start + 1, (i) => start - 1 + i);
    }
  }

  @override
  void onClose() {
    _cleanupPdfDoc();
    super.onClose();
  }

  void _cleanupPdfDoc() {
    try {
      _pdfDoc?.close();
    } catch (_) {}
    _pdfDoc = null;
  }

  // ── 1. Pick PDF File ───────────────────────────────────────────────────────
  Future<void> pickPdfFile() async {
    try {
      isPicking.value = true;
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isEmpty || result.first.path == null) return;

      final path = result.first.path!;
      final name = result.first.name;
      await loadPdf(path, fileName: name);
    } catch (e) {
      log('[PdfToExcel] pickPdfFile error: $e');
      MyDialogs.info(msg: 'Failed to select PDF: $e');
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> loadPdf(String path, {String? fileName}) async {
    try {
      isLoadingDoc.value = true;
      _cleanupPdfDoc();
      convertedXlsxPath.value = null;
      convertedXlsxSize.value = 0;
      pageThumbnails.clear();
      previewRows.clear();

      final file = File(path);
      if (!await file.exists()) {
        MyDialogs.info(msg: 'File does not exist.');
        return;
      }

      final size = await file.length();
      selectedPdfPath.value = path;
      final name = fileName ?? path.split(Platform.pathSeparator).last;
      selectedPdfName.value = name;
      fileSizeInBytes.value = size;

      workbookTitle.value = name
          .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
          .replaceAll('_', ' ');

      _pdfDoc = await PdfDocument.openFile(path);
      final count = _pdfDoc!.pagesCount;
      pageCount.value = count;

      selectedPages.clear();
      for (int i = 0; i < count; i++) {
        selectedPages.add(i);
      }
      rangeStart.value = 1;
      rangeEnd.value = count.clamp(1, 99999);
      selectionMode.value = ExcelPageSelectionMode.all;

      // Extract sample text for table preview
      try {
        final text = await ReadPdfText.getPDFtext(path);
        final sampleTable = _parseTextToTable(text);
        if (sampleTable.isNotEmpty) {
          previewRows.value = sampleTable.take(5).map((r) => r.cells).toList();
        }
      } catch (_) {}

      _loadThumbnailsInBackground();
    } catch (e) {
      log('[PdfToExcel] loadPdf error: $e');
      MyDialogs.info(msg: 'Failed to open PDF: $e');
    } finally {
      isLoadingDoc.value = false;
    }
  }

  Future<void> _loadThumbnailsInBackground() async {
    if (_pdfDoc == null) return;
    final total = pageCount.value;

    for (int i = 0; i < total; i++) {
      if (selectedPdfPath.value == null) break;
      if (pageThumbnails.containsKey(i)) continue;

      try {
        final page = await _pdfDoc!.getPage(i + 1);
        final thumb = await page.render(
          width: 180,
          height: (180 * (page.height / page.width)),
          format: PdfPageImageFormat.jpeg,
          quality: 60,
          backgroundColor: '#FFFFFF',
        );
        await page.close();

        if (thumb != null) {
          pageThumbnails[i] = thumb.bytes;
        }
      } catch (e) {
        log('[PdfToExcel] render thumb $i error: $e');
      }
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  // ── Selection controls ───────────────────────────────────────────────────
  void togglePageSelection(int pageIndex) {
    if (selectedPages.contains(pageIndex)) {
      if (selectedPages.length > 1) {
        selectedPages.remove(pageIndex);
      } else {
        MyDialogs.info(msg: 'At least one page must be selected.');
      }
    } else {
      selectedPages.add(pageIndex);
    }
  }

  void selectAllPages() {
    selectedPages.clear();
    for (int i = 0; i < pageCount.value; i++) {
      selectedPages.add(i);
    }
  }

  void deselectAllPages() {
    if (pageCount.value > 0) {
      selectedPages.clear();
      selectedPages.add(0);
    }
  }

  void setRange(int start, int end) {
    final count = pageCount.value;
    if (count <= 0) return;
    rangeStart.value = start.clamp(1, count);
    rangeEnd.value = end.clamp(rangeStart.value, count);
  }

  // ── 2. Convert PDF to Excel (.xlsx) ──────────────────────────────────────
  Future<void> convertPdfToExcel() async {
    final pdfPath = selectedPdfPath.value;
    if (pdfPath == null || !File(pdfPath).existsSync()) {
      MyDialogs.info(msg: 'Please select a valid PDF file first.');
      return;
    }

    final pages = effectiveSelectedPageIndices;
    if (pages.isEmpty) {
      MyDialogs.info(msg: 'Please select at least one page to convert.');
      return;
    }

    try {
      isConverting.value = true;
      conversionProgress.value = 0.15;
      statusMessage.value = 'Extracting table data and rows from PDF...';

      // 1. Extract Paginated Text
      List<String> pagesText = [];
      try {
        pagesText = await ReadPdfText.getPDFtextPaginated(pdfPath);
      } catch (e) {
        log('[PdfToExcel] paginated extraction failed: $e');
      }

      while (pagesText.length < pageCount.value) {
        pagesText.add('');
      }

      conversionProgress.value = 0.50;
      statusMessage.value = 'Structuring tabular columns & values...';

      // 2. Parse text into structured table rows for each page
      final List<List<ParsedTableRow>> sheetsData = [];
      int totalRows = 0;

      if (workbookLayout.value == ExcelWorkbookLayout.singleConsolidated) {
        final List<ParsedTableRow> consolidatedRows = [];
        for (final pageIdx in pages) {
          final text = pagesText.length > pageIdx ? pagesText[pageIdx] : '';
          final rows = _parseTextToTable(text);
          if (rows.isNotEmpty) {
            consolidatedRows.addAll(rows);
          }
        }

        if (consolidatedRows.isEmpty) {
          consolidatedRows.add(ParsedTableRow(['Document Content', 'Extracted from ${selectedPdfName.value}']));
        }

        sheetsData.add(consolidatedRows);
        totalRows = consolidatedRows.length;
      } else {
        for (int i = 0; i < pages.length; i++) {
          final pageIdx = pages[i];
          final text = pagesText.length > pageIdx ? pagesText[pageIdx] : '';
          final rows = _parseTextToTable(text);
          if (rows.isNotEmpty) {
            sheetsData.add(rows);
            totalRows += rows.length;
          } else {
            sheetsData.add([ParsedTableRow(['Page ${pageIdx + 1}', 'No extractable table text'])]);
            totalRows += 1;
          }
        }
      }

      conversionProgress.value = 0.75;
      statusMessage.value = 'Compiling OpenXML Spreadsheet (.xlsx)...';

      // 3. Build Standard OpenXML .xlsx archive
      final xlsxBytes = _buildXlsxArchive(
        title: workbookTitle.value.trim().isEmpty ? 'Spreadsheet' : workbookTitle.value.trim(),
        sheetsData: sheetsData,
        layout: workbookLayout.value,
        theme: tableTheme.value,
        autoNumbers: autoDetectNumbers.value,
      );

      conversionProgress.value = 0.90;
      statusMessage.value = 'Saving Excel workbook...';

      final tempDir = await getTemporaryDirectory();
      final safeName = (workbookTitle.value.trim().isEmpty
              ? 'spreadsheet'
              : workbookTitle.value.trim())
          .replaceAll(RegExp(r'[^\w\s-]'), '_')
          .replaceAll(' ', '_');
      final outputPath = '${tempDir.path}/$safeName.xlsx';

      final outFile = File(outputPath);
      await outFile.writeAsBytes(xlsxBytes, flush: true);

      conversionProgress.value = 1.0;
      statusMessage.value = 'Excel Workbook Created!';

      convertedXlsxPath.value = outputPath;
      convertedXlsxSize.value = await outFile.length();
      totalRowsExtracted.value = totalRows;
      totalSheetsCreated.value = sheetsData.length;

      MyDialogs.success(
        msg: 'Converted to Excel (.xlsx) successfully! ($totalRows rows extracted)',
      );
    } catch (e, stack) {
      log('[PdfToExcel] convert error: $e\n$stack');
      MyDialogs.info(msg: 'Conversion failed: $e');
    } finally {
      isConverting.value = false;
    }
  }

  // ── 3. Table Extraction Parser ────────────────────────────────────────────
  List<ParsedTableRow> _parseTextToTable(String rawText) {
    final results = <ParsedTableRow>[];
    if (rawText.trim().isEmpty) return results;

    final lines = rawText.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      List<String> columns = [];

      // 1. Check for tab separation
      if (trimmed.contains('\t')) {
        columns = trimmed.split('\t').map((c) => c.trim()).toList();
      }
      // 2. Check for pipe separation (| Table | Format |)
      else if (trimmed.contains('|')) {
        columns = trimmed
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty && !c.startsWith('---'))
            .toList();
      }
      // 3. Check for comma or semicolon separation
      else if (trimmed.contains(',') && !RegExp(r'^\d+,\d+$').hasMatch(trimmed)) {
        columns = trimmed.split(',').map((c) => c.trim()).toList();
      }
      // 4. Check for multi-space separation (e.g. 2 or more consecutive spaces)
      else if (RegExp(r'\s{2,}').hasMatch(trimmed)) {
        columns = trimmed.split(RegExp(r'\s{2,}')).map((c) => c.trim()).toList();
      } else {
        // Single column fallback
        columns = [trimmed];
      }

      if (columns.isNotEmpty && columns.any((c) => c.isNotEmpty)) {
        results.add(ParsedTableRow(columns));
      }
    }
    return results;
  }

  // ── 4. OpenXML XLSX Package Builder ───────────────────────────────────────
  List<int> _buildXlsxArchive({
    required String title,
    required List<List<ParsedTableRow>> sheetsData,
    required ExcelWorkbookLayout layout,
    required ExcelTableTheme theme,
    required bool autoNumbers,
  }) {
    final archive = Archive();
    final sheetCount = sheetsData.length;

    // 1. [Content_Types].xml
    final ct = StringBuffer();
    ct.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    ct.write('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n');
    ct.write('  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n');
    ct.write('  <Default Extension="xml" ContentType="application/xml"/>\n');
    ct.write('  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\n');
    ct.write('  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>\n');
    ct.write('  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>\n');
    ct.write('  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>\n');

    for (int i = 1; i <= sheetCount; i++) {
      ct.write('  <Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\n');
    }
    ct.write('</Types>');
    final ctBytes = utf8.encode(ct.toString());
    archive.addFile(ArchiveFile('[Content_Types].xml', ctBytes.length, ctBytes));

    // 2. _rels/.rels
    const rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\n'
        '  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>\n'
        '  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>\n'
        '</Relationships>';
    final rootRelsBytes = utf8.encode(rootRels);
    archive.addFile(ArchiveFile('_rels/.rels', rootRelsBytes.length, rootRelsBytes));

    // 3. docProps/core.xml & app.xml
    final coreXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">\n'
        '  <dc:title>${_xmlEscape(title)}</dc:title>\n'
        '  <dc:creator>Translator Ably</dc:creator>\n'
        '  <cp:lastModifiedBy>Translator Ably</cp:lastModifiedBy>\n'
        '  <dcterms:created xsi:type="dcterms:W3CDTF">${DateTime.now().toUtc().toIso8601String()}</dcterms:created>\n'
        '</cp:coreProperties>';
    final coreBytes = utf8.encode(coreXml);
    archive.addFile(ArchiveFile('docProps/core.xml', coreBytes.length, coreBytes));

    final appXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">\n'
        '  <Application>Translator Ably PDF to Excel</Application>\n'
        '  <DocSecurity>0</DocSecurity>\n'
        '  <ScaleCrop>false</ScaleCrop>\n'
        '  <HeadingPairs><vt:vector size="2" baseType="variant"><vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant><vt:variant><vt:i4>$sheetCount</vt:i4></vt:variant></vt:vector></HeadingPairs>\n'
        '</Properties>';
    final appBytes = utf8.encode(appXml);
    archive.addFile(ArchiveFile('docProps/app.xml', appBytes.length, appBytes));

    // 4. xl/styles.xml (Professional fonts, header colors, zebra rows, borders)
    _addStyles(archive, theme);

    // 5. xl/workbook.xml & rels
    final wbXml = StringBuffer();
    wbXml.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    wbXml.write('<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\n');
    wbXml.write('  <sheets>\n');

    for (int i = 1; i <= sheetCount; i++) {
      final sheetName = layout == ExcelWorkbookLayout.singleConsolidated
          ? 'Data Sheet'
          : 'Page $i';
      wbXml.write('    <sheet name="$sheetName" sheetId="$i" r:id="rIdSheet$i"/>\n');
    }
    wbXml.write('  </sheets>\n');
    wbXml.write('</workbook>');
    final wbBytes = utf8.encode(wbXml.toString());
    archive.addFile(ArchiveFile('xl/workbook.xml', wbBytes.length, wbBytes));

    // xl/_rels/workbook.xml.rels
    final wbRels = StringBuffer();
    wbRels.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    wbRels.write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n');
    wbRels.write('  <Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>\n');
    for (int i = 1; i <= sheetCount; i++) {
      wbRels.write('  <Relationship Id="rIdSheet$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>\n');
    }
    wbRels.write('</Relationships>');
    final wbRelsBytes = utf8.encode(wbRels.toString());
    archive.addFile(ArchiveFile('xl/_rels/workbook.xml.rels', wbRelsBytes.length, wbRelsBytes));

    // 6. xl/worksheets/sheet{N}.xml
    for (int s = 0; s < sheetCount; s++) {
      final sheetNum = s + 1;
      final rows = sheetsData[s];
      final sheetXml = _buildWorksheetXml(rows, autoNumbers);
      final sBytes = utf8.encode(sheetXml);
      archive.addFile(ArchiveFile('xl/worksheets/sheet$sheetNum.xml', sBytes.length, sBytes));
    }

    final encoder = ZipEncoder();
    return encoder.encode(archive);
  }

  void _addStyles(Archive archive, ExcelTableTheme theme) {
    final stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="3">
    <!-- 0: Normal Font -->
    <font><sz val="11"/><color rgb="0F172A"/><name val="Calibri"/><family val="2"/></font>
    <!-- 1: Header Font Bold -->
    <font><b/><sz val="11"/><color rgb="${theme.headerTextColor}"/><name val="Calibri"/><family val="2"/></font>
    <!-- 2: Title Font -->
    <font><b/><sz val="14"/><color rgb="0F172A"/><name val="Calibri"/><family val="2"/></font>
  </fonts>
  <fills count="4">
    <!-- 0: None -->
    <fill><patternFill patternType="none"/></fill>
    <!-- 1: Gray125 -->
    <fill><patternFill patternType="gray125"/></fill>
    <!-- 2: Header Fill -->
    <fill><patternFill patternType="solid"><fgColor rgb="${theme.headerColor}"/><bgColor indexed="64"/></patternFill></fill>
    <!-- 3: Stripe Fill -->
    <fill><patternFill patternType="solid"><fgColor rgb="${theme.stripeColor}"/><bgColor indexed="64"/></patternFill></fill>
  </fills>
  <borders count="2">
    <!-- 0: No border -->
    <border><left/><right/><top/><bottom/><diagonal/></border>
    <!-- 1: Thin border -->
    <border>
      <left style="thin"><color rgb="CBD5E1"/></left>
      <right style="thin"><color rgb="CBD5E1"/></right>
      <top style="thin"><color rgb="CBD5E1"/></top>
      <bottom style="thin"><color rgb="CBD5E1"/></bottom>
    </border>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs count="4">
    <!-- 0: Default Cell -->
    <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/>
    <!-- 1: Header Cell -->
    <xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">
      <alignment horizontal="center" vertical="center"/>
    </xf>
    <!-- 2: Stripe Cell -->
    <xf numFmtId="0" fontId="0" fillId="3" borderId="1" xfId="0" applyFill="1" applyBorder="1"/>
    <!-- 3: Number/Currency Cell Right Aligned -->
    <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1">
      <alignment horizontal="right"/>
    </xf>
  </cellXfs>
</styleSheet>''';
    final bytes = utf8.encode(stylesXml);
    archive.addFile(ArchiveFile('xl/styles.xml', bytes.length, bytes));
  }

  String _buildWorksheetXml(List<ParsedTableRow> rows, bool autoNumbers) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\n');

    // Calculate max columns for column widths
    int maxCols = 1;
    for (final r in rows) {
      if (r.cells.length > maxCols) maxCols = r.cells.length;
    }

    buffer.write('  <cols>\n');
    for (int col = 1; col <= maxCols; col++) {
      buffer.write('    <col min="$col" max="$col" width="22" customWidth="1"/>\n');
    }
    buffer.write('  </cols>\n');

    buffer.write('  <sheetData>\n');

    for (int r = 0; r < rows.length; r++) {
      final rowNum = r + 1;
      final rowData = rows[r];
      final isHeader = (r == 0);
      final isStripe = (r % 2 == 1 && !isHeader);

      buffer.write('    <row r="$rowNum">\n');

      for (int c = 0; c < rowData.cells.length; c++) {
        final cellRef = '${_colLetter(c)}$rowNum';
        final rawVal = rowData.cells[c];
        final cleanVal = rawVal.trim();

        int styleId = 0;
        if (isHeader) {
          styleId = 1; // Header style
        } else if (isStripe) {
          styleId = 2; // Stripe style
        }

        // Check if numeric
        final numVal = double.tryParse(cleanVal.replaceAll(',', '').replaceAll('\$', '').replaceAll('₹', ''));
        final isNumeric = autoNumbers && !isHeader && numVal != null && cleanVal.length < 16;

        if (isNumeric) {
          if (!isStripe && !isHeader) styleId = 3;
          buffer.write('      <c r="$cellRef" s="$styleId"><v>$numVal</v></c>\n');
        } else {
          buffer.write('      <c r="$cellRef" t="inlineStr" s="$styleId"><is><t>${_xmlEscape(cleanVal)}</t></is></c>\n');
        }
      }

      buffer.write('    </row>\n');
    }

    buffer.write('  </sheetData>\n');
    buffer.write('</worksheet>');
    return buffer.toString();
  }

  String _colLetter(int colIndex) {
    int col = colIndex + 1;
    String letter = '';
    while (col > 0) {
      int rem = (col - 1) % 26;
      letter = String.fromCharCode(65 + rem) + letter;
      col = (col - rem) ~/ 26;
    }
    return letter;
  }

  String _xmlEscape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  // ── 5. Sharing & Saving ──────────────────────────────────────────────────
  Future<void> shareExcel() async {
    final path = convertedXlsxPath.value;
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await Share.shareXFiles(
          [
            XFile(
              path,
              name: '${workbookTitle.value}.xlsx',
              mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            )
          ],
          text: 'Excel Spreadsheet: "${workbookTitle.value}" ($formattedXlsxSize)',
        );
      }
    } catch (e) {
      log('[PdfToExcel] share error: $e');
      MyDialogs.info(msg: 'Failed to share Excel file: $e');
    }
  }

  Future<void> saveToDownloads() async {
    final path = convertedXlsxPath.value;
    if (path == null) return;
    try {
      Directory? targetDir;
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          targetDir = Directory('${downloadDir.path}/TranslatorAbly');
        } else {
          targetDir = await getExternalStorageDirectory();
        }
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      targetDir ??= await getApplicationDocumentsDirectory();

      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final source = File(path);
      if (await source.exists()) {
        final fileName = '${workbookTitle.value.trim().replaceAll(RegExp(r'[^\w\s-]'), '_')}.xlsx';
        final dest = File('${targetDir.path}/$fileName');
        await source.copy(dest.path);
        MyDialogs.success(
          msg: 'Saved "$fileName" to ${targetDir.path.split(Platform.pathSeparator).last}!',
        );
      }
    } catch (e) {
      log('[PdfToExcel] saveToDownloads error: $e');
      MyDialogs.info(msg: 'Saved to app storage (Path: $e)');
    }
  }

  void reset() {
    _cleanupPdfDoc();
    selectedPdfPath.value = null;
    selectedPdfName.value = null;
    fileSizeInBytes.value = 0;
    pageCount.value = 0;
    workbookTitle.value = '';
    convertedXlsxPath.value = null;
    convertedXlsxSize.value = 0;
    pageThumbnails.clear();
    previewRows.clear();
    selectedPages.clear();
    selectionMode.value = ExcelPageSelectionMode.all;
    conversionProgress.value = 0.0;
    statusMessage.value = 'Ready';
  }
}
