# Comprehensive Dependency Compliance & Licensing Matrix

| Component Name | Exact Version | Official License | Official Source Repository | Platform Compatibility | Native / Transitive Dependencies | Closed-Source & Subscription Compatible? | Required Notices / Obligations |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`flutter_riverpod`** | `2.5.1` | **MIT** | [github.com/rrousselGit/riverpod](https://github.com/rrousselGit/riverpod) | Android, iOS, Web, Desktop | Pure Dart/Flutter (`riverpod`, `state_notifier`) | **Yes** (100% Permissive) | Retain MIT copyright notice in app bundle. |
| **`pdfx`** | `2.6.0` | **BSD-3-Clause / Apache 2.0** | [github.com/proninyaroslav/pdfx](https://github.com/proninyaroslav/pdfx) | Android, iOS, macOS, Windows, Linux, Web | Bundles Google PDFium prebuilt C++ binaries (BSD 3-Clause) | **Yes** (100% Permissive) | Include BSD-3 Clause disclaimer and Google PDFium copyright notice. |
| **`pdf` (package:pdf)** | `3.11.0` | **Apache 2.0** | [github.com/DavBfr/dart_pdf](https://github.com/DavBfr/dart_pdf) | Cross-platform (Pure Dart) | None | **Yes** (100% Permissive) | Provide copy of Apache 2.0 License. |
| **`pdfbox-android`** | `2.0.27.0` | **Apache 2.0** | [github.com/TomRoush/PdfBox-Android](https://github.com/TomRoush/PdfBox-Android) | Android (Android API 19+) | Apache PDFBox, BouncyCastle (MIT-style), Apache Commons | **Yes** (100% Permissive) | Include Apache 2.0 License text and `NOTICE` file (`NOTICE_APACHE_PDFBOX.txt`). |
| **Apple `PDFKit` & `CoreGraphics`** | iOS 11.0+ | **Apple OS Framework SDK** | [developer.apple.com/documentation/pdfkit](https://developer.apple.com/documentation/pdfkit) | iOS, macOS, iPadOS, visionOS | None (Standard Apple iOS System Framework) | **Yes** (Standard native SDK) | Standard Apple Developer Agreement terms; zero 3rd party notice required. |
| **Flutter SDK / Dart SDK** | Flutter 3.44.9 / Dart 3.12.2 | **BSD-3-Clause** | [github.com/flutter/flutter](https://github.com/flutter/flutter) | Cross-platform | Skia / Impeller rendering engine | **Yes** (Standard Flutter License) | Handled by Flutter build toolchain. |

---

## Disqualified SDKs & Prohibited Copyleft Dependencies

| Prohibited Library | License Type | Reason for Disqualification | Risk if Integrated in Proprietary App |
| :--- | :--- | :--- | :--- |
| **iText 7 / iText 8** | **AGPL v3.0** / Paid Commercial | Copyleft (AGPL) requires disclosing entire app source code, or paying $> \$5,000/\text{year}$ per app. | **FATAL COPYLEFT LEAK**: Forces your proprietary Flutter app code to be open-sourced under AGPL. |
| **MuPDF** | **AGPL v3.0** / Paid Commercial | Copyleft (AGPL) viral terms. Commercial license costs thousands per platform. | **FATAL COPYLEFT LEAK**: Requires public disclosure of your application source code. |
| **Syncfusion Flutter PDF** | Syncfusion Commercial / Community | Free only if business revenue $< \$1\text{M}$ USD AND $\le 5$ devs; otherwise requires annual subscription ($> \$995/\text{dev}$). | **Commercial lock-in**: Breach of license once revenue or developer thresholds are crossed. |
| **ComPDFKit, PSPDFKit, Apryse (PDFTron), Foxit** | Proprietary Commercial Paid SDK | Closed commercial SDKs requiring recurring license keys ($> \$3,000 - \$25,000/\text{year}$). | Watermarks in exported files; license verification fails without paid key. |
