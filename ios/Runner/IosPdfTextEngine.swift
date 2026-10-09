// ios/Runner/IosPdfTextEngine.swift
import Foundation
import PDFKit
import UIKit

/// Native iOS PDF text extraction and modification engine using Apple's built-in PDFKit & CoreGraphics.
/// 100% Free, Permissive Apple SDK, Zero 3rd party license fees, Zero AGPL/GPL risk.
class IosPdfTextEngine {

    func extractTextElements(pdfPath: String, pageIndex: Int) -> [[String: Any]] {
        guard FileManager.default.fileExists(atPath: pdfPath) else { return [] }
        guard let doc = PDFDocument(url: URL(fileURLWithPath: pdfPath)) else { return [] }
        guard pageIndex >= 0 && pageIndex < doc.pageCount else { return [] }
        guard let page = doc.page(at: pageIndex) else { return [] }

        let bounds = page.bounds(for: .cropBox)
        let pageHeight = bounds.height
        let pageWidth = bounds.width

        guard let attrString = page.attributedString else { return [] }
        let fullText = attrString.string
        if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }

        var results: [[String: Any]] = []
        var elementId = 0

        // Extract words or line blocks with spatial bounds and font traits
        let lines = fullText.components(separatedBy: .newlines)
        var searchStartLocation = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let nsString = fullText as NSString
            let lineRange = nsString.range(of: line, options: [], range: NSRange(location: searchStartLocation, length: nsString.length - searchStartLocation))
            if lineRange.location == NSNotFound { continue }
            searchStartLocation = lineRange.location + lineRange.length

            guard let selection = page.selection(for: lineRange) else { continue }
            let rect = selection.bounds(for: page)

            // PDFKit origin is bottom-left; convert to top-left for Flutter
            let topDownY = pageHeight - rect.origin.y - rect.height

            // Extract typography attributes at line start
            var fontName = "Helvetica"
            var fontSize: CGFloat = 14.0
            var isBold = false
            var isItalic = false
            var colorInt: Int64 = 0xFF000000

            if lineRange.location < attrString.length {
                let attrs = attrString.attributes(at: lineRange.location, effectiveRange: nil)
                if let font = attrs[.font] as? UIFont {
                    fontName = font.fontName
                    fontSize = font.pointSize
                    let traits = font.fontDescriptor.symbolicTraits
                    isBold = traits.contains(.traitBold) || fontName.lowercased().contains("bold")
                    isItalic = traits.contains(.traitItalic) || fontName.lowercased().contains("italic")
                }
                if let color = attrs[.foregroundColor] as? UIColor {
                    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
                    if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
                        let rInt = Int64(r * 255.0) & 0xFF
                        let gInt = Int64(g * 255.0) & 0xFF
                        let bInt = Int64(b * 255.0) & 0xFF
                        let aInt = Int64(a * 255.0) & 0xFF
                        colorInt = (aInt << 24) | (rInt << 16) | (gInt << 8) | bInt
                    }
                }
            }

            let item: [String: Any] = [
                "id": "pdf_\(pageIndex)_\(elementId)",
                "text": trimmed,
                "x": Double(rect.origin.x),
                "y": Double(topDownY),
                "width": Double(max(10.0, rect.width)),
                "height": Double(max(10.0, rect.height)),
                "pageWidth": Double(pageWidth),
                "pageHeight": Double(pageHeight),
                "fontSize": Double(fontSize),
                "fontName": fontName,
                "textColor": colorInt,
                "color": colorInt,
                "isBold": isBold,
                "isItalic": isItalic,
                "isFontEmbedded": false,
                "rotation": 0.0,
                "baseline": Double(topDownY + rect.height * 0.8),
                "pageIndex": pageIndex
            ]
            results.append(item)
            elementId += 1
        }

        return results
    }

    func saveModifiedPdf(sourcePath: String, outPath: String, modifications: [[String: Any]]) -> Bool {
        guard FileManager.default.fileExists(atPath: sourcePath) else { return false }
        guard let doc = PDFDocument(url: URL(fileURLWithPath: sourcePath)) else { return false }

        let outUrl = URL(fileURLWithPath: outPath)
        try? FileManager.default.createDirectory(at: outUrl.deletingLastPathComponent(), withIntermediateDirectories: true)

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))

        let modsByPage = Dictionary(grouping: modifications, by: { ($0["pageIndex"] as? Int) ?? 0 })

        let data = renderer.pdfData { context in
            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i) else { continue }
                let bounds = page.bounds(for: .cropBox)

                context.beginPage(withBounds: bounds, pageInfo: [:])
                let cgContext = context.cgContext

                // Draw original page vector contents
                cgContext.saveGState()
                // PDF page draws bottom-up
                cgContext.translateBy(x: 0, y: bounds.height)
                cgContext.scaleBy(x: 1.0, y: -1.0)
                page.draw(with: .cropBox, to: cgContext)
                cgContext.restoreGState()

                // Apply modifications for this page
                if let pageMods = modsByPage[i] {
                    for mod in pageMods {
                        let topX = (mod["x"] as? Double) ?? 0.0
                        let topY = (mod["y"] as? Double) ?? 0.0
                        let w = (mod["width"] as? Double) ?? 100.0
                        let h = (mod["height"] as? Double) ?? 20.0
                        let text = (mod["replacementText"] as? String) ?? (mod["text"] as? String) ?? ""
                        let fontSize = CGFloat((mod["fontSize"] as? Double) ?? 14.0)
                        let isBold = (mod["isBold"] as? Bool) ?? false
                        let isItalic = (mod["isItalic"] as? Bool) ?? false
                        let colorVal = (mod["color"] as? Int64) ?? 0xFF000000

                        let targetRect = CGRect(x: topX, y: topY, width: w, height: h)

                        // 1. Cover original bounding box with clean white background
                        cgContext.saveGState()
                        cgContext.setFillColor(UIColor.white.cgColor)
                        cgContext.fill(targetRect.insetBy(dx: -1.0, dy: -1.0))
                        cgContext.restoreGState()

                        // 2. Draw replacement text
                        if !text.isEmpty {
                            var font = UIFont.systemFont(ofSize: fontSize)
                            if isBold && isItalic {
                                if let descriptor = font.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) {
                                    font = UIFont(descriptor: descriptor, size: fontSize)
                                }
                            } else if isBold {
                                font = UIFont.boldSystemFont(ofSize: fontSize)
                            } else if isItalic {
                                font = UIFont.italicSystemFont(ofSize: fontSize)
                            }

                            let r = CGFloat((colorVal >> 16) & 0xFF) / 255.0
                            let g = CGFloat((colorVal >> 8) & 0xFF) / 255.0
                            let b = CGFloat(colorVal & 0xFF) / 255.0
                            let textColor = UIColor(red: r, green: g, blue: b, alpha: 1.0)

                            let attributes: [NSAttributedString.Key: Any] = [
                                .font: font,
                                .foregroundColor: textColor
                            ]

                            let nsStr = NSAttributedString(string: text, attributes: attributes)
                            nsStr.draw(in: targetRect)
                        }
                    }
                }
            }
        }

        do {
            try data.write(to: outUrl)
            return true
        } catch {
            return false
        }
    }
}
