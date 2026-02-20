/// 服务器类型
enum ServerType { openai, openclaw }

/// OpenClaw Gateway 连接模式
enum GatewayConnectionMode { sshTunnel, direct }

/// 服务器配置模型
class Server {
  final String id;
  final String name;
  final ServerType type;
  final bool isActive;

  // OpenAI 类型字段
  final String? apiUrl;
  final String? apiKey;
  final String? model;

  // OpenClaw Gateway 字段
  final String? sshHost;
  final int? sshPort;
  final String? sshUsername;
  final String? sshPassword;

  // Gateway 端口配置（可自动获取或手动设置）
  final int? remotePort; // Gateway 在远程服务器上的端口（默认 18789）
  final int? localPort; // 本地转发端口（默认 18789）
  final String? remoteHost; // Gateway 绑定的远程地址（默认 127.0.0.1）

  // Gateway 认证
  final String? gatewayToken;
  final String? deviceId;
  final String? deviceName;
  final String? deviceToken;

  // 连接模式
  final GatewayConnectionMode connectionMode;
  final String? gatewayUrl;

  // 客户端配置
  final String? clientId; // 如 'openclaw-control-ui', 'cli'
  final String? clientMode; // 如 'ui', 'cli'
  final String? platform; // 如 'android', 'ios'
  final String? locale; // 如 'zh-CN', 'en-US'

  Server({
    required this.id,
    required this.name,
    required this.type,
    this.isActive = false,
    // OpenAI
    this.apiUrl,
    this.apiKey,
    this.model,
    // OpenClaw SSH
    this.sshHost,
    this.sshPort = 22,
    this.sshUsername,
    this.sshPassword,
    // OpenClaw Gateway
    this.remotePort = 18789,
    this.localPort = 18789,
    this.remoteHost = '127.0.0.1',
    this.gatewayToken,
    this.deviceId,
    this.deviceName,
    this.deviceToken,
    this.connectionMode = GatewayConnectionMode.sshTunnel,
    this.gatewayUrl,
    // Client config
    this.clientId = 'openclaw-control-ui',
    this.clientMode = 'ui',
    this.platform = 'android',
    this.locale = 'zh-CN',
  });

  /// 创建 OpenClaw Gateway 服务器
  factory Server.openclaw({
    required String id,
    required String name,
    bool isActive = false,
    required String sshHost,
    int sshPort = 22,
    required String sshUsername,
    required String sshPassword,
    int? remotePort,
    int? localPort,
    String? gatewayToken,
    String? clientId,
    String? clientMode,
    String? deviceId,
    String? deviceName,
    String? deviceToken,
    GatewayConnectionMode connectionMode = GatewayConnectionMode.sshTunnel,
    String? gatewayUrl,
  }) {
    return Server(
      id: id,
      name: name,
      type: ServerType.openclaw,
      isActive: isActive,
      sshHost: sshHost,
      sshPort: sshPort,
      sshUsername: sshUsername,
      sshPassword: sshPassword,
      remotePort: remotePort ?? 18789,
      localPort: localPort ?? 18789,
      gatewayToken: gatewayToken,
      clientId: clientId ?? 'openclaw-control-ui',
      clientMode: clientMode ?? 'ui',
      deviceId: deviceId,
      deviceName: deviceName,
      deviceToken: deviceToken,
      connectionMode: connectionMode,
      gatewayUrl: gatewayUrl,
    );
  }

  /// 创建 OpenAI 服务器
  factory Server.openai({
    required String id,
    required String name,
    bool isActive = false,
    required String apiUrl,
    required String apiKey,
    required String model,
  }) {
    return Server(
      id: id,
      name: name,
      type: ServerType.openai,
      isActive: isActive,
      apiUrl: apiUrl,
      apiKey: apiKey,
      model: model,
    );
  }

  Server copyWith({
    String? id,
    String? name,
    ServerType? type,
    bool? isActive,
    String? apiUrl,
    String? apiKey,
    String? model,
    String? sshHost,
    int? sshPort,
    String? sshUsername,
    String? sshPassword,
    int? remotePort,
    int? localPort,
    String? remoteHost,
    String? gatewayToken,
    String? clientId,
    String? clientMode,
    String? platform,
    String? locale,
    String? deviceId,
    String? deviceName,
    String? deviceToken,
    GatewayConnectionMode? connectionMode,
    String? gatewayUrl,
  }) {
    return Server(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      sshHost: sshHost ?? this.sshHost,
      sshPort: sshPort ?? this.sshPort,
      sshUsername: sshUsername ?? this.sshUsername,
      sshPassword: sshPassword ?? this.sshPassword,
      remotePort: remotePort ?? this.remotePort,
      localPort: localPort ?? this.localPort,
      remoteHost: remoteHost ?? this.remoteHost,
      gatewayToken: gatewayToken ?? this.gatewayToken,
      clientId: clientId ?? this.clientId,
      clientMode: clientMode ?? this.clientMode,
      platform: platform ?? this.platform,
      locale: locale ?? this.locale,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceToken: deviceToken ?? this.deviceToken,
      connectionMode: connectionMode ?? this.connectionMode,
      gatewayUrl: gatewayUrl ?? this.gatewayUrl,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'isActive': isActive,
      'apiUrl': apiUrl,
      'apiKey': apiKey,
      'model': model,
      'sshHost': sshHost,
      'sshPort': sshPort,
      'sshUsername': sshUsername,
      'sshPassword': sshPassword,
      'remotePort': remotePort,
      'localPort': localPort,
      'remoteHost': remoteHost,
      'gatewayToken': gatewayToken,
      'clientId': clientId,
      'clientMode': clientMode,
      'platform': platform,
      'locale': locale,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'deviceToken': deviceToken,
      'connectionMode': connectionMode.toString().split('.').last,
      'gatewayUrl': gatewayUrl,
    };
  }

  /// 从 JSON 创建
  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      id: json['id'] as String,
      name: json['name'] as String,
      type: ServerType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => ServerType.openai,
      ),
      isActive: json['isActive'] as bool? ?? false,
      apiUrl: json['apiUrl'] as String?,
      apiKey: json['apiKey'] as String?,
      model: json['model'] as String?,
      sshHost: json['sshHost'] as String?,
      sshPort: json['sshPort'] as int? ?? 22,
      sshUsername: json['sshUsername'] as String?,
      sshPassword: json['sshPassword'] as String?,
      remotePort: json['remotePort'] as int? ?? 18789,
      localPort: json['localPort'] as int? ?? 18789,
      remoteHost: json['remoteHost'] as String? ?? '127.0.0.1',
      gatewayToken: json['gatewayToken'] as String?,
      clientId: 'openclaw-control-ui', // 强制使用正确的 clientId
      clientMode: json['clientMode'] as String? ?? 'ui',
      platform: json['platform'] as String? ?? 'android',
      locale: json['locale'] as String? ?? 'zh-CN',
      deviceId: json['deviceId'] as String?,
      deviceName: json['deviceName'] as String?,
      deviceToken: json['deviceToken'] as String?,
      connectionMode: GatewayConnectionMode.values.firstWhere(
        (e) => e.toString().split('.').last == json['connectionMode'],
        orElse: () => GatewayConnectionMode.sshTunnel,
      ),
      gatewayUrl: json['gatewayUrl'] as String?,
    );
  }
}
