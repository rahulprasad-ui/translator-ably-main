// lib/features/pdf_editor_v2/domain/coordinate_converter.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/models/pdf_text_item.dart';

/// Handles coordinate conversion between PDF Points, Page Canvas, Viewport, and Screen.
///
/// In standard PDF specs (ISO 32000-1):
/// - Native PDF origin is Bottom-Left, with Y pointing Upwards.
/// - In Flutter and extracted page models, origin is normalized to Top-Left, with Y pointing Downwards.
/// - 1 PDF Point = 1/72 inch (~0.3527 mm).
class CoordinateConverter {
  /// Converts a point on the PDF page (top-left origin, in points) to viewport screen coordinates.
  static Offset pageToScreen(
    Offset pagePoint, {
    required double scale,
    Offset panOffset = Offset.zero,
  }) {
    return Offset(
      pagePoint.dx * scale + panOffset.dx,
      pagePoint.dy * scale + panOffset.dy,
    );
  }

  /// Converts a viewport screen tap back to page coordinates (in PDF points).
  static Offset screenToPage(
    Offset screenPoint, {
    required double scale,
    Offset panOffset = Offset.zero,
  }) {
    if (scale <= 0) return Offset.zero;
    return Offset(
      (screenPoint.dx - panOffset.dx) / scale,
      (screenPoint.dy - panOffset.dy) / scale,
    );
  }

  /// Scales a PDF bounding box rectangle to screen coordinates.
  static Rect pdfRectToScreen(
    Rect pdfRect, {
    required double scale,
    Offset panOffset = Offset.zero,
  }) {
    return Rect.fromLTWH(
      pdfRect.left * scale + panOffset.dx,
      pdfRect.top * scale + panOffset.dy,
      pdfRect.width * scale,
      pdfRect.height * scale,
    );
  }

  /// Converts a screen rectangle back to PDF points.
  static Rect screenRectToPdf(
    Rect screenRect, {
    required double scale,
    Offset panOffset = Offset.zero,
  }) {
    if (scale <= 0) return Rect.zero;
    return Rect.fromLTWH(
      (screenRect.left - panOffset.dx) / scale,
      (screenRect.top - panOffset.dy) / scale,
      screenRect.width / scale,
      screenRect.height / scale,
    );
  }

  /// Converts bottom-left PDF coordinates to top-left viewport coordinates.
  static Offset nativePdfToTopLeft(
    Offset nativePdfPoint, {
    required double pageHeight,
  }) {
    return Offset(nativePdfPoint.dx, pageHeight - nativePdfPoint.dy);
  }

  /// Converts top-left viewport coordinates to native bottom-left PDF coordinates.
  static Offset topLeftToNativePdf(
    Offset topLeftPoint, {
    required double pageHeight,
    double itemHeight = 0.0,
  }) {
    return Offset(topLeftPoint.dx, pageHeight - topLeftPoint.dy - itemHeight);
  }

  /// Rotates a rectangle around page dimensions by given angle (0, 90, 180, 270 degrees).
  static Rect applyRotation(
    Rect rect, {
    required int rotationDegrees,
    required Size pageSize,
  }) {
    final normalizedAngle = ((rotationDegrees % 360) + 360) % 360;
    switch (normalizedAngle) {
      case 90:
        // Clockwise 90: (x, y) -> (pageHeight - y - h, x)
        return Rect.fromLTWH(
          pageSize.height - rect.bottom,
          rect.left,
          rect.height,
          rect.width,
        );
      case 180:
        // 180 degrees: (x, y) -> (pageWidth - x - w, pageHeight - y - h)
        return Rect.fromLTWH(
          pageSize.width - rect.right,
          pageSize.height - rect.bottom,
          rect.width,
          rect.height,
        );
      case 270:
        // Clockwise 270: (x, y) -> (y, pageWidth - x - w)
        return Rect.fromLTWH(
          rect.top,
          pageSize.width - rect.right,
          rect.height,
          rect.width,
        );
      case 0:
      default:
        return rect;
    }
  }

  /// Reverses rotation to map a rotated coordinate back to original page coordinates.
  static Rect unapplyRotation(
    Rect rect, {
    required int rotationDegrees,
    required Size pageSize,
  }) {
    final normalizedAngle = ((rotationDegrees % 360) + 360) % 360;
    final reverseAngle = (360 - normalizedAngle) % 360;
    // Note: for 90 and 270, the rotated page dimensions are swapped
    final effectiveSize = (normalizedAngle == 90 || normalizedAngle == 270)
        ? Size(pageSize.height, pageSize.width)
        : pageSize;
    return applyRotation(rect, rotationDegrees: reverseAngle, pageSize: effectiveSize);
  }

  /// Finds the closest matching text item at the specified page point.
  /// If multiple items hit, selects the closest item by bounding-box center distance.
  static PdfTextItem? hitTest(
    Offset pagePoint,
    List<PdfTextItem> items, {
    double hitSlop = 6.0,
  }) {
    if (items.isEmpty) return null;

    final hits = <PdfTextItem>[];
    for (final item in items) {
      if (item.containsPoint(pagePoint, slop: hitSlop)) {
        hits.add(item);
      }
    }

    if (hits.isEmpty) {
      // Find nearest item within a reasonable proximity threshold
      PdfTextItem? nearest;
      double minDistanceSq = 400.0; // 20pt radius squared
      for (final item in items) {
        final distSq = item.distanceSquaredTo(pagePoint);
        if (distSq < minDistanceSq) {
          minDistanceSq = distSq;
          nearest = item;
        }
      }
      return nearest;
    }

    if (hits.length == 1) return hits.first;

    // Multiple overlaps: select closest by center distance
    hits.sort((a, b) => a.distanceSquaredTo(pagePoint).compareTo(b.distanceSquaredTo(pagePoint)));
    return hits.first;
  }
}
