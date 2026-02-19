import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

/// SSH 配置读取和修复服务
/// 用于 SSH 登录服务器并读取/修复 OpenClaw 配置文件
class SshConfigService {
  /// 检测 Gateway 配置（包括 CORS 设置）
  static Future<Map<String, dynamic>> detectGatewayConfig({
    required String host,
    int port = 22,
    required String username,
    required String password,
  }) async {
    SSHClient? client;
    
    try {
      // 1. 建立 SSH 连接
      final socket = await SSHSocket.connect(host, port);
      
      client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );

      await client.authenticated;

      // 2. 读取配置文件
      String? configContent;
      String configPath = '/root/.openclaw/openclaw.json';
      
      try {
        configContent = await _readFile(client, configPath);
      } catch (e) {
        // 尝试其他路径
        try {
          configPath = '/home/$username/.openclaw/openclaw.json';
          configContent = await _readFile(client, configPath);
        } catch (e2) {
          print('无法读取配置文件: $e2');
          return {
            'success': false,
            'error': '无法读取服务器配置文件',
            'configPath': configPath,
          };
        }
      }

      if (configContent == null || configContent.isEmpty) {
        return {
          'success': false,
          'error': '配置文件为空',
          'configPath': configPath,
        };
      }

      // 3. 解析配置
      final config = jsonDecode(configContent);
      final gatewayConfig = config['gateway'];
      
      if (gatewayConfig == null) {
        return {
          'success': false,
          'error': '配置文件中缺少 gateway 配置',
          'configPath': configPath,
        };
      }

      // 4. 提取关键信息
      final result = <String, dynamic>{
        'success': true,
        'configPath': configPath,
        'port': gatewayConfig['port'] ?? 18789,
        'bind': gatewayConfig['bind'] ?? 'loopback',
        'hasCorsConfig': false,
        'needsCorsFix': false,
      };

      // 检查 CORS 配置 - 根据错误信息，检查 allowedOrigins
      final controlUi = gatewayConfig['controlUi'];
      if (controlUi != null) {
        // 检查 allowInsecureAuth
        result['allowInsecureAuth'] = controlUi['allowInsecureAuth'] ?? false;
        
        // 检查 allowedOrigins（根据错误提示，这是实际存在的配置）
        final allowedOrigins = controlUi['allowedOrigins'];
        if (allowedOrigins != null && allowedOrigins is List && allowedOrigins.isNotEmpty) {
          result['hasCorsConfig'] = true;
          result['allowedOrigins'] = allowedOrigins;
          
          // 检查是否包含通配符或本地地址
          final origins = allowedOrigins.cast<String>();
          if (origins.contains('*') || 
              origins.any((o) => o.contains('localhost') || o.contains('127.0.0.1'))) {
            result['needsCorsFix'] = false;
          } else {
            result['needsCorsFix'] = true;
            result['corsIssue'] = 'allowedOrigins 不包含本地地址，需要添加 * 通配符';
          }
        } else {
          // allowedOrigins 为空或未配置
          result['needsCorsFix'] = true;
          result['corsIssue'] = '缺少 allowedOrigins 配置，WebSocket 连接会被拒绝';
        }
        
        // 检查 scope 权限问题
        if (controlUi['allowInsecureAuth'] != true) {
          result['needsScopeFix'] = true;
          result['scopeIssue'] = '需要设置 allowInsecureAuth: true 以获得完整权限';
        }
      } else {
        // 缺少整个 controlUi 配置
        result['needsCorsFix'] = true;
        result['needsScopeFix'] = true;
        result['corsIssue'] = '缺少 controlUi 配置节';
        result['scopeIssue'] = '需要设置 allowInsecureAuth: true 以获得完整权限';
      }

      // 提取 Token
      final authConfig = gatewayConfig['auth'];
      if (authConfig != null) {
        result['token'] = authConfig['token'];
        result['authMode'] = authConfig['mode'] ?? 'token';
      }

      return result;
      
    } catch (e) {
      print('SSH 配置检测失败: $e');
      return {
        'success': false,
        'error': '连接失败: $e',
      };
    } finally {
      client?.close();
    }
  }

  /// 读取完整的服务器配置
  static Future<Map<String, dynamic>> readFullConfig({
    required String host,
    int port = 22,
    required String username,
    required String password,
    required String configPath,
  }) async {
    SSHClient? client;
    
    try {
      final socket = await SSHSocket.connect(host, port);
      
      client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );

      await client.authenticated;

      final content = await _readFile(client, configPath);
      return jsonDecode(content) as Map<String, dynamic>;
      
    } catch (e) {
      print('读取完整配置失败: $e');
      throw Exception('无法读取完整配置: $e');
    } finally {
      client?.close();
    }
  }
  static Future<Map<String, dynamic>> fixCorsConfig({
    required String host,
    int port = 22,
    required String username,
    required String password,
    required String configPath,
    required Map<String, dynamic> currentConfig,
  }) async {
    SSHClient? client;
    
    try {
      // 1. 建立 SSH 连接
      final socket = await SSHSocket.connect(host, port);
      
      client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );

      await client.authenticated;

      // 2. 修改配置
      final gatewayConfig = currentConfig['gateway'];
      if (gatewayConfig == null) {
        return {'success': false, 'error': '配置结构错误'};
      }

      // 确保 controlUi 存在
      if (!gatewayConfig.containsKey('controlUi')) {
        gatewayConfig['controlUi'] = {};
      }

      // 设置 allowedOrigins
      gatewayConfig['controlUi']['allowedOrigins'] = [
        '*',  // 允许所有来源（开发环境）
      ];
      
      // 设置 allowInsecureAuth - 允许无设备身份的连接使用完整权限
      gatewayConfig['controlUi']['allowInsecureAuth'] = true;

      // 3. 备份原配置
      final backupPath = '$configPath.backup.${DateTime.now().millisecondsSinceEpoch}';
      await _executeCommand(client, 'cp $configPath $backupPath');

      // 4. 写入新配置
      final newConfigJson = jsonEncode(currentConfig);
      await _writeFile(client, configPath, newConfigJson);

      // 5. 验证写入
      final verifyContent = await _readFile(client, configPath);
      final verifyConfig = jsonDecode(verifyContent);
      
      final verifyControlUi = verifyConfig['gateway']?['controlUi'];
      if (verifyControlUi?['allowedOrigins'] != null && verifyControlUi?['allowInsecureAuth'] == true) {
        return {
          'success': true,
          'message': '配置已修复（CORS 和权限）',
          'backupPath': backupPath,
          'allowedOrigins': verifyControlUi['allowedOrigins'],
          'allowInsecureAuth': verifyControlUi['allowInsecureAuth'],
        };
      } else {
        return {
          'success': false,
          'error': '配置写入验证失败',
        };
      }
      
    } catch (e) {
      print('修复 CORS 配置失败: $e');
      return {
        'success': false,
        'error': '修复失败: $e',
      };
    } finally {
      client?.close();
    }
  }

  /// 通过 SFTP 读取远程文件
  static Future<String> _readFile(SSHClient client, String remotePath) async {
    try {
      final sftp = await client.sftp();
      final file = await sftp.open(remotePath);
      final content = await file.readBytes();
      await file.close();
      
      return utf8.decode(content);
    } catch (e) {
      throw Exception('无法读取文件 $remotePath: $e');
    }
  }

  /// 通过 SFTP 写入远程文件
  static Future<void> _writeFile(SSHClient client, String remotePath, String content) async {
    try {
      final sftp = await client.sftp();
      final file = await sftp.open(
        remotePath,
        mode: SftpFileOpenMode.create | SftpFileOpenMode.truncate | SftpFileOpenMode.write,
      );
      
      final bytes = utf8.encode(content);
      await file.writeBytes(bytes);
      await file.close();
    } catch (e) {
      throw Exception('无法写入文件 $remotePath: $e');
    }
  }

  /// 执行远程命令
  static Future<String> _executeCommand(SSHClient client, String command) async {
    try {
      final session = await client.execute(command);
      final output = await session.stdout.toList();
      await session.done;
      
      return output.map((e) => utf8.decode(e)).join();
    } catch (e) {
      throw Exception('命令执行失败: $e');
    }
  }

  /// 重启 Gateway 服务
  static Future<Map<String, dynamic>> restartGateway({
    required String host,
    int port = 22,
    required String username,
    required String password,
  }) async {
    SSHClient? client;
    
    try {
      final socket = await SSHSocket.connect(host, port);
      
      client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );

      await client.authenticated;

      // 尝试多种重启方式
      String? restartOutput;
      bool restarted = false;

      // 方式1: systemctl restart openclaw
      try {
        restartOutput = await _executeCommand(client, 'systemctl restart openclaw 2>&1 || echo "SYSTEMCTL_FAILED"');
        if (!restartOutput.contains('SYSTEMCTL_FAILED') && !restartOutput.contains('not found')) {
          restarted = true;
        }
      } catch (e) {
        // 忽略错误，尝试下一种方式
      }

      // 方式2: pkill && 重启
      if (!restarted) {
        try {
          await _executeCommand(client, 'pkill -f "openclaw gateway" || true');
          await Future.delayed(const Duration(seconds: 1));
          await _executeCommand(client, 'nohup openclaw gateway > /dev/null 2>&1 &');
          restarted = true;
        } catch (e) {
          // 忽略错误
        }
      }

      if (restarted) {
        // 等待服务重启
        await Future.delayed(const Duration(seconds: 2));
        return {
          'success': true,
          'message': 'Gateway 服务已重启',
        };
      } else {
        return {
          'success': false,
          'error': '无法重启 Gateway 服务，请手动重启',
        };
      }
      
    } catch (e) {
      print('重启 Gateway 失败: $e');
      return {
        'success': false,
        'error': '重启失败: $e',
      };
    } finally {
      client?.close();
    }
  }

  /// 测试 SSH 连接
  static Future<bool> testConnection({
    required String host,
    int port = 22,
    required String username,
    required String password,
  }) async {
    SSHClient? client;
    
    try {
      final socket = await SSHSocket.connect(host, port);
      
      client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );

      await client.authenticated;
      return true;
      
    } catch (e) {
      print('SSH 连接测试失败: $e');
      return false;
    } finally {
      client?.close();
    }
  }
}
