import 'package:get/get.dart';

class Game {
  late final String hint;
  late final String word;

  Game({required this.hint, required this.word});

  Game.fromJson(Map<String, dynamic> json) {
    hint = json['hint'] ?? '';
    word = json['word'] ?? '';
  }
}

class Letter {
  final RxString letter = ' '.obs;
  final RxBool isSelected = false.obs;
}
