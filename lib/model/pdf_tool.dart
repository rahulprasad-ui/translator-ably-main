import 'package:flutter/material.dart';

//single pdf tool item (shown as icon + label tile)
class PdfTool {
  final String name;
  final String icon; //asset path
  final Color color; //icon tile bg
  final VoidCallback? onTap;

  const PdfTool({
    required this.name,
    required this.icon,
    required this.color,
    this.onTap,
  });
}

//category of tools (title + list of tools)
class PdfToolCategory {
  final String title;
  final List<PdfTool> tools;

  const PdfToolCategory({required this.title, required this.tools});
}
