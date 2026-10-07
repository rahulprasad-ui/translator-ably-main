import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../../controllers/pronouncer_controller.dart';
import '../../helper/global.dart';
import '../../model/home.dart';
import '../../utils/strings.dart';
import '../../widget/button/home_btn.dart';
import '../../widget/button/square_btn.dart';

class PronouncerTab extends StatefulWidget {
  const PronouncerTab({super.key});

  @override
  State<PronouncerTab> createState() => _PronouncerTabState();
}

class _PronouncerTabState extends State<PronouncerTab> {
  final _c = PronouncerController();
  final _hType = HomeType.word_pronouncer;

  @override
  void initState() {
    super.initState();
    _c.initFlutterTts();
  }

  @override
  void dispose() {
    _c.stop();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
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
          title: Text(Strings.wordPronouncer.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, letterSpacing: .25)),
        ),
      ),

      ...[
        Padding(
          padding: EdgeInsets.only(
              top: mq.height * .015,
              bottom: mq.height * .03,
              left: mq.width * .03,
              right: mq.width * .03),
          child: _SearchField(controller: _c),
        ),

        //btn
        Align(
          child: Obx(
            () => SquareBtn(
                size: mq.height * .12,
                color: gradientColors(_hType)[1],
                icon: _c.status.value == Loading.loading
                    ? Lottie.asset('assets/lottie/recording.json',
                        width: mq.width * .125)
                    : const Icon(CupertinoIcons.volume_up,
                        color: Colors.white, size: 24),
                onTap: _c.enable.value ? null : () => _c.wordPronounce()),
          ),
        ),

        const Spacer(),

        // Padding(
        //   padding: EdgeInsets.only(
        //       left: mq.width * .03,
        //       right: mq.width * .03,
        //       bottom: mq.height * .01),
        //   child: CustomAd(
        //       adController: adController, border: true, safeArea: false),
        // ),
      ].animate().fade(
          duration: const Duration(milliseconds: 500), curve: Curves.easeIn)
    ]);
  }
}

class _SearchField extends StatelessWidget {
  final PronouncerController controller;

  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TextFormField(
          minLines: 5,
          controller: controller.textC,
          onChanged: (r) => controller.enable.value = r.isEmpty,
          onTapOutside: (e) => FocusScope.of(context).unfocus(),
          maxLines: null,
          decoration: InputDecoration(
              hintStyle: const TextStyle(fontSize: 14, letterSpacing: .25),
              hintText: Strings.wordPronHint.tr,
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
