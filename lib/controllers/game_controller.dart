import 'dart:convert';
import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';

import '../ads/config.dart';
import '../helper/pref.dart';
import '../model/game.dart';

enum GameStatus { playing, won, lose }

class GameController extends GetxController {
  //list of game data for different levels
  final _gameList = List.from(jsonDecode(Config.classicWordGame))
      .map((e) => Game.fromJson(e))
      .toList()
    ..sort((g1, g2) {
      return g1.word.length.compareTo(g2.word.length);
    });

  final selectedList = <String>[].obs;
  final shuffledList = <Letter>[].obs;
  final gStatus = GameStatus.playing.obs;
  final showHint = false.obs;

  final _player = AudioPlayer();

  final level = Pref.level.obs;
  late final maxLevel = _gameList.length.obs;

  late var game = _gameList[Pref.level - 1];

  void initGame() {
    selectedList.value = List.generate(game.word.length, (i) => ' ');
    shuffledList.value = shuffleWord();
    gStatus.value = GameStatus.playing;
  }

  List<Letter> shuffleWord() {
    List<String> letters = game.word.split('');

    log('\nletters: $letters');

    letters.shuffle();

    log('shuffled letters: $letters');

    if (game.word == letters.join()) {
      letters.shuffle();
      log('same : $letters');
    }

    return letters.map((e) => Letter()..letter.value = e).toList();
  }

  Future<GameStatus> checkIsWon() async {
    if (selectedList.join() == game.word) {
      await clearPlayer();
      await _player.setSourceAsset('sounds/win.mp3');
      await _player.resume();

      if (!isLastLevel) Pref.level += 1;

      return GameStatus.won;
    }

    if (!selectedList.contains(' ')) {
      log('game over');
      await clearPlayer();
      await _player.setSourceAsset('sounds/lose.mp3');
      await _player.resume();
      return GameStatus.lose;
    }

    return GameStatus.playing;
  }

  bool get isLastLevel => Pref.level == maxLevel.value;

  Future<void> tapSound() async {
    if (selectedList.contains(' ')) {
      await clearPlayer();

      await _player.setSourceAsset('sounds/tap.mp3');
      await _player.resume();
    }
  }

  Future<void> clearPlayer() async {
    await _player.pause();
    await _player.release();
  }

  void nextLevel() {
    if (Pref.level < maxLevel.value) {
      showHint.value = false;
      gStatus.value = GameStatus.playing;
      level.value += 1;
      maxLevel.value = _gameList.length;
      game = _gameList[Pref.level - 1];

      selectedList.value = List.generate(game.word.length, (i) => ' ');
      shuffledList.value = shuffleWord();
    }
  }
}
