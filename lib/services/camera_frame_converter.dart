// lib/services/camera_frame_converter.dart
//
// Adapter between the `camera` plugin's raw frames and the `document_scan`
// detection engine. Keeps all pixel-format / orientation knowledge in one
// place so the controller and the overlay only ever deal with normalized
// (0..1) corner coordinates.

import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:document_scan/document_scan.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

/// Converts a live [CameraImage] into a [ScanInput] the native detector can
/// consume, and reports the geometry needed to draw the overlay on top of the
/// preview.
class CameraFrameConverter {
  const CameraFrameConverter();

  /// Clockwise rotation (0/90/180/270) that brings [image] upright for a device
  /// currently held in [orientation].
  ///
  /// Derived from the buffer's own aspect rather than hard-coding a platform:
  /// Android's YUV plane arrives in sensor (landscape) orientation and needs a
  /// quarter turn in portrait, while iOS already hands back an upright BGRA
  /// buffer and needs none. This stays correct on both without a platform check.
  int rotationFor(CameraImage image, DeviceOrientation orientation) {
    final bool bufferIsLandscape = image.width > image.height;
    final bool upsideDown = orientation == DeviceOrientation.portraitDown ||
        orientation == DeviceOrientation.landscapeRight;

    if (bufferIsLandscape) return upsideDown ? 270 : 90;
    return upsideDown ? 180 : 0;
  }

  /// The size of the frame *after* [rotation] has been applied — i.e. the space
  /// the detector's normalized corners are expressed in, and the space the
  /// preview must be mapped onto.
  Size uprightSize(CameraImage image, int rotation) {
    final bool swapped = rotation == 90 || rotation == 270;
    return swapped
        ? Size(image.height.toDouble(), image.width.toDouble())
        : Size(image.width.toDouble(), image.height.toDouble());
  }

  /// Builds a detector input for [image], or `null` when the frame's plane
  /// layout can't be represented (so the caller simply drops that frame).
  ScanInput? toScanInput(CameraImage image, {required int rotation}) {
    final planes = image.planes;
    if (planes.isEmpty) return null;

    // iOS delivers a single interleaved BGRA plane.
    if (image.format.group == ImageFormatGroup.bgra8888) {
      final plane = planes.first;
      return ScanInput.bgraFrame(
        width: image.width,
        height: image.height,
        rotation: rotation,
        bytes: plane.bytes,
        bytesPerRow: plane.bytesPerRow,
      );
    }

    // Android delivers planar (or semi-planar) YUV 4:2:0: Y + U + V.
    if (planes.length < 3) return null;
    final y = planes[0];
    final u = planes[1];
    final v = planes[2];

    return ScanInput.yuvFrame(
      width: image.width,
      height: image.height,
      rotation: rotation,
      yBytes: y.bytes,
      uBytes: u.bytes,
      vBytes: v.bytes,
      yRowStride: y.bytesPerRow,
      uvRowStride: u.bytesPerRow,
      // 1 for a fully planar layout, 2 for the semi-planar (NV12) layout most
      // CameraX devices report — the native side reads the U/V planes with this
      // stride, so passing it through keeps both layouts correct.
      uvPixelStride: u.bytesPerPixel ?? 1,
    );
  }
}
