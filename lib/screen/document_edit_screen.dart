// lib/screen/document_edit_screen.dart
//
// Post-capture editing, in two steps (like Adobe Scan):
//   1. Adjust  — drag the four detected corners until the outline hugs the page.
//   2. Filter  — choose a scan style and preview it on the cropped result.
//
// The perspective warp runs once (step 1 -> 2); switching filters afterwards
// only re-filters the already-cropped image, so previews stay fast.

import 'dart:async';
import 'dart:io';

import 'package:document_scan/document_scan.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../helper/my_dialogs.dart';
import '../services/document_scan_service.dart';
import '../widget/document_corner_editor.dart';

/// What the editor hands back to the scanner.
class DocumentEditResult {
  const DocumentEditResult({required this.document, required this.filter});

  /// The cropped, deskewed, filtered page.
  final ScannedDocument document;

  /// The filter the user settled on — remembered as the default for the next
  /// page so a multi-page scan keeps one consistent look.
  final ScanFilter filter;
}

class DocumentEditScreen extends StatefulWidget {
  const DocumentEditScreen({
    super.key,
    required this.imagePath,
    required this.corners,
    this.initialFilter = ScanFilter.enhance,
  });

  final String imagePath;

  /// Corners detected on the still, normalized 0..1.
  final DocumentCorners corners;

  final ScanFilter initialFilter;

  @override
  State<DocumentEditScreen> createState() => _DocumentEditScreenState();
}

class _DocumentEditScreenState extends State<DocumentEditScreen> {
  static const Color _accent = Color(0xFF2979FF);

  final DocumentScanService _service = DocumentScanService();

  late DocumentCorners _corners = widget.corners;
  late ScanFilter _filter = widget.initialFilter;

  Size? _imageSize;
  bool _imageFailed = false;

  int _step = 0;

  /// The unfiltered crop produced in step 1 — the base for every filter change.
  ScannedDocument? _cropped;

  /// The currently displayed (filtered) result.
  ScannedDocument? _filtered;

  bool _busy = false;
  Timer? _filterDebounce;

  @override
  void initState() {
    super.initState();
    _resolveImageSize();
  }

  @override
  void dispose() {
    _filterDebounce?.cancel();
    super.dispose();
  }

  /// Reads the still's true pixel dimensions so corner dragging can be mapped
  /// onto the image. `ImageStreamListener` gives the EXIF-oriented size, which
  /// is the same space the detector reports corners in.
  void _resolveImageSize() {
    final stream =
        FileImage(File(widget.imagePath)).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        if (!mounted) return;
        setState(() {
          _imageSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      },
      onError: (_, _) {
        stream.removeListener(listener);
        if (!mounted) return;
        setState(() => _imageFailed = true);
      },
    );
    stream.addListener(listener);
  }

  // ── Step 1 -> 2 ───────────────────────────────────────────────────────────

  Future<void> _applyCropAndContinue() async {
    setState(() => _busy = true);
    try {
      final cropped = await _service.cropToDocument(
        widget.imagePath,
        _corners,
        filter: ScanFilter.none,
        maxDimension: 1600,
      );

      if (!mounted) return;
      if (cropped == null) {
        MyDialogs.info(
          msg: 'Could not crop the page. Adjust the corners and try again.',
        );
        return;
      }

      _cropped = cropped;
      setState(() => _step = 1);
      await _runFilter(_filter);
    } catch (e) {
      if (mounted) MyDialogs.info(msg: 'Could not crop the page: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Filters ───────────────────────────────────────────────────────────────

  Future<void> _runFilter(ScanFilter filter) async {
    final base = _cropped;
    if (base == null) return;

    setState(() => _busy = true);
    try {
      final result = await _service.applyFilter(base, filter);
      if (!mounted || _filter != filter) return;
      setState(() => _filtered = result ?? base);
    } catch (e) {
      if (mounted) MyDialogs.info(msg: 'Could not apply the filter: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectFilter(ScanFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    // Coalesce rapid taps so only the last choice is rendered.
    _filterDebounce?.cancel();
    _filterDebounce =
        Timer(const Duration(milliseconds: 150), () => _runFilter(filter));
  }

  void _finish() {
    final result = _filtered;
    if (result == null) {
      MyDialogs.info(msg: 'Still preparing the page — try again in a moment.');
      return;
    }
    Get.back(result: DocumentEditResult(document: result, filter: _filter));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F18),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _busy ? null : () => Get.back(),
            icon: Icon(
              _step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
              color: Colors.white,
            ),
            tooltip: _step == 0 ? 'Cancel' : 'Back to crop',
          ),
          const Spacer(),
          Text(
            _step == 0 ? 'Adjust crop' : 'Choose filter',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // balances the leading icon
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_imageFailed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Could not read the captured photo.\nPlease go back and capture again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
        ),
      );
    }

    if (_imageSize == null) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation(_accent),
        ),
      );
    }

    if (_step == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: DocumentCornerEditor(
          imagePath: widget.imagePath,
          imageSize: _imageSize!,
          corners: _corners,
          onCornersChanged: (updated) => setState(() => _corners = updated),
        ),
      );
    }

    final preview = _filtered;
    if (preview == null) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation(_accent),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Image.memory(
            preview.bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(_accent),
                ),
              ),
            ),
          if (_step == 0) _buildStepOneFooter() else _buildStepTwoFooter(),
        ],
      ),
    );
  }

  Widget _buildStepOneFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Drag the corners until the outline fits the page exactly',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 12.5),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => Get.back(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retake'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _applyCropAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Next'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepTwoFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 74,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip(ScanFilter.none, 'Original', Icons.image_rounded),
              _filterChip(
                  ScanFilter.enhance, 'Enhance', Icons.auto_awesome_rounded),
              _filterChip(
                  ScanFilter.grayscale, 'Grayscale', Icons.gradient_rounded),
              _filterChip(
                  ScanFilter.blackWhite, 'B&W', Icons.contrast_rounded),
              _filterChip(
                  ScanFilter.magicColor, 'Magic', Icons.blur_on_rounded),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => setState(() => _step = 0),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.crop_free_rounded, size: 18),
                label: const Text('Adjust'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _finish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Done'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(ScanFilter filter, String label, IconData icon) {
    final selected = _filter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => _selectFilter(filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _accent : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _accent : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
