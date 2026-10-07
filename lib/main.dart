import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ads/ad_helper.dart';
import 'ads/config.dart';
import 'firebase_options.dart';
import 'helper/global.dart';
import 'helper/iap.dart';
import 'helper/pref.dart';
import 'screen/splash_screen.dart';
import 'utils/language/local_string.dart';
import 'utils/strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //initialize firebase & then ads in config
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
      .then((value) async => await Config.initConfig());

  await Pref.initializeHive();

  // for initializing ads sdk
  await MobileAds.instance.initialize();
  AdHelper.startPeriodicInterstitial();

  //init in-app purchases
  IAP.initialize(showDialogs: false);

  //for full screen
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Locking Device Orientation
  await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitDown, DeviceOrientation.portraitUp])
      .then((value) {
    // main app
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
        title: appName,
        translations: LocalString(),
        fallbackLocale: const Locale('en', 'US'),
        locale: Strings.languageList
            .firstWhere((e) => e.flag == Pref.langFlag)
            .locale,
        theme: ThemeData(
            useMaterial3: false,
            appBarTheme: const AppBarTheme(
                backgroundColor: pColor, centerTitle: true, elevation: 0)),
        debugShowCheckedModeBanner: false,
        home: const SplashScreen());
  }
}
