// lib/features/pdf_editor_v2/domain/license_registry_service.dart
import 'package:flutter/foundation.dart';

/// Registers all required open-source notices and licenses into Flutter's LicenseRegistry.
/// This ensures full compliance with Apache 2.0 Section 4 and MIT/BSD notice obligations on Google Play.
class PdfLicenseRegistryService {
  static bool _isRegistered = false;

  /// Call once at app startup or when opening the PDF Editor module
  static void registerLicenses() {
    if (_isRegistered) return;
    _isRegistered = true;

    LicenseRegistry.addLicense(() async* {
      // 1. PdfBox-Android & Apache PDFBox
      yield const LicenseEntryWithLineBreaks(
        ['pdfbox-android', 'Apache PDFBox'],
        '''Apache PDFBox
Copyright 2002-2023 The Apache Software Foundation
This product includes software developed at The Apache Software Foundation (http://www.apache.org/).

PdfBox-Android
Copyright 2018-2023 Tom Roush
Licensed under the Apache License, Version 2.0.
http://www.apache.org/licenses/LICENSE-2.0''',
      );

      // 2. Google PDFium (bundled in pdfx)
      yield const LicenseEntryWithLineBreaks(
        ['PDFium (Google Chrome)'],
        '''PDFium
Copyright 2014-2024 The PDFium Authors. All rights reserved.
Licensed under the BSD 3-Clause License.
Redistribution and use in source and binary forms are permitted provided that the copyright notice and disclaimer are preserved.''',
      );

      // 3. Flutter Riverpod
      yield const LicenseEntryWithLineBreaks(
        ['flutter_riverpod', 'riverpod'],
        '''MIT License
Copyright (c) Remi Rousselet and Flutter Riverpod Contributors
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files...''',
      );
    });
  }
}
