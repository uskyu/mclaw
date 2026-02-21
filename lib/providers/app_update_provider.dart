import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/app_update_service.dart';

class AppUpdateProvider with ChangeNotifier {
  String _currentVersion = '0.0.0';
  String? _latestVersion;
  String? _downloadUrl;
  String? _releaseNotes;
  bool _hasUpdate = false;
  bool _forceUpdate = false;
  bool _isChecking = false;
  DateTime? _lastCheckedAt;

  String get currentVersion => _currentVersion;
  String? get latestVersion => _latestVersion;
  String? get downloadUrl => _downloadUrl;
  String? get releaseNotes => _releaseNotes;
  bool get hasUpdate => _hasUpdate;
  bool get forceUpdate => _forceUpdate;
  bool get isChecking => _isChecking;
  DateTime? get lastCheckedAt => _lastCheckedAt;

  Future<void> initialize() async {
    await _loadCurrentVersion();
    unawaited(checkForUpdates());
  }

  Future<void> checkForUpdates({bool forceRefresh = false}) async {
    if (_isChecking) {
      return;
    }
    if (!forceRefresh && _lastCheckedAt != null) {
      final elapsed = DateTime.now().difference(_lastCheckedAt!);
      if (elapsed.inMinutes < 10) {
        return;
      }
    }

    _isChecking = true;
    notifyListeners();

    try {
      final info = await AppUpdateService.fetchLatestInfo();
      _lastCheckedAt = DateTime.now();
      if (info == null) {
        _isChecking = false;
        notifyListeners();
        return;
      }

      _latestVersion = info.latestVersion;
      _downloadUrl = (info.downloadUrl == null || info.downloadUrl!.isEmpty)
          ? AppUpdateService.releasePageUrl
          : info.downloadUrl;
      _releaseNotes = info.releaseNotes;
      _forceUpdate = info.force;
      _hasUpdate = AppUpdateService.isNewerThanCurrent(
        latestVersion: info.latestVersion,
        currentVersion: _currentVersion,
      );
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      if (version.isNotEmpty) {
        _currentVersion = version;
      }
    } catch (_) {}
  }
}
