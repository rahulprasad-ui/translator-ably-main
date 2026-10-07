// lib/controllers/excel_to_pdf_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../ads/ad_helper.dart';
import '../helper/my_dialogs.dart';

// ── Models & Enums ──────────────────────────────────────────────────────────

enum ExcelPdfPageOrientation {
  landscape('Landscape (Recommended)', 'Wide layout to fit tabular columns comfortably'),
  portrait('Portrait', 'Vertical layout for tall narrow tables');

  final String title;
  final String subtitle;
  const ExcelPdfPageOrientation(this.title, this.subtitle);
}

enum ExcelPdfPageSize {
  a4('A4', 'Standard international paper (297 × 210 mm)'),
  a3('A3 (Wide Tables)', 'Double-width sheet for large 10+ column tables'),
  letter('US Letter', 'Standard US document format (11 × 8.5 in)');

  final String title;
  final String subtitle;
  const ExcelPdfPageSize(this.title, this.subtitle);
}

enum ExcelPdfTableTheme {
  excelGreen('Excel Green', 'Official Microsoft Excel green header with soft mint striping', 0xFF107C41, 0xFFF0FDF4),
  corporateSlate('Corporate Slate', 'Dark slate navy header with clean grey alternating rows', 0xFF1E293B, 0xFFF8FAFC),
  cleanGrid('Minimal Grid', 'Clean border lines without background fills', 0xFF475569, 0xFFFFFFFF);

  final String title;
  final String subtitle;
  final int headerColor;
  final int stripeColor;
  const ExcelPdfTableTheme(this.title, this.subtitle, this.headerColor, this.stripeColor);
}

class ExcelSheetData {
  final String name;
  final List<List<String>> rows;
  final int totalCols;

  ExcelSheetData({
    required this.name,
    required this.rows,
    required this.totalCols,
  });

  int get rowCount => rows.length;
}

// ── Controller Implementation ───────────────────────────────────────────────

class ExcelToPdfController extends GetxController {
  // Source Spreadsheet state
  final selectedFilePath = RxnString();
  final selectedFileName = RxnString();
  final fileSizeInBytes = 0.obs;
  final isXlsxFormat = true.obs;

  // Extracted sheets
  final sheets = <ExcelSheetData>[].obs;
  final selectedSheetIndex = 0.obs;
  final totalCellsCount = 0.obs;

  // Settings
  final selectedOrientation = ExcelPdfPageOrientation.landscape.obs;
  final selectedPageSize = ExcelPdfPageSize.a4.obs;
  final selectedTheme = ExcelPdfTableTheme.excelGreen.obs;
  final fitColumnsOnOnePage = true.obs;
  final includeSheetTitle = true.obs;
  final includePageNumbers = true.obs;
  final printGridlines = true.obs;
  final convertAllSheets = true.obs;

  // UI state
  final isPicking = false.obs;
  final isParsing = false.obs;
  final isConverting = false.obs;
  final conversionProgress = 0.0.obs;
  final statusMessage = 'Ready'.obs;

  // Result state
  final convertedPdfPath = RxnString();
  final convertedPdfSize = 0.obs;
  final convertedPageCount = 0.obs;
  final previewThumbnailBytes = Rxn<Uint8List>();

  String get formattedFileSize {
    final bytes = fileSizeInBytes.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedConvertedSize {
    final bytes = convertedPdfSize.value;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  // ── 1. Pick Excel File (.xlsx, .xls, .csv) ────────────────────────────────
  Future<void> pickExcelFile() async {
    try {
      isPicking.value = true;
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv', 'tsv', 'XLSX', 'XLS', 'CSV'],
      );

      if (result.isEmpty) return;
      final path = result.first.path;
      if (path == null) return;

      await loadExcelFile(path, fileName: result.first.name);
    } catch (e) {
      log('[ExcelToPdf] pickExcelFile error: $e');
      MyDialogs.info(msg: 'Failed to pick spreadsheet: $e');
    } finally {
      isPicking.value = false;
    }
  }

  // ── 2. Load and Parse Spreadsheet ─────────────────────────────────────────
  Future<void> loadExcelFile(String path, {String? fileName}) async {
    try {
      isParsing.value = true;
      statusMessage.value = 'Reading spreadsheet...';
      final file = File(path);
      if (!await file.exists()) {
        MyDialogs.info(msg: 'Selected file does not exist');
        return;
      }

      selectedFilePath.value = path;
      selectedFileName.value =
          fileName ?? path.split(Platform.pathSeparator).last;
      fileSizeInBytes.value = await file.length();

      // Reset previous results
      convertedPdfPath.value = null;
      convertedPdfSize.value = 0;
      convertedPageCount.value = 0;
      previewThumbnailBytes.value = null;
      sheets.clear();

      final lowerName = selectedFileName.value!.toLowerCase();
      final isXlsx = lowerName.endsWith('.xlsx');
      isXlsxFormat.value = isXlsx;

      final bytes = await file.readAsBytes();
      List<ExcelSheetData> parsedSheets = [];

      if (isXlsx) {
        parsedSheets = await _parseXlsxBytes(bytes);
      } else if (lowerName.endsWith('.csv') || lowerName.endsWith('.tsv')) {
        parsedSheets = await _parseCsvBytes(bytes, isTsv: lowerName.endsWith('.tsv'));
      } else {
        parsedSheets = await _parseLegacyXlsBytes(bytes);
      }

      if (parsedSheets.isEmpty) {
        parsedSheets = [
          ExcelSheetData(
            name: 'Sheet1',
            rows: [
              ['Col 1', 'Col 2', 'Col 3'],
              ['Data 1', 'Data 2', 'Data 3'],
            ],
            totalCols: 3,
          )
        ];
      }

      sheets.value = parsedSheets;
      selectedSheetIndex.value = 0;

      int cells = 0;
      for (final sh in parsedSheets) {
        for (final r in sh.rows) {
          cells += r.length;
        }
      }
      totalCellsCount.value = cells;
      statusMessage.value = 'Ready to convert';
    } catch (e) {
      log('[ExcelToPdf] loadExcelFile error: $e');
      MyDialogs.info(msg: 'Failed to read spreadsheet: $e');
    } finally {
      isParsing.value = false;
    }
  }

  // ── 3. Parse .xlsx OpenXML Archive ────────────────────────────────────────
  Future<List<ExcelSheetData>> _parseXlsxBytes(Uint8List bytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      ArchiveFile? findZipFile(String path) {
        final lower = path.toLowerCase().replaceAll('\\', '/');
        for (final f in archive.files) {
          final fLower = f.name.toLowerCase().replaceAll('\\', '/');
          if (fLower == lower || fLower.endsWith('/$lower') || fLower == 'xl/$lower') {
            return f;
          }
        }
        return null;
      }

      // 1. Parse Shared Strings (xl/sharedStrings.xml)
      final sharedStrings = <String>[];
      final ssFile = findZipFile('xl/sharedStrings.xml') ?? findZipFile('sharedstrings.xml');
      if (ssFile != null) {
        final ssXml = utf8.decode(ssFile.content as List<int>, allowMalformed: true);
        final siRegex = RegExp(r'<si[\s>].*?<\/si>', dotAll: true);
        for (final siMatch in siRegex.allMatches(ssXml)) {
          final siContent = siMatch.group(0)!;
          final tMatches = RegExp(r'<t[^>]*>(.*?)<\/t>', dotAll: true).allMatches(siContent);
          if (tMatches.isNotEmpty) {
            final combined = tMatches.map((m) => _xmlUnescape(m.group(1)!)).join();
            sharedStrings.add(combined);
          } else {
            sharedStrings.add('');
          }
        }
      }

      // 2. Parse Sheet Names & Relationship IDs from xl/workbook.xml
      final sheetEntries = <Map<String, String>>[];
      final wbFile = findZipFile('xl/workbook.xml') ?? findZipFile('workbook.xml');
      if (wbFile != null) {
        final wbXml = utf8.decode(wbFile.content as List<int>, allowMalformed: true);
        final sheetTagRegex = RegExp(
            r'<sheet\s+[^>]*name="([^"]+)"[^>]*sheetId="([^"]+)"(?:[^>]*r:id="([^"]+)")?',
            dotAll: true);
        for (final m in sheetTagRegex.allMatches(wbXml)) {
          sheetEntries.add({
            'name': m.group(1)!,
            'sheetId': m.group(2)!,
            'rId': m.group(3) ?? '',
          });
        }
      }

      // If no sheets found in workbook.xml, discover directly from zip files
      if (sheetEntries.isEmpty) {
        int index = 1;
        for (final f in archive.files) {
          final n = f.name.toLowerCase().replaceAll('\\', '/');
          if ((n.contains('worksheets/sheet') || n.contains('worksheets/')) && n.endsWith('.xml')) {
            sheetEntries.add({'name': 'Sheet$index', 'path': f.name});
            index++;
          }
        }
      }

      final resultSheets = <ExcelSheetData>[];

      for (int i = 0; i < sheetEntries.length; i++) {
        final entry = sheetEntries[i];
        final sheetName = entry['name'] ?? 'Sheet${i + 1}';
        final customPath = entry['path'];

        ArchiveFile? sheetFile;
        if (customPath != null) {
          sheetFile = findZipFile(customPath);
        }
        sheetFile ??= findZipFile('xl/worksheets/sheet${i + 1}.xml') ??
            findZipFile('worksheets/sheet${i + 1}.xml') ??
            findZipFile('sheet${i + 1}.xml');

        if (sheetFile == null) {
          final wsFiles = archive.files.where((f) {
            final n = f.name.toLowerCase().replaceAll('\\', '/');
            return n.contains('worksheets/') && n.endsWith('.xml');
          }).toList();
          if (i < wsFiles.length) {
            sheetFile = wsFiles[i];
          }
        }

        if (sheetFile == null) continue;

        final sheetXml = utf8.decode(sheetFile.content as List<int>, allowMalformed: true);
        final sheetData = _parseSheetXml(sheetXml, sheetName, sharedStrings);
        if (sheetData.rows.isNotEmpty) {
          resultSheets.add(sheetData);
        }
      }

      return resultSheets;
    } catch (e) {
      log('[ExcelToPdf] _parseXlsxBytes error: $e');
      return [];
    }
  }

  ExcelSheetData _parseSheetXml(String xml, String name, List<String> sharedStrings) {
    final rows = <List<String>>[];
    int maxCols = 0;

    final rowRegex = RegExp(r'<row\s+[^>]*r="(\d+)"[^>]*>(.*?)<\/row>', dotAll: true);
    final rowMatches = rowRegex.allMatches(xml);

    for (final rMatch in rowMatches) {
      final rowXml = rMatch.group(2)!;
      final cellMap = <int, String>{}; // colIndex (0-based) -> value

      final cellRegex = RegExp(r'<c\s+[^>]*r="([A-Z]+)(\d+)"([^>]*)>(.*?)<\/c>', dotAll: true);
      for (final cMatch in cellRegex.allMatches(rowXml)) {
        final colLetters = cMatch.group(1)!;
        final colIndex = _colLettersToIndex(colLetters);
        final attr = cMatch.group(3)!;
        final inner = cMatch.group(4)!;

        final isShared = attr.contains('t="s"');
        final isInline = attr.contains('t="inlineStr"');

        String cellVal = '';
        if (isShared) {
          final vMatch = RegExp(r'<v>(.*?)<\/v>').firstMatch(inner);
          if (vMatch != null) {
            final idx = int.tryParse(vMatch.group(1)!) ?? -1;
            if (idx >= 0 && idx < sharedStrings.length) {
              cellVal = sharedStrings[idx];
            }
          }
        } else if (isInline) {
          final tMatch = RegExp(r'<t[^>]*>(.*?)<\/t>').firstMatch(inner);
          if (tMatch != null) cellVal = _xmlUnescape(tMatch.group(1)!);
        } else {
          final vMatch = RegExp(r'<v>(.*?)<\/v>').firstMatch(inner);
          if (vMatch != null) {
            cellVal = _xmlUnescape(vMatch.group(1)!);
          }
        }

        cellMap[colIndex] = cellVal.trim();
        if (colIndex + 1 > maxCols) maxCols = colIndex + 1;
      }

      if (cellMap.isNotEmpty && cellMap.values.any((v) => v.isNotEmpty)) {
        final rowList = <String>[];
        for (int c = 0; c < maxCols; c++) {
          rowList.add(cellMap[c] ?? '');
        }
        rows.add(rowList);
      }
    }

    // Normalize all rows to maxCols
    for (int i = 0; i < rows.length; i++) {
      while (rows[i].length < maxCols) {
        rows[i].add('');
      }
    }

    return ExcelSheetData(
      name: name,
      rows: rows,
      totalCols: maxCols,
    );
  }

  int _colLettersToIndex(String letters) {
    int index = 0;
    for (int i = 0; i < letters.length; i++) {
      index = index * 26 + (letters.codeUnitAt(i) - 64);
    }
    return index - 1; // 0-based
  }

  // ── 4. Parse CSV / TSV ────────────────────────────────────────────────────
  Future<List<ExcelSheetData>> _parseCsvBytes(Uint8List bytes, {bool isTsv = false}) async {
    final delimiter = isTsv ? '\t' : ',';
    final text = utf8.decode(bytes, allowMalformed: true);
    final lines = text.split(RegExp(r'\r?\n'));
    final rows = <List<String>>[];
    int maxCols = 0;

    for (final l in lines) {
      if (l.trim().isEmpty) continue;
      final cells = _splitCsvLine(l, delimiter);
      if (cells.length > maxCols) maxCols = cells.length;
      rows.add(cells);
    }

    for (int i = 0; i < rows.length; i++) {
      while (rows[i].length < maxCols) {
        rows[i].add('');
      }
    }

    return [
      ExcelSheetData(
        name: isTsv ? 'TSV Data' : 'CSV Data',
        rows: rows,
        totalCols: maxCols,
      )
    ];
  }

  List<String> _splitCsvLine(String line, String delimiter) {
    final cells = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == delimiter && !inQuotes) {
        cells.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    cells.add(sb.toString().trim());
    return cells;
  }

  // ── 5. Fallback Parser for Legacy .xls ─────────────────────────────────────
  Future<List<ExcelSheetData>> _parseLegacyXlsBytes(Uint8List bytes) async {
    final sb = StringBuffer();
    for (int i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      if ((b >= 32 && b <= 126) || b == 9 || b == 10 || b == 13) {
        sb.writeCharCode(b);
      } else if (b == 0 && sb.isNotEmpty && !sb.toString().endsWith(' ')) {
        sb.write(' ');
      }
    }

    final raw = sb.toString();
    final lines = raw.split(RegExp(r'\r?\n'));
    final rows = <List<String>>[];
    int maxCols = 0;

    for (final l in lines) {
      final trimmed = l.trim();
      if (trimmed.length < 3) continue;
      final tokens = trimmed.split(RegExp(r'\s{2,}|\t'));
      if (tokens.length >= 2) {
        if (tokens.length > maxCols) maxCols = tokens.length;
        rows.add(tokens);
      }
    }

    for (int i = 0; i < rows.length; i++) {
      while (rows[i].length < maxCols) {
        rows[i].add('');
      }
    }

    return [
      ExcelSheetData(
        name: 'Sheet1',
        rows: rows,
        totalCols: maxCols,
      )
    ];
  }

  String _xmlUnescape(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  // ── 6. Convert Excel to PDF Document ──────────────────────────────────────
  Future<String?> convertToPdf() async {
    if (selectedFilePath.value == null || sheets.isEmpty) {
      MyDialogs.info(msg: 'Please select a valid spreadsheet first');
      return null;
    }

    try {
      isConverting.value = true;
      conversionProgress.value = 0.15;
      statusMessage.value = 'Preparing PDF spreadsheet grid...';

      final pdfDoc = pw.Document(
        title: selectedFileName.value ?? 'Spreadsheet Document',
        author: 'Translator Ably',
        creator: 'Excel to PDF Converter',
      );

      // Determine Page Format & Dimensions
      pw_pdf.PdfPageFormat format;
      switch (selectedPageSize.value) {
        case ExcelPdfPageSize.a3:
          format = selectedOrientation.value == ExcelPdfPageOrientation.landscape
              ? pw_pdf.PdfPageFormat.a3.landscape
              : pw_pdf.PdfPageFormat.a3;
          break;
        case ExcelPdfPageSize.letter:
          format = selectedOrientation.value == ExcelPdfPageOrientation.landscape
              ? pw_pdf.PdfPageFormat.letter.landscape
              : pw_pdf.PdfPageFormat.letter;
          break;
        case ExcelPdfPageSize.a4:
        default:
          format = selectedOrientation.value == ExcelPdfPageOrientation.landscape
              ? pw_pdf.PdfPageFormat.a4.landscape
              : pw_pdf.PdfPageFormat.a4;
          break;
      }

      final theme = selectedTheme.value;
      final headerColor = pw_pdf.PdfColor.fromInt(theme.headerColor);
      final stripeColor = pw_pdf.PdfColor.fromInt(theme.stripeColor);
      final borderGrey = pw_pdf.PdfColors.grey300;

      final bodyFont = pw.Font.helvetica();
      final boldFont = pw.Font.helveticaBold();

      final targetSheets = convertAllSheets.value
          ? sheets
          : [sheets[selectedSheetIndex.value.clamp(0, sheets.length - 1)]];

      final totalSheets = targetSheets.length;

      for (int s = 0; s < totalSheets; s++) {
        final sheet = targetSheets[s];
        final progress = 0.20 + (0.65 * ((s + 1) / totalSheets));
        conversionProgress.value = progress;
        statusMessage.value = 'Formatting sheet "${sheet.name}"...';

        if (sheet.rows.isEmpty) continue;

        final headerRow = sheet.rows.first;
        final dataRows = sheet.rows.length > 1 ? sheet.rows.sublist(1) : <List<String>>[];

        // Dynamic font sizing based on column count so text doesn't overflow
        final colCount = sheet.totalCols;
        double fontSize = 8.5;
        double headerFontSize = 9.0;
        double cellPaddingH = 5.0;
        double cellPaddingV = 4.0;

        if (colCount > 10) {
          fontSize = 6.5;
          headerFontSize = 7.0;
          cellPaddingH = 3.0;
          cellPaddingV = 3.0;
        } else if (colCount > 6) {
          fontSize = 7.5;
          headerFontSize = 8.0;
          cellPaddingH = 4.0;
          cellPaddingV = 3.5;
        }

        pdfDoc.addPage(
          pw.MultiPage(
            pageFormat: format,
            margin: const pw.EdgeInsets.all(28),
            header: (pw.Context ctx) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.only(bottom: 6),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: pw_pdf.PdfColors.grey300, width: 0.8),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: headerColor,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text(
                            sheet.name,
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 8.5,
                              color: pw_pdf.PdfColors.white,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          selectedFileName.value ?? 'Spreadsheet',
                          style: pw.TextStyle(
                            font: bodyFont,
                            fontSize: 8.5,
                            color: pw_pdf.PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      '${sheet.rows.length} Rows • ${sheet.totalCols} Columns',
                      style: pw.TextStyle(
                        font: bodyFont,
                        fontSize: 8.0,
                        color: pw_pdf.PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
              );
            },
            footer: (pw.Context ctx) {
              if (!includePageNumbers.value) return pw.SizedBox.shrink();
              return pw.Container(
                margin: const pw.EdgeInsets.only(top: 10),
                padding: const pw.EdgeInsets.only(top: 4),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: pw_pdf.PdfColors.grey300, width: 0.8),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                      style: pw.TextStyle(font: bodyFont, fontSize: 8.0, color: pw_pdf.PdfColors.grey600),
                    ),
                    pw.Text(
                      'Generated with Translator Ably (Excel to PDF)',
                      style: pw.TextStyle(font: bodyFont, fontSize: 7.5, color: pw_pdf.PdfColors.grey400),
                    ),
                  ],
                ),
              );
            },
            build: (pw.Context ctx) {
              return [
                pw.TableHelper.fromTextArray(
                  border: printGridlines.value
                      ? pw.TableBorder.all(color: borderGrey, width: 0.5)
                      : const pw.TableBorder(
                          horizontalInside: pw.BorderSide(color: pw_pdf.PdfColors.grey200, width: 0.5),
                        ),
                  headers: headerRow,
                  data: dataRows,
                  headerStyle: pw.TextStyle(
                    font: boldFont,
                    fontSize: headerFontSize,
                    color: pw_pdf.PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  headerDecoration: pw.BoxDecoration(color: headerColor),
                  cellStyle: pw.TextStyle(
                    font: bodyFont,
                    fontSize: fontSize,
                    color: pw_pdf.PdfColors.black,
                  ),
                  cellPadding: pw.EdgeInsets.symmetric(
                    horizontal: cellPaddingH,
                    vertical: cellPaddingV,
                  ),
                  rowDecoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: pw_pdf.PdfColors.grey200, width: 0.5),
                    ),
                  ),
                  oddRowDecoration: pw.BoxDecoration(color: stripeColor),
                ),
              ];
            },
          ),
        );
      }

      conversionProgress.value = 0.90;
      statusMessage.value = 'Writing PDF document...';

      final outputBytes = await pdfDoc.save();
      final tempDir = await getTemporaryDirectory();
      final baseName = selectedFileName.value!.replaceAll(RegExp(r'\.[^.]+$'), '');
      final outputPath = '${tempDir.path}/${baseName}_converted.pdf';
      final outFile = File(outputPath);
      await outFile.writeAsBytes(outputBytes, flush: true);

      convertedPdfPath.value = outputPath;
      convertedPdfSize.value = outputBytes.length;

      // Render Page 1 preview thumbnail
      try {
        final pdfViewDoc = await PdfDocument.openFile(outputPath);
        convertedPageCount.value = pdfViewDoc.pagesCount;
        final pageOne = await pdfViewDoc.getPage(1);
        final pageImg = await pageOne.render(
          width: pageOne.width * 1.2,
          height: pageOne.height * 1.2,
          format: PdfPageImageFormat.png,
        );
        previewThumbnailBytes.value = pageImg?.bytes;
        await pageOne.close();
        await pdfViewDoc.close();
      } catch (e) {
        log('[ExcelToPdf] thumbnail render error: $e');
        convertedPageCount.value = targetSheets.length;
      }

      conversionProgress.value = 1.0;
      statusMessage.value = 'Spreadsheet Converted!';
      MyDialogs.success(msg: 'Excel spreadsheet converted to PDF successfully!');
      AdHelper.showInterstitialAd(onComplete: () {});
      return outputPath;
    } catch (e) {
      log('[ExcelToPdf] convertToPdf error: $e');
      MyDialogs.info(msg: 'Conversion failed: $e');
      return null;
    } finally {
      isConverting.value = false;
    }
  }

  // ── 7. Share and Reset ────────────────────────────────────────────────────
  Future<void> shareConvertedPdf() async {
    final path = convertedPdfPath.value;
    if (path == null) return;
    try {
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'PDF Spreadsheet: ${selectedFileName.value}',
        text: 'Converted from Excel spreadsheet "${selectedFileName.value}"',
      );
    } catch (e) {
      log('[ExcelToPdf] share error: $e');
      MyDialogs.info(msg: 'Failed to share PDF: $e');
    }
  }

  void reset() {
    selectedFilePath.value = null;
    selectedFileName.value = null;
    fileSizeInBytes.value = 0;
    sheets.clear();
    selectedSheetIndex.value = 0;
    totalCellsCount.value = 0;
    convertedPdfPath.value = null;
    convertedPdfSize.value = 0;
    convertedPageCount.value = 0;
    previewThumbnailBytes.value = null;
    conversionProgress.value = 0.0;
    statusMessage.value = 'Ready';
  }
}
