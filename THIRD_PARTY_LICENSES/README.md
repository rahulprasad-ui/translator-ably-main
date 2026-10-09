# Third-Party Licenses & Legal Compliance Documentation

This directory contains the license texts, attribution notices, and legal documentation for all third-party open-source components integrated into this application, specifically for the **PDF Processing & Editing Engine**.

## Commercial Closed-Source Compatibility

All libraries included in this application have been audited and verified for:
1. **Commercial Distribution**: Permitted to monetize via in-app purchases and subscriptions on Google Play and Apple App Store.
2. **Proprietary/Closed-Source Protection**: **Zero reciprocal or copyleft licenses (e.g. AGPL, GPL, LGPL)** are used for application logic. Your source code remains strictly proprietary and confidential.
3. **No Commercial SDK Licensing Fees**: 100% free and open-source or native platform framework implementations.

## License Inventory Summary

| Component | License Type | Notice Obligation | Commercial Suitability |
| :--- | :--- | :--- | :--- |
| **Apache PDFBox (Android)** | Apache License 2.0 | Include Apache 2.0 text and NOTICE file | Approved (Closed-source compatible) |
| **Google PDFium (`pdfx`)** | BSD 3-Clause / Apache 2.0 | Include copyright notices | Approved (Closed-source compatible) |
| **Flutter Riverpod** | MIT License | Include MIT copyright statement | Approved (Closed-source compatible) |
| **Apple PDFKit / CoreGraphics** | Apple SDK (Native iOS) | None (Standard OS Framework) | Approved (Standard native framework) |
| **package:pdf** | Apache License 2.0 | Include Apache 2.0 text | Approved (Closed-source compatible) |

## Compliance Obligations for Google Play Release

To fulfill the requirements of Apache License 2.0 (Section 4) and MIT/BSD:
1. Retain the notice files located in this directory (`NOTICE_APACHE_PDFBOX.txt`, `NOTICE_GOOGLE_PDFIUM.txt`).
2. Provide access to open-source licenses within the app (e.g. via Flutter's built-in `showLicensePage()` or in the app's Settings -> About -> Third-Party Licenses screen).
3. Do not remove or alter copyright notices in source files.
