import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/voice_translate_controller.dart';
import '../../helper/global.dart';
import '../../helper/my_dialogs.dart';
import '../../model/home.dart';
import '../../utils/strings.dart';
import '../../widget/button/home_btn.dart';
import '../../widget/button/image_btn.dart';
import '../../widget/button/square_btn.dart';
import '../../widget/loading/custom_loading.dart';
import 'translate/select_language.dart';

class VoiceTranslateTab extends StatefulWidget {
  const VoiceTranslateTab({super.key});

  @override
  State<VoiceTranslateTab> createState() => _VoiceTranslateTabState();
}

class _VoiceTranslateTabState extends State<VoiceTranslateTab> {
  final _c = VoiceTranslateController();
  final _hType = HomeType.voice_translator;

  @override
  void initState() {
    super.initState();
    _c.initSpeech();
  }

  @override
  void dispose() {
    _c.release();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
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
                      colors: gradientColors(_hType))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    elevation: 0,
                    centerTitle: false,
                    backgroundColor: Colors.transparent,

                    //home
                    leading: const HomeBtn(),

                    //label
                    title: Text(Strings.voiceTranslator.tr,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(fontSize: 18, letterSpacing: .25)),
                  ),

                  //
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        //from
                        _CustomCard(
                            onTap: () => Get.to(() => SelectLanguage(
                                isFrom: true, c: _c, homeType: _hType)),
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
                                isFrom: false, c: _c, homeType: _hType)),
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
              //       adController: adController, border: true, safeArea: false),
              // ),
              //
              Padding(
                padding: EdgeInsets.only(
                    top: mq.height * .01,
                    bottom: mq.height * .03,
                    left: mq.width * .03,
                    right: mq.width * .03),
                child: _SearchField(controller: _c),
              ),

              _c.showRecord.value
                  //record btn
                  ? Align(
                      child: SquareBtn(
                          size: mq.height * .12,
                          color: gradientColors(_hType)[1],
                          icon: _c.isListening.value
                              ? Lottie.asset('assets/lottie/recording.json',
                                  width: mq.width * .125)
                              : const Icon(Icons.mic_rounded,
                                  color: Colors.white, size: 30),
                          onTap: () => _c.isListening.value
                              ? _c.stopListening()
                              : _c.startListening()),
                    )
                  :
                  //translate btn
                  _c.status.value != Loading.loading
                      ? Column(
                          children: [
                            ImageBtn(
                              color: gradientColors(_hType)[1],
                              onTap: () => _c.translate(),
                              text: Strings.translate.tr,
                            ),

                            //retake
                            MaterialButton(
                                onPressed: () {
                                  _c.textC.text = '';
                                  _c.resultC.text = '';
                                  _c.showRecord.value = true;
                                  _c.status.value = Loading.pending;
                                },
                                shape: const StadiumBorder(),
                                child: Text(Strings.retake.tr,
                                    style: TextStyle(
                                        color: gradientColors(_hType)[1],
                                        fontSize: 16,
                                        decoration: TextDecoration.underline)))
                          ],
                        )
                      : const Padding(
                          padding: EdgeInsets.symmetric(vertical: 19),
                          child: SizedBox(height: 80, child: CustomLoading()),
                        ),

              //how to instruction
              if (_c.status.value == Loading.pending)
                Padding(
                  padding: EdgeInsets.only(
                    left: mq.width * .15,
                    right: mq.width * .15,
                    top: mq.height * .03,
                  ),
                  child: Text(Strings.howToVoiceT.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: gradientColors(_hType)[1],
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
                curve: Curves.easeIn)
          ]),
    );
  }
}

class _SearchField extends StatelessWidget {
  final VoiceTranslateController controller;

  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TextFormField(
          minLines: 6,
          controller: controller.textC,
          enabled: controller.showRecord.isFalse,
          onChanged: (r) => controller.showRecord.value = r.isEmpty,
          onTapOutside: (e) => FocusScope.of(context).unfocus(),
          maxLines: null,
          decoration: const InputDecoration(
              disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: Colors.grey)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)))),
        ),

        //hint
        if (controller.showRecord.value && controller.isListening.isFalse)
          Align(
            child: Padding(
              padding: EdgeInsets.only(
                  top: mq.height * .07,
                  left: mq.width * .175,
                  right: mq.width * .175),
              child: Text(
                Strings.tapOnMic.tr,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(letterSpacing: .25, color: Colors.black54),
              ),
            ),
          )
      ],
    );
  }
}

class _ResultField extends StatelessWidget {
  final VoiceTranslateController controller;

  const _ResultField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        //
        TextFormField(
          minLines: 6,
          controller: controller.resultC,
          onTapOutside: (e) => FocusScope.of(context).unfocus(),
          maxLines: null,
          decoration: InputDecoration(
              hintStyle: const TextStyle(fontSize: 14, letterSpacing: .25),
              hintText: Strings.startTypingText.tr,
              disabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10))),
              border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)))),
        ),
        Wrap(
          children: [
            //audio
            IconButton(
                onPressed: () => controller.audioResult(),
                icon: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(CupertinoIcons.speaker_2_fill,
                        color: Colors.blue))),

            //share
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
