import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/server.dart';

/// 安全存储服务
/// 用于存储敏感信息（SSH 密码、Gateway Token 等）
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accountName: 'flutter_secure_storage_service',
    ),
  );

  static const _serversKey = 'servers';
  static const _activeServerIdKey = 'active_server_id';

  /// 保存服务器列表
  static Future<void> saveServers(List<Server> servers) async {
    final List<Map<String, dynamic>> serverList = 
        servers.map((s) => s.toJson()).toList();
    await _storage.write(
      key: _serversKey,
      value: jsonEncode(serverList),
    );
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

  /// 保存当前活跃的服务器 ID
  static Future<void> saveActiveServerId(String serverId) async {
    await _storage.write(key: _activeServerIdKey, value: serverId);
  }

  /// 读取当前活跃的服务器 ID
  static Future<String?> loadActiveServerId() async {
    return await _storage.read(key: _activeServerIdKey);
  }

  /// 删除所有数据
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
