// test/features/pdf_editor_v2/license_registry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:translator/features/pdf_editor_v2/domain/license_registry_service.dart';

void main() {
  test('PdfLicenseRegistryService registers third-party licenses without error', () {
    expect(() => PdfLicenseRegistryService.registerLicenses(), returnsNormally);
    // Idempotency check: calling multiple times should be safe
    expect(() => PdfLicenseRegistryService.registerLicenses(), returnsNormally);
  });
}
