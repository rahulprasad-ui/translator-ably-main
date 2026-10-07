// lib/services/document_scan_service.dart
//
// Thin, UI-free wrapper around the `document_scan` engine so the rest of the
// app depends on one small surface instead of the package directly:
//   * live frame detection  -> normalized four-corner quads
//   * perspective correction -> a deskewed, cropped ScannedDocument
//   * persistence            -> a temp JPEG path the existing OCR pipeline reads
//
// Nothing here touches the camera or widgets; the controller owns those.

import 'dart:io';
import 'dart:typed_data';

import 'package:document_scan/document_scan.dart';
import 'package:path_provider/path_provider.dart';

/// A perspective-corrected page written to a temp file on disk.
///
/// The OCR pipeline works on file paths (`InputImage.fromFilePath`), so the
/// scanner hands back paths rather than in-memory bytes.
class ScannedPageFile {
  const ScannedPageFile({
    required this.path,
    required this.width,
    required this.height,
  });

  final String path;
  final int width;
  final int height;
}

/// What the scanner screen hands back to whoever opened it.
class DocumentScanOutcome {
  const DocumentScanOutcome({
    this.imagePaths = const [],
    this.cameraFailed = false,
  });

  /// Temp-file paths of the cropped, deskewed pages, in capture order.
  final List<String> imagePaths;

  /// True when the live camera could not be used on this device, so the caller
  /// may fall back to its previous capture path.
  final bool cameraFailed;

  bool get isEmpty => imagePaths.isEmpty;
}

/// Document detection + perspective correction + temp-file persistence.
class DocumentScanService {
  DocumentScanService({DocumentDetector? detector, DocumentProcessor? processor})
      : _detector = detector ?? DocumentDetector(),
        _processor = processor ?? const DocumentProcessor();

  final DocumentDetector _detector;
  final DocumentProcessor _processor;

  /// Cap on how often a live frame reaches the native detector. 30–60 fps of
  /// OpenCV work heats the device without making the overlay smoother.
  static const Duration liveDetectionInterval = Duration(milliseconds: 120);

  /// Watches a stream of camera frames and emits one [DetectionEvent] per
  /// handled frame. [stabilizer] damps the per-frame corner jitter so the blue
  /// outline doesn't shimmer while the document is held still.
  ///
  /// [sensitivity] defaults to strict — the safest choice while framing, since
  /// it keeps the overlay off table edges and shadows. Expose lenient/balanced
  /// to the user for low-contrast paper on a light desk.
  Stream<DetectionEvent> watchFrames(
    Stream<ScanInput> frames, {
    CornerStabilizer? stabilizer,
    DetectionSensitivity sensitivity = DetectionSensitivity.strict,
  }) {
    return _detector.detectStream(
      frames,
      stabilize: stabilizer,
      sensitivity: sensitivity,
      minInterval: liveDetectionInterval,
    );
  }

  /// Finds document corners in a still image. Lenient because the user has
  /// already committed to a document by pressing capture.
  Future<DocumentCorners?> detectInStill(String path) {
    return _detector.detect(
      ScanInput.file(path),
      sensitivity: DetectionSensitivity.lenient,
    );
  }

  /// Perspective-corrects the quad at [corners] out of the still at [path] and
  /// returns an upright, cropped, optionally filtered document.
  ///
  /// Runs on a background isolate (`background: true`) because the warp samples
  /// every output pixel in Dart.
  Future<ScannedDocument?> cropToDocument(
    String path,
    DocumentCorners corners, {
    ScanFilter filter = ScanFilter.enhance,
    ScanOutputFormat output = const ScanOutputFormat.jpegAt(92),
    int? maxDimension = DocumentProcessor.defaultMaxDimension,
  }) {
    return _processor.crop(
      ScanInput.file(path),
      corners,
      filter: filter,
      output: output,
      maxDimension: maxDimension,
      background: true,
    );
  }

  /// Re-applies [filter] to an already-cropped scan, skipping detection and the
  /// perspective warp. Cheap enough for the editor to preview filter changes
  /// without re-running the expensive part.
  Future<ScannedDocument?> applyFilter(
    ScannedDocument cropped,
    ScanFilter filter, {
    ScanOutputFormat output = const ScanOutputFormat.jpegAt(92),
  }) {
    return _processor.applyFilter(
      ScanInput.bytes(
        cropped.bytes,
        width: cropped.width,
        height: cropped.height,
      ),
      filter,
      output: output,
      background: true,
    );
  }

  /// Writes [document] to a temp JPEG and returns its path + dimensions.
  ///
  /// Give this a document produced with [ScanOutputFormat.jpeg] — the `.jpg`
  /// extension is what ML Kit uses to decode it during OCR.
  Future<ScannedPageFile> savePageToTemp(
    ScannedDocument document, {
    String? tag,
  }) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final suffix = (tag == null || tag.isEmpty) ? '' : '_$tag';
    final path =
        '${dir.path}/scan_$stamp${suffix}_${document.width}x${document.height}.jpg';

    final file = File(path);
    await file.writeAsBytes(Uint8List.fromList(document.bytes), flush: true);

    return ScannedPageFile(
      path: path,
      width: document.width,
      height: document.height,
    );
  }

  /// Best-effort cleanup of temp scan files that the caller did not keep.
  Future<void> deletePages(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Temp files — a failed delete is harmless.
      }
    }
  }
}
