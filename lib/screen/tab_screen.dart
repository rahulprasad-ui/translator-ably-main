import '../../controllers/main_controller.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../model/home.dart';
import '../widget/bottom_nav.dart';
import 'tab/dictionary_tab.dart';
import 'tab/pdf_tab.dart';
import 'tab/pronouncer_tab.dart';
import 'tab/text_translate_tab.dart';
import 'tab/voice_translate_tab.dart';

class TabScreen extends StatefulWidget {
  final int i;

  const TabScreen({super.key, required this.i});

  @override
  State<TabScreen> createState() => _TabScreenState();
}

class _TabScreenState extends State<TabScreen> {
  final _c = MainController();

  @override
  void initState() {
    super.initState();
    _c.index.value = widget.i;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // resizeToAvoidBottomInset: false,
        bottomNavigationBar: BottomNav(controller: _c),

        //body
        body: Obx(
          () => const [
            TextTranslateTab(hType: HomeType.text_translator),
            VoiceTranslateTab(),
            PdfTab(),
            DictionaryTab(),
            PronouncerTab(),
          ][_c.index.value],
        ));
  }
}
