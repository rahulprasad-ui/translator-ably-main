// lib/screen/document_scanner_screen.dart
//
// Live document scanner screen (Adobe Scan style). Returns a
// `DocumentScanOutcome` through `Get.to`, whose `imagePaths` are already
// perspective-corrected, cropped documents ready for OCR.

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:document_scan/document_scan.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/document_scan_controller.dart';
import '../widget/document_overlay_painter.dart';

class DocumentScannerScreen extends StatefulWidget {
  const DocumentScannerScreen({super.key});

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen>
    with SingleTickerProviderStateMixin {
  static const String _sessionTag = 'document_scanner_session';

  late final DocumentScanController _c;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _c = Get.put(DocumentScanController(), tag: _sessionTag);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    // Triggers DocumentScanController.onClose -> camera teardown + cleanup of
    // any pages the user never confirmed.
    if (Get.isRegistered<DocumentScanController>(tag: _sessionTag)) {
      Get.delete<DocumentScanController>(tag: _sessionTag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (_c.cameraFailed.value) return _buildCameraUnavailable();
        if (_c.isInitializing.value) return _buildStarting();
        return _buildScanner();
      }),
    );
  }

  // ── Main scanner layout ───────────────────────────────────────────────────

  Widget _buildScanner() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Live camera preview, laid out with BoxFit.cover so the overlay
        //    can map normalized corners with the exact same transform.
        _buildPreview(),

        // 2. Blue document boundary, drawn from the detected corners.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final corners = _c.liveCorners.value;
              return CustomPaint(
                painter: DocumentOverlayPainter(
                  corners: corners,
                  frameSize: _c.previewFrameSize,
                  pulse: _pulse.value,
                  steady: corners != null &&
                      _c.autoCaptureEnabled.value &&
                      _c.captureStatus.value == AutoCaptureStatus.detecting,
                ),
              );
            },
          ),
        ),

        // 3. Chrome
        SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const Spacer(),
              _buildGuidancePill(),
              const SizedBox(height: 14),
              _buildPageStrip(),
              _buildBottomBar(),
            ],
          ),
        ),

        // 4. Zoom, only when the lens actually supports it
        Positioned(
          right: 8,
          top: 0,
          bottom: 200,
          child: Center(child: _buildZoomSlider()),
        ),

        // 5. Blocking state while the still is cropped / warped
        if (_c.isBusy.value) _buildBusyOverlay(),
      ],
    );
  }

  Widget _buildPreview() {
    final controller = _c.cameraController;
    final frame = _c.previewFrameSize;
    if (controller == null ||
        frame == null ||
        !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: frame.width,
          height: frame.height,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          _roundIconButton(
            icon: Icons.close_rounded,
            onTap: _c.isBusy.value ? null : () => _c.cancel(),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.document_scanner_rounded,
                    color: Colors.white, size: 15),
                SizedBox(width: 6),
                Text(
                  'Document Scan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Obx(
            () => _roundIconButton(
              icon: _c.flashMode.value == FlashMode.torch
                  ? Icons.flash_on_rounded
                  : Icons.flash_off_rounded,
              active: _c.flashMode.value == FlashMode.torch,
              onTap: _c.toggleFlash,
            ),
          ),
          const SizedBox(width: 8),
          _buildSensitivityMenu(),
        ],
      ),
    );
  }

  /// Picks how eagerly the detector accepts a rectangle. Lenient helps when a
  /// faint page on a light desk isn't being found at the default.
  Widget _buildSensitivityMenu() {
    return Obx(() {
      final current = _c.detectionSensitivity.value;
      return PopupMenuButton<DetectionSensitivity>(
        tooltip: 'Detection sensitivity',
        color: const Color(0xFF1B2230),
        onSelected: _c.setSensitivity,
        itemBuilder: (context) => DetectionSensitivity.values
            .map(
              (value) => PopupMenuItem<DetectionSensitivity>(
                value: value,
                child: Row(
                  children: [
                    Icon(
                      value == current
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: value == current
                          ? const Color(0xFF2979FF)
                          : Colors.white54,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _sensitivityLabel(value),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
        ),
      );
    });
  }

  String _sensitivityLabel(DetectionSensitivity value) {
    switch (value) {
      case DetectionSensitivity.strict:
        return 'Strict — clear pages only';
      case DetectionSensitivity.balanced:
        return 'Balanced — recommended';
      case DetectionSensitivity.lenient:
        return 'Lenient — faint / low-contrast';
    }
  }

  Widget _buildZoomSlider() {
    return Obx(() {
      final max = _c.maxZoomLevel.value;
      if (max <= 1.05) return const SizedBox.shrink();
      final value = _c.zoomLevel.value.clamp(1.0, max);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${value.toStringAsFixed(1)}x',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 116,
              width: 34,
              child: RotatedBox(
                quarterTurns: 3, // vertical, min at the bottom
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    activeTrackColor: const Color(0xFF2979FF),
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor:
                        const Color(0xFF2979FF).withValues(alpha: 0.2),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: value,
                    min: 1.0,
                    max: max,
                    onChanged: _c.setZoom,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _roundIconButton({
    required IconData icon,
    VoidCallback? onTap,
    bool active = false,
  }) {
    return Material(
      color: active
          ? const Color(0xFF2979FF)
          : Colors.black.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  // ── Guidance ──────────────────────────────────────────────────────────────

  Widget _buildGuidancePill() {
    return Obx(() {
      final bool detected = _c.hasDocument;
      final bool steady = detected &&
          _c.autoCaptureEnabled.value &&
          _c.captureStatus.value == AutoCaptureStatus.detecting;

      final Color accent = steady
          ? const Color(0xFF00E676)
          : detected
              ? const Color(0xFF2979FF)
              : Colors.white;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _c.autoCaptureEnabled.value && steady
                  ? Icons.motion_photos_on_rounded
                  : detected
                      ? Icons.check_circle_rounded
                      : Icons.center_focus_strong_rounded,
              color: accent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _c.guidanceText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── Captured page strip ───────────────────────────────────────────────────

  Widget _buildPageStrip() {
    return Obx(() {
      if (_c.pages.isEmpty) return const SizedBox.shrink();
      return SizedBox(
        height: 68,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _c.pages.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) => _buildThumbnail(index),
        ),
      );
    });
  }

  Widget _buildThumbnail(int index) {
    final page = _c.pages[index];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF2979FF), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(
            File(page.path),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const Icon(
              Icons.description_rounded,
              color: Colors.grey,
              size: 22,
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: () => _c.removePage(index),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Color(0xFFFF5252),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 12),
            ),
          ),
        ),
        Positioned(
          bottom: -2,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${index + 1}',
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
    );
  }

  // ── Bottom controls ───────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      child: Row(
        children: [
          // Auto-capture toggle
          Obx(
            () => _c.autoCaptureEnabled.value
                ? _textChip(
                    icon: Icons.bolt_rounded,
                    label: 'Auto',
                    active: true,
                    onTap: () => _c.toggleAutoCapture(false),
                  )
                : _textChip(
                    icon: Icons.pan_tool_alt_rounded,
                    label: 'Manual',
                    active: false,
                    onTap: () => _c.toggleAutoCapture(true),
                  ),
          ),

          // Capture button
          Expanded(
            child: Center(
              child: Obx(
                () => _buildCaptureButton(enabled: !_c.isBusy.value),
              ),
            ),
          ),

          // Done
          Obx(
            () => _c.pages.isEmpty
                ? const SizedBox(width: 74)
                : _textChip(
                    icon: Icons.check_rounded,
                    label: 'Done (${_c.pages.length})',
                    active: true,
                    onTap: _c.finish,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureButton({required bool enabled}) {
    return Semantics(
      button: true,
      label: 'Capture document',
      child: GestureDetector(
        onTap: enabled ? _c.capture : null,
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: enabled ? Colors.white : Colors.white38,
              width: 3,
            ),
          ),
          child: Center(
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled ? Colors.white : Colors.white38,
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                color: enabled ? Colors.black87 : Colors.black38,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _textChip({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active
          ? const Color(0xFF2979FF)
          : Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 15),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Overlays ──────────────────────────────────────────────────────────────

  Widget _buildBusyOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(Color(0xFF2979FF)),
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Cropping document…',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarting() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(Color(0xFF2979FF)),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Starting camera…',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraUnavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_rounded,
                color: Colors.white54, size: 54),
            const SizedBox(height: 18),
            Text(
              _c.errorMessage.value ?? 'Camera is unavailable.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _c.retryCamera(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _c.cancel(cameraUnavailable: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2979FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    icon: const Icon(Icons.photo_camera_rounded, size: 18),
                    label: const Text('System camera'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
