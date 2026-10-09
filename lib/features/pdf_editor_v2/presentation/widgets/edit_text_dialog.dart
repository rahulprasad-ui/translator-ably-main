// lib/features/pdf_editor_v2/presentation/widgets/edit_text_dialog.dart
import 'package:flutter/material.dart';
import '../../data/models/pdf_font_metadata.dart';
import '../../data/models/pdf_text_item.dart';

/// Modal dialog / bottom sheet allowing full modification of PDF text content,
/// typography, font size, style (bold/italic), and color.
class EditTextDialog extends StatefulWidget {
  final String initialText;
  final PdfFontMetadata font;
  final PdfTextItem? originalItem;
  final void Function(String newText, PdfFontMetadata newFont) onApply;
  final VoidCallback? onDelete;

  const EditTextDialog({
    super.key,
    required this.initialText,
    required this.font,
    this.originalItem,
    required this.onApply,
    this.onDelete,
  });

  /// Displays the dialog centered or as a bottom sheet
  static Future<void> show({
    required BuildContext context,
    required String initialText,
    required PdfFontMetadata font,
    PdfTextItem? originalItem,
    required void Function(String newText, PdfFontMetadata newFont) onApply,
    VoidCallback? onDelete,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => EditTextDialog(
        initialText: initialText,
        font: font,
        originalItem: originalItem,
        onApply: onApply,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<EditTextDialog> {
  late TextEditingController _textCtrl;
  late String _fontFamily;
  late double _fontSize;
  late bool _isBold;
  late bool _isItalic;
  late Color _textColor;

  static const List<String> _fonts = [
    'Helvetica',
    'Times-Roman',
    'Courier',
    'Roboto',
    'Arial',
  ];

  static const List<Color> _palette = [
    Color(0xFF000000), // Black
    Color(0xFF1E293B), // Dark Slate
    Color(0xFFE11D48), // Rose Red
    Color(0xFF2563EB), // Royal Blue
    Color(0xFF16A34A), // Green
    Color(0xFFD97706), // Amber
    Color(0xFF9333EA), // Purple
    Color(0xFFFFFFFF), // White
  ];

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.initialText);
    _fontFamily = _fonts.contains(widget.font.fontName) ? widget.font.fontName : 'Helvetica';
    _fontSize = widget.font.fontSize.clamp(8.0, 72.0);
    _isBold = widget.font.isBold;
    _isItalic = widget.font.isItalic;
    _textColor = Color(widget.font.textColor);

    if (_textCtrl.text.isNotEmpty) {
      _textCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textCtrl.text.length,
      );
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _applyChanges() {
    final newText = _textCtrl.text;
    if (newText.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final updatedFont = widget.font.copyWith(
      fontName: _fontFamily,
      fontSize: _fontSize,
      isBold: _isBold,
      isItalic: _isItalic,
      textColor: _textColor.toARGB32(),
    );

    widget.onApply(newText, updatedFont);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: Color(0xFFE11D48), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit PDF Text',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Change text content and typography',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Original Text Preview (if replacing existing item)
              if (widget.originalItem != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 14, color: Colors.white38),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Original: "${widget.originalItem!.text}"',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),

              // Text Input Field
              TextField(
                controller: _textCtrl,
                autofocus: true,
                maxLines: 4,
                minLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Replacement Text',
                  labelStyle: const TextStyle(color: Color(0xFFE11D48), fontSize: 13),
                  hintText: 'Enter replacement text here...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Typography & Font Selector Row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Typography & Style',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // Font Family & Size Row
                    Row(
                      children: [
                        // Font Dropdown
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _fontFamily,
                                dropdownColor: const Color(0xFF1E293B),
                                isExpanded: true,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                items: _fonts.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _fontFamily = v);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Size Increment / Decrement
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 16, color: Colors.white),
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  if (_fontSize > 8) setState(() => _fontSize -= 1);
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '${_fontSize.toInt()} pt',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  if (_fontSize < 72) setState(() => _fontSize += 1);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Bold, Italic & Color Palette Row
                    Row(
                      children: [
                        // Bold Toggle
                        _buildToggle(
                          label: 'B',
                          active: _isBold,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          onTap: () => setState(() => _isBold = !_isBold),
                        ),
                        const SizedBox(width: 6),

                        // Italic Toggle
                        _buildToggle(
                          label: 'I',
                          active: _isItalic,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                          onTap: () => setState(() => _isItalic = !_isItalic),
                        ),
                        const SizedBox(width: 12),

                        // Colors Palette
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _palette.map((col) {
                                final isSel = _textColor.toARGB32() == col.toARGB32();
                                return GestureDetector(
                                  onTap: () => setState(() => _textColor = col),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: col,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSel ? const Color(0xFFE11D48) : Colors.white24,
                                        width: isSel ? 2.5 : 1.0,
                                      ),
                                    ),
                                    child: isSel
                                        ? Icon(
                                            Icons.check,
                                            size: 14,
                                            color: col.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                          )
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  if (widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                      tooltip: 'Erase text',
                      onPressed: () {
                        widget.onDelete?.call();
                        Navigator.of(context).pop();
                      },
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _applyChanges,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Apply Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggle({
    required String label,
    required bool active,
    required TextStyle style,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE11D48) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? const Color(0xFFE11D48) : Colors.white24),
        ),
        child: Text(
          label,
          style: style.copyWith(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }
}
