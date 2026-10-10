package com.translator.voicetotext.dictionarywordgame.pdfimage

import android.content.Context
import android.graphics.Color
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.contentstream.operator.Operator
import com.tom_roush.pdfbox.cos.COSArray
import com.tom_roush.pdfbox.cos.COSFloat
import com.tom_roush.pdfbox.cos.COSInteger
import com.tom_roush.pdfbox.cos.COSName
import com.tom_roush.pdfbox.cos.COSNumber
import com.tom_roush.pdfbox.cos.COSString
import com.tom_roush.pdfbox.pdfparser.PDFStreamParser
import com.tom_roush.pdfbox.pdfwriter.ContentStreamWriter
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.PDPage
import com.tom_roush.pdfbox.pdmodel.PDPageContentStream
import com.tom_roush.pdfbox.pdmodel.PDResources
import com.tom_roush.pdfbox.pdmodel.common.PDRectangle
import com.tom_roush.pdfbox.pdmodel.common.PDStream
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

    private data class TargetTextMod(
        val id: String,
        val originalText: String,
        val newText: String,
        val origX: Float,
        val origTopY: Float,
        val origW: Float,
        val origH: Float,
        val w: Float = origW,
        val h: Float = origH,
        val origPdfBottomY: Float,
        val origPdfTopY: Float,
        val targetBaseline: Float,
        val fontSize: Float,
        val fontName: String,
        val color: Long,
        val isBold: Boolean,
        val isItalic: Boolean,
        val bgR: Float = 1f,
        val bgG: Float = 1f,
        val bgB: Float = 1f,
        var replacedCount: Int = 0
    )

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
                val pageRotation = page.rotation
                val pageHeight = if (pageRotation == 90 || pageRotation == 270) cropBox.width else cropBox.height

                // Convert modifications into TargetTextMod
                val targetMods = pageMods.mapIndexed { idx, mod ->
                    val x = ((mod["x"] as? Number)?.toFloat() ?: 0f)
                    val topY = ((mod["y"] as? Number)?.toFloat() ?: 0f)
                    val w = ((mod["width"] as? Number)?.toFloat() ?: 100f)
                    val h = ((mod["height"] as? Number)?.toFloat() ?: 20f)
                    val origX = ((mod["originalX"] as? Number)?.toFloat() ?: x)
                    val origTopY = ((mod["originalY"] as? Number)?.toFloat() ?: topY)
                    val origW = ((mod["originalWidth"] as? Number)?.toFloat() ?: w)
                    val origH = ((mod["originalHeight"] as? Number)?.toFloat() ?: h)
                    val text = (mod["text"] as? String) ?: ""
                    val originalText = ((mod["originalText"] as? String) ?: "").trim()
                    val colorVal = ((mod["color"] as? Number)?.toLong() ?: 0xFF000000)
                    val fontSize = ((mod["fontSize"] as? Number)?.toFloat() ?: 12f)
                    val isBold = (mod["isBold"] as? Boolean) ?: false
                    val isItalic = (mod["isItalic"] as? Boolean) ?: false
                    val fontName = (mod["fontName"] as? String) ?: "Helvetica"
                    val baseline = ((mod["baseline"] as? Number)?.toFloat() ?: (origTopY + origH * 0.8f))
                    val targetBaseline = pageHeight - baseline

                    val bgVal = (mod["backgroundColor"] as? Number)?.toLong()
                    val (bgR, bgG, bgB) = if (bgVal != null && bgVal != 0L && bgVal != 0x00FFFFFFL) {
                        val r = ((bgVal shr 16) and 0xFF) / 255f
                        val g = ((bgVal shr 8) and 0xFF) / 255f
                        val b = (bgVal and 0xFF) / 255f
                        Triple(r, g, b)
                    } else {
                        Triple(1f, 1f, 1f)
                    }

                    TargetTextMod(
                        id = "mod_$idx",
                        originalText = originalText,
                        newText = text,
                        origX = origX,
                        origTopY = origTopY,
                        origW = origW,
                        origH = origH,
                        w = w,
                        h = h,
                        origPdfBottomY = pageHeight - origTopY - origH,
                        origPdfTopY = pageHeight - origTopY,
                        targetBaseline = targetBaseline,
                        fontSize = fontSize,
                        fontName = fontName,
                        color = colorVal,
                        isBold = isBold,
                        isItalic = isItalic,
                        bgR = bgR,
                        bgG = bgG,
                        bgB = bgB
                    )
                }

                // 1. Parse page tokens directly from content stream
                val parser = PDFStreamParser(page)
                parser.parse()
                val rawTokens = parser.tokens
                val tokens = ArrayList<Any>(rawTokens.size + (targetMods.size * 30))
                tokens.addAll(rawTokens)

                // Track transformation matrix (CTM) and text matrices
                val ctmStack = ArrayDeque<FloatArray>()
                var ctm = floatArrayOf(1f, 0f, 0f, 1f, 0f, 0f)
                var textMatrix = floatArrayOf(1f, 0f, 0f, 1f, 0f, 0f)
                var textLineMatrix = floatArrayOf(1f, 0f, 0f, 1f, 0f, 0f)
                var currentLeading = 12f

                fun multMatrix(m1: FloatArray, m2: FloatArray): FloatArray {
                    return floatArrayOf(
                        m1[0] * m2[0] + m1[1] * m2[2],
                        m1[0] * m2[1] + m1[1] * m2[3],
                        m1[2] * m2[0] + m1[3] * m2[2],
                        m1[2] * m2[1] + m1[3] * m2[3],
                        m1[4] * m2[0] + m1[5] * m2[2] + m2[4],
                        m1[4] * m2[1] + m1[5] * m2[3] + m2[5]
                    )
                }

                fun getCurrentPagePos(): Pair<Float, Float> {
                    val tx = textMatrix[4]
                    val ty = textMatrix[5]
                    val px = tx * ctm[0] + ty * ctm[2] + ctm[4]
                    val py = tx * ctm[1] + ty * ctm[3] + ctm[5]
                    return Pair(px, py)
                }

                // 2. Walk tokens, track exact page coordinates, and NEUTRALIZE original text operators
                for (i in 0 until tokens.size) {
                    val token = tokens[i]
                    if (token is Operator) {
                        val opName = token.name
                        when (opName) {
                            "q" -> {
                                ctmStack.addLast(ctm.copyOf())
                            }
                            "Q" -> {
                                if (ctmStack.isNotEmpty()) {
                                    ctm = ctmStack.removeLast()
                                }
                            }
                            "cm" -> {
                                if (i >= 6) {
                                    val a = (tokens[i - 6] as? COSNumber)?.floatValue() ?: 1f
                                    val b = (tokens[i - 5] as? COSNumber)?.floatValue() ?: 0f
                                    val c = (tokens[i - 4] as? COSNumber)?.floatValue() ?: 0f
                                    val d = (tokens[i - 3] as? COSNumber)?.floatValue() ?: 1f
                                    val e = (tokens[i - 2] as? COSNumber)?.floatValue() ?: 0f
                                    val f = (tokens[i - 1] as? COSNumber)?.floatValue() ?: 0f
                                    ctm = multMatrix(ctm, floatArrayOf(a, b, c, d, e, f))
                                }
                            }
                            "BT" -> {
                                textMatrix = floatArrayOf(1f, 0f, 0f, 1f, 0f, 0f)
                                textLineMatrix = floatArrayOf(1f, 0f, 0f, 1f, 0f, 0f)
                            }
                            "TL" -> {
                                if (i >= 1) {
                                    currentLeading = (tokens[i - 1] as? COSNumber)?.floatValue() ?: currentLeading
                                }
                            }
                            "Tm" -> {
                                if (i >= 6) {
                                    val a = (tokens[i - 6] as? COSNumber)?.floatValue() ?: 1f
                                    val b = (tokens[i - 5] as? COSNumber)?.floatValue() ?: 0f
                                    val c = (tokens[i - 4] as? COSNumber)?.floatValue() ?: 0f
                                    val d = (tokens[i - 3] as? COSNumber)?.floatValue() ?: 1f
                                    val e = (tokens[i - 2] as? COSNumber)?.floatValue() ?: 0f
                                    val f = (tokens[i - 1] as? COSNumber)?.floatValue() ?: 0f
                                    textMatrix = floatArrayOf(a, b, c, d, e, f)
                                    textLineMatrix = textMatrix.copyOf()
                                }
                            }
                            "Td" -> {
                                if (i >= 2) {
                                    val dx = (tokens[i - 2] as? COSNumber)?.floatValue() ?: 0f
                                    val dy = (tokens[i - 1] as? COSNumber)?.floatValue() ?: 0f
                                    textLineMatrix[4] += dx * textLineMatrix[0] + dy * textLineMatrix[2]
                                    textLineMatrix[5] += dx * textLineMatrix[1] + dy * textLineMatrix[3]
                                    textMatrix = textLineMatrix.copyOf()
                                }
                            }
                            "TD" -> {
                                if (i >= 2) {
                                    val dx = (tokens[i - 2] as? COSNumber)?.floatValue() ?: 0f
                                    val dy = (tokens[i - 1] as? COSNumber)?.floatValue() ?: 0f
                                    currentLeading = -dy
                                    textLineMatrix[4] += dx * textLineMatrix[0] + dy * textLineMatrix[2]
                                    textLineMatrix[5] += dx * textLineMatrix[1] + dy * textLineMatrix[3]
                                    textMatrix = textLineMatrix.copyOf()
                                }
                            }
                            "T*" -> {
                                textLineMatrix[5] -= currentLeading
                                textMatrix = textLineMatrix.copyOf()
                            }
                            "Tj" -> {
                                val (px, py) = getCurrentPagePos()
                                if (i >= 1) {
                                    val operand = tokens[i - 1]
                                    if (operand is COSString) {
                                        val str = operand.string ?: ""
                                        val matched = findMatchingTarget(str, px, py, targetMods)
                                        if (matched != null) {
                                            tokens[i - 1] = COSString("")
                                            matched.replacedCount++
                                        }
                                    }
                                }
                            }
                            "TJ" -> {
                                val (px, py) = getCurrentPagePos()
                                if (i >= 1) {
                                    val operand = tokens[i - 1]
                                    if (operand is COSArray) {
                                        val str = operand.filterIsInstance<COSString>().joinToString("") { it.string ?: "" }
                                        val matched = findMatchingTarget(str, px, py, targetMods)
                                        if (matched != null) {
                                            tokens[i - 1] = COSArray()
                                            matched.replacedCount++
                                        }
                                    }
                                }
                            }
                            "'" -> {
                                textLineMatrix[5] -= currentLeading
                                textMatrix = textLineMatrix.copyOf()
                                val (px, py) = getCurrentPagePos()
                                if (i >= 1) {
                                    val operand = tokens[i - 1]
                                    if (operand is COSString) {
                                        val str = operand.string ?: ""
                                        val matched = findMatchingTarget(str, px, py, targetMods)
                                        if (matched != null) {
                                            tokens[i - 1] = COSString("")
                                            matched.replacedCount++
                                        }
                                    }
                                }
                            }
                            "\"" -> {
                                textLineMatrix[5] -= currentLeading
                                textMatrix = textLineMatrix.copyOf()
                                val (px, py) = getCurrentPagePos()
                                if (i >= 1) {
                                    val operand = tokens[i - 1]
                                    if (operand is COSString) {
                                        val str = operand.string ?: ""
                                        val matched = findMatchingTarget(str, px, py, targetMods)
                                        if (matched != null) {
                                            tokens[i - 1] = COSString("")
                                            matched.replacedCount++
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. Ensure resources dictionary exists
                var resources = page.resources
                if (resources == null) {
                    resources = PDResources()
                    page.resources = resources
                }

                // 4. Inject clean vector clearing rectangle & replacement text directly into content stream
                for (t in targetMods) {
                    if (t.newText.isEmpty() && t.originalText.isEmpty()) continue

                    // 4a. Vector Background Clearing Rectangle
                    // Permanently wipes out the original line in native vector space so that
                    // zero residual glyphs, bullet points, or overlapping characters can show through.
                    tokens.add(Operator.getOperator("q"))
                    tokens.add(COSFloat(t.bgR))
                    tokens.add(COSFloat(t.bgG))
                    tokens.add(COSFloat(t.bgB))
                    tokens.add(Operator.getOperator("rg"))

                    val padX = 1.5f
                    val padY = 1.5f
                    val descenderPad = (t.fontSize * 0.25f).coerceAtLeast(2f)
                    val clearX = t.origX - padX
                    val clearY = t.origPdfBottomY - padY - descenderPad
                    val clearW = max(t.origW, t.w) + (padX * 2f)
                    val clearH = t.origH + (padY * 2f) + (descenderPad * 1.5f)

                    tokens.add(COSFloat(clearX))
                    tokens.add(COSFloat(clearY))
                    tokens.add(COSFloat(clearW))
                    tokens.add(COSFloat(clearH))
                    tokens.add(Operator.getOperator("re"))
                    tokens.add(Operator.getOperator("f"))
                    tokens.add(Operator.getOperator("Q"))

                    if (t.newText.isEmpty()) continue

                    // 4b. Draw crisp native replacement text
                    val font = when {
                        t.fontName.contains("Times", ignoreCase = true) -> when {
                            t.isBold && t.isItalic -> PDType1Font.TIMES_BOLD_ITALIC
                            t.isBold -> PDType1Font.TIMES_BOLD
                            t.isItalic -> PDType1Font.TIMES_ITALIC
                            else -> PDType1Font.TIMES_ROMAN
                        }
                        t.fontName.contains("Courier", ignoreCase = true) -> when {
                            t.isBold && t.isItalic -> PDType1Font.COURIER_BOLD_OBLIQUE
                            t.isBold -> PDType1Font.COURIER_BOLD
                            t.isItalic -> PDType1Font.COURIER_OBLIQUE
                            else -> PDType1Font.COURIER
                        }
                        else -> when {
                            t.isBold && t.isItalic -> PDType1Font.HELVETICA_BOLD_OBLIQUE
                            t.isBold -> PDType1Font.HELVETICA_BOLD
                            t.isItalic -> PDType1Font.HELVETICA_OBLIQUE
                            else -> PDType1Font.HELVETICA
                        }
                    }
                    val fontResName = resources.add(font)

                    // Wrap in isolated graphics state
                    tokens.add(Operator.getOperator("q"))

                    // Set non-stroking text color
                    val r = ((t.color shr 16) and 0xFF) / 255f
                    val g = ((t.color shr 8) and 0xFF) / 255f
                    val b = (t.color and 0xFF) / 255f
                    tokens.add(COSFloat(r))
                    tokens.add(COSFloat(g))
                    tokens.add(COSFloat(b))
                    tokens.add(Operator.getOperator("rg"))

                    // Begin Text block
                    tokens.add(Operator.getOperator("BT"))
                    tokens.add(fontResName)
                    tokens.add(COSFloat(t.fontSize))
                    tokens.add(Operator.getOperator("Tf"))

                    // Position text matrix at original line origin
                    tokens.add(COSFloat(1f))
                    tokens.add(COSFloat(0f))
                    tokens.add(COSFloat(0f))
                    tokens.add(COSFloat(1f))
                    tokens.add(COSFloat(t.origX))
                    tokens.add(COSFloat(t.targetBaseline))
                    tokens.add(Operator.getOperator("Tm"))

                    // Emit replacement text
                    val sanitized = sanitizePdfText(t.newText)
                    tokens.add(COSString(sanitized))
                    tokens.add(Operator.getOperator("Tj"))

                    tokens.add(Operator.getOperator("ET"))
                    tokens.add(Operator.getOperator("Q"))
                }

                // 5. Write modified tokens back into page content stream
                val updatedStream = PDStream(document)
                val outStream = updatedStream.createOutputStream(COSName.FLATE_DECODE)
                val writer = ContentStreamWriter(outStream)
                writer.writeTokens(tokens)
                outStream.close()
                page.setContents(updatedStream)
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

    private fun findMatchingTarget(
        tokenStr: String,
        tx: Float,
        ty: Float,
        targetMods: List<TargetTextMod>
    ): TargetTextMod? {
        val cleanToken = tokenStr.trim()

        for (t in targetMods) {
            val cleanOrig = t.originalText.trim()
            val textMatch = cleanOrig.isNotEmpty() && cleanToken.isNotEmpty() &&
                    (cleanToken.equals(cleanOrig, ignoreCase = true) ||
                     cleanOrig.contains(cleanToken, ignoreCase = true) ||
                     cleanToken.contains(cleanOrig, ignoreCase = true))

            val xWithin = (tx >= (t.origX - 25f)) && (tx <= (t.origX + t.origW + 25f))
            val yWithin = (ty >= (t.origPdfBottomY - 18f)) && (ty <= (t.origPdfTopY + 18f))
            val posMatch = xWithin && yWithin

            // 1. Text matches and vertical or full position is consistent -> MATCH
            if (textMatch && (posMatch || ty == 0f || yWithin)) {
                return t
            }

            // 2. Positional hit-test: if coordinates locate this operator within the line box -> MATCH
            // Handles CID fonts, subset TrueType fonts, and raw byte glyph IDs seamlessly
            if (posMatch) {
                return t
            }

            // 3. Fallback: if substring has 4+ characters and vertical line matches
            if (cleanToken.length >= 4 && cleanOrig.contains(cleanToken, ignoreCase = true) && yWithin) {
                return t
            }
        }
        return null
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
            } else if (c == '•' || c == '·' || c == '●' || c == '○' || c == '▪') {
                sb.append('-')
            } else {
                sb.append(' ')
            }
        }
        return sb.toString()
    }
}
