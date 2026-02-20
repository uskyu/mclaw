import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/server.dart';
import '../services/secure_storage_service.dart';
import 'ssh_tunnel_service.dart';
import 'gateway_protocol_service.dart';

/// 完整连接状态
enum ConnectionStatus {
  disconnected,
  sshConnecting,
  sshConnected,
  wsConnecting,
  wsConnected,
  handshaking,
  connected,
  error,
}

/// OpenClaw Gateway 主服务
class GatewayService extends ChangeNotifier {
  final SshTunnelService _sshService = SshTunnelService();
  final GatewayProtocolService _protocolService = GatewayProtocolService();
  
  Server? _currentServer;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _errorMessage;
  StreamSubscription? _sshSubscription;
  StreamSubscription? _chatSubscription;
  StreamSubscription? _agentSubscription;
  
  // 当前运行的 runId
  String? _currentRunId;

  // Getters
  ConnectionStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _status == ConnectionStatus.connected;
  Server? get currentServer => _currentServer;
  String? get currentRunId => _currentRunId;
  int get tickIntervalMs => _protocolService.tickIntervalMs;
  
  // 事件流
  Stream<ChatEventPayload> get chatEventStream => _protocolService.chatEventStream;
  Stream<AgentEventPayload> get agentEventStream => _protocolService.agentEventStream;

  /// 连接到服务器
  Future<bool> connect(Server server) async {
    try {
      if (server.sshHost == null || server.sshHost!.isEmpty) {
        throw Exception('SSH 主机地址不能为空');
      }
      if (server.sshUsername == null || server.sshUsername!.isEmpty) {
        throw Exception('SSH 用户名不能为空');
      }
      if (server.gatewayToken == null || server.gatewayToken!.isEmpty) {
        throw Exception('Gateway Token 不能为空');
      }

      final preparedServer = await _ensureDeviceIdentity(server);
      _currentServer = preparedServer;
      _errorMessage = null;
      _updateStatus(ConnectionStatus.sshConnecting);

      await _sshService.connect(
        host: preparedServer.sshHost!,
        port: preparedServer.sshPort ?? 22,
        username: preparedServer.sshUsername!,
        password: preparedServer.sshPassword ?? '',
        localPort: preparedServer.localPort ?? 18789,
        remoteHost: preparedServer.remoteHost ?? '127.0.0.1',
        remotePort: preparedServer.remotePort ?? 18789,
      );

      await _waitForSshForwarding();
      _updateStatus(ConnectionStatus.sshConnected);

      _updateStatus(ConnectionStatus.wsConnecting);
      final actualLocalPort = _sshService.localPort ?? (preparedServer.localPort ?? 18789);
      final wsUrl = 'ws://127.0.0.1:$actualLocalPort';
      print('连接 WebSocket: $wsUrl');
      await _protocolService.connect(wsUrl);
      _updateStatus(ConnectionStatus.wsConnected);

      _updateStatus(ConnectionStatus.handshaking);
      final success = await _protocolService.handshake(
        clientId: preparedServer.clientId ?? 'openclaw-control-ui',
        clientVersion: '1.0.0',
        platform: preparedServer.platform ?? 'android',
        mode: preparedServer.clientMode ?? 'ui',
        token: preparedServer.gatewayToken!,
        locale: preparedServer.locale ?? 'zh-CN',
        deviceToken: preparedServer.deviceToken,
      );

      if (success) {
        await _persistDeviceTokenIfNeeded(preparedServer);
        _updateStatus(ConnectionStatus.connected);
        _startListeningToEvents();
        return true;
      } else {
        _errorMessage = _protocolService.lastError ?? '握手失败';
        _updateStatus(ConnectionStatus.error);
        return false;
      }

    } catch (e) {
      _errorMessage = e.toString();
      _updateStatus(ConnectionStatus.error);
      return false;
    }
  }

  /// 断开连接
  Future<Server> _ensureDeviceIdentity(Server server) async {
    final deviceId = (server.deviceId != null && server.deviceId!.isNotEmpty)
        ? server.deviceId
        : 'clawchat-${server.id}';
    final deviceName = (server.deviceName != null && server.deviceName!.isNotEmpty)
        ? server.deviceName
        : 'ClawChat ${server.name}';

    if (deviceId == server.deviceId && deviceName == server.deviceName) {
      return server;
    }

    final updated = server.copyWith(deviceId: deviceId, deviceName: deviceName);
    await SecureStorageService.upsertServer(updated);
    return updated;
  }

  Future<void> _persistDeviceTokenIfNeeded(Server server) async {
    final newDeviceToken = _protocolService.deviceToken;
    if (newDeviceToken == null || newDeviceToken.isEmpty) return;
    if (newDeviceToken == server.deviceToken) return;

    final updated = server.copyWith(deviceToken: newDeviceToken);
    _currentServer = updated;
    await SecureStorageService.upsertServer(updated);
  }

  /// Disconnect
  Future<void> disconnect() async {
    await _chatSubscription?.cancel();
    await _agentSubscription?.cancel();
    await _sshSubscription?.cancel();
    _chatSubscription = null;
    _agentSubscription = null;
    _sshSubscription = null;
    
    await _protocolService.disconnect();
    await _sshService.disconnect();
    _currentServer = null;
    _errorMessage = null;
    _currentRunId = null;
    _updateStatus(ConnectionStatus.disconnected);
  }

  /// 发送聊天消息
  Future<ChatSendResult> sendMessage(String message, {String sessionKey = 'main'}) async {
    if (!isConnected) {
      return ChatSendResult(errorMessage: '未连接到服务器');
    }
    
    final result = await _protocolService.chatSend(message, sessionKey);
    if (result.isSuccess && result.response != null) {
      _currentRunId = result.response!.runId;
    }
    return result;
  }

  /// 获取聊天历史
  Future<List<Map<String, dynamic>>> getChatHistory({String sessionKey = 'main'}) async {
    if (!isConnected) return [];
    return await _protocolService.chatHistory(sessionKey);
  }
  
  /// 健康检查
  Future<bool> healthCheck({int timeoutMs = 5000}) async {
    if (!isConnected) return false;
    return await _protocolService.health(timeoutMs: timeoutMs);
  }

  /// 等待 SSH 转发就绪
  Future<void> _waitForSshForwarding() async {
    if (_sshService.currentState == SshConnectionState.forwarding) return;
    
    await for (final state in _sshService.stateStream) {
      if (state == SshConnectionState.forwarding) return;
      if (state == SshConnectionState.error) {
        throw Exception(_sshService.lastError ?? 'SSH 连接失败');
      }
    }
  }

  /// 开始监听 Gateway 事件
  void _startListeningToEvents() {
    _chatSubscription = _protocolService.chatEventStream.listen((event) {
      if (event.state == 'final' || event.state == 'aborted' || event.state == 'error') {
        _currentRunId = null;
      }
      notifyListeners();
    });
    
    _agentSubscription = _protocolService.agentEventStream.listen((event) {
      notifyListeners();
    });
  }

  void _updateStatus(ConnectionStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _sshService.dispose();
    _protocolService.dispose();
    super.dispose();
  }
}
