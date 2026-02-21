import 'dart:async';

import 'package:flutter/material.dart';

import '../services/secure_storage_service.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  Locale? _locale;

  ThemeProvider() {
    _loadSavedThemeMode();
    _loadSavedLocale();
  }

  bool get isDarkMode => _isDarkMode;
  Locale? get locale => _locale;
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
    if (_locale?.languageCode == locale.languageCode) {
      return;
    }
    _locale = locale;
    unawaited(SecureStorageService.saveLocaleCode(locale.languageCode));
    notifyListeners();
  }

  void toggleLocale(Locale fallbackLocale) {
    final currentCode = (_locale ?? fallbackLocale).languageCode;
    final next = currentCode == 'zh' ? const Locale('en') : const Locale('zh');
    _locale = next;
    unawaited(SecureStorageService.saveLocaleCode(next.languageCode));
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

  Future<void> _loadSavedLocale() async {
    try {
      final saved = await SecureStorageService.loadLocaleCode();
      if (saved == null || (saved != 'zh' && saved != 'en')) {
        return;
      }
      _locale = Locale(saved);
      notifyListeners();
    } catch (_) {}
  }
}
