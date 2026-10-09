// lib/features/pdf_editor_v2/presentation/widgets/editable_text_overlay.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/pdf_font_metadata.dart';
import '../../data/models/pdf_text_item.dart';
import '../providers/pdf_editor_provider.dart';

/// Positioned interactive TextField overlaid directly over selected text on the PDF page
class EditableTextOverlay extends ConsumerStatefulWidget {
  final PdfTextItem item;
  final PdfFontMetadata font;
  final String initialText;
  final VoidCallback onCommit;
  final VoidCallback onCancel;

  const EditableTextOverlay({
    super.key,
    required this.item,
    required this.font,
    required this.initialText,
    required this.onCommit,
    required this.onCancel,
  });

  @override
  ConsumerState<EditableTextOverlay> createState() => _EditableTextOverlayState();
}

class _EditableTextOverlayState extends ConsumerState<EditableTextOverlay> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();

    // Auto-focus after widget build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void didUpdateWidget(covariant EditableTextOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText && _controller.text != widget.initialText) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.font.toFlutterTextStyle();

    // Calculate dynamic width based on text length
    final textLength = _controller.text.length;
    final charWidth = widget.font.fontSize * 0.6;
    final estimatedWidth = math.max(
      widget.item.width + 24.0,
      textLength * charWidth + 32.0,
    );

    return Positioned(
      left: widget.item.x - 4.0,
      top: widget.item.y - 4.0,
      width: estimatedWidth.clamp(60.0, 650.0),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(color: const Color(0xFFE11D48), width: 2.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: textStyle,
                  cursorColor: const Color(0xFFE11D48),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    border: InputBorder.none,
                  ),
                  onChanged: (text) {
                    ref.read(pdfEditorProvider.notifier).updateEditingText(text);
                    setState(() {});
                  },
                  onSubmitted: (_) => widget.onCommit(),
                ),
              ),
              // Commit check button
              InkWell(
                onTap: widget.onCommit,
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  color: const Color(0xFFE11D48),
                  child: const Icon(Icons.check, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
