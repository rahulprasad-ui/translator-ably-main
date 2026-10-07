// lib/controllers/document_scan_controller.dart
//
// Owns the live scanner session: camera lifecycle, the frame stream feeding the
// native document detector, corner stabilization / auto-capture decisions, and
// the "capture -> detect on the still -> perspective-correct -> temp file"
// pipeline.
//
// Deliberately knows nothing about how the overlay is painted — it exposes
// normalized corners and lets the widget map them onto the preview.

import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:document_scan/document_scan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../helper/my_dialogs.dart';
import '../screen/document_edit_screen.dart';
import '../services/camera_frame_converter.dart';
import '../services/document_scan_service.dart';

/// Live Adobe-Scan-style document capture.
class DocumentScanController extends GetxController {
  DocumentScanController({
    DocumentScanService? service,
    CameraFrameConverter? converter,
  })  : _service = service ?? DocumentScanService(),
        _converter = converter ?? const CameraFrameConverter();

  final DocumentScanService _service;
  final CameraFrameConverter _converter;

  /// Damps the sub-pixel jitter the detector returns every frame so the blue
  /// outline holds still while the document does.
  final CornerStabilizer _stabilizer =
      CornerStabilizer(smoothing: 0.45, resetDistance: 0.12);

  /// Decides when a held document is steady and confident enough to shoot.
  /// Only consulted while [autoCaptureEnabled] is on.
  final AutoCaptureAnalyzer _autoCapture = AutoCaptureAnalyzer(
    requiredSteadyFrames: 3,
    minArea: 0.12,
    maxJitter: 0.045,
  );

  CameraController? _camera;
  StreamController<ScanInput>? _frameSink;
  StreamSubscription<DetectionEvent>? _detectionSub;

  /// Blocked until the frame currently being held leaves the view, so swapping
  /// a page can't trigger a second automatic shot of the same paper.
  bool _autoCaptureArmed = true;

  /// Guards teardown from running twice (dispose + explicit cancel).
  bool _closed = false;

  /// True once pages have been handed to the caller, so teardown keeps them.
  bool _handedOff = false;

  /// Coalesces zoom-slider ticks into fewer platform calls.
  Timer? _zoomDebounce;

  // ── Observable state ───────────────────────────────────────────────────────

  final isInitializing = true.obs;
  final isCameraReady = false.obs;
  final errorMessage = RxnString();
  final cameraFailed = false.obs;

  /// Current detected document quad, normalized 0..1 over the upright frame.
  final liveCorners = Rxn<DocumentCorners>();
  final captureStatus = AutoCaptureStatus.searching.obs;

  /// OFF by default: the shutter is manual, so the photo is taken only when the
  /// user taps the capture button. The user can opt into auto-capture with the
  /// Auto/Manual toggle.
  final autoCaptureEnabled = false.obs;

  /// Live-detection eagerness. Strict is the safe default while framing;
  /// Balanced/Lenient help with faint pages on a low-contrast surface.
  final detectionSensitivity = DetectionSensitivity.strict.obs;

  /// Scan style applied to captured pages. Remembered between pages so a
  /// multi-page scan keeps one consistent look, and used without asking when
  /// auto-capture is on.
  final scanFilter = ScanFilter.enhance.obs;

  final zoomLevel = 1.0.obs;
  final maxZoomLevel = 1.0.obs;

  final isBusy = false.obs;

  /// Pages captured so far this session (cropped + deskewed temp files).
  final pages = <ScannedPageFile>[].obs;
  final flashMode = FlashMode.off.obs;

  CameraController? get cameraController => _camera;

  bool get hasDocument => liveCorners.value != null;

  /// Normalized quad area (0..1) — used to nudge the user closer/farther.
  double get documentArea => liveCorners.value?.area ?? 0.0;

  double? get confidence => liveCorners.value?.confidence;

  /// The upright size of the preview, in the same space as [liveCorners].
  /// Matches `CameraPreview`'s own portrait/landscape aspect handling so the
  /// overlay lines up exactly with what is on screen.
  Size? get previewFrameSize {
    final controller = _camera;
    final size = controller?.value.previewSize;
    if (controller == null || size == null) return null;
    return _isPortrait(controller.value.deviceOrientation)
        ? Size(size.height, size.width)
        : Size(size.width, size.height);
  }

  /// Short instruction shown under the viewfinder.
  String get guidanceText {
    if (errorMessage.value != null) return errorMessage.value!;
    if (!isCameraReady.value) return 'Starting camera…';
    if (!hasDocument) return 'Point the camera at a document';
    if (documentArea < 0.12) return 'Move closer';
    if (documentArea > 0.92) return 'Move farther';
    if (!autoCaptureEnabled.value) return 'Document detected — tap to capture';
    if (captureStatus.value == AutoCaptureStatus.detecting) {
      return 'Document detected — keep steady';
    }
    return 'Document detected';
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    unawaited(_initCamera());
  }

  @override
  void onClose() {
    unawaited(_teardown());
    super.onClose();
  }

  // ── Camera setup ──────────────────────────────────────────────────────────

  ImageFormatGroup get _frameFormat {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return ImageFormatGroup.yuv420;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return ImageFormatGroup.bgra8888;
    }
    return ImageFormatGroup.unknown;
  }

  Future<void> _initCamera() async {
    if (_closed) return;
    isInitializing.value = true;
    errorMessage.value = null;
    cameraFailed.value = false;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _failCamera('No camera was found on this device.');
        return;
      }

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = await _openCamera(back);
      if (controller == null) return;
      _camera = controller;

      isCameraReady.value = true;
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        // Not every lens exposes a flash — the toggle just stays disabled.
      }
      await _loadZoomRange();
      await _beginDetection();
    } catch (e) {
      _failCamera('Could not start the camera: $e');
    } finally {
      isInitializing.value = false;
    }
  }

  /// Opens the camera, preferring 1080p for capture quality and falling back to
  /// 720p on devices that reject the higher preset.
  Future<CameraController?> _openCamera(CameraDescription description) async {
    CameraException? lastError;

    for (final preset in const [ResolutionPreset.veryHigh, ResolutionPreset.high]) {
      final controller = CameraController(
        description,
        preset,
        enableAudio: false,
        imageFormatGroup: _frameFormat,
      );
      try {
        await controller.initialize();
        return controller;
      } on CameraException catch (e) {
        lastError = e;
        try {
          await controller.dispose();
        } catch (_) {}
      }
    }

    if (lastError != null) _failCamera(_describeCameraError(lastError));
    return null;
  }

  String _describeCameraError(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Camera access was denied. Enable camera permission for this app in your device settings, then try again.';
      case 'AudioAccessDenied':
      case 'AudioAccessDeniedWithoutPrompt':
        return 'Microphone access was denied.';
      default:
        return 'Could not start the camera (${e.code}).';
    }
  }

  void _failCamera(String message) {
    errorMessage.value = message;
    cameraFailed.value = true;
    isCameraReady.value = false;
    captureStatus.value = AutoCaptureStatus.searching;
  }

  Future<void> retryCamera() async {
    await _stopDetection();
    try {
      await _camera?.dispose();
    } catch (_) {}
    _camera = null;
    zoomLevel.value = 1.0;
    maxZoomLevel.value = 1.0;
    _stabilizer.reset();
    _autoCapture.reset();
    _autoCaptureArmed = true;
    await _initCamera();
  }

  // ── Detection pipeline ────────────────────────────────────────────────────

  Future<void> _beginDetection() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    // Guard against double-starting — startImageStream() throws if the stream
    // is already running.
    if (_frameSink != null) return;

    final sink = StreamController<ScanInput>();
    _frameSink = sink;

    _detectionSub = _service
        .watchFrames(
          sink.stream,
          stabilizer: _stabilizer,
          sensitivity: detectionSensitivity.value,
        )
        .listen(_onDetectionEvent, onError: (Object e) {
      log('[DocumentScan] detection stream error: $e');
    });

    await camera.startImageStream((CameraImage image) {
      final target = _frameSink;
      if (target == null || target.isClosed) return;
      final rotation = _converter.rotationFor(image, camera.value.deviceOrientation);
      final input = _converter.toScanInput(image, rotation: rotation);
      if (input == null) return;
      target.add(input);
    });
  }

  void _onDetectionEvent(DetectionEvent event) {
    // While a still is being taken and warped the stream is paused anyway; this
    // also stops a late event from moving the overlay under the user.
    if (isBusy.value) return;

    switch (event) {
      case DetectionSuccess(:final corners):
        liveCorners.value = corners;
      case DetectionEmpty():
        liveCorners.value = null;
      case DetectionSkipped():
        // Backpressure, not a detection result — keep the last overlay state.
        return;
      case DetectionError(:final error):
        log('[DocumentScan] frame detection failed: $error');
        liveCorners.value = null;
    }

    final state = _autoCapture.addEvent(event);
    captureStatus.value = state.status;

    if (!_autoCaptureArmed) {
      if (liveCorners.value == null) _autoCaptureArmed = true;
      return;
    }

    if (autoCaptureEnabled.value && state.shouldCapture) {
      // Hands-free capture: crop with the remembered filter instead of stopping
      // to edit each page.
      unawaited(capture(edit: false));
    }
  }

  Future<void> _stopDetection() async {
    final sink = _frameSink;
    final camera = _camera;
    _frameSink = null;

    try {
      if (camera != null && camera.value.isStreamingImages) {
        await camera.stopImageStream();
      }
    } catch (e) {
      log('[DocumentScan] stopImageStream failed: $e');
    }

    await _detectionSub?.cancel();
    _detectionSub = null;

    if (sink != null && !sink.isClosed) {
      await sink.close();
    }
  }

  // ── Capture ───────────────────────────────────────────────────────────────

  /// Takes a full-resolution still, detects the document in it, and turns it
  /// into a new page.
  ///
  /// With [edit] true (a manual tap) the user gets the adjust-corners + filter
  /// step before the page is added. With [edit] false — used by hands-free
  /// auto-capture — the page is cropped straight away with the remembered
  /// filter, since stopping to edit every page would defeat auto-capture.
  Future<void> capture({bool edit = true}) async {
    if (isBusy.value) return;
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;

    isBusy.value = true;
    final liveSnapshot = liveCorners.value;
    String? stillPath;

    try {
      // The camera plugin is not reliable when a picture is taken while an
      // image stream is running, so pause detection for the shot. The preview
      // keeps rendering throughout.
      await _stopDetection();

      final XFile still = await camera.takePicture();
      stillPath = still.path;

      // Re-detect on the full-resolution still: the live quad lives in preview
      // space and can be off if the still has a different size or orientation.
      // Fall back to the live quad so a hard-to-detect still still crops.
      final detected = await _service.detectInStill(stillPath) ?? liveSnapshot;
      if (detected == null) {
        MyDialogs.info(
          msg: 'No document detected. Point the camera at a page and try again.',
        );
        return;
      }
      final corners = detected;

      // Let the preview come back to life while the editor is open.
      if (!_closed && _camera != null) await _beginDetection();

      ScannedDocument? document;
      ScanFilter usedFilter = scanFilter.value;

      if (edit) {
        final edited = await Get.to<DocumentEditResult>(
          () => DocumentEditScreen(
            imagePath: stillPath!,
            corners: corners,
            initialFilter: scanFilter.value,
          ),
        );
        if (edited == null) return; // page abandoned in the editor
        document = edited.document;
        usedFilter = edited.filter;
      } else {
        document = await _service.cropToDocument(
          stillPath,
          corners,
          filter: usedFilter,
        );
      }

      if (document == null) {
        MyDialogs.info(msg: 'Could not process the captured document.');
        return;
      }

      final page = await _service.savePageToTemp(
        document,
        tag: 'p${pages.length + 1}',
      );
      pages.add(page);
      scanFilter.value = usedFilter;

      // Hold off auto-capture until this page is out of frame, so a swap can't
      // fire a second shot of the same paper.
      _autoCapture.reset();
      _autoCaptureArmed = false;
      captureStatus.value = AutoCaptureStatus.searching;
    } catch (e) {
      log('[DocumentScan] capture failed: $e');
      MyDialogs.info(msg: 'Capture failed: $e');
    } finally {
      if (stillPath != null) await _safeDelete(stillPath);

      // Covers the paths that bail out before the preview was resumed.
      if (!_closed && _camera != null && _frameSink == null) {
        try {
          await _beginDetection();
        } catch (e) {
          log('[DocumentScan] failed to resume detection: $e');
        }
      }
      isBusy.value = false;
    }
  }

  Future<void> _safeDelete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Plugin cache dir — a failed cleanup is harmless.
    }
  }

  // ── User actions ──────────────────────────────────────────────────────────

  void toggleAutoCapture(bool value) {
    autoCaptureEnabled.value = value;
    if (value) {
      _autoCapture.reset();
      _autoCaptureArmed = true;
      captureStatus.value = AutoCaptureStatus.searching;
    }
  }

  Future<void> toggleFlash() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    final next = flashMode.value == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await camera.setFlashMode(next);
      flashMode.value = next;
    } catch (e) {
      log('[DocumentScan] setFlashMode failed: $e');
      MyDialogs.info(msg: 'Flash is not available on this camera.');
    }
  }

  // ── Zoom ──────────────────────────────────────────────────────────────────

  /// Reads the lens' zoom range once the camera is up. Stays at 1.0 (slider
  /// hidden) when the device exposes no zoom or the call fails.
  Future<void> _loadZoomRange() async {
    final camera = _camera;
    if (camera == null) return;
    try {
      final max = await camera.getMaxZoomLevel();
      maxZoomLevel.value = (max.isFinite && max > 1.0) ? max : 1.0;
    } catch (e) {
      log('[DocumentScan] getMaxZoomLevel failed: $e');
      maxZoomLevel.value = 1.0;
    }
  }

  /// Updates the zoom level. Safe to call on every slider tick — the value
  /// shows immediately and the platform call is coalesced.
  void setZoom(double value) {
    final ceiling = maxZoomLevel.value > 1.0 ? maxZoomLevel.value : 1.0;
    final target = value.clamp(1.0, ceiling);
    zoomLevel.value = target;
    _zoomDebounce?.cancel();
    _zoomDebounce = Timer(const Duration(milliseconds: 40), () {
      _applyZoomLevel(target);
    });
  }

  Future<void> _applyZoomLevel(double target) async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    try {
      await camera.setZoomLevel(target);
    } catch (e) {
      log('[DocumentScan] setZoomLevel failed: $e');
    }
  }

  // ── Detection sensitivity ─────────────────────────────────────────────────

  /// How eagerly the live detector accepts a rectangle. Restarts the detection
  /// stream so the new threshold takes effect immediately — except while a
  /// capture is in flight, in which case [beginDetection] picks it up on resume.
  Future<void> setSensitivity(DetectionSensitivity sensitivity) async {
    if (detectionSensitivity.value == sensitivity) return;
    detectionSensitivity.value = sensitivity;

    if (isBusy.value || _closed || _camera == null) return;

    await _stopDetection();
    _stabilizer.reset();
    _autoCapture.reset();
    _autoCaptureArmed = true;
    captureStatus.value = AutoCaptureStatus.searching;
    try {
      await _beginDetection();
    } catch (e) {
      log('[DocumentScan] restart after sensitivity change failed: $e');
    }
  }

  Future<void> removePage(int index) async {
    if (index < 0 || index >= pages.length) return;
    final page = pages.removeAt(index);
    await _service.deletePages([page.path]);
  }

  /// Hands the captured pages back to the caller.
  void finish() {
    if (pages.isEmpty) return;
    _handedOff = true;
    Get.back(result: DocumentScanOutcome(imagePaths: pages.map((p) => p.path).toList()));
  }

  /// Abandons the session and lets the caller fall back to another capture path.
  /// Any pages captured so far are NOT handed back, so teardown deletes them.
  void cancel({bool cameraUnavailable = false}) {
    Get.back(result: DocumentScanOutcome(cameraFailed: cameraUnavailable));
  }

  // ── Teardown ──────────────────────────────────────────────────────────────

  Future<void> _teardown() async {
    if (_closed) return;
    _closed = true;

    _zoomDebounce?.cancel();
    await _stopDetection();

    try {
      await _camera?.dispose();
    } catch (e) {
      log('[DocumentScan] camera dispose failed: $e');
    }
    _camera = null;

    if (!_handedOff) {
      await _service.deletePages(pages.map((p) => p.path));
      pages.clear();
    }
  }

  static bool _isPortrait(DeviceOrientation orientation) {
    return orientation == DeviceOrientation.portraitUp ||
        orientation == DeviceOrientation.portraitDown;
  }
}
