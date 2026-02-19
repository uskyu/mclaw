import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/server.dart';
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
/// 整合 SSH 隧道和 WebSocket 协议
class GatewayService extends ChangeNotifier {
  final SshTunnelService _sshService = SshTunnelService();
  final GatewayProtocolService _protocolService = GatewayProtocolService();
  
  Server? _currentServer;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _errorMessage;
  StreamSubscription? _sshSubscription;
  StreamSubscription? _messageSubscription;

  // Getters
  ConnectionStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _status == ConnectionStatus.connected;
  Server? get currentServer => _currentServer;

  /// 连接到服务器
  Future<bool> connect(Server server) async {
    try {
      // 验证必需字段
      if (server.sshHost == null || server.sshHost!.isEmpty) {
        throw Exception('SSH 主机地址不能为空');
      }
      if (server.sshUsername == null || server.sshUsername!.isEmpty) {
        throw Exception('SSH 用户名不能为空');
      }
      if (server.gatewayToken == null || server.gatewayToken!.isEmpty) {
        throw Exception('Gateway Token 不能为空');
      }

      _currentServer = server;
      _errorMessage = null;
      _updateStatus(ConnectionStatus.sshConnecting);

      // 1. 建立 SSH 隧道
      await _sshService.connect(
        host: server.sshHost!,
        port: server.sshPort ?? 22,
        username: server.sshUsername!,
        password: server.sshPassword ?? '',
        localPort: server.localPort ?? 18789,
        remoteHost: server.remoteHost ?? '127.0.0.1',
        remotePort: server.remotePort ?? 18789,
      );

      // 等待 SSH 转发就绪
      await _waitForSshForwarding();
      _updateStatus(ConnectionStatus.sshConnected);

      // 2. 连接 WebSocket（使用 SSH 隧道实际绑定的端口）
      _updateStatus(ConnectionStatus.wsConnecting);
      final actualLocalPort = _sshService.localPort ?? (server.localPort ?? 18789);
      final wsUrl = 'ws://127.0.0.1:$actualLocalPort';
      print('连接 WebSocket: $wsUrl');
      await _protocolService.connect(wsUrl);
      _updateStatus(ConnectionStatus.wsConnected);

      // 3. 协议握手
      _updateStatus(ConnectionStatus.handshaking);
      final success = await _protocolService.handshake(
        clientId: server.clientId ?? 'webchat-ui',
        clientVersion: '1.0.0',
        platform: server.platform ?? 'android',
        mode: server.clientMode ?? 'ui',
        token: server.gatewayToken!,
        locale: server.locale ?? 'zh-CN',
      );

      if (success) {
        _updateStatus(ConnectionStatus.connected);
        _startListeningToMessages();
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
  Future<void> disconnect() async {
    await _messageSubscription?.cancel();
    await _sshSubscription?.cancel();
    await _protocolService.disconnect();
    await _sshService.disconnect();
    _currentServer = null;
    _errorMessage = null;
    _updateStatus(ConnectionStatus.disconnected);
  }

  /// 发送聊天消息
  Future<bool> sendMessage(String message, {String sessionKey = 'main'}) async {
    if (!isConnected) return false;
    return await _protocolService.chatSend(message, sessionKey);
  }

  /// 获取聊天历史
  Future<List<Map<String, dynamic>>> getChatHistory({String sessionKey = 'main'}) async {
    if (!isConnected) return [];
    return await _protocolService.chatHistory(sessionKey);
  }

  /// 监听消息流
  Stream<GatewayMessage> get messageStream => _protocolService.messageStream;

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

  /// 开始监听 Gateway 消息
  void _startListeningToMessages() {
    _messageSubscription = _protocolService.messageStream.listen((message) {
      // 处理消息事件
      if (message.event == 'chat') {
        // 触发聊天消息更新
        notifyListeners();
      } else if (message.event == 'agent') {
        // 处理代理事件
        notifyListeners();
      }
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
