import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/text_translate_controller.dart';
import '../../helper/global.dart';
import '../../helper/my_dialogs.dart';
import '../../helper/pref.dart';
import '../../model/home.dart';
import '../../utils/strings.dart';
import '../../widget/button/back_btn.dart';
import '../../widget/button/home_btn.dart';
import '../../widget/button/image_btn.dart';
import '../../widget/loading/custom_loading.dart';
import 'translate/select_language.dart';

class TextTranslateTab extends StatefulWidget {
  final HomeType hType;

  const TextTranslateTab({super.key, required this.hType});

  @override
  State<TextTranslateTab> createState() => _TextTranslateTabState();
}

class _TextTranslateTabState extends State<TextTranslateTab> {
  final _c = TextTranslateController();

  @override
  void initState() {
    super.initState();

    //preload pdf text
    if (widget.hType == HomeType.pdf_translator) {
      _c.textC.text = Pref.pdfText;

      if (_c.textC.text.isNotEmpty &&
          !_c.textC.text.contains(Strings.notAbleToReadPdf.tr)) {
        _c.enable.value = false;
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Obx(
        () => ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: mq.height * .1),
            children: [
              //app bar
              DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors(widget.hType))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppBar(
                      elevation: 0,
                      centerTitle: false,
                      backgroundColor: Colors.transparent,

                      //home
                      leading: widget.hType == HomeType.pdf_translator
                          ? const BackBtn()
                          : const HomeBtn(),

                      //label
                      title: Text(
                          widget.hType == HomeType.pdf_translator
                              ? Strings.pdfTranslator.tr
                              : Strings.textTranslator.tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 18, letterSpacing: .25)),
                    ),

                    //
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          //from
                          _CustomCard(
                              onTap: () => Get.to(() => SelectLanguage(
                                  isFrom: true, c: _c, homeType: widget.hType)),
                              lang: _c.from.value.name),

                          //
                          IconButton(
                            onPressed: _c.from.value.code.contains('auto')
                                ? () {
                                    MyDialogs.info(
                                        msg: Strings.pleaseSelectLanguage.tr,
                                        bottom: true);
                                  }
                                : () {
                                    final temp = _c.from.value;
                                    _c.from.value = _c.to.value;
                                    _c.to.value = temp;
                                  },
                            icon: Image.asset('assets/icons/ic_arrow.webp',
                                width: 32,
                                color: _c.from.value.code.contains('auto')
                                    ? Colors.white30
                                    : Colors.white),
                          ),

                          //to
                          _CustomCard(
                              onTap: () => Get.to(() => SelectLanguage(
                                  isFrom: false,
                                  c: _c,
                                  homeType: widget.hType)),
                              lang: _c.to.value.name),
                        ]),

                    const SizedBox(height: 6)
                  ],
                ),
              ),

              ...[
                // Padding(
                //   padding: EdgeInsets.only(
                //       left: mq.width * .03,
                //       right: mq.width * .03,
                //       top: mq.height * .01),
                //   child: CustomAd(
                //       adController: adController,
                //       border: true,
                //       safeArea: false),
                // ),

                Padding(
                  padding: EdgeInsets.only(
                      top: mq.height * .01,
                      bottom: mq.height * .03,
                      left: mq.width * .03,
                      right: mq.width * .03),
                  child: _SearchField(controller: _c),
                ),

                //btn
                _c.status.value != Loading.loading
                    ? Align(
                        child: ImageBtn(
                        onTap: _c.enable.value ? null : () => _c.translate(),
                        text: Strings.translate.tr,
                        color: gradientColors(widget.hType)[1],
                        greyBtn: _c.enable.value,
                      ))
                    : const SizedBox(height: 70, child: CustomLoading()),

                //how to instruction
                if (_c.status.value == Loading.pending)
                  Padding(
                    padding: EdgeInsets.only(
                      left: mq.width * .1,
                      right: mq.width * .1,
                      top: mq.height * .03,
                    ),
                    child: Text(Strings.howToTranslate.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: gradientColors(widget.hType)[1],
                            fontSize: 15,
                            letterSpacing: .5)),
                  ),

                if (_c.status.value != Loading.pending)
                  Padding(
                    padding: EdgeInsets.only(
                        top: mq.height * .03,
                        bottom: mq.height * .03,
                        left: mq.width * .03,
                        right: mq.width * .03),
                    child: _ResultField(controller: _c),
                  ),
              ].animate().fade(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeIn),
            ]),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextTranslateController controller;

  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TextFormField(
          minLines: 10,
          controller: controller.textC,
          onChanged: (r) => controller.enable.value = r.isEmpty,
          onTapOutside: (e) => FocusScope.of(context).unfocus(),
          maxLines: 10,
          decoration: InputDecoration(
              hintStyle: const TextStyle(fontSize: 14, letterSpacing: .25),
              hintText: Strings.startTypingText.tr,
              border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)))),
        ),

        //paste
        Positioned(
          bottom: 0,
          child: IconButton(
              onPressed: () async {
                controller.textC.text = controller.textC.text +
                    ((await Clipboard.getData(Clipboard.kTextPlain))?.text ??
                        '');
                controller.enable.value = false;
              },
              icon: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(CupertinoIcons.doc_on_clipboard_fill,
                      color: Colors.blue))),
        ),

        //clear
        Positioned(
          bottom: 0,
          right: 0,
          child: IconButton(
              onPressed: () {
                controller.textC.text = '';
                controller.enable.value = true;
              },
              icon: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child:
                      Icon(Icons.delete_forever, color: Colors.red, size: 28))),
        ),
      ],
    );
  }
}

class _ResultField extends StatelessWidget {
  final TextTranslateController controller;

  const _ResultField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TextFormField(
          minLines: 10,
          controller: controller.resultC,
          onTapOutside: (e) => FocusScope.of(context).unfocus(),
          maxLines: 10,
          decoration: InputDecoration(
              hintStyle: const TextStyle(fontSize: 14, letterSpacing: .25),
              hintText: Strings.startTypingText.tr,
              border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)))),
        ),

        //
        Positioned(
          right: 0,
          bottom: 0,
          child: Wrap(
            //share
            children: [
              IconButton(
                  onPressed: () async {
                    await Share.share(controller.resultC.text);
                  },
                  icon: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.share, color: Colors.blue))),

              //copy
              IconButton(
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: controller.resultC.text));
                    MyDialogs.success(msg: 'Translation Copied');
                  },
                  icon: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.copy_all, color: Colors.blue))),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomCard extends StatelessWidget {
  final String lang;
  final VoidCallback onTap;

  const _CustomCard({required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
        onPressed: onTap,
        label: const Icon(CupertinoIcons.chevron_down,
            color: Colors.white, size: 19),
        style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent,
            maximumSize: Size(mq.width * .5, 50),
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)))),
        icon: Flexible(
          child: Text(lang,
              overflow: TextOverflow.ellipsis,
              // maxLines: 1,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, letterSpacing: .25)),
        ));
  }
}
