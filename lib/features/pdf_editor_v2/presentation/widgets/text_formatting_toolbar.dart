// lib/features/pdf_editor_v2/presentation/widgets/text_formatting_toolbar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/pdf_font_metadata.dart';
import '../providers/pdf_editor_provider.dart';

/// Formatting toolbar that allows live font, size, weight, style, and color editing
class TextFormattingToolbar extends ConsumerWidget {
  const TextFormattingToolbar({super.key});

  static const List<Color> _paletteColors = [
    Color(0xFF000000), // Black
    Color(0xFF334155), // Slate
    Color(0xFFE11D48), // Rose Red
    Color(0xFF2563EB), // Royal Blue
    Color(0xFF16A34A), // Emerald Green
    Color(0xFFD97706), // Amber
    Color(0xFF9333EA), // Purple
    Color(0xFFFFFFFF), // White
  ];

  static const List<String> _fontFamilies = [
    'Helvetica',
    'Times-Roman',
    'Courier',
    'Roboto',
    'Arial',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pdfEditorProvider);
    final notifier = ref.read(pdfEditorProvider.notifier);
    final font = state.currentFont;

    if (state.selectedTextItem == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Dark slate premium card
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Font Family Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _fontFamilies.contains(font.fontName) ? font.fontName : 'Helvetica',
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                  items: _fontFamilies.map((f) {
                    return DropdownMenuItem<String>(
                      value: f,
                      child: Text(f),
                    );
                  }).toList(),
                  onChanged: (newFont) {
                    if (newFont != null) notifier.updateFontFamily(newFont);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 2. Font Size decrement (-)
            _buildIconButton(
              icon: Icons.remove,
              tooltip: 'Decrease font size',
              onTap: () => notifier.updateFontSize(font.fontSize - 1),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${font.fontSize.toInt()} pt',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            // Font Size increment (+)
            _buildIconButton(
              icon: Icons.add,
              tooltip: 'Increase font size',
              onTap: () => notifier.updateFontSize(font.fontSize + 1),
            ),
            const SizedBox(width: 8),
            _buildDivider(),

            // 3. Bold Toggle
            _buildToggleChip(
              label: 'B',
              isActive: font.isBold,
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              onTap: () => notifier.toggleBold(),
            ),
            const SizedBox(width: 4),

            // 4. Italic Toggle
            _buildToggleChip(
              label: 'I',
              isActive: font.isItalic,
              textStyle: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
              onTap: () => notifier.toggleItalic(),
            ),
            const SizedBox(width: 8),
            _buildDivider(),

            // 5. Color Palette
            Row(
              children: _paletteColors.map((col) {
                final isSelected = font.textColor == col.toARGB32();
                return GestureDetector(
                  onTap: () => notifier.updateTextColor(col),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? const Color(0xFFE11D48) : Colors.white24,
                        width: isSelected ? 2.5 : 1.0,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(width: 8),
            _buildDivider(),

            // 6. Inline Edit Action Button
            ElevatedButton.icon(
              onPressed: () => notifier.startInlineEditing(),
              icon: const Icon(Icons.edit, size: 14),
              label: const Text('Edit Text', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(width: 4),

            // 7. Clear selection / Dismiss
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 18),
              tooltip: 'Deselect',
              onPressed: () => notifier.clearSelection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF334155),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildToggleChip({
    required String label,
    required bool isActive,
    required TextStyle textStyle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE11D48) : const Color(0xFF334155),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: textStyle.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 20,
      width: 1,
      color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
