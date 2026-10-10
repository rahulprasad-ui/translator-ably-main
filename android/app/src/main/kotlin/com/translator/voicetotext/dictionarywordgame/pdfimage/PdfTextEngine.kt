package com.translator.voicetotext.dictionarywordgame.pdfimage

import android.content.Context
import android.graphics.Color
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.PDPage
import com.tom_roush.pdfbox.pdmodel.PDPageContentStream
import com.tom_roush.pdfbox.pdmodel.common.PDRectangle
import com.tom_roush.pdfbox.pdmodel.font.PDType1Font
import com.tom_roush.pdfbox.pdmodel.graphics.image.PDImageXObject
import com.tom_roush.pdfbox.text.PDFTextStripper
import com.tom_roush.pdfbox.text.TextPosition
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.StringWriter
import kotlin.math.max
import kotlin.math.min

data class TextGlyph(
    val unicode: String,
    val x: Float,
    val y: Float, // Top-down coordinate
    val width: Float,
    val height: Float,
    val fontSize: Float,
    val fontName: String,
    val color: Int = 0xFF000000.toInt(),
    val isBold: Boolean = false,
    val isItalic: Boolean = false,
    val isEmbedded: Boolean = false,
    val rotation: Float = 0f
)

class PageTextStripper(private val targetPageIndex: Int) : PDFTextStripper() {
    val glyphs = mutableListOf<TextGlyph>()

    init {
        sortByPosition = true
        startPage = targetPageIndex + 1
        endPage = targetPageIndex + 1
    }

    override fun processTextPosition(text: TextPosition) {
        val unicode = text.unicode
        if (unicode.isNullOrEmpty()) return

        val font = text.font
        val fontDescriptor = font?.fontDescriptor
        val rawFontName = font?.name ?: "Helvetica"
        val cleanFontName = if (rawFontName.contains("+") && rawFontName.indexOf("+") == 6) {
            rawFontName.substring(7)
        } else {
            rawFontName
        }

        val isEmbedded = font?.isEmbedded ?: false
        val weight = (fontDescriptor?.fontWeight as? Number)?.toFloat() ?: 400f
        val isBold = (fontDescriptor?.isForceBold == true) ||
                weight >= 700f ||
                cleanFontName.contains("Bold", ignoreCase = true) ||
                cleanFontName.contains("Black", ignoreCase = true)

        val italicAngle = (fontDescriptor?.italicAngle as? Number)?.toFloat() ?: 0f
        val isItalic = italicAngle != 0f ||
                (fontDescriptor?.isItalic == true) ||
                cleanFontName.contains("Italic", ignoreCase = true) ||
                cleanFontName.contains("Oblique", ignoreCase = true)

        var colorInt = 0xFF000000.toInt()
        try {
            val nonStroking = graphicsState?.nonStrokingColor
            if (nonStroking != null) {
                val cs = nonStroking.colorSpace
                val components = nonStroking.components
                if (components != null && components.isNotEmpty()) {
                    val rgb = cs?.toRGB(components)
                    if (rgb != null && rgb.size >= 3) {
                        val r = (rgb[0] * 255f).toInt().coerceIn(0, 255)
                        val g = (rgb[1] * 255f).toInt().coerceIn(0, 255)
                        val b = (rgb[2] * 255f).toInt().coerceIn(0, 255)
                        colorInt = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
                    }
                }
            }
        } catch (_: Exception) {}

        glyphs.add(
            TextGlyph(
                unicode = unicode,
                x = text.xDirAdj,
                y = text.yDirAdj,
                width = text.widthDirAdj,
                height = text.heightDir,
                fontSize = text.fontSizeInPt,
                fontName = cleanFontName,
                color = colorInt,
                isBold = isBold,
                isItalic = isItalic,
                isEmbedded = isEmbedded,
                rotation = text.rotation.toFloat()
            )
        )
    }
}

class PdfTextEngine(private val context: Context) {
    private var isInitialized = false

    private fun ensureInit() {
        if (!isInitialized) {
            PDFBoxResourceLoader.init(context)
            isInitialized = true
        }
    }

    fun extractTextElements(pdfPath: String, pageIndex: Int): List<Map<String, Any>> {
        ensureInit()
        val file = File(pdfPath)
        if (!file.exists()) return emptyList()

        var document: PDDocument? = null
        try {
            document = PDDocument.load(file)
            if (pageIndex < 0 || pageIndex >= document.numberOfPages) return emptyList()

            val page = document.getPage(pageIndex)
            val cropBox: PDRectangle = page.cropBox ?: page.mediaBox ?: PDRectangle(0f, 0f, 595f, 842f)
            val pageRotation = page.rotation
            val pageWidth = if (pageRotation == 90 || pageRotation == 270) cropBox.height else cropBox.width
            val pageHeight = if (pageRotation == 90 || pageRotation == 270) cropBox.width else cropBox.height

            val stripper = PageTextStripper(pageIndex)
            stripper.writeText(document, StringWriter())

            if (stripper.glyphs.isEmpty()) {
                return emptyList()
            }

            // Group glyphs into lines and words
            val lines = groupGlyphsIntoLines(stripper.glyphs)
            val result = mutableListOf<Map<String, Any>>()

            var elementId = 0
            for (line in lines) {
                if (line.isEmpty()) continue

                val textBuilder = StringBuilder()
                var prevEnd = -1f
                for (g in line) {
                    if (prevEnd > 0f && (g.x - prevEnd) > (g.fontSize * 0.18f)) {
                        textBuilder.append(" ")
                    }
                    textBuilder.append(g.unicode)
                    prevEnd = g.x + g.width
                }
                val lineText = textBuilder.toString().trim()
                if (lineText.isEmpty()) continue

                var minX = Float.MAX_VALUE
                var minY = Float.MAX_VALUE
                var maxX = -Float.MAX_VALUE
                var maxY = -Float.MAX_VALUE
                var avgFontSize = 0f
                val fontNames = mutableListOf<String>()
                val colors = mutableListOf<Int>()
                var hasBold = false
                var hasItalic = false
                var hasEmbedded = false
                var rotation = 0f

                for (g in line) {
                    val glyphH = if (g.height > 0f) g.height else (if (g.fontSize > 0f) g.fontSize else 12f)
                    minX = min(minX, g.x)
                    minY = min(minY, g.y - glyphH)
                    maxX = max(maxX, g.x + g.width)
                    maxY = max(maxY, g.y)
                    avgFontSize += g.fontSize
                    fontNames.add(g.fontName)
                    colors.add(g.color)
                    if (g.isBold) hasBold = true
                    if (g.isItalic) hasItalic = true
                    if (g.isEmbedded) hasEmbedded = true
                    rotation = g.rotation
                }
                avgFontSize /= line.size

                val dominantFont = fontNames.groupingBy { it }.eachCount().maxByOrNull { it.value }?.key ?: "Helvetica"
                val dominantColor = colors.groupingBy { it }.eachCount().maxByOrNull { it.value }?.key ?: 0xFF000000.toInt()

                val lineW = max(10f, maxX - minX)
                val lineH = max(10f, maxY - minY)

                val item = mutableMapOf<String, Any>(
                    "id" to "pdf_${pageIndex}_${elementId++}",
                    "text" to lineText,
                    "x" to minX.toDouble(),
                    "y" to minY.toDouble(),
                    "width" to lineW.toDouble(),
                    "height" to lineH.toDouble(),
                    "pageWidth" to pageWidth.toDouble(),
                    "pageHeight" to pageHeight.toDouble(),
                    "fontSize" to avgFontSize.toDouble(),
                    "fontName" to dominantFont,
                    "textColor" to dominantColor,
                    "color" to dominantColor,
                    "isBold" to hasBold,
                    "isItalic" to hasItalic,
                    "isFontEmbedded" to hasEmbedded,
                    "rotation" to rotation.toDouble(),
                    "baseline" to maxY.toDouble(),
                    "pageIndex" to pageIndex
                )
                result.add(item)
            }

            return result
        } catch (e: Exception) {
            e.printStackTrace()
            return emptyList()
        } finally {
            try {
                document?.close()
            } catch (_: Exception) {}
        }
    }

    private fun groupGlyphsIntoLines(glyphs: List<TextGlyph>): List<List<TextGlyph>> {
        if (glyphs.isEmpty()) return emptyList()

        // Sort primarily by Y (top-down), secondarily by X
        val sorted = glyphs.sortedWith(compareBy({ it.y }, { it.x }))
        val lines = mutableListOf<MutableList<TextGlyph>>()
        var currentLine = mutableListOf<TextGlyph>()
        var currentY = sorted.first().y
        var currentH = sorted.first().height

        for (g in sorted) {
            val yTolerance = max(3f, max(currentH, g.height) * 0.45f)
            if (kotlin.math.abs(g.y - currentY) <= yTolerance) {
                currentLine.add(g)
            } else {
                if (currentLine.isNotEmpty()) {
                    currentLine.sortBy { it.x }
                    lines.add(currentLine)
                }
                currentLine = mutableListOf(g)
                currentY = g.y
                currentH = g.height
            }
        }
        if (currentLine.isNotEmpty()) {
            currentLine.sortBy { it.x }
            lines.add(currentLine)
        }

        return lines
    }

    fun saveModifiedPdf(
        sourcePath: String,
        outPath: String,
        modifications: List<Map<String, Any>>
    ): Boolean {
        ensureInit()
        val file = File(sourcePath)
        if (!file.exists()) return false

        var document: PDDocument? = null
        try {
            document = PDDocument.load(file)
            val modsByPage = modifications.groupBy { (it["pageIndex"] as? Number)?.toInt() ?: 0 }

            for ((pageIndex, pageMods) in modsByPage) {
                if (pageIndex < 0 || pageIndex >= document.numberOfPages) continue
                val page = document.getPage(pageIndex)
                val cropBox: PDRectangle = page.cropBox ?: page.mediaBox ?: PDRectangle(0f, 0f, 595f, 842f)
                val pageHeight = cropBox.height

                val contentStream = PDPageContentStream(
                    document,
                    page,
                    PDPageContentStream.AppendMode.APPEND,
                    true,
                    true
                )

                try {
                    for (mod in pageMods) {
                        val type = (mod["type"] as? String) ?: "text"
                        val x = ((mod["x"] as? Number)?.toFloat() ?: 0f)
                        val topY = ((mod["y"] as? Number)?.toFloat() ?: 0f)
                        val w = ((mod["width"] as? Number)?.toFloat() ?: 100f)
                        val h = ((mod["height"] as? Number)?.toFloat() ?: 20f)
                        val origX = ((mod["originalX"] as? Number)?.toFloat() ?: x)
                        val origY = ((mod["originalY"] as? Number)?.toFloat() ?: topY)
                        val origW = ((mod["originalWidth"] as? Number)?.toFloat() ?: w)
                        val origH = ((mod["originalHeight"] as? Number)?.toFloat() ?: h)
                        val text = (mod["text"] as? String) ?: ""
                        val colorVal = ((mod["color"] as? Number)?.toLong() ?: 0xFF000000)
                        val bgColorVal = ((mod["backgroundColor"] as? Number)?.toLong())
                        val fontSize = ((mod["fontSize"] as? Number)?.toFloat() ?: 12f)
                        val isBold = (mod["isBold"] as? Boolean) ?: false
                        val isItalic = (mod["isItalic"] as? Boolean) ?: false
                        val coverOriginal = (mod["coverOriginal"] as? Boolean) ?: true

                        // Full union erase box: covers 100% of the original bounding box + new bounding box
                        // with margin for font ascenders, descenders (g, j, p, q, y) and raster anti-aliasing
                        val eraseLeft = min(origX, x) - 2f
                        val eraseTop = min(origY, topY) - 2f
                        val eraseRight = max(origX + origW, x + w) + 4f
                        val eraseBottom = max(origY + origH, topY + h) + 4f

                        val eraseW = max(10f, eraseRight - eraseLeft)
                        val eraseH = max(10f, eraseBottom - eraseTop)

                        // Convert top-down erase box to PDF bottom-up coordinates
                        val erasePdfY = pageHeight - eraseTop - eraseH

                        // 1. Draw solid clean background covering 100% of original text area
                        if (coverOriginal || (bgColorVal != null && bgColorVal != 0L)) {
                            contentStream.saveGraphicsState()
                            if (bgColorVal != null && bgColorVal != 0L) {
                                val r = ((bgColorVal shr 16) and 0xFF) / 255f
                                val g = ((bgColorVal shr 8) and 0xFF) / 255f
                                val b = (bgColorVal and 0xFF) / 255f
                                contentStream.setNonStrokingColor(r, g, b)
                            } else {
                                contentStream.setNonStrokingColor(1f, 1f, 1f) // White
                            }
                            contentStream.addRect(eraseLeft, erasePdfY, eraseW, eraseH)
                            contentStream.fill()
                            contentStream.restoreGraphicsState()
                        }

                        // 2. Write new text
                        if (type == "text" && text.isNotEmpty()) {
                            contentStream.saveGraphicsState()
                            contentStream.beginText()

                            val fontName = (mod["fontName"] as? String) ?: "Helvetica"
                            val font = when {
                                fontName.contains("Times", ignoreCase = true) -> when {
                                    isBold && isItalic -> PDType1Font.TIMES_BOLD_ITALIC
                                    isBold -> PDType1Font.TIMES_BOLD
                                    isItalic -> PDType1Font.TIMES_ITALIC
                                    else -> PDType1Font.TIMES_ROMAN
                                }
                                fontName.contains("Courier", ignoreCase = true) -> when {
                                    isBold && isItalic -> PDType1Font.COURIER_BOLD_OBLIQUE
                                    isBold -> PDType1Font.COURIER_BOLD
                                    isItalic -> PDType1Font.COURIER_OBLIQUE
                                    else -> PDType1Font.COURIER
                                }
                                else -> when {
                                    isBold && isItalic -> PDType1Font.HELVETICA_BOLD_OBLIQUE
                                    isBold -> PDType1Font.HELVETICA_BOLD
                                    isItalic -> PDType1Font.HELVETICA_OBLIQUE
                                    else -> PDType1Font.HELVETICA
                                }
                            }
                            contentStream.setFont(font, fontSize)

                            val r = ((colorVal shr 16) and 0xFF) / 255f
                            val g = ((colorVal shr 8) and 0xFF) / 255f
                            val b = (colorVal and 0xFF) / 255f
                            contentStream.setNonStrokingColor(r, g, b)

                            // Baseline placement aligned with the original text line
                            val baselineY = pageHeight - (origY + origH * 0.78f)
                            contentStream.newLineAtOffset(x, baselineY)

                            val cleanText = sanitizePdfText(text)
                            try {
                                contentStream.showText(cleanText)
                            } catch (e: Exception) {
                                // Fallback: replace unencodable characters with ascii
                                val asciiOnly = cleanText.filter { it.code in 32..126 }
                                contentStream.showText(asciiOnly)
                            }

                            contentStream.endText()
                            contentStream.restoreGraphicsState()
                        }
                    }
                } finally {
                    contentStream.close()
                }
            }

            val outFile = File(outPath)
            outFile.parentFile?.mkdirs()
            document.save(outFile)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        } finally {
            try {
                document?.close()
            } catch (_: Exception) {}
        }
    }

    private fun sanitizePdfText(input: String): String {
        val sb = StringBuilder()
        for (c in input) {
            val code = c.code
            // WinAnsi supported range
            if (code in 32..126 || code in 160..255) {
                sb.append(c)
            } else if (c == '\t') {
                sb.append("   ")
            } else if (c == '‘' || c == '’') {
                sb.append('\'')
            } else if (c == '“' || c == '”') {
                sb.append('"')
            } else if (c == '–' || c == '—') {
                sb.append('-')
            } else {
                sb.append(' ')
            }
        }
        return sb.toString()
    }
}
