import 'package:flutter/material.dart';

class Language {
  final String title;
  final String flag;
  final Locale locale;

  Language({required this.title, required this.flag, required this.locale});
}

class TLanguage {
  String name;
  String code;

  TLanguage({required this.code, required this.name});

  @override
  String toString() => name;
}
