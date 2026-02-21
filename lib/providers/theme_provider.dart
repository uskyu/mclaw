import 'dart:async';

import 'package:flutter/material.dart';

import '../services/secure_storage_service.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  Locale _locale = const Locale('zh'); // 默认中文

  ThemeProvider() {
    _loadSavedThemeMode();
  }

  bool get isDarkMode => _isDarkMode;
  Locale get locale => _locale;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    unawaited(_persistThemeMode());
    notifyListeners();
  }

  void setDarkMode(bool value) {
    if (_isDarkMode == value) {
      return;
    }
    _isDarkMode = value;
    unawaited(_persistThemeMode());
    notifyListeners();
  }

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }

  void toggleLocale() {
    _locale = _locale.languageCode == 'zh' ? const Locale('en') : const Locale('zh');
    notifyListeners();
  }

  Future<void> _loadSavedThemeMode() async {
    try {
      final saved = await SecureStorageService.loadThemeDarkMode();
      if (saved == null || saved == _isDarkMode) {
        return;
      }
      _isDarkMode = saved;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persistThemeMode() async {
    try {
      await SecureStorageService.saveThemeDarkMode(_isDarkMode);
    } catch (_) {}
  }
}
