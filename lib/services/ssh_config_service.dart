import 'dart:async';
import 'dart:convert';
import 'dart:math';
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

      if (configContent.isEmpty) {
        return {'success': false, 'error': '配置文件为空', 'configPath': configPath};
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
        if (allowedOrigins != null &&
            allowedOrigins is List &&
            allowedOrigins.isNotEmpty) {
          result['hasCorsConfig'] = true;
          result['allowedOrigins'] = allowedOrigins;

          // 检查是否包含通配符或本地地址
          final origins = allowedOrigins.cast<String>();
          if (origins.contains('*') ||
              origins.any(
                (o) => o.contains('localhost') || o.contains('127.0.0.1'),
              )) {
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

      final detectedToken = result['token']?.toString().trim() ?? '';
      if (detectedToken.isNotEmpty) {
        result['directGatewayUrl'] = 'ws://$host:${result['port'] ?? 18789}';
      }
      result['isDirectReady'] =
          detectedToken.isNotEmpty &&
          result['bind'] == 'loopback' &&
          result['allowInsecureAuth'] == true;

      return result;
    } catch (e) {
      print('SSH 配置检测失败: $e');
      return {'success': false, 'error': '连接失败: $e'};
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
        '*', // 允许所有来源（开发环境）
      ];

      // 设置 allowInsecureAuth - 允许无设备身份的连接使用完整权限
      gatewayConfig['controlUi']['allowInsecureAuth'] = true;

      // 3. 备份原配置
      final backupPath =
          '$configPath.backup.${DateTime.now().millisecondsSinceEpoch}';
      await _executeCommand(client, 'cp $configPath $backupPath');

      // 4. 写入新配置
      final newConfigJson = jsonEncode(currentConfig);
      await _writeFile(client, configPath, newConfigJson);

      // 5. 验证写入
      final verifyContent = await _readFile(client, configPath);
      final verifyConfig = jsonDecode(verifyContent);

      final verifyControlUi = verifyConfig['gateway']?['controlUi'];
      if (verifyControlUi?['allowedOrigins'] != null &&
          verifyControlUi?['allowInsecureAuth'] == true) {
        return {
          'success': true,
          'message': '配置已修复（CORS 和权限）',
          'backupPath': backupPath,
          'allowedOrigins': verifyControlUi['allowedOrigins'],
          'allowInsecureAuth': verifyControlUi['allowInsecureAuth'],
        };
      } else {
        return {'success': false, 'error': '配置写入验证失败'};
      }
    } catch (e) {
      print('修复 CORS 配置失败: $e');
      return {'success': false, 'error': '修复失败: $e'};
    } finally {
      client?.close();
    }
  }

  /// 一键部署直连模式（支持可选 WSS 反向代理）
  static Future<Map<String, dynamic>> deployDirectAccess({
    required String host,
    int port = 22,
    required String username,
    required String password,
    int gatewayPort = 18789,
    String? publicDomain,
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

      final configPath = await _resolveConfigPath(client, username);

      Map<String, dynamic> config;
      try {
        final raw = await _readFile(client, configPath);
        config = raw.trim().isEmpty
            ? <String, dynamic>{}
            : jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        config = <String, dynamic>{};
      }

      final gateway =
          (config['gateway'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final auth =
          (gateway['auth'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final controlUi =
          (gateway['controlUi'] as Map<String, dynamic>?) ??
          <String, dynamic>{};

      final trimmedDomain = publicDomain?.trim() ?? '';
      final existing = await _detectExistingDirectSetup(
        client: client,
        host: host,
        gatewayPort: gatewayPort,
        preferredDomain: trimmedDomain.isEmpty ? null : trimmedDomain,
        gateway: gateway,
        auth: auth,
        controlUi: controlUi,
      );
      if (existing['installed'] == true && trimmedDomain.isEmpty) {
        return {
          'success': true,
          'reused': true,
          'mode': existing['mode'] ?? 'direct-ws',
          'gatewayUrl': existing['gatewayUrl'],
          'gatewayToken': existing['gatewayToken'],
          'configPath': configPath,
          'backupPath': null,
          'note': '检测到服务器已完成直连部署，已直接复用现有配置',
        };
      }
      if (existing['installed'] == true &&
          trimmedDomain.isNotEmpty &&
          existing['wssReadyForPreferredDomain'] == true) {
        return {
          'success': true,
          'reused': true,
          'mode': 'wss',
          'gatewayUrl': 'wss://$trimmedDomain',
          'gatewayToken': existing['gatewayToken'],
          'configPath': configPath,
          'backupPath': null,
          'note': '检测到 $trimmedDomain 已部署 WSS，已直接复用',
        };
      }

      final alreadyInstalled = existing['installed'] == true;
      final existingToken = (existing['gatewayToken'] as String?)?.trim();

      final token = (auth['token'] as String?)?.trim().isNotEmpty == true
          ? (auth['token'] as String)
          : (existingToken?.isNotEmpty == true
                ? existingToken!
                : _generateGatewayToken());

      String? backupPath;
      if (!alreadyInstalled) {
        auth['mode'] = 'token';
        auth['token'] = token;
        gateway['auth'] = auth;
        gateway['bind'] = 'loopback';
        gateway['port'] = gatewayPort;

        controlUi['allowedOrigins'] = ['*'];
        controlUi['allowInsecureAuth'] = true;
        gateway['controlUi'] = controlUi;
        config['gateway'] = gateway;

        backupPath =
            '$configPath.backup.${DateTime.now().millisecondsSinceEpoch}';
        await _executeCommand(
          client,
          'cp $configPath $backupPath 2>/dev/null || true',
        );
        await _writeFile(client, configPath, jsonEncode(config));

        final restart = await _restartGatewayViaExistingSession(client);
        if (!restart) {
          return {
            'success': false,
            'error': 'Gateway 配置已写入，但重启失败，请手动执行 systemctl restart openclaw',
            'configPath': configPath,
            'backupPath': backupPath,
          };
        }
      }

      if (trimmedDomain.isNotEmpty) {
        final proxy = await _setupCaddyProxy(
          client: client,
          domain: trimmedDomain,
          gatewayPort: gatewayPort,
        );

        if (proxy['success'] == true) {
          return {
            'success': true,
            'mode': 'wss',
            'gatewayUrl': 'wss://$trimmedDomain',
            'gatewayToken': token,
            'configPath': configPath,
            'backupPath': backupPath,
            'reused': alreadyInstalled,
            'note': '已部署 WSS 反向代理，移动端可直接直连',
          };
        }

        return {
          'success': true,
          'mode': 'direct-ws-fallback',
          'gatewayUrl': 'ws://$host:$gatewayPort',
          'gatewayToken': token,
          'configPath': configPath,
          'backupPath': backupPath,
          'reused': alreadyInstalled,
          'warning': proxy['error'] ?? 'WSS 部署失败，已回退到 WS 直连',
        };
      }

      return {
        'success': true,
        'mode': 'direct-ws',
        'gatewayUrl': 'ws://$host:$gatewayPort',
        'gatewayToken': token,
        'configPath': configPath,
        'backupPath': backupPath,
        'reused': alreadyInstalled,
        'note': '已启用直连模式（无 WSS），建议后续配置域名启用 TLS',
      };
    } catch (e) {
      return {'success': false, 'error': '一键部署失败: $e'};
    } finally {
      client?.close();
    }
  }

  static Future<String> _resolveConfigPath(
    SSHClient client,
    String username,
  ) async {
    final cmd =
        'if [ -f /root/.openclaw/openclaw.json ]; then echo /root/.openclaw/openclaw.json; '
        'elif [ -f /home/$username/.openclaw/openclaw.json ]; then echo /home/$username/.openclaw/openclaw.json; '
        'else echo /home/$username/.openclaw/openclaw.json; fi';
    final rawPath = (await _executeCommand(client, cmd)).trim();
    final path = rawPath.isNotEmpty
        ? rawPath
        : '/home/$username/.openclaw/openclaw.json';
    final parent = path.substring(0, path.lastIndexOf('/'));
    await _executeCommand(client, 'mkdir -p $parent');
    await _executeCommand(client, 'test -f $path || printf "{}" > $path');
    return path;
  }

  static String _generateGatewayToken() {
    const chars = 'abcdef0123456789';
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 48; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  static Future<Map<String, dynamic>> _detectExistingDirectSetup({
    required SSHClient client,
    required String host,
    required int gatewayPort,
    required Map<String, dynamic> gateway,
    required Map<String, dynamic> auth,
    required Map<String, dynamic> controlUi,
    String? preferredDomain,
  }) async {
    final token = (auth['token'] as String?)?.trim() ?? '';
    final bind =
        (gateway['bind'] as String?)?.trim().toLowerCase() ?? 'loopback';
    final mode = (auth['mode'] as String?)?.trim().toLowerCase() ?? 'token';
    final allowInsecureAuth = controlUi['allowInsecureAuth'] == true;
    final hasWildcard = _hasWildcardOrigin(controlUi['allowedOrigins']);

    final installed =
        token.isNotEmpty &&
        mode == 'token' &&
        bind == 'loopback' &&
        allowInsecureAuth &&
        hasWildcard;
    if (!installed) {
      return {'installed': false, 'gatewayToken': token};
    }

    String? selectedWssDomain;
    bool caddyActive = false;
    try {
      final caddyFile = await _executeCommand(
        client,
        'test -f /etc/caddy/Caddyfile && cat /etc/caddy/Caddyfile || true',
      );
      if (caddyFile.trim().isNotEmpty) {
        final domains = _extractCaddyDomainsForPort(caddyFile, gatewayPort);
        if (domains.isNotEmpty) {
          final active = await _executeCommand(
            client,
            'systemctl is-active caddy 2>/dev/null || true',
          );
          caddyActive = active.contains('active');
          if (caddyActive) {
            if (preferredDomain != null && preferredDomain.isNotEmpty) {
              if (domains.contains(preferredDomain)) {
                selectedWssDomain = preferredDomain;
              }
            } else {
              selectedWssDomain = domains.first;
            }
          }
        }
      }
    } catch (_) {}

    final gatewayUrl = selectedWssDomain != null
        ? 'wss://$selectedWssDomain'
        : 'ws://$host:$gatewayPort';
    return {
      'installed': true,
      'mode': selectedWssDomain != null ? 'wss' : 'direct-ws',
      'gatewayUrl': gatewayUrl,
      'gatewayToken': token,
      'wssReadyForPreferredDomain': selectedWssDomain != null,
    };
  }

  static bool _hasWildcardOrigin(dynamic allowedOrigins) {
    if (allowedOrigins is! List) {
      return false;
    }
    return allowedOrigins.any((item) => item.toString().trim() == '*');
  }

  static List<String> _extractCaddyDomainsForPort(
    String caddyFile,
    int gatewayPort,
  ) {
    final lines = caddyFile.split('\n');
    final domains = <String>[];
    String? currentDomain;
    final reverseProxy = RegExp(r'^\s*reverse_proxy\s+127\.0\.0\.1:(\d+)\s*$');
    final blockStart = RegExp(r'^\s*([A-Za-z0-9.-]+)\s*\{\s*$');

    for (final rawLine in lines) {
      final line = rawLine.trim();
      final startMatch = blockStart.firstMatch(line);
      if (startMatch != null) {
        currentDomain = startMatch.group(1);
        continue;
      }
      if (line == '}') {
        currentDomain = null;
        continue;
      }
      final proxyMatch = reverseProxy.firstMatch(rawLine);
      if (proxyMatch != null && currentDomain != null) {
        final port = int.tryParse(proxyMatch.group(1) ?? '');
        if (port == gatewayPort && !domains.contains(currentDomain)) {
          domains.add(currentDomain);
        }
      }
    }
    return domains;
  }

  static Future<bool> _restartGatewayViaExistingSession(
    SSHClient client,
  ) async {
    try {
      final out = await _executeCommand(
        client,
        'systemctl restart openclaw 2>&1 || echo __RESTART_FAILED__',
      );
      if (!out.contains('__RESTART_FAILED__')) {
        return true;
      }
    } catch (_) {}

    try {
      await _executeCommand(client, 'pkill -f "openclaw gateway" || true');
      await Future.delayed(const Duration(milliseconds: 800));
      await _executeCommand(
        client,
        'nohup openclaw gateway > /dev/null 2>&1 &',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> _setupCaddyProxy({
    required SSHClient client,
    required String domain,
    required int gatewayPort,
  }) async {
    if (!_isSafeDomain(domain)) {
      return {'success': false, 'error': '域名格式不合法: $domain'};
    }

    try {
      final sudoPrefix = await _resolveSudoPrefix(client);

      final installCommand =
          'if command -v caddy >/dev/null 2>&1; then echo CADDY_EXISTS; '
          'elif command -v apt-get >/dev/null 2>&1; then ${sudoPrefix}apt-get update -y >/dev/null 2>&1 && ${sudoPrefix}apt-get install -y caddy >/dev/null 2>&1 && echo CADDY_INSTALLED; '
          'elif command -v dnf >/dev/null 2>&1; then ${sudoPrefix}dnf install -y caddy >/dev/null 2>&1 && echo CADDY_INSTALLED; '
          'elif command -v yum >/dev/null 2>&1; then ${sudoPrefix}yum install -y caddy >/dev/null 2>&1 && echo CADDY_INSTALLED; '
          'else echo CADDY_UNSUPPORTED; fi';
      final installOut = await _executeCommand(client, installCommand);

      if (installOut.contains('CADDY_UNSUPPORTED')) {
        return {'success': false, 'error': '系统不支持自动安装 Caddy，请手动安装后重试'};
      }

      final caddyFile =
          '$domain {\n  reverse_proxy 127.0.0.1:$gatewayPort\n}\n';
      final escaped = base64Encode(utf8.encode(caddyFile));
      await _executeCommand(
        client,
        'printf "$escaped" | base64 -d | ${sudoPrefix}tee /etc/caddy/Caddyfile >/dev/null',
      );

      await _executeCommand(
        client,
        '${sudoPrefix}systemctl enable caddy >/dev/null 2>&1 || true',
      );
      final restartOut = await _executeCommand(
        client,
        '${sudoPrefix}systemctl restart caddy >/dev/null 2>&1; ${sudoPrefix}systemctl is-active caddy 2>/dev/null || true',
      );

      if (!restartOut.contains('active')) {
        return {'success': false, 'error': 'Caddy 启动失败，请检查域名解析和防火墙（80/443）'};
      }

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': '配置 Caddy 失败: $e'};
    }
  }

  static bool _isSafeDomain(String domain) {
    final pattern = RegExp(r'^[a-zA-Z0-9.-]+$');
    return pattern.hasMatch(domain) && domain.contains('.');
  }

  static Future<String> _resolveSudoPrefix(SSHClient client) async {
    final uid = (await _executeCommand(client, 'id -u')).trim();
    if (uid == '0') {
      return '';
    }

    final hasSudo = (await _executeCommand(
      client,
      'command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1 && echo YES || echo NO',
    )).trim();
    if (hasSudo == 'YES') {
      return 'sudo -n ';
    }
    throw Exception('当前用户不是 root 且不支持免密 sudo，无法自动安装 WSS 代理');
  }

  /// 清理远程会话历史（会先打包备份）
  static Future<Map<String, dynamic>> clearRemoteHistory({
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

      final backupName =
          'sessions-backup-${DateTime.now().millisecondsSinceEpoch}.tar.gz';
      final backupPath = '/tmp/$backupName';
      await _executeCommand(
        client,
        'if [ -d ~/.openclaw/agents ]; then '
        'tar -czf $backupPath ~/.openclaw/agents/*/sessions 2>/dev/null || true; '
        'rm -f ~/.openclaw/agents/*/sessions/*.jsonl ~/.openclaw/agents/*/sessions/sessions.json 2>/dev/null || true; '
        'fi',
      );

      final restartOk = await _restartGatewayViaExistingSession(client);
      return {
        'success': true,
        'backupPath': backupPath,
        'restarted': restartOk,
      };
    } catch (e) {
      return {'success': false, 'error': '清理失败: $e'};
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
  static Future<void> _writeFile(
    SSHClient client,
    String remotePath,
    String content,
  ) async {
    try {
      final sftp = await client.sftp();
      final file = await sftp.open(
        remotePath,
        mode:
            SftpFileOpenMode.create |
            SftpFileOpenMode.truncate |
            SftpFileOpenMode.write,
      );

      final bytes = utf8.encode(content);
      await file.writeBytes(bytes);
      await file.close();
    } catch (e) {
      throw Exception('无法写入文件 $remotePath: $e');
    }
  }

  /// 执行远程命令
  static Future<String> _executeCommand(
    SSHClient client,
    String command,
  ) async {
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
        restartOutput = await _executeCommand(
          client,
          'systemctl restart openclaw 2>&1 || echo "SYSTEMCTL_FAILED"',
        );
        if (!restartOutput.contains('SYSTEMCTL_FAILED') &&
            !restartOutput.contains('not found')) {
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
          await _executeCommand(
            client,
            'nohup openclaw gateway > /dev/null 2>&1 &',
          );
          restarted = true;
        } catch (e) {
          // 忽略错误
        }
      }

      if (restarted) {
        // 等待服务重启
        await Future.delayed(const Duration(seconds: 2));
        return {'success': true, 'message': 'Gateway 服务已重启'};
      } else {
        return {'success': false, 'error': '无法重启 Gateway 服务，请手动重启'};
      }
    } catch (e) {
      print('重启 Gateway 失败: $e');
      return {'success': false, 'error': '重启失败: $e'};
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
