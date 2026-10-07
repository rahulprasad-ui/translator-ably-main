import 'dart:developer';

import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../helper/iap.dart';

class Config {
// for remotely configuring app
  static final _rc = FirebaseRemoteConfig.instance;

  // Set to true to use official Google AdMob test ad units
  static const bool useTestAds = true;

  // Production Ad Unit IDs provided by user
  static const String prodNativeAd = 'ca-app-pub-2051326559192921/6696562796';
  static const String prodInterstitialAd = 'ca-app-pub-2051326559192921/4221075284';
  static const String prodBannerAd = 'ca-app-pub-2051326559192921/6300978111';

  // Google AdMob Official Test Ad Unit IDs
  static const String testNativeAd = 'ca-app-pub-3940256099942544/2247696110';
  static const String testInterstitialAd = 'ca-app-pub-3940256099942544/1033173712';
  static const String testBannerAd = 'ca-app-pub-3940256099942544/6300978111';

  static Map<String, dynamic> get _defaultValues => const {
        "classic_word_game":
            "[             {\"hint\": \"A common pet.\", \"word\": \"DOG\"},             {\"hint\": \"A common bird with black feathers.\", \"word\": \"CROW\"},             {\"hint\": \"A musical instrument with strings.\", \"word\": \"GUITAR\"},             {\"hint\": \"A mode of transportation on water.\", \"word\": \"BOAT\"},             {\"hint\": \"A planet in our solar system.\", \"word\": \"EARTH\"},             {\"hint\": \"A common beverage in the morning.\", \"word\": \"COFFEE\"},             {\"hint\": \"A type of flower.\", \"word\": \"ROSES\"},             {\"hint\": \"A tool for writing or drawing.\", \"word\": \"PENCIL\"},             {\"hint\": \"A citrus fruit.\", \"word\": \"ORANGE\"},             {               \"hint\": \"A mode of transportation with pedals.\",               \"word\": \"BICYCLE\"             },             {               \"hint\": \"It\u0027s up in the night sky \u0026 sometimes looks like cheese.\",               \"word\": \"MOON\"             },             {\"hint\": \"A type of nut.\", \"word\": \"PEANUT\"},             {\"hint\": \"A place to store books.\", \"word\": \"LIBRARY\"},             {\"hint\": \"A tasty, frozen dessert.\", \"word\": \"ICECREAM\"},             {\"hint\": \"A reptile that slithers.\", \"word\": \"SNAKE\"},             {\"hint\": \"A type of weather condition.\", \"word\": \"RAIN\"},             {\"hint\": \"A musical genre with fast beats.\", \"word\": \"DANCE\"},             {\"hint\": \"A body part on your face.\", \"word\": \"NOSE\"},             {\"hint\": \"A small, buzzing insect.\", \"word\": \"BEE\"},             {               \"hint\": \"A mode of transportation with four wheels.\",               \"word\": \"CAR\"             },             {\"hint\": \"A type of clothing for your feet.\", \"word\": \"SOCKS\"},             {               \"hint\": \"A bird known for its colorful feathers.\",               \"word\": \"PEACOCK\"             },             {\"hint\": \"A mode of transportation in the sky.\", \"word\": \"PLANE\"},             {\"hint\": \"A small, flat device for computing.\", \"word\": \"TABLET\"},             {\"hint\": \"A common breakfast food.\", \"word\": \"TOAST\"},             {\"hint\": \"A musical instrument with keys.\", \"word\": \"PIANO\"},             {\"hint\": \"A reptile with a long tail.\", \"word\": \"LIZARD\"},             {\"hint\": \"A type of fabric.\", \"word\": \"COTTON\"},             {\"hint\": \"A season with falling leaves.\", \"word\": \"FALL\"},             {               \"hint\": \"A mode of transportation that hovers.\",               \"word\": \"HELICOPTER\"             },             {               \"hint\": \"A mode of transportation pulled by horses.\",               \"word\": \"CARRIAGE\"             },             {\"hint\": \"A fruit known for its tartness.\", \"word\": \"LEMON\"},             {               \"hint\": \"A type of flower often associated with love.\",               \"word\": \"ROSE\"             },             {\"hint\": \"A mode of transportation on two wheels.\", \"word\": \"BIKE\"},             {\"hint\": \"A type of weather phenomenon in winter.\", \"word\": \"SNOW\"},             {\"hint\": \"A type of vegetable that\u0027s orange.\", \"word\": \"CARROT\"},             {\"hint\": \"A furry pet that says \u0027Meow\u0027.\", \"word\": \"CAT\"},             {\"hint\": \"It\u0027s a funny, animated character on TV.\", \"word\": \"TOON\"},             {               \"hint\":                   \"You wear it on your head to keep the sun out of your eyes.\",               \"word\": \"HAT\"             },             {\"hint\": \"You bounce it and play games with it.\", \"word\": \"BALL\"},             {\"hint\": \"You read it and it has lots of stories.\", \"word\": \"BOOK\"},             {               \"hint\": \"It\u0027s bright in the night sky and twinkle, twinkle...\",               \"word\": \"STAR\"             },             {               \"hint\":                   \"It\u0027s tall and has leaves, and you might find it in a forest.\",               \"word\": \"TREE\"             },             {               \"hint\": \"It\u0027s a slimy creature that swims in water.\",               \"word\": \"FISH\"             },             {\"hint\": \"It has feathers and can fly.\", \"word\": \"BIRD\"},             {               \"hint\": \"A sweet treat often with candles on top.\",               \"word\": \"CAKE\"             },             {\"hint\": \"The color of strawberries.\", \"word\": \"RED\"},             {\"hint\": \"The color of the sky on a clear day.\", \"word\": \"BLUE\"},             {               \"hint\": \"Something fun to play with, like a doll or a car.\",               \"word\": \"TOY\"             },             {\"hint\": \"You sleep on it, and it\u0027s soft.\", \"word\": \"BED\"},             {\"hint\": \"It quacks and swims in ponds.\", \"word\": \"DUCK\"},             {\"hint\": \"It jumps and croaks in ponds.\", \"word\": \"FROG\"},             {               \"hint\": \"What you do when you\u0027re happy in a photo.\",               \"word\": \"SMILE\"             },             {               \"hint\": \"The feeling when everything is going well.\",               \"word\": \"HAPPY\"             },             {\"hint\": \"A tiny human who needs lots of care.\", \"word\": \"BABY\"},             {               \"hint\": \"What you do with both feet off the ground.\",               \"word\": \"JUMP\"             },             {\"hint\": \"Someone you like and play with.\", \"word\": \"FRIEND\"},             {\"hint\": \"A place to learn and make friends.\", \"word\": \"SCHOOL\"},             {\"hint\": \"A yellow fruit you can peel.\", \"word\": \"BANANA\"},             {\"hint\": \"A juicy fruit often found in pies.\", \"word\": \"APPLE\"},             {\"hint\": \"A pretty plant that grows in gardens.\", \"word\": \"FLOWER\"},             {\"hint\": \"It goes on tracks and carries people.\", \"word\": \"TRAIN\"},             {\"hint\": \"Where you live with your family.\", \"word\": \"HOUSE\"},             {\"hint\": \"She takes care of you and loves you.\", \"word\": \"MOM\"},             {\"hint\": \"He\u0027s often the one who fixes things.\", \"word\": \"DAD\"},             {\"hint\": \"Often wears dresses and likes dolls.\", \"word\": \"GIRL\"},             {               \"hint\": \"Often likes playing with toy cars and trucks.\",               \"word\": \"BOY\"             },             {               \"hint\":                   \"The big, bright ball of light in the sky during the day.\",               \"word\": \"SUN\"             },             {               \"hint\":                   \"It\u0027s a symbol of love and emotions that beats in your chest.\",               \"word\": \"HEART\"             },             {\"hint\": \"Hair that grows on a man\u0027s face.\", \"word\": \"BEARD\"},             {               \"hint\": \"Someone who glides on snow with long, narrow boards.\",               \"word\": \"SKIER\"             },             {               \"hint\": \"Something that\u0027s really awesome or exciting.\",               \"word\": \"EPIC\"             },             {               \"hint\": \"A heavy metal used to make things like nails and pans.\",               \"word\": \"IRON\"             },             {\"hint\": \"Guidelines you should follow.\", \"word\": \"RULES\"},             {\"hint\": \"What you say to show appreciation.\", \"word\": \"THANK\"},             {\"hint\": \"A task or assignment you work on.\", \"word\": \"PROJECT\"},             {\"hint\": \"A feeling of happiness and delight.\", \"word\": \"JOY\"},             {\"hint\": \"A sweet treat you can bake and eat.\", \"word\": \"COOKIE\"}           ]",
        "interstitial_ad": "ca-app-pub-3940256099942544/1033173712",
        "rewarded_ad": "ca-app-pub-3940256099942544/5224354917",
        "native_ad": "ca-app-pub-3940256099942544/2247696110",
        "app_open_ad": "ca-app-pub-3940256099942544/9257395921",
        "banner_ad": "ca-app-pub-3940256099942544/6300978111",
        "show_ads": "true",
      };

  static Future<void> initConfig() async {
    try {
      await _rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 5),
        minimumFetchInterval: const Duration(minutes: 30),
      ));

      await _rc.setDefaults(_defaultValues);
      await _rc.fetchAndActivate();
      log('\nremote config initialized: ${_rc.lastFetchTime}');
      log('remote config show_ads (raw): "${_rc.getString('show_ads')}"');
    } catch (e) {
      log('\ninitConfig: $e');
    }
  }

  //ads values
  static bool get _showAds {
    try {
      final str = _rc.getString('show_ads').toLowerCase();
      if (str == 'true' || str == '1') return true;
      if (str == 'false' || str == '0') return false;
      return _rc.getBool('show_ads');
    } catch (_) {
      return true;
    }
  }
  static String get rewardedAd => _rc.getString('rewarded_ad');
  static String get nativeAd {
    if (useTestAds) return testNativeAd;
    final ad = _rc.getString('native_ad');
    return ad.isNotEmpty ? ad : prodNativeAd;
  }
  static String get bannerAd {
    if (useTestAds) return testBannerAd;
    final ad = _rc.getString('banner_ad');
    return ad.isNotEmpty ? ad : prodBannerAd;
  }
  static String get interstitialAd {
    if (useTestAds) return testInterstitialAd;
    final ad = _rc.getString('interstitial_ad');
    return ad.isNotEmpty ? ad : prodInterstitialAd;
  }
  static String get appOpenAd => _rc.getString('app_open_ad');

  // Test mode me remote config ka show_ads flag bypass karo, warna testing
  // ke time remote config se false aane par koi bhi ad load nahi hota.
  static bool get hideAds =>
      useTestAds ? false : (!_showAds || IAP.isPurchased.value);

  // Razorpay Key for India payments
  static String get razorpayKey {
    final key = _rc.getString('razorpay_key');
    return key.isNotEmpty ? key : 'rzp_test_1DP5mmOlF5G5ag';
  }

  //classic word game list
  static String get classicWordGame => _rc.getString('classic_word_game');
}
