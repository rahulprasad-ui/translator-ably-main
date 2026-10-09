import 'package:flutter/material.dart';
import 'domain/license_registry_service.dart';
import 'presentation/pages/pdf_editor_page.dart';

/// Clean public entry point for PDF Editor V2 module
class PdfEditorV2 {
  /// Opens the PDF Editor V2 in a new route
  static Future<void> open(BuildContext context, {String? pdfPath}) async {
    PdfLicenseRegistryService.registerLicenses();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfEditorPage(initialPdfPath: pdfPath),
      ),
    );
  }

  /// Returns the widget directly
  static Widget createScreen({String? pdfPath}) {
    PdfLicenseRegistryService.registerLicenses();
    return PdfEditorPage(initialPdfPath: pdfPath);
  }

  /// Displays the full third-party open-source license page for legal compliance
  static void showLicenses(BuildContext context) {
    PdfLicenseRegistryService.registerLicenses();
    showLicensePage(
      context: context,
      applicationName: 'PDF Editor Pro',
      applicationVersion: '2.0.0',
    );
  }
}
