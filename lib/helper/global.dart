import 'package:flutter/material.dart';
import 'dart:math' as math;

//global object for accessing device screen size
late Size mq;

const appName = 'All Language Translator';
const packageName = 'com.translator.voicetotext.dictionarywordgame.pdfimage';
const todo = 'Needs to be implemented according to your need';

//colors
const pColor = Color(0xFF3A6CED);
const dictColor = Color(0xFF8772FD);
const wordPronColor = Color(0xFFF144EC);
const bgColor = Color(0xFF03010D);

//
enum Loading { pending, loading, done, error }

//helper (mapping list with index)
extension FicListExtension<T> on List<T> {
  Iterable<E> mapIndexed<E>(E Function(int index, T item) map) sync* {
    for (var index = 0; index < length; index++) {
      yield map(index, this[index]);
    }
  }
}

// helper (Random Item from list)
extension StringCasingExtension on String {
  String toCapitalized() =>
      length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
  String toTitleCase() => replaceAll(RegExp(' +'), ' ')
      .split(' ')
      .map((str) => str.toCapitalized())
      .join(' ');
}

// helper (Random Item from list)
extension RandomListItem<T> on List<T> {
  T randomItem() => this[math.Random().nextInt(length)];
}
