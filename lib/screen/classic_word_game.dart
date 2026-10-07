import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../../helper/global.dart';
import '../../model/home.dart';
import '../../utils/strings.dart';
import '../ads/widget/bottom_native_ad.dart';

import '../controllers/game_controller.dart';
import '../model/game.dart';
import '../widget/button/back_btn.dart';
import '../widget/button/image_btn.dart';
import '../widget/button/square_btn.dart';
import '../widget/dialog/all_level_complete_dialog.dart';
import '../widget/dialog/hint_dialog.dart';
import '../widget/dialog/won_dialog.dart';

class ClassicWordGame extends StatefulWidget {
  const ClassicWordGame({super.key});

  @override
  State<ClassicWordGame> createState() => _ClassicWordGameState();
}

class _ClassicWordGameState extends State<ClassicWordGame> {
  final _c = GameController();

  final _hType = HomeType.classic_word_game;

  @override
  void initState() {
    super.initState();
    _c.initGame();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        bottomNavigationBar: const BottomNativeAd(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: const Text(
          'Note: Only supported in english',
          style: TextStyle(
              color: Colors.black54, fontSize: 12.5, letterSpacing: .5),
        ),

        //body
        body: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: mq.height * .1),
            children: [
              //app bar
              DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors(_hType))),
                child: AppBar(
                  elevation: 0,
                  centerTitle: false,
                  backgroundColor: Colors.transparent,

                  //home
                  leading: const BackBtn(),

                  //label
                  title: Text(Strings.classicWordGame.tr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, letterSpacing: .25)),
                ),
              ),

              Container(
                margin: EdgeInsets.symmetric(
                    horizontal: mq.width * .02, vertical: mq.height * .02),
                decoration: BoxDecoration(
                  border: Border.all(color: gradientColors(_hType)[1]),
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                ),

                //
                child: Obx(
                  () => Stack(
                    children: [
                      //
                      Column(children: [
                        //leader board
                        Container(
                            width: mq.width,
                            padding: EdgeInsets.symmetric(
                                horizontal: mq.width * .2, vertical: 6),
                            decoration: const BoxDecoration(
                                image: DecorationImage(
                                    image: AssetImage(
                                        'assets/images/level_bg.webp'))),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              children: [
                                //
                                const Text(
                                  'Level: ',
                                  style: TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16),
                                ),

                                Text(
                                  '${_c.level}/${_c.maxLevel}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15),
                                ),
                              ],
                            )),

                        //for adding some space
                        SizedBox(height: mq.height * .05),

                        //
                        Wrap(
                            spacing: 10,
                            alignment: WrapAlignment.center,
                            children: _c.selectedList
                                .mapIndexed((i, e) => _LetterField(letter: e))
                                .toList()),

                        //for adding some space
                        SizedBox(height: mq.height * .03),

                        //
                        Wrap(
                            spacing: 10,
                            alignment: WrapAlignment.center,
                            children: _c.shuffledList
                                .mapIndexed((i, e) => _LetterSelect(
                                      letter: e,
                                      controller: _c,
                                      color: colorsList[i % colorsList.length]
                                          [1],
                                    ))
                                .toList()),

                        if (_c.showHint.isTrue)
                          Padding(
                            padding: EdgeInsets.only(
                                top: mq.height * .02,
                                left: mq.width * .04,
                                right: mq.width * .04),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  //
                                  const Text(
                                    'Hint: ',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15),
                                  ),

                                  Flexible(
                                    child: Text(
                                      _c.game.hint,
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.black54),
                                    ),
                                  ),
                                ]),
                          ),

                        //for adding some space
                        SizedBox(height: mq.height * .03),
                      ]),

                      //hint
                      if (_c.showHint.isFalse)
                        Positioned(
                            right: 0,
                            child: IconButton(
                                onPressed: () =>
                                    Get.dialog(HintDialog(controller: _c)),
                                iconSize: 50,
                                padding: EdgeInsets.zero,
                                icon: Lottie.asset('assets/lottie/hint.json')))
                    ],
                  ),
                ),
              ),

              //for adding some space
              SizedBox(height: mq.height * .03),

              Obx(
                () => Align(
                    child: ImageBtn(
                        height: 50,
                        onTap: _c.initGame,
                        text: _c.gStatus.value == GameStatus.playing
                            ? 'Clear all'
                            : 'Restart',
                        fontSize: 16,
                        color: _c.gStatus.value == GameStatus.playing
                            ? null
                            : gradientColors(HomeType.pdf_translator)[1])),
              ),
            ]));
  }
}

class _LetterField extends StatelessWidget {
  final String letter;

  const _LetterField({required this.letter});

  @override
  Widget build(BuildContext context) {
    final isSelected = letter != ' ';

    return Container(
      width: 40,
      margin: EdgeInsets.only(bottom: mq.height * .02),
      padding: EdgeInsets.only(bottom: isSelected ? 2 : 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(width: 2, color: Colors.grey)),
      ),
      child: Text(
        letter,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 20),
      ),
    );
  }
}

class _LetterSelect extends StatelessWidget {
  final Letter letter;
  final GameController controller;
  final Color color;

  const _LetterSelect(
      {required this.letter, required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return SquareBtn(
        onTap: () async {
          if (letter.isSelected.value) return;

          final i = controller.selectedList.indexOf(' ');
          controller.selectedList
            ..insert(i, letter.letter.value)
            ..removeLast();
          letter.isSelected.value = true;

          controller.gStatus.value = await controller.checkIsWon();
          controller.gStatus.value == GameStatus.won
              ? Get.dialog(controller.isLastLevel
                  ? AllLevelCompleteDialog(controller: controller)
                  : WonDialog(controller: controller))
              : controller.tapSound();

          log(controller.selectedList.toString());
        },
        icon: Text(letter.letter.value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500)),
        color: letter.isSelected.value ? Colors.black54 : color);
  }
}
