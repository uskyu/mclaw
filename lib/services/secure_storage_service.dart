import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/server.dart';

/// 安全存储服务
/// 用于存储敏感信息（SSH 密码、Gateway Token 等）
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accountName: 'flutter_secure_storage_service'),
  );

  static const _serversKey = 'servers';
  static const _activeServerIdKey = 'active_server_id';
  static const _conversationNotesKey = 'conversation_notes';
  static const _lastSessionByServerKey = 'last_session_by_server';

  /// 保存服务器列表
  static Future<void> saveServers(List<Server> servers) async {
    final List<Map<String, dynamic>> serverList = servers
        .map((s) => s.toJson())
        .toList();
    await _storage.write(key: _serversKey, value: jsonEncode(serverList));
  }

  /// 读取服务器列表
  static Future<List<Server>> loadServers() async {
    try {
      final String? data = await _storage.read(key: _serversKey);
      if (data == null || data.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((json) => Server.fromJson(json)).toList();
    } catch (e) {
      print('加载服务器配置失败: $e');
      return [];
    }
  }

  /// 鏇存柊鍗曚釜鏈嶅姟鍣ㄩ厤缃?
  static Future<void> upsertServer(Server server) async {
    final servers = await loadServers();
    final index = servers.indexWhere((s) => s.id == server.id);
    if (index >= 0) {
      servers[index] = server;
    } else {
      servers.add(server);
    }
    await saveServers(servers);
  }

  /// 保存当前活跃的服务器 ID
  static Future<void> saveActiveServerId(String serverId) async {
    await _storage.write(key: _activeServerIdKey, value: serverId);
  }

  /// 读取当前活跃的服务器 ID
  static Future<String?> loadActiveServerId() async {
    return await _storage.read(key: _activeServerIdKey);
  }

  static Future<void> saveLastSessionForServer(
    String serverId,
    String sessionKey,
  ) async {
    if (serverId.trim().isEmpty || sessionKey.trim().isEmpty) {
      return;
    }

    final existing = await loadLastSessionMap();
    existing[serverId.trim()] = sessionKey.trim();
    await _storage.write(
      key: _lastSessionByServerKey,
      value: jsonEncode(existing),
    );
  }

  static Future<Map<String, String>> loadLastSessionMap() async {
    try {
      final raw = await _storage.read(key: _lastSessionByServerKey);
      if (raw == null || raw.trim().isEmpty) {
        return {};
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return {};
      }

      final result = <String, String>{};
      decoded.forEach((key, value) {
        final k = key.toString().trim();
        final v = value.toString().trim();
        if (k.isNotEmpty && v.isNotEmpty) {
          result[k] = v;
        }
      });
      return result;
    } catch (e) {
      print('读取上次会话映射失败: $e');
      return {};
    }
  }

  static Future<String?> loadLastSessionForServer(String serverId) async {
    if (serverId.trim().isEmpty) {
      return null;
    }
    final map = await loadLastSessionMap();
    return map[serverId.trim()];
  }

  /// 保存会话本地备注（key: normalized session key）
  static Future<void> saveConversationNotes(Map<String, String> notes) async {
    await _storage.write(key: _conversationNotesKey, value: jsonEncode(notes));
  }

  /// 读取会话本地备注
  static Future<Map<String, String>> loadConversationNotes() async {
    try {
      final data = await _storage.read(key: _conversationNotesKey);
      if (data == null || data.isEmpty) {
        return {};
      }
      final decoded = jsonDecode(data);
      if (decoded is! Map) {
        return {};
      }

      final notes = <String, String>{};
      decoded.forEach((key, value) {
        final k = key.toString().trim();
        final v = value?.toString().trim() ?? '';
        if (k.isNotEmpty && v.isNotEmpty) {
          notes[k] = v;
        }
      });
      return notes;
    } catch (e) {
      print('加载会话备注失败: $e');
      return {};
    }
  }

  /// 删除所有数据
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
