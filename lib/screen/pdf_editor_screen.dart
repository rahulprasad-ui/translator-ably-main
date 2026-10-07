// lib/screen/pdf_editor_screen.dart
// Premium PDF Editor matching client video frames (frame_001 to frame_040)
// Features:
// - Viewer Mode (frame_001): Night mode toggle, Convert to Word, Search, Share, Thumbnail sidebar, 3-dots menu
// - Bottom Bar (frame_001): Edit, Annotate, Sign, Fill out, More tools
// - Edit Mode (frame_005 - frame_040): Close X, Help tooltip, Undo, Redo, Save dropdown pill
// - Floating top badge: "Tap any content to edit"
// - Edit Bottom Bar: Edit text, Insert text, Insert Images
// - Selected Text Box: Red border, circular left/right handles, teardrop bottom handle
// - Text Formatting Bar: Bold, A-, A+, Font (T), Color palette, Alignment, Keyboard edit, Delete
// - Annotate Mode: Pen, Highlighter, Underline, Eraser, Palette
// - Sign Pad Modal: Finger signature placement
// - Fill Out Mode: Quick stamps (Checkmark, Cross, Date, Text)
// - More Tools Sheet: Full suite navigation (Merge, Split, Compress, OCR, Word, Excel, JPG, Unlock, Watermark)
// - Native Ad docked at bottom

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/pdf_editor_controller.dart';
import '../helper/global.dart';

// Destination tool screens for "More tools" and AppBar quick actions
import 'pdf_compress_screen.dart';
import 'pdf_fill_screen.dart';
import 'pdf_merge_screen.dart';
import 'pdf_ocr_screen.dart';
import 'pdf_remove_watermark_screen.dart';
import 'pdf_sign_screen.dart';
import 'pdf_split_screen.dart';
import 'pdf_to_excel_screen.dart';
import 'pdf_to_jpg_screen.dart';
import 'pdf_to_png_screen.dart';
import 'pdf_to_word_screen.dart';
import 'pdf_unlock_screen.dart';

class PdfEditorScreen extends StatefulWidget {
  final String? initialPdfPath;
  const PdfEditorScreen({super.key, this.initialPdfPath});

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen>
    with SingleTickerProviderStateMixin {
  late final PdfEditorController c;
  late final AnimationController _toolbarAnim;

  // View state flags
  bool _thumbPanelOpen = false;
  bool _isSearchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();

  // Annotation states
  bool _isDrawing = false;
  bool _isHighlightMode = false;
  Color _drawColor = const Color(0xFFEF4444);
  double _strokeWidth = 3.0;

  // Design tokens matching app & video frames
  static const _bg = Color(0xFFF1F5F9);
  static const _accent = pColor; // Primary app blue
  static const _accentDark = Color(0xFF1D4ED8);
  static const _text = Color(0xFF0F172A);
  static const _subtext = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);
  static const _selectionRed = Color(0xFFEF4444);

  // Available font families
  static const List<String> _availableFonts = [
    'Roboto',
    'Montserrat',
    'Courier',
    'Times New Roman',
    'Lato',
    'Open Sans',
  ];

  // Quick palette colors
  static const List<Color> _paletteColors = [
    Color(0xFF000000), // Black
    Color(0xFFEF4444), // Coral Red
    Color(0xFF3B82F6), // Royal Blue
    Color(0xFF10B981), // Emerald Green
    Color(0xFFF59E0B), // Amber Orange
    Color(0xFF8B5CF6), // Purple
    Color(0xFFFACC15), // Yellow
    Color(0xFFFFFFFF), // White
  ];

  @override
  void initState() {
    super.initState();
    c = Get.put(PdfEditorController());
    _toolbarAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1,
    );
    final path = widget.initialPdfPath ??
        (Get.arguments is String ? Get.arguments as String : null);
    if (path != null && path.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        c.openPdf(path);
      });
    }
  }

  @override
  void dispose() {
    _toolbarAnim.dispose();
    _searchCtrl.dispose();
    Get.delete<PdfEditorController>();
    super.dispose();
  }

  void _toggleToolbar() {
    if (c.isToolbarVisible.value) {
      _toolbarAnim.reverse();
    } else {
      _toolbarAnim.forward();
    }
    c.isToolbarVisible.toggle();
  }

  // ── Jump to Page Dialog ───────────────────────────────────────────────────
  Future<void> _showPageJumpDialog() async {
    final ctrl =
        TextEditingController(text: (c.currentPage.value + 1).toString());
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Go to page',
          style: TextStyle(color: _text, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: _text),
          decoration: InputDecoration(
            hintText: '1 - ${c.pageCount.value}',
            hintStyle: const TextStyle(color: _subtext),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _accent, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _subtext)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final v = int.tryParse(ctrl.text);
              if (v != null && v >= 1 && v <= c.pageCount.value) {
                Navigator.pop(context, v - 1);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      c.goToPage(result);
      final pageH = MediaQuery.of(context).size.height * .85;
      c.scrollToPage(result, pageH);
    }
  }

  // ── Document Info Dialog ──────────────────────────────────────────────────
  void _showDocumentInfoDialog() {
    final fileName = c.pdfPath != null ? c.pdfPath!.split(RegExp(r'[\\/]')).last : 'Document';
    int fileSize = 0;
    if (c.pdfPath != null) {
      try {
        fileSize = File(c.pdfPath!).lengthSync();
      } catch (_) {}
    }
    final sizeKb = (fileSize / 1024).toStringAsFixed(1);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.info_outline_rounded, color: _accent),
            SizedBox(width: 8),
            Text('Document Details', style: TextStyle(color: _text, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Name', fileName),
            const SizedBox(height: 10),
            _buildInfoRow('Total Pages', '${c.pageCount.value}'),
            const SizedBox(height: 10),
            _buildInfoRow('Size', '$sizeKb KB'),
            const SizedBox(height: 10),
            _buildInfoRow('Path', c.pdfPath ?? 'Unknown'),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _subtext, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ── In-place Add or Edit Text Dialog ───────────────────────────────────────
  Future<void> _showTextEditDialog({String? existingId, String? initialText}) async {
    final ctrl = TextEditingController(text: initialText ?? '');
    final isEditing = existingId != null;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isEditing ? 'Edit Text' : 'Insert Text',
          style: const TextStyle(color: _text, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: _text, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Type your text here...',
            hintStyle: const TextStyle(color: _subtext),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _accent, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _subtext)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text(isEditing ? 'Apply' : 'Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (isEditing) {
        c.updateOverlayText(existingId, result);
      } else {
        c.addTextOverlay(
          c.currentPage.value,
          const Offset(50, 80),
          result,
        );
      }
    }
  }

  // ── Pick and Insert Image Overlay ──────────────────────────────────────────
  Future<void> _handleInsertImage() async {
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (res.isNotEmpty && res.first.path != null) {
        final filePath = res.first.path!;
        final file = File(filePath);
        final bytes = await file.readAsBytes();
        c.addImageOverlay(c.currentPage.value, const Offset(60, 100), bytes, filePath);
        Get.snackbar(
          'Image Added',
          'Drag to reposition or handles to resize.',
          backgroundColor: Colors.black87,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Failed to pick image',
        e.toString(),
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  // ── Digital Signature Modal ────────────────────────────────────────────────
  void _showSignatureDialog() {
    final List<Offset> points = [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPadState) {
          return Container(
            height: 400,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sign Document',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _text,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Draw your signature below using your finger.',
                  style: TextStyle(fontSize: 13, color: _subtext),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                    ),
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        final RenderBox box = ctx.findRenderObject() as RenderBox;
                        final local = box.globalToLocal(details.globalPosition);
                        setPadState(() {
                          points.add(details.localPosition);
                        });
                      },
                      onPanEnd: (_) {
                        setPadState(() {
                          points.add(Offset.zero); // Separator
                        });
                      },
                      child: CustomPaint(
                        painter: _SignaturePadPainter(points: points),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _subtext,
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        setPadState(() {
                          points.clear();
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Clear'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          if (points.isNotEmpty) {
                            final validStrokes = points.where((p) => p != Offset.zero).toList();
                            if (validStrokes.isNotEmpty) {
                              c.addDrawingOverlay(c.currentPage.value, validStrokes, Colors.black);
                            }
                          }
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Place Signature'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Fill Out Stamps Palette ────────────────────────────────────────────────
  void _insertFillStamp(String symbol) {
    c.addTextOverlay(
      c.currentPage.value,
      const Offset(80, 100),
      symbol,
      fontSize: 22,
      color: symbol == '✓' ? const Color(0xFF10B981) : (symbol == '✗' ? const Color(0xFFEF4444) : Colors.black87),
    );
    Get.snackbar(
      'Stamp Added',
      'Drag into position on the document.',
      backgroundColor: Colors.black87,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
    );
  }

  // ── More Tools Bottom Sheet ────────────────────────────────────────────────
  void _showMoreToolsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'All PDF Tools',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: _subtext),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(color: _border, height: 1),
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.all(18),
                crossAxisCount: 3,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.95,
                children: [
                  _buildToolGridCard(
                    icon: Icons.description_rounded,
                    label: 'PDF to Word',
                    color: const Color(0xFF2B579A),
                    onTap: () {
                      Navigator.pop(ctx);
                      Get.to(() => PdfToWordScreen(initialPdfPath: c.pdfPath));
                    },
                  ),
                  _buildToolGridCard(
                    icon: Icons.table_chart_rounded,
                    label: 'PDF to Excel',
                    color: const Color(0xFF107C41),
                    onTap: () {
                      Navigator.pop(ctx);
                      Get.to(() => PdfToExcelScreen(initialPdfPath: c.pdfPath));
                    },
                  ),
                  _buildToolGridCard(
                    icon: Icons.image_rounded,
                    label: 'PDF to JPG',
                    color: const Color(0xFFF59E0B),
                    onTap: () {
                      Navigator.pop(ctx);
                      Get.to(() => PdfToJpgScreen(initialPdfPath: c.pdfPath));
                    },
                  ),
                  _buildToolGridCard(
                    icon: Icons.photo_library_rounded,
                    label: 'PDF to PNG',
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                      Navigator.pop(ctx);
                      Get.to(() => PdfToPngScreen(initialPdfPath: c.pdfPath));
                    },
                  ),
                  _buildToolGridCard(
                    icon: Icons.call_merge_rounded,
                    label: 'Merge PDF',
                    color: const Color(0xFF3B82F6),
                    onTap: () {
                      Navigator.pop(ctx);
                      Get.to(() => const PdfMergeScreen());
                    },
                  ),
                  _buildToolGridCard(
                    icon: Icons.call_split_rounded,
                    label: 'Split PDF',
                    color: const Color(0xFFEC4899),
                    onTap: () {
                      Navigator.pop(ctx);
                      Get.to(() => PdfSplitScreen(initialPdfPath: c.pdfPath));
                    },
                  ),
                  _buildToolGridCard(
                    icon: Icons.compress_rounded,
                    label: 'Compress PDF',
                    color: const Color(0xFF06B6D4),
                    onTap: () {
                      Navigator.pop(ctx);
                      Get.to(() => const PdfCompressScreen());
                    },
                  ),
                  _buildToolGridCard(
                    icon: Icons.document_scanner_rounded,
                    label: 'OCR Text',
                    color: const Color(0xFF6366F1),
                    onTap: () {
                      Navigator.pop(ctx);
                      Get.to(() => PdfOcrScreen(initialPdfPath: c.pdfPath));
                    },
                  ),
                  _buildToolGridCard(
                    icon: Icons.lock_open_rounded,
                    label: 'Unlock PDF',
                    color: const Color(0xFF10B981),
                    onTap: () {
                      Navigator.pop(ctx);
                      Get.to(() => PdfUnlockScreen(initialPdfPath: c.pdfPath));
                    },
                  ),
                  _buildToolGridCard(
                    icon: Icons.water_drop_outlined,
                    label: 'Watermark',
                    color: const Color(0xFFF97316),
                    onTap: () {
                      Navigator.pop(ctx);
                      Get.to(() => PdfRemoveWatermarkScreen(initialPdfPath: c.pdfPath));
                    },
                  ),
                  _buildToolGridCard(
                    icon: Icons.drive_file_rename_outline_rounded,
                    label: 'Sign PDF',
                    color: const Color(0xFF1E293B),
                    onTap: () {
                      Navigator.pop(ctx);
                      Get.to(() => PdfSignScreen(initialPdfPath: c.pdfPath));
                    },
                  ),
                  _buildToolGridCard(
                    icon: Icons.assignment_turned_in_rounded,
                    label: 'Fill Out',
                    color: const Color(0xFF14B8A6),
                    onTap: () {
                      Navigator.pop(ctx);
                      Get.to(() => PdfFillScreen(initialPdfPath: c.pdfPath));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolGridCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Share PDF ─────────────────────────────────────────────────────────────
  Future<void> _shareCurrentDocument() async {
    if (c.pdfPath == null) return;
    try {
      if (c.overlays.isNotEmpty) {
        final exported = await c.exportWithOverlays();
        if (exported != null) {
          await Share.shareXFiles([XFile(exported)], text: 'Edited Document');
          return;
        }
      }
      await Share.shareXFiles([XFile(c.pdfPath!)], text: 'Document');
    } catch (e) {
      Get.snackbar('Share failed', e.toString(), backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  // ── Save Handler ──────────────────────────────────────────────────────────
  Future<void> _handleSave() async {
    final path = await c.exportWithOverlays();
    if (path != null) {
      Get.snackbar(
        'Saved Successfully!',
        'Exported to: $path',
        backgroundColor: const Color(0xFF10B981).withOpacity(.95),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
        borderRadius: 14,
        duration: const Duration(seconds: 4),
      );
    } else {
      Get.snackbar(
        'Export Failed',
        'Something went wrong while saving.',
        backgroundColor: const Color(0xFFEF4444).withOpacity(.95),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
        borderRadius: 14,
      );
    }
  }

  // ── Main Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isEditMode = c.editorMode.value == EditorMode.edit;
      final showPageInfo = c.pageCount.value > 0;

      return Scaffold(
        backgroundColor: _bg,
        appBar: isEditMode
            ? _buildEditAppBar()
            : _buildViewAppBar(showPageInfo: showPageInfo),
        body: _buildCurrentState(),
      );
    });
  }

  Widget _buildCurrentState() {
    if (c.isLoading.value) return _buildLoadingState();
    if (c.hasError.value) return _buildErrorState();
    if (c.pageCount.value == 0) return _buildEmptyState();
    return _buildEditorBody();
  }

  Widget _buildLoadingState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _accent),
            const SizedBox(height: 20),
            const Text(
              'Opening PDF...',
              style: TextStyle(
                color: _subtext,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ).animate().fadeIn();

  Widget _buildErrorState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFEF4444), size: 64),
            const SizedBox(height: 16),
            const Text(
              'Failed to open PDF',
              style: TextStyle(
                color: _text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please try another file.',
              style: TextStyle(color: _subtext, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: c.pickAndOpen,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Pick PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn();

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_accent, Color(0xFF60A5FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: const Icon(Icons.picture_as_pdf_rounded,
                  color: Colors.white, size: 54),
            )
                .animate(onPlay: (c) => c.repeat())
                .shimmer(duration: 2200.ms, color: Colors.white38),
            const SizedBox(height: 28),
            const Text(
              'PDF Editor',
              style: TextStyle(
                color: _text,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Open a PDF to annotate, edit text,\nsign and export.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _subtext, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            _GradientButton(
              label: 'Open PDF',
              icon: Icons.folder_open_rounded,
              onTap: c.pickAndOpen,
            ).animate().fadeIn(delay: 200.ms).slideY(begin: .2),
          ],
        ),
      );

  // ── Document View Mode AppBar (matches frame_001.jpg) ─────────────────────
  PreferredSizeWidget _buildViewAppBar({required bool showPageInfo}) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0.8,
      shadowColor: Colors.black.withOpacity(0.08),
      titleSpacing: 4,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.black87, size: 20),
        onPressed: () => Get.back(),
      ),
      title: showPageInfo
          ? Obx(() => GestureDetector(
                onTap: _showPageJumpDialog,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _accent.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book_rounded,
                          color: _accent, size: 14),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Page ${c.currentPage.value + 1} / ${c.pageCount.value}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          : const Text(
              'PDF Editor',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
      actions: showPageInfo
          ? [
              // 1. Search icon
              IconButton(
                icon: Icon(
                  _isSearchOpen ? Icons.search_off_rounded : Icons.search_rounded,
                  color: _isSearchOpen ? _accent : Colors.black87,
                ),
                onPressed: () {
                  setState(() => _isSearchOpen = !_isSearchOpen);
                },
                tooltip: 'Search Document',
              ),
              // 2. Share icon
              IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.black87),
                onPressed: _shareCurrentDocument,
                tooltip: 'Share PDF',
              ),
              // 3. Overflow menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.black87),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (val) {
                  if (val == 'night') c.toggleNightMode();
                  if (val == 'word') Get.to(() => PdfToWordScreen(initialPdfPath: c.pdfPath));
                  if (val == 'thumbnails') setState(() => _thumbPanelOpen = !_thumbPanelOpen);
                  if (val == 'info') _showDocumentInfoDialog();
                  if (val == 'jump') _showPageJumpDialog();
                  if (val == 'open') c.pickAndOpen();
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'night',
                    child: Row(
                      children: [
                        Icon(
                          c.isNightMode.value
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          size: 20,
                          color: _subtext,
                        ),
                        const SizedBox(width: 10),
                        Text(c.isNightMode.value ? 'Light Mode' : 'Night Mode'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'word',
                    child: Row(
                      children: [
                        Icon(Icons.description_rounded, size: 20, color: Color(0xFF2B579A)),
                        SizedBox(width: 10),
                        Text('Convert to Word'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'thumbnails',
                    child: Row(
                      children: [
                        Icon(
                          _thumbPanelOpen ? Icons.view_sidebar_rounded : Icons.view_sidebar_outlined,
                          size: 20,
                          color: _subtext,
                        ),
                        const SizedBox(width: 10),
                        Text(_thumbPanelOpen ? 'Hide Thumbnails' : 'Page Thumbnails'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'info',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 20, color: _subtext),
                        SizedBox(width: 10),
                        Text('Document Info'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'jump',
                    child: Row(
                      children: [
                        Icon(Icons.directions_rounded, size: 20, color: _subtext),
                        SizedBox(width: 10),
                        Text('Go to page...'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'open',
                    child: Row(
                      children: [
                        Icon(Icons.folder_open_rounded, size: 20, color: _subtext),
                        SizedBox(width: 10),
                        Text('Open another PDF'),
                      ],
                    ),
                  ),
                ],
              ),
            ]
          : [],
    );
  }

  // ── Edit Mode AppBar (matches frame_005.jpg - frame_040.jpg) ───────────────
  PreferredSizeWidget _buildEditAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0.8,
      shadowColor: Colors.black.withOpacity(0.08),
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.black87, size: 24),
        onPressed: () => c.setEditorMode(EditorMode.view),
        tooltip: 'Close Edit Mode',
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded,
                color: Color(0xFF64748B), size: 22),
            onPressed: () {
              Get.snackbar(
                'How to Edit',
                'Tap on any text or element to select and format. Drag handles to resize or reposition.',
                backgroundColor: Colors.black87,
                colorText: Colors.white,
                snackPosition: SnackPosition.TOP,
                duration: const Duration(seconds: 4),
              );
            },
            tooltip: 'Help',
          ),
        ],
      ),
      actions: [
        // Undo button
        Obx(() => IconButton(
              icon: Icon(
                Icons.undo_rounded,
                color: c.canUndo ? Colors.black87 : Colors.black26,
              ),
              onPressed: c.canUndo ? c.undo : null,
              tooltip: 'Undo',
            )),
        // Redo button
        Obx(() => IconButton(
              icon: Icon(
                Icons.redo_rounded,
                color: c.canRedo ? Colors.black87 : Colors.black26,
              ),
              onPressed: c.canRedo ? c.redo : null,
              tooltip: 'Redo',
            )),
        // Save Pill Button with dropdown chevron (matches frame_010.jpg)
        Padding(
          padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
          child: PopupMenuButton<String>(
            offset: const Offset(0, 42),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              if (val == 'save') _handleSave();
              if (val == 'share') _shareCurrentDocument();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.save_rounded, size: 18, color: _accent),
                    SizedBox(width: 8),
                    Text('Save Changes'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_rounded, size: 18, color: _accent),
                    SizedBox(width: 8),
                    Text('Share PDF'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down_rounded,
                      color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Editor Main Body ──────────────────────────────────────────────────────
  Widget _buildEditorBody() {
    return Stack(
      children: [
        // 1. PDF Pages List with Gestures
        GestureDetector(
          onTap: () {
            if (c.editorMode.value == EditorMode.view) {
              _toggleToolbar();
            } else {
              c.selectOverlay(null);
            }
          },
          child: _buildPagesList(),
        ),

        // 2. Search Bar overlay (if open)
        if (_isSearchOpen)
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: _buildSearchBar(),
          ),

        // 3. Edit Mode Floating Badge ("Tap any content to edit" - frame_010.jpg)
        Obx(() {
          if (c.editorMode.value == EditorMode.edit) {
            return Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: const Color(0xFF3B82F6).withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded,
                          size: 16, color: Color(0xFF2563EB)),
                      SizedBox(width: 6),
                      Text(
                        'Tap any content to edit',
                        style: TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.2),
              ),
            );
          }
          return const SizedBox.shrink();
        }),

        // 4. Thumbnail Panel (Slide out)
        if (_thumbPanelOpen)
          Positioned(
            top: 10,
            bottom: 90,
            right: 0,
            child: _buildThumbnailPanel(),
          ),

        // 5. Bottom Navigation Toolbar & Text Formatting Toolbar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Obx(() {
            final isEdit = c.editorMode.value == EditorMode.edit;
            final isAnnotate = c.editorMode.value == EditorMode.annotate;
            final isFillOut = c.editorMode.value == EditorMode.fillOut;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Text Formatting bar (appears when an overlay is selected in edit mode)
                if (isEdit && c.selectedOverlay != null)
                  _buildTextFormattingToolbar(c.selectedOverlay!)
                      .animate()
                      .fadeIn(duration: 180.ms)
                      .slideY(begin: 0.1),

                // Annotate Secondary Toolbar
                if (isAnnotate)
                  _buildAnnotateSubToolbar()
                      .animate()
                      .fadeIn(duration: 180.ms),

                // Fill Out Secondary Toolbar
                if (isFillOut)
                  _buildFillOutSubToolbar()
                      .animate()
                      .fadeIn(duration: 180.ms),

                // Main Bottom Bar (Viewer 5-items vs Edit 3-tabs)
                if (isEdit)
                  _buildEditBottomBar()
                else
                  _buildViewerBottomBar(),
              ],
            );
          }),
        ),

        // 6. Loading overlay during PDF export
        Obx(() => c.isSaving.value
            ? Container(
                color: Colors.black38,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 18,
                        )
                      ],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: _accent),
                        SizedBox(height: 14),
                        Text(
                          'Saving PDF...',
                          style: TextStyle(
                            color: _text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink()),
      ],
    );
  }

  // ── Search Bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _subtext),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 14, color: _text),
              decoration: const InputDecoration(
                hintText: 'Search in document...',
                hintStyle: TextStyle(color: _subtext, fontSize: 14),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: _subtext),
            onPressed: () {
              setState(() {
                _searchCtrl.clear();
                _isSearchOpen = false;
              });
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.2);
  }

  // ── Pages Scroll List ─────────────────────────────────────────────────────
  Widget _buildPagesList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification) {
          final pageH = MediaQuery.of(context).size.height * .85;
          final newPage = (n.metrics.pixels / (pageH + 16)).round();
          if (newPage >= 0 &&
              newPage < c.pageCount.value &&
              newPage != c.currentPage.value) {
            c.goToPage(newPage);
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: c.scrollController,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 120),
        physics: _isDrawing
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        cacheExtent: 150.0,
        itemCount: c.pageCount.value,
        itemBuilder: (context, index) => _buildPageItem(index),
      ),
    );
  }

  // ── Individual Page Item ──────────────────────────────────────────────────
  Widget _buildPageItem(int index) {
    return Obx(() {
      final isCurrent = c.currentPage.value == index;
      final isNight = c.isNightMode.value;

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isNight ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent ? _accent : _border,
            width: isCurrent ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isCurrent
                  ? _accent.withOpacity(.22)
                  : Colors.black.withOpacity(.06),
              blurRadius: isCurrent ? 16 : 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // PDF Rendered Image (with optional Night Mode Filter)
              ColorFiltered(
                colorFilter: isNight
                    ? const ColorFilter.matrix([
                        -1.0,  0.0,  0.0, 0.0, 255.0, // red
                         0.0, -1.0,  0.0, 0.0, 255.0, // green
                         0.0,  0.0, -1.0, 0.0, 255.0, // blue
                         0.0,  0.0,  0.0, 1.0,   0.0, // alpha
                      ])
                    : const ColorFilter.mode(
                        Colors.transparent, BlendMode.dst),
                child: _LazyPageImage(
                  key: ValueKey('page_${c.pdfPath}_$index'),
                  controller: c,
                  pageIndex: index,
                ),
              ),

              // Interactive Overlays & In-place Selection Handles
              Positioned.fill(
                child: _InteractivePageOverlayLayer(
                  controller: c,
                  pageIndex: index,
                  isDrawing: _isDrawing && isCurrent,
                  drawColor: _drawColor,
                  strokeWidth: _strokeWidth,
                  onStrokeEnd: (strokes) {
                    if (_isHighlightMode) {
                      c.addHighlightOverlay(index, strokes.first, _drawColor);
                    } else {
                      c.addDrawingOverlay(index, strokes, _drawColor);
                    }
                    setState(() => _isDrawing = false);
                  },
                  onTapEditOverlay: (o) {
                    if (o.type == OverlayType.text) {
                      _showTextEditDialog(
                          existingId: o.id, initialText: o.text);
                    }
                  },
                ),
              ),

              // Page Number Badge (bottom right)
              Positioned(
                bottom: 8,
                right: 10,
                child: GestureDetector(
                  onTap: _showPageJumpDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.68),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${index + 1} / ${c.pageCount.value}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ── Viewer Bottom Toolbar (5 items matching frame_001.jpg) ────────────────
  Widget _buildViewerBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 1. Edit (switches to edit mode matching frame_005 - frame_040)
              _ViewerToolBtn(
                icon: Icons.edit_note_rounded,
                label: 'Edit',
                color: _accent,
                onTap: () {
                  c.setEditorMode(EditorMode.edit);
                },
              ),
              // 2. Annotate (pen, highlight, note)
              _ViewerToolBtn(
                icon: Icons.draw_rounded,
                label: 'Annotate',
                color: const Color(0xFFF59E0B),
                onTap: () {
                  c.setEditorMode(EditorMode.annotate);
                  setState(() {
                    _isDrawing = true;
                    _isHighlightMode = false;
                  });
                },
              ),
              // 3. Sign (digital signature pad)
              _ViewerToolBtn(
                icon: Icons.gesture_rounded,
                label: 'Sign',
                color: const Color(0xFF8B5CF6),
                onTap: _showSignatureDialog,
              ),
              // 4. Fill out (stamps, checkmarks, date)
              _ViewerToolBtn(
                icon: Icons.task_alt_rounded,
                label: 'Fill out',
                color: const Color(0xFF10B981),
                onTap: () {
                  c.setEditorMode(EditorMode.fillOut);
                },
              ),
              // 5. More tools (bottom sheet with all PDF tools)
              _ViewerToolBtn(
                icon: Icons.grid_view_rounded,
                label: 'More tools',
                color: const Color(0xFF475569),
                onTap: _showMoreToolsSheet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Edit Bottom Bar (3 tabs matching frame_010.jpg) ───────────────────────
  Widget _buildEditBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Obx(() {
            final activeTab = c.editSubTab.value;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Tab 1: Edit text
                _EditSubTabBtn(
                  icon: Icons.edit_note_rounded,
                  label: 'Edit text',
                  isActive: activeTab == 0,
                  onTap: () {
                    c.setEditSubTab(0);
                  },
                ),
                // Tab 2: Insert text
                _EditSubTabBtn(
                  icon: Icons.post_add_rounded,
                  label: 'Insert text',
                  isActive: activeTab == 1,
                  onTap: () {
                    c.setEditSubTab(1);
                    _showTextEditDialog();
                  },
                ),
                // Tab 3: Insert Images
                _EditSubTabBtn(
                  icon: Icons.add_photo_alternate_rounded,
                  label: 'Insert Images',
                  isActive: activeTab == 2,
                  onTap: () {
                    c.setEditSubTab(2);
                    _handleInsertImage();
                  },
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── Text Formatting Toolbar (docked when text overlay is selected - frame_020, frame_040) ───
  Widget _buildTextFormattingToolbar(PdfOverlay overlay) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bold Toggle [ B ]
            _FormattingBtn(
              label: 'B',
              isBoldText: true,
              isActive: overlay.isBold,
              onTap: () => c.toggleBold(overlay.id),
              tooltip: 'Bold',
            ),
            const SizedBox(width: 4),

            // Font Size Decrease [ A- ]
            _FormattingBtn(
              label: 'A-',
              onTap: () => c.decreaseFontSize(overlay.id),
              tooltip: 'Decrease Size',
            ),
            const SizedBox(width: 4),

            // Font Size Increase [ A+ ]
            _FormattingBtn(
              label: 'A+',
              onTap: () => c.increaseFontSize(overlay.id),
              tooltip: 'Increase Size',
            ),
            const SizedBox(width: 6),

            // Font Family Selector [ T ]
            PopupMenuButton<String>(
              tooltip: 'Font Family',
              initialValue: overlay.fontFamily,
              onSelected: (font) => c.setOverlayFontFamily(overlay.id, font),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              itemBuilder: (ctx) => _availableFonts
                  .map((f) => PopupMenuItem(
                        value: f,
                        child: Text(f, style: TextStyle(fontFamily: f)),
                      ))
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('T',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      overlay.fontFamily,
                      style: const TextStyle(fontSize: 11, color: _subtext),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded,
                        size: 16, color: _subtext),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Color Palette Selector [ Color box ]
            PopupMenuButton<Color>(
              tooltip: 'Text Color',
              onSelected: (col) => c.setOverlayColor(overlay.id, col),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  enabled: false,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _paletteColors.map((col) {
                      return GestureDetector(
                        onTap: () {
                          c.setOverlayColor(overlay.id, col);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(color: _border, width: 1.5),
                          ),
                          child: overlay.color == col
                              ? Icon(Icons.check_rounded,
                                  size: 18,
                                  color: col == Colors.white
                                      ? Colors.black
                                      : Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: overlay.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: overlay.color.withOpacity(0.3),
                      blurRadius: 4,
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Text Alignment Toggle (Left / Center / Right)
            IconButton(
              icon: Icon(
                overlay.textAlign == TextAlign.center
                    ? Icons.format_align_center_rounded
                    : (overlay.textAlign == TextAlign.right
                        ? Icons.format_align_right_rounded
                        : Icons.format_align_left_rounded),
                size: 20,
                color: _text,
              ),
              onPressed: () {
                final nextAlign = overlay.textAlign == TextAlign.left
                    ? TextAlign.center
                    : (overlay.textAlign == TextAlign.center
                        ? TextAlign.right
                        : TextAlign.left);
                c.setOverlayAlignment(overlay.id, nextAlign);
              },
              tooltip: 'Alignment',
            ),

            const SizedBox(
              height: 22,
              child: VerticalDivider(color: _border, thickness: 1.2),
            ),

            // Keyboard Edit Text Dialog Button
            IconButton(
              icon: const Icon(Icons.keyboard_rounded,
                  size: 20, color: _accent),
              onPressed: () => _showTextEditDialog(
                  existingId: overlay.id, initialText: overlay.text),
              tooltip: 'Edit Text Content',
            ),

            // Delete Overlay Button
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 20, color: _selectionRed),
              onPressed: () => c.removeOverlay(overlay.id),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  // ── Annotate Sub Toolbar ──────────────────────────────────────────────────
  Widget _buildAnnotateSubToolbar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Pen
          IconButton(
            icon: Icon(Icons.edit_rounded,
                color: (!_isHighlightMode && _isDrawing)
                    ? _accent
                    : const Color(0xFF64748B)),
            onPressed: () {
              setState(() {
                _isDrawing = true;
                _isHighlightMode = false;
              });
            },
            tooltip: 'Pen',
          ),
          // Highlighter
          IconButton(
            icon: Icon(Icons.highlight_rounded,
                color: _isHighlightMode ? _accent : const Color(0xFF64748B)),
            onPressed: () {
              setState(() {
                _isDrawing = true;
                _isHighlightMode = true;
                _drawColor = const Color(0xFFFFD166).withOpacity(0.5);
              });
            },
            tooltip: 'Highlighter',
          ),
          // Color selector
          PopupMenuButton<Color>(
            tooltip: 'Color',
            onSelected: (col) => setState(() => _drawColor = col),
            itemBuilder: (ctx) => _paletteColors
                .map((col) => PopupMenuItem(
                      value: col,
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                                color: col, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(
                              col == Colors.black ? 'Black' : 'Color Choice'),
                        ],
                      ),
                    ))
                .toList(),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _drawColor,
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
            ),
          ),
          // Done
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              setState(() => _isDrawing = false);
              c.setEditorMode(EditorMode.view);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ── Fill Out Sub Toolbar ──────────────────────────────────────────────────
  Widget _buildFillOutSubToolbar() {
    final today =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StampBtn(
            label: '✓ Check',
            color: const Color(0xFF10B981),
            onTap: () => _insertFillStamp('✓'),
          ),
          _StampBtn(
            label: '✗ Cross',
            color: const Color(0xFFEF4444),
            onTap: () => _insertFillStamp('✗'),
          ),
          _StampBtn(
            label: '📅 Date',
            color: const Color(0xFF3B82F6),
            onTap: () => _insertFillStamp(today),
          ),
          _StampBtn(
            label: '✍ Text',
            color: const Color(0xFF8B5CF6),
            onTap: () => _showTextEditDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: _subtext),
            onPressed: () => c.setEditorMode(EditorMode.view),
          ),
        ],
      ),
    );
  }

  // ── Thumbnail Side Panel ──────────────────────────────────────────────────
  Widget _buildThumbnailPanel() {
    return Container(
      width: 104,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
        border: const Border(left: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.1),
            blurRadius: 16,
            offset: const Offset(-2, 0),
          )
        ],
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: c.pageCount.value,
        itemBuilder: (_, index) => _ThumbnailItem(
          controller: c,
          pageIndex: index,
          onTap: () {
            c.goToPage(index);
            final pageH = MediaQuery.of(context).size.height * .85;
            c.scrollToPage(index, pageH);
          },
        ),
      ),
    ).animate().slideX(begin: 1, duration: 220.ms, curve: Curves.easeOut);
  }
}

// ── Interactive Page Overlay Layer with Selection Handles (matching frame_020, frame_040) ────
class _InteractivePageOverlayLayer extends StatefulWidget {
  final PdfEditorController controller;
  final int pageIndex;
  final bool isDrawing;
  final Color drawColor;
  final double strokeWidth;
  final void Function(List<Offset>) onStrokeEnd;
  final void Function(PdfOverlay) onTapEditOverlay;

  const _InteractivePageOverlayLayer({
    required this.controller,
    required this.pageIndex,
    required this.isDrawing,
    required this.drawColor,
    required this.strokeWidth,
    required this.onStrokeEnd,
    required this.onTapEditOverlay,
  });

  @override
  State<_InteractivePageOverlayLayer> createState() =>
      _InteractivePageOverlayLayerState();
}

class _InteractivePageOverlayLayerState
    extends State<_InteractivePageOverlayLayer> {
  List<Offset> _liveStrokes = [];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isEditMode = widget.controller.editorMode.value == EditorMode.edit;
      final overlays = widget.controller.overlaysForPage(widget.pageIndex);
      final selectedId = widget.controller.selectedOverlayId.value;

      return LayoutBuilder(builder: (ctx, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        if (w <= 0 || h <= 0 || h == double.infinity) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: [
            // Static / Drawn overlays painter
            CustomPaint(
              size: Size(w, h),
              painter: _OverlayPainter(
                overlays: overlays
                    .where((o) =>
                        o.type == OverlayType.drawing ||
                        o.type == OverlayType.highlight)
                    .toList(),
                liveStrokes: _liveStrokes,
                liveColor: widget.drawColor,
              ),
            ),

            // Drawing gesture recognizer (when drawing)
            if (widget.isDrawing)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (d) =>
                      setState(() => _liveStrokes = [d.localPosition]),
                  onPanUpdate: (d) =>
                      setState(() => _liveStrokes.add(d.localPosition)),
                  onPanEnd: (_) {
                    if (_liveStrokes.isNotEmpty) {
                      widget.onStrokeEnd(List.from(_liveStrokes));
                    }
                    setState(() => _liveStrokes = []);
                  },
                ),
              ),

            // Movable and Resizable Text & Image Overlays
            ...overlays
                .where((o) =>
                    o.type == OverlayType.text ||
                    o.type == OverlayType.image ||
                    o.type == OverlayType.signature)
                .map((o) {
              final isSelected = isEditMode && (selectedId == o.id);
              return _MovableOverlayWidget(
                overlay: o,
                isSelected: isSelected,
                isEditMode: isEditMode,
                onSelect: () => widget.controller.selectOverlay(o.id),
                onUpdatePos: (newPos) =>
                    widget.controller.updateOverlayPosition(o.id, newPos),
                onUpdateSize: (newSize) =>
                    widget.controller.updateOverlaySize(o.id, newSize),
                onDoubleTap: () => widget.onTapEditOverlay(o),
              );
            }),
          ],
        );
      });
    });
  }
}

// ── Movable Overlay Widget with Red Selection Box and Drag Handles (frame_020, frame_040) ────
class _MovableOverlayWidget extends StatefulWidget {
  final PdfOverlay overlay;
  final bool isSelected;
  final bool isEditMode;
  final VoidCallback onSelect;
  final void Function(Offset) onUpdatePos;
  final void Function(Size) onUpdateSize;
  final VoidCallback onDoubleTap;

  const _MovableOverlayWidget({
    required this.overlay,
    required this.isSelected,
    required this.isEditMode,
    required this.onSelect,
    required this.onUpdatePos,
    required this.onUpdateSize,
    required this.onDoubleTap,
  });

  @override
  State<_MovableOverlayWidget> createState() => _MovableOverlayWidgetState();
}

class _MovableOverlayWidgetState extends State<_MovableOverlayWidget> {
  late Offset _pos;
  late Size _size;

  @override
  void initState() {
    super.initState();
    _pos = widget.overlay.position;
    _size = widget.overlay.size;
  }

  @override
  void didUpdateWidget(covariant _MovableOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.overlay.position != widget.overlay.position) {
      _pos = widget.overlay.position;
    }
    if (oldWidget.overlay.size != widget.overlay.size) {
      _size = widget.overlay.size;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: GestureDetector(
        onTap: () {
          if (widget.isEditMode) widget.onSelect();
        },
        onDoubleTap: () {
          if (widget.isEditMode) widget.onDoubleTap();
        },
        onPanUpdate: widget.isEditMode && widget.isSelected
            ? (details) {
                setState(() {
                  _pos += details.delta;
                });
                widget.onUpdatePos(_pos);
              }
            : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Overlay Content Container
            Container(
              width: _size.width,
              constraints: BoxConstraints(minHeight: _size.height),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                // When selected: crisp red border as in video frame_020 and frame_040
                border: widget.isSelected
                    ? Border.all(color: const Color(0xFFEF4444), width: 1.6)
                    : (widget.isEditMode
                        ? Border.all(color: Colors.blue.withOpacity(0.3), width: 1)
                        : null),
                borderRadius: BorderRadius.circular(4),
                color: widget.isSelected
                    ? const Color(0xFFEF4444).withOpacity(0.04)
                    : Colors.transparent,
              ),
              child: _buildContent(),
            ),

            // Selection Handles (Left & Right circular, Bottom teardrop - frame_020, frame_040)
            if (widget.isSelected) ...[
              // Left Middle Circular Handle
              Positioned(
                left: -7,
                top: (_size.height / 2) - 7,
                child: GestureDetector(
                  onPanUpdate: (d) {
                    setState(() {
                      final newWidth = (_size.width - d.delta.dx).clamp(60.0, 500.0);
                      _pos = Offset(_pos.dx + d.delta.dx, _pos.dy);
                      _size = Size(newWidth, _size.height);
                    });
                    widget.onUpdatePos(_pos);
                    widget.onUpdateSize(_size);
                  },
                  child: _buildCircleHandle(),
                ),
              ),

              // Right Middle Circular Handle
              Positioned(
                right: -7,
                top: (_size.height / 2) - 7,
                child: GestureDetector(
                  onPanUpdate: (d) {
                    setState(() {
                      final newWidth = (_size.width + d.delta.dx).clamp(60.0, 500.0);
                      _size = Size(newWidth, _size.height);
                    });
                    widget.onUpdateSize(_size);
                  },
                  child: _buildCircleHandle(),
                ),
              ),

              // Bottom Teardrop / Pin Handle (matches frame_020, frame_040)
              Positioned(
                left: (_size.width / 2) - 8,
                bottom: -22,
                child: GestureDetector(
                  onPanUpdate: (d) {
                    setState(() {
                      final newHeight = (_size.height + d.delta.dy).clamp(30.0, 400.0);
                      _size = Size(_size.width, newHeight);
                    });
                    widget.onUpdateSize(_size);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Connector stem
                      Container(
                        width: 1.6,
                        height: 6,
                        color: const Color(0xFFEF4444),
                      ),
                      // Red pin / teardrop circle
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.35),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.overlay.type == OverlayType.text) {
      return Text(
        widget.overlay.text ?? '',
        textAlign: widget.overlay.textAlign,
        style: TextStyle(
          color: widget.overlay.color,
          fontSize: widget.overlay.fontSize,
          fontWeight: widget.overlay.isBold ? FontWeight.bold : FontWeight.w500,
          fontFamily: widget.overlay.fontFamily,
          shadows: const [Shadow(color: Colors.white70, blurRadius: 2)],
        ),
      );
    } else if (widget.overlay.type == OverlayType.image &&
        widget.overlay.imageBytes != null) {
      return Image.memory(
        widget.overlay.imageBytes!,
        fit: BoxFit.contain,
        width: _size.width,
        height: _size.height,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCircleHandle() {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFEF4444), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 4,
          )
        ],
      ),
    );
  }
}

// ── Overlay Painter ─────────────────────────────────────────────────────────
class _OverlayPainter extends CustomPainter {
  final List<PdfOverlay> overlays;
  final List<Offset> liveStrokes;
  final Color liveColor;

  const _OverlayPainter({
    required this.overlays,
    required this.liveStrokes,
    required this.liveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final o in overlays) {
      switch (o.type) {
        case OverlayType.highlight:
          _drawHighlight(canvas, o);
          break;
        case OverlayType.drawing:
          if (o.strokes != null && o.strokes!.length > 1) {
            _drawStrokes(canvas, o.strokes!, o.color);
          }
          break;
        default:
          break;
      }
    }
    if (liveStrokes.length > 1) {
      _drawStrokes(canvas, liveStrokes, liveColor);
    }
  }

  void _drawHighlight(Canvas canvas, PdfOverlay o) {
    canvas.drawRect(
      Rect.fromLTWH(o.position.dx, o.position.dy, 180, 24),
      Paint()..color = o.color,
    );
  }

  void _drawStrokes(Canvas canvas, List<Offset> pts, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      if (pts[i] == Offset.zero) {
        if (i + 1 < pts.length) path.moveTo(pts[i + 1].dx, pts[i + 1].dy);
      } else {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.overlays != overlays ||
      old.liveStrokes != liveStrokes ||
      old.liveColor != liveColor;
}

// ── Lazy Page Image (Stateful + AutomaticKeepAliveClientMixin) ───────────────
class _LazyPageImage extends StatefulWidget {
  final PdfEditorController controller;
  final int pageIndex;
  const _LazyPageImage({
    super.key,
    required this.controller,
    required this.pageIndex,
  });

  @override
  State<_LazyPageImage> createState() => _LazyPageImageState();
}

class _LazyPageImageState extends State<_LazyPageImage> {
  Future<PdfPageImage?>? _future;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  void _loadPage() {
    _future = widget.controller.getPageImage(widget.pageIndex);
  }

  @override
  void didUpdateWidget(covariant _LazyPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageIndex != widget.pageIndex) {
      _loadPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PdfPageImage?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.white,
            child: const AspectRatio(
              aspectRatio: 0.707,
              child: Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    color: _PdfEditorScreenState._accent,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            ),
          );
        }
        if (snap.hasError || snap.data == null) {
          return Container(
            color: Colors.white,
            child: AspectRatio(
              aspectRatio: 0.707,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded,
                        color: Colors.black45, size: 36),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _loadPage();
                        });
                      },
                      child: const Text(
                        'Retry Page',
                        style: TextStyle(
                          color: _PdfEditorScreenState._accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final img = snap.data!;
        return Container(
          color: Colors.white,
          child: Image.memory(
            img.bytes,
            fit: BoxFit.contain,
            width: double.infinity,
          ),
        );
      },
    );
  }
}

// ── Thumbnail item ──────────────────────────────────────────────────────────
class _ThumbnailItem extends StatefulWidget {
  final PdfEditorController controller;
  final int pageIndex;
  final VoidCallback onTap;
  const _ThumbnailItem({
    required this.controller,
    required this.pageIndex,
    required this.onTap,
  });

  @override
  State<_ThumbnailItem> createState() => _ThumbnailItemState();
}

class _ThumbnailItemState extends State<_ThumbnailItem> {
  Future<Uint8List?>? _thumbFuture;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  void _loadThumbnail() {
    _thumbFuture = widget.controller.getThumbnail(widget.pageIndex);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Obx(() {
        final isCurrent =
            widget.controller.currentPage.value == widget.pageIndex;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCurrent ? pColor : _PdfEditorScreenState._border,
              width: isCurrent ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: FutureBuilder<Uint8List?>(
              future: _thumbFuture,
              builder: (_, snap) {
                if (snap.data != null) {
                  return Image.memory(snap.data!, fit: BoxFit.cover);
                }
                return AspectRatio(
                  aspectRatio: 0.707,
                  child: Container(
                    color: const Color(0xFFF1F5F9),
                    child: Center(
                      child: Text(
                        '${widget.pageIndex + 1}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }),
    );
  }
}

// ── Signature Pad Painter ───────────────────────────────────────────────────
class _SignaturePadPainter extends CustomPainter {
  final List<Offset> points;
  _SignaturePadPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != Offset.zero && points[i + 1] != Offset.zero) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePadPainter old) => old.points != points;
}

// ── Viewer Bottom Tool Button (frame_001.jpg) ───────────────────────────────
class _ViewerToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ViewerToolBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: _PdfEditorScreenState._text,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit Sub Tab Button (frame_010.jpg) ───────────────────────────────────────
class _EditSubTabBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _EditSubTabBtn({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = _PdfEditorScreenState._accent;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(color: activeColor.withOpacity(0.3), width: 1.2)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? activeColor : const Color(0xFF64748B),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : const Color(0xFF475569),
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Text Formatting Button ──────────────────────────────────────────────────
class _FormattingBtn extends StatelessWidget {
  final String label;
  final bool isBoldText;
  final bool isActive;
  final VoidCallback onTap;
  final String? tooltip;

  const _FormattingBtn({
    required this.label,
    this.isBoldText = false,
    this.isActive = false,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? _PdfEditorScreenState._accent
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? _PdfEditorScreenState._accent
                  : _PdfEditorScreenState._border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : _PdfEditorScreenState._text,
              fontSize: 13,
              fontWeight: isBoldText ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stamp Button for Fill Out Mode ──────────────────────────────────────────
class _StampBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _StampBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ── Gradient button ─────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [pColor, Color(0xFF60A5FA)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: pColor.withOpacity(.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
