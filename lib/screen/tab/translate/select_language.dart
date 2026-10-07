import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:translator_plus/translator_plus.dart';

import '../../../helper/global.dart';
import '../../../model/home.dart';
import '../../../model/language.dart';
import '../../../utils/strings.dart';
import '../../../widget/button/back_btn.dart';
import '../../../widget/button/square_btn.dart';

class SelectLanguage extends StatefulWidget {
  final bool isFrom;
  final dynamic c; //controller
  final HomeType homeType;

  const SelectLanguage(
      {super.key,
      required this.isFrom,
      required this.c,
      required this.homeType});

  @override
  State<SelectLanguage> createState() => _SelectLanguageState();
}

class _SelectLanguageState extends State<SelectLanguage> {
  final _search = ''.obs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(

        //body
        body: Column(children: [
      //app bar
      DecoratedBox(
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors(widget.homeType))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              elevation: 0,
              centerTitle: false,
              backgroundColor: Colors.transparent,

              //home
              leading: const BackBtn(),

              //label
              title: Text(
                  widget.isFrom
                      ? Strings.fromLanguage.tr
                      : Strings.toLanguage.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, letterSpacing: .25)),
            ),

            // const SizedBox(height: 6)
          ],
        ),
      ),

      //search field
      ...[
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
                  onChanged: (v) => _search.value = v,
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
                      prefixIcon: const Icon(CupertinoIcons.search,
                          color: Colors.blue, size: 26),
                      hintText: Strings.searchLanguage.tr),
                ),
              ),

              //btn
              SquareBtn(
                  color: gradientColors(widget.homeType)[1],
                  icon: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white),
                  onTap: Get.back),

              const SizedBox(width: 6),
            ],
          ),
        ),

        //list
        Expanded(
          child: Obx(
            () {
              log('obx executed');
              final searchList = LanguageList.langs.entries
                  .where((e) => e.value
                      .toLowerCase()
                      .contains(_search.value.toLowerCase()))
                  .toList();

              final langList = LanguageList.langs.entries.toList();
              if (!widget.isFrom) {
                langList.removeWhere((e) => e.key == 'auto');
              }

              return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(bottom: mq.height * .1),
                  itemCount: _search.isEmpty
                      ? LanguageList.langs.length
                      : searchList.length,
                  itemBuilder: (ctx, i) {
                    final title = _search.isEmpty ? langList[i] : searchList[i];

                    return InkWell(
                      onTap: () {
                        if (widget.isFrom) {
                          widget.c.from.value =
                              TLanguage(code: title.key, name: title.value);
                        } else {
                          widget.c.to.value =
                              TLanguage(code: title.key, name: title.value);
                        }
                        log('lang: ${title.value}');
                        // _lang.value.code = title.key;
                        // _lang.value.name = title.value;
                        setState(() {});
                      },
                      child: ListTile(
                          title: Text(title.value),
                          trailing: _lang.value.code == title.key
                              ? CircleAvatar(
                                  backgroundColor:
                                      gradientColors(widget.homeType)[1],
                                  radius: 13,
                                  child: const Icon(
                                    Icons.done_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ))
                              : null),
                    );
                  });
            },
          ),
        )
      ].animate().fade(
          duration: const Duration(milliseconds: 500), curve: Curves.easeIn)
    ]));
  }

  Rx<TLanguage> get _lang => widget.isFrom ? widget.c.from : widget.c.to;
}
