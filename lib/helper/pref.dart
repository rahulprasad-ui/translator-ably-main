//for accessing hive database

import 'package:hive_flutter/hive_flutter.dart';

class Pref {
  static late Box _box;

  static Future<void> initializeHive() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('data');
  }

  static bool get skipIntro => _box.get('skip_intro') ?? false;
  static set skipIntro(bool v) => _box.put('skip_intro', v);

  static String get langFlag => _box.get('langFlag') ?? 'us';
  static set langFlag(String v) => _box.put('langFlag', v);

  static String get pdfText => _box.get('pdfText') ?? '';
  static set pdfText(String v) => _box.put('pdfText', v);

  static int get level => _box.get('level') ?? 1;
  static set level(int v) => _box.put('level', v);

  static bool get isPurchased => _box.get('isPurchased') ?? false;
  static set isPurchased(bool v) => _box.put('isPurchased', v);

  static int get premiumCount => _box.get('premiumCount') ?? 1;
  static set premiumCount(int v) => _box.put('premiumCount', v);

  static List<String> get recentPdfPaths =>
      List<String>.from(_box.get('recent_pdf_paths') ?? []);
  static set recentPdfPaths(List<String> v) =>
      _box.put('recent_pdf_paths', v);

  static List<String> get bookmarkedPdfPaths =>
      List<String>.from(_box.get('bookmarked_pdf_paths') ?? []);
  static set bookmarkedPdfPaths(List<String> v) =>
      _box.put('bookmarked_pdf_paths', v);
}
