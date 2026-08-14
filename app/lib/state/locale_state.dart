import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'app_locale';

class LocaleState extends ChangeNotifier {
  // 첫 방문은 브라우저 언어와 관계없이 한국어로 시작한다. 이후에는 사용자가
  // Language 메뉴에서 고른 값을 저장해 다음 방문에도 유지한다.
  Locale locale = const Locale('ko');

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null) {
      locale = Locale(code);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale value) async {
    locale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, value.languageCode);
  }
}

final LocaleState localeState = LocaleState();
