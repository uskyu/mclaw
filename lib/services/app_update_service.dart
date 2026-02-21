import 'dart:convert';
import 'dart:io';

class AppUpdateInfo {
  final String latestVersion;
  final String? downloadUrl;
  final String? releaseNotes;
  final bool force;

  const AppUpdateInfo({
    required this.latestVersion,
    this.downloadUrl,
    this.releaseNotes,
    this.force = false,
  });
}

class AppUpdateService {
  AppUpdateService._();

  static const String manifestUrl =
      'https://a3c09445.mclaw.pages.dev/update.json';
  static const String githubReleaseApi =
      'https://api.github.com/repos/uskyu/mclaw/releases/latest';
  static const String releasePageUrl =
      'https://a3c09445.mclaw.pages.dev/update';

  static Future<AppUpdateInfo?> fetchLatestInfo() async {
    final manifest = await _fetchJson(manifestUrl);
    if (manifest != null) {
      final version = (manifest['latestVersion'] ?? manifest['version'])
          ?.toString()
          .trim();
      if (version != null && version.isNotEmpty) {
        return AppUpdateInfo(
          latestVersion: _normalizeVersion(version),
          downloadUrl: (manifest['downloadUrl'] ?? manifest['url'])
              ?.toString()
              .trim(),
          releaseNotes: manifest['releaseNotes']?.toString(),
          force: manifest['force'] == true,
        );
      }
    }

    final release = await _fetchJson(githubReleaseApi);
    if (release != null) {
      final tag = release['tag_name']?.toString().trim();
      if (tag != null && tag.isNotEmpty) {
        return AppUpdateInfo(
          latestVersion: _normalizeVersion(tag),
          downloadUrl: release['html_url']?.toString().trim(),
          releaseNotes: release['body']?.toString(),
        );
      }
    }

    return null;
  }

  static bool isNewerThanCurrent({
    required String latestVersion,
    required String currentVersion,
  }) {
    final latest = _parseVersionParts(_normalizeVersion(latestVersion));
    final current = _parseVersionParts(_normalizeVersion(currentVersion));
    final maxLen = latest.length > current.length
        ? latest.length
        : current.length;

    for (var i = 0; i < maxLen; i++) {
      final lv = i < latest.length ? latest[i] : 0;
      final cv = i < current.length ? current[i] : 0;
      if (lv > cv) {
        return true;
      }
      if (lv < cv) {
        return false;
      }
    }
    return false;
  }

  static String _normalizeVersion(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
      return trimmed.substring(1);
    }
    return trimmed;
  }

  static List<int> _parseVersionParts(String value) {
    final numeric = value.split('+').first;
    return numeric
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }

  static Future<Map<String, dynamic>?> _fetchJson(String url) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'MClaw-App');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }
}
