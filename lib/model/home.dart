// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

enum HomeType {
  app_language,
  terms_condition,
  classic_word_game,
  word_pronouncer,
  pdf_translator,
  advance_dictionary,
  voice_translator,
  text_translator,
  pdf_tools
}

const colorsList = [
  [Color(0xFF5E89FC), Color(0xFF245AE4)],
  [Color(0xFFFFAB6C), Color(0xFFFD8838)],
  [Color(0xFFA392FA), Color(0xFF8772FD)],
  [Color(0xFFFD8B8A), Color(0xFFFB484C)],
  [Color(0xFFF185EB), Color(0xFFF144EC)],
  [Color(0xFF4FEE13), Color(0xFF36C404)],
  [Color(0xFFFC7FA9), Color(0xFFF0497D)],
  [Color(0xFF2DEBE9), Color(0xFF02D3D7)]
];

List<Color> gradientColors(HomeType homeType) => switch (homeType) {
      HomeType.text_translator => [
          const Color(0xFF5E89FC),
          const Color(0xFF245AE4)
        ],
      HomeType.voice_translator => [
          const Color(0xFFFFAB6C),
          const Color(0xFFFD8838)
        ],
      HomeType.advance_dictionary => [
          const Color(0xFFA392FA),
          const Color(0xFF8772FD)
        ],
      HomeType.pdf_translator => [
          const Color(0xFFFD8B8A),
          const Color(0xFFFB484C)
        ],
      HomeType.word_pronouncer => [
          const Color(0xFFFC7FA9),
          const Color(0xFFF0497D)
        ],
      HomeType.classic_word_game => [Colors.lightGreen, Colors.green],
      HomeType.app_language => [
          // const Color(0xFF5FDAFC),
          const Color(0xFF46B5FA),
          const Color(0xFF46B5FA)
        ],
      HomeType.terms_condition => [
          const Color(0xFF00EBA7),
          const Color(0xFF00B8A3)
        ],
      HomeType.pdf_tools => [
          const Color(0xFFFF6B6B),
          const Color(0xFFEE5A24)
        ],
    };
