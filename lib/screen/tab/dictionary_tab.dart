import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../controllers/dictionary_controller.dart';
import '../../helper/global.dart';
import '../../model/dictionary.dart';
import '../../model/home.dart';
import '../../utils/strings.dart';
import '../../widget/button/home_btn.dart';
import '../../widget/button/square_btn.dart';
import '../../widget/loading/custom_loading.dart';

class DictionaryTab extends StatefulWidget {
  const DictionaryTab({super.key});

  @override
  State<DictionaryTab> createState() => _DictionaryTabState();
}

class _DictionaryTabState extends State<DictionaryTab> {
  final _c = DictionaryController();
  final _hType = HomeType.advance_dictionary;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
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
              leading: const HomeBtn(),

              //label
              title: Text(Strings.advanceDictionary.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, letterSpacing: .25)),
            ),
          ),

          //search field
          ...[
            // Padding(
            //   padding: EdgeInsets.only(
            //     left: mq.width * .03,
            //     right: mq.width * .03,
            //     top: mq.height * .01,
            //   ),
            //   child: CustomAd(
            //       adController: adController, border: true, safeArea: false),
            // ),

            Padding(
              padding: EdgeInsets.only(
                  bottom: mq.height * .01,
                  top: mq.height * .01,
                  left: mq.width * .02),
              child: Row(
                children: [
                  const SizedBox(width: 6),

                  //search field
                  Expanded(
                    child: TextField(
                      controller: _c.textC,
                      onTapOutside: (e) => FocusScope.of(context).unfocus(),
                      decoration: InputDecoration(
                          isDense: true,
                          enabledBorder: const OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(15)),
                            borderSide: BorderSide(color: Colors.blue),
                          ),
                          border: const OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(15)),
                          ),
                          prefix: const SizedBox(width: 10),
                          hintText: Strings.searchWord.tr),
                    ),
                  ),

                  //btn
                  SquareBtn(
                      color: gradientColors(_hType)[1],
                      icon: const Icon(CupertinoIcons.search,
                          color: Colors.white, size: 24),
                      onTap: () => _c.findMeaning()),

                  const SizedBox(width: 6),
                ],
              ),
            ),

            //
            Obx(() => Column(children: [
                  if (_c.status.value == Loading.pending)
                    ..._placeholder()
                  else
                    ..._resultImage(),
                ]))
          ].animate().fade(
              duration: const Duration(milliseconds: 500), curve: Curves.easeIn)
        ]);
  }

  List<Widget> _placeholder() => [
        SizedBox(height: mq.height * .05),

        //image
        Image.asset('assets/images/dictionary.webp', height: mq.height * .15),

        SizedBox(height: mq.height * .02),

        //
        Text(Strings.typeSearchWord.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w500,
                fontSize: 16)),

        const SizedBox(height: 6),

        //
        Align(
          child: SizedBox(
            width: mq.width * .5,
            child: Text(Strings.useDictionary.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.black54, fontSize: 13, letterSpacing: .25)),
          ),
        )
      ];

  List<Widget> _resultImage() => [
        Container(
            padding: EdgeInsets.symmetric(
                vertical: mq.height * .02, horizontal: mq.width * .04),
            margin: EdgeInsets.symmetric(horizontal: mq.width * .05),
            constraints: BoxConstraints(minHeight: mq.height * .3),
            width: double.maxFinite,
            decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: Colors.black54)),
            child: _c.status.value == Loading.loading ||
                    _c.status.value == Loading.error

                //
                ? _c.status.value == Loading.loading
                    //loading
                    ? Align(
                        child: SizedBox(
                            height: mq.height * .15,
                            child: const CustomLoading()))

                    //error
                    : Align(
                        child: Text(Strings.somethingWentWrong.tr,
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 14)),
                      )

                //
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      //word
                      SelectableText(_c.dictionary.value.word,
                          style: const TextStyle(
                              color: dictColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),

                      SizedBox(height: mq.height * .01),

                      //meanings
                      ..._c.dictionary.value.meanings
                          .map((e) => _getMeanings(e))
                    ],
                  ))
      ];

  Widget _getMeanings(Meanings m) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(color: pColor),

        SizedBox(height: mq.height * .01),

        //part of speech
        _customRow(
            title: 'Part of Speech: ',
            msg: m.partOfSpeech.capitalize.toString()),

        //antonyms
        if (m.antonyms.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _customRow(title: 'Antonyms: ', msg: m.antonyms.toString()),
          ),

        //synonyms
        if (m.synonyms.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _customRow(title: 'Synonyms: ', msg: m.synonyms.toString()),
          ),

        const SizedBox(height: 6),

        //definition
        _customRow(title: 'Definition: ', msg: m.definitions.first.definition),

        //example
        if (m.definitions.first.example.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _customRow(
                title: 'Example: ', msg: m.definitions.first.example),
          ),

        SizedBox(height: mq.height * .01)
      ]);

  Widget _customRow({required String title, required String msg}) =>
      Wrap(children: [
        //title
        SelectableText(title,
            style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
                fontWeight: FontWeight.bold)),

        //msg
        SelectableText(msg,
            // textAlign: TextAlign.justify,
            style: const TextStyle(color: Colors.black54, fontSize: 14)),
      ]);
}
