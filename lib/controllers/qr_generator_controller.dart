// lib/controllers/qr_generator_controller.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../helper/my_dialogs.dart';

enum QrDataType {
  url,
  text,
  wifi,
  contact,
  email,
  phone,
  upi,
}

class SavedQrItem {
  final String id;
  final String title;
  final String payload;
  final QrDataType type;
  final int colorValue;
  final DateTime createdAt;

  SavedQrItem({
    required this.id,
    required this.title,
    required this.payload,
    required this.type,
    required this.colorValue,
    required this.createdAt,
  });
}

class QrGeneratorController extends GetxController {
  // ── Input State ───────────────────────────────────────────────────────────
  final selectedType = QrDataType.url.obs;

  // Controllers for various types
  final urlController = TextEditingController(text: 'https://google.com');
  final textController = TextEditingController(text: 'Hello, Antigravity QR!');
  
  // Wi-Fi
  final wifiSsidController = TextEditingController(text: 'MyHomeWiFi');
  final wifiPasswordController = TextEditingController(text: 'wifi12345');
  final wifiSecurity = 'WPA'.obs; // WPA, WEP, nopass
  final wifiIsHidden = false.obs;

  // Contact (vCard)
  final contactNameController = TextEditingController(text: 'John Doe');
  final contactPhoneController = TextEditingController(text: '+91 9876543210');
  final contactEmailController = TextEditingController(text: 'john@example.com');
  final contactOrgController = TextEditingController(text: 'Acme Corp');

  // Email
  final emailToController = TextEditingController(text: 'hello@example.com');
  final emailSubjectController = TextEditingController(text: 'Inquiry');
  final emailBodyController = TextEditingController(text: 'Hi there,');

  // Phone / SMS
  final phoneController = TextEditingController(text: '+91 9876543210');
  final smsMessageController = TextEditingController(text: 'Hello!');

  // UPI Payment
  final upiIdController = TextEditingController(text: 'merchant@upi');
  final upiNameController = TextEditingController(text: 'Merchant Store');
  final upiAmountController = TextEditingController(text: '100');

  // ── Styling State ─────────────────────────────────────────────────────────
  final qrColor = const Color(0xFF0F172A).obs; // Default: Midnight Black
  final qrBgColor = const Color(0xFFFFFFFF).obs; // Default: Pure White
  final selectedCenterIcon = Rxn<IconData>(); // Optional Center Badge
  final isExporting = false.obs;

  // Recent / Saved QR Codes
  final recentQrs = <SavedQrItem>[].obs;

  @override
  void onClose() {
    urlController.dispose();
    textController.dispose();
    wifiSsidController.dispose();
    wifiPasswordController.dispose();
    contactNameController.dispose();
    contactPhoneController.dispose();
    contactEmailController.dispose();
    contactOrgController.dispose();
    emailToController.dispose();
    emailSubjectController.dispose();
    emailBodyController.dispose();
    phoneController.dispose();
    smsMessageController.dispose();
    upiIdController.dispose();
    upiNameController.dispose();
    upiAmountController.dispose();
    super.onClose();
  }

  // ── Compute QR Payload String ─────────────────────────────────────────────
  String get currentPayload {
    switch (selectedType.value) {
      case QrDataType.url:
        final u = urlController.text.trim();
        if (u.isEmpty) return 'https://example.com';
        if (!u.startsWith('http://') && !u.startsWith('https://')) {
          return 'https://$u';
        }
        return u;

      case QrDataType.text:
        final t = textController.text.trim();
        return t.isEmpty ? 'Sample Text' : t;

      case QrDataType.wifi:
        final ssid = wifiSsidController.text.trim();
        final pass = wifiPasswordController.text;
        final sec = wifiSecurity.value;
        final hidden = wifiIsHidden.value ? 'true' : 'false';
        return 'WIFI:S:$ssid;T:$sec;P:$pass;H:$hidden;;';

      case QrDataType.contact:
        final name = contactNameController.text.trim();
        final phone = contactPhoneController.text.trim();
        final email = contactEmailController.text.trim();
        final org = contactOrgController.text.trim();
        return 'BEGIN:VCARD\nVERSION:3.0\nFN:$name\nTEL:$phone\nEMAIL:$email\nORG:$org\nEND:VCARD';

      case QrDataType.email:
        final to = emailToController.text.trim();
        final sub = Uri.encodeComponent(emailSubjectController.text.trim());
        final body = Uri.encodeComponent(emailBodyController.text.trim());
        return 'mailto:$to?subject=$sub&body=$body';

      case QrDataType.phone:
        final p = phoneController.text.trim();
        return 'tel:$p';

      case QrDataType.upi:
        final id = upiIdController.text.trim();
        final name = Uri.encodeComponent(upiNameController.text.trim());
        final amt = upiAmountController.text.trim();
        if (amt.isNotEmpty) {
          return 'upi://pay?pa=$id&pn=$name&am=$amt&cu=INR';
        }
        return 'upi://pay?pa=$id&pn=$name&cu=INR';
    }
  }

  String get currentTitle {
    switch (selectedType.value) {
      case QrDataType.url:
        return urlController.text.trim().isEmpty
            ? 'Website QR'
            : urlController.text.trim();
      case QrDataType.text:
        return 'Text Note QR';
      case QrDataType.wifi:
        return 'Wi-Fi: ${wifiSsidController.text.trim()}';
      case QrDataType.contact:
        return 'Contact: ${contactNameController.text.trim()}';
      case QrDataType.email:
        return 'Email: ${emailToController.text.trim()}';
      case QrDataType.phone:
        return 'Phone: ${phoneController.text.trim()}';
      case QrDataType.upi:
        return 'UPI Pay: ${upiNameController.text.trim()}';
    }
  }

  // ── Render QR Code to High-Res PNG Bytes ──────────────────────────────────
  Future<Uint8List?> generateQrPngBytes({double size = 1000.0}) async {
    try {
      final payload = currentPayload;
      final bc = Barcode.qrCode();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final canvasSize = Size(size, size);

      // Draw background
      final bgPaint = Paint()..color = qrBgColor.value;
      canvas.drawRect(Offset.zero & canvasSize, bgPaint);

      // Draw barcode bars/modules
      final fgPaint = Paint()
        ..color = qrColor.value
        ..style = PaintingStyle.fill;

      const pad = 60.0;
      final contentSize = size - (pad * 2);

      final elements = bc.make(
        payload,
        width: contentSize,
        height: contentSize,
      );

      for (final elem in elements) {
        if (elem is BarcodeBar && elem.black) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                pad + elem.left,
                pad + elem.top,
                elem.width,
                elem.height,
              ),
              const Radius.circular(1.5),
            ),
            fgPaint,
          );
        }
      }

      // Draw Center Icon if selected
      if (selectedCenterIcon.value != null) {
        final iconBoxSize = size * 0.18;
        final iconCenter = Offset(size / 2, size / 2);
        final iconRect = Rect.fromCenter(
          center: iconCenter,
          width: iconBoxSize,
          height: iconBoxSize,
        );

        // White circular background shield for icon
        canvas.drawCircle(
          iconCenter,
          iconBoxSize / 2,
          Paint()..color = qrBgColor.value,
        );
        canvas.drawCircle(
          iconCenter,
          iconBoxSize / 2,
          Paint()
            ..color = qrColor.value
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0,
        );

        // Draw Icon glyph
        final textPainter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(selectedCenterIcon.value!.codePoint),
            style: TextStyle(
              fontSize: iconBoxSize * 0.55,
              fontFamily: selectedCenterIcon.value!.fontFamily,
              package: selectedCenterIcon.value!.fontPackage,
              color: qrColor.value,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            iconCenter.dx - (textPainter.width / 2),
            iconCenter.dy - (textPainter.height / 2),
          ),
        );
      }

      final picture = recorder.endRecording();
      final img =
          await picture.toImage(canvasSize.width.toInt(), canvasSize.height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      log('[QrGenerator] generateQrPngBytes error: $e');
      return null;
    }
  }

  // ── Save QR Image to Storage ──────────────────────────────────────────────
  Future<String?> saveQrImage() async {
    try {
      isExporting.value = true;
      final bytes = await generateQrPngBytes(size: 1200);
      if (bytes == null) {
        MyDialogs.info(msg: 'Failed to render QR Code image');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final fileName =
          'qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      _addToRecent();
      MyDialogs.success(msg: 'QR Code image generated successfully!');
      return file.path;
    } catch (e) {
      log('[QrGenerator] saveQrImage error: $e');
      MyDialogs.info(msg: 'Error saving QR code: $e');
      return null;
    } finally {
      isExporting.value = false;
    }
  }

  // ── Export as Printable PDF Page ──────────────────────────────────────────
  Future<String?> exportPrintablePdf() async {
    try {
      isExporting.value = true;
      final pngBytes = await generateQrPngBytes(size: 1200);
      if (pngBytes == null) {
        MyDialogs.info(msg: 'Failed to generate QR Code');
        return null;
      }

      final pwDoc = pw.Document();
      final qrImage = pw.MemoryImage(pngBytes);
      final title = currentTitle;
      final payload = currentPayload;

      pwDoc.addPage(
        pw.Page(
          pageFormat: pw_pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (pw.Context ctx) {
            return pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(28),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: pw_pdf.PdfColors.grey400,
                    width: 1.5,
                  ),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: pw_pdf.PdfColor.fromInt(qrColor.value.value),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Scan this QR code with any camera or scanner app',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: pw_pdf.PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 24),
                    pw.Container(
                      width: 280,
                      height: 280,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: pw_pdf.PdfColors.grey300),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(12)),
                      ),
                      child: pw.ClipRRect(
                        horizontalRadius: 12,
                        verticalRadius: 12,
                        child: pw.Image(qrImage, fit: pw.BoxFit.contain),
                      ),
                    ),
                    pw.SizedBox(height: 24),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: const pw.BoxDecoration(
                        color: pw_pdf.PdfColors.grey100,
                        borderRadius:
                            pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Text(
                        payload,
                        maxLines: 2,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: pw_pdf.PdfColors.grey800,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Text(
                      'Official Digital QR Code • High Resolution Document',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: pw_pdf.PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      final outputBytes = await pwDoc.save();
      final tempDir = await getTemporaryDirectory();
      final outPath =
          '${tempDir.path}/qr_printable_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outFile = File(outPath);
      await outFile.writeAsBytes(outputBytes, flush: true);

      _addToRecent();
      MyDialogs.success(msg: 'Printable PDF ready!');
      return outPath;
    } catch (e) {
      log('[QrGenerator] exportPrintablePdf error: $e');
      MyDialogs.info(msg: 'Error creating printable PDF: $e');
      return null;
    } finally {
      isExporting.value = false;
    }
  }

  // ── Share QR Image ────────────────────────────────────────────────────────
  Future<void> shareQrCode() async {
    final path = await saveQrImage();
    if (path == null) return;

    Share.shareXFiles(
      [XFile(path)],
      subject: 'QR Code: $currentTitle',
      text: 'Scan this QR code: $currentPayload',
    );
  }

  // ── Copy Payload to Clipboard ─────────────────────────────────────────────
  void copyPayload() {
    Clipboard.setData(ClipboardData(text: currentPayload));
    HapticFeedback.lightImpact();
    MyDialogs.success(msg: 'QR code link/content copied to clipboard!');
  }

  void _addToRecent() {
    final item = SavedQrItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: currentTitle,
      payload: currentPayload,
      type: selectedType.value,
      colorValue: qrColor.value.value,
      createdAt: DateTime.now(),
    );
    recentQrs.insert(0, item);
    if (recentQrs.length > 20) recentQrs.removeLast();
  }

  void restoreRecent(SavedQrItem item) {
    selectedType.value = item.type;
    qrColor.value = Color(item.colorValue);
    switch (item.type) {
      case QrDataType.url:
        urlController.text = item.payload;
        break;
      case QrDataType.text:
        textController.text = item.payload;
        break;
      default:
        textController.text = item.payload;
        break;
    }
    MyDialogs.info(msg: 'Restored QR: ${item.title}');
  }
}
