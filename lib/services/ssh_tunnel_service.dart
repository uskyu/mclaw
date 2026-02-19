import 'dart:async';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

/// SSH 隧道连接状态
enum SshConnectionState {
  disconnected,
  connecting,
  connected,
  forwarding,
  error,
}

/// SSH 隧道服务
/// 负责建立 SSH 连接并创建本地端口转发
class SshTunnelService {
  SSHClient? _sshClient;
  ServerSocket? _localServer;
  final _stateController = StreamController<SshConnectionState>.broadcast();
  String? _lastError;

  Stream<SshConnectionState> get stateStream => _stateController.stream;
  SshConnectionState _currentState = SshConnectionState.disconnected;
  SshConnectionState get currentState => _currentState;
  String? get lastError => _lastError;

  /// 建立 SSH 连接并启动端口转发
  Future<void> connect({
    required String host,
    int port = 22,
    required String username,
    required String password,
    int localPort = 18789,
    String remoteHost = '127.0.0.1',
    int remotePort = 18789,
  }) async {
    try {
      _updateState(SshConnectionState.connecting);
      _lastError = null;

      // 断开已有连接
      await disconnect();
      await Future.delayed(const Duration(milliseconds: 300));

      // 建立 SSH 连接
      final socket = await SSHSocket.connect(host, port);
      
      _sshClient = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );

      await _sshClient!.authenticated;
      _updateState(SshConnectionState.connected);

      // 启动本地端口转发
      await _startPortForwarding(
        preferredPort: localPort,
        remoteHost: remoteHost,
        remotePort: remotePort,
      );

      _updateState(SshConnectionState.forwarding);
      
    } catch (e) {
      _lastError = 'SSH 连接失败: $e';
      _updateState(SshConnectionState.error);
      rethrow;
    }
  }

  /// 启动本地端口转发 - Android 必须使用 shared: true
  Future<int> _startPortForwarding({
    required int preferredPort,
    required String remoteHost,
    required int remotePort,
  }) async {
    int actualPort = preferredPort;
    
    // 尝试绑定端口 - Android 必须使用 shared: true
    try {
      _localServer = await ServerSocket.bind(
        '127.0.0.1', 
        preferredPort,
        shared: true,  // Android 必需
      );
      print('成功绑定端口: $preferredPort');
    } catch (e) {
      // 端口被占用，尝试随机端口
      print('端口 $preferredPort 被占用: $e');
      try {
        _localServer = await ServerSocket.bind(
          '127.0.0.1', 
          0,  // 随机端口
          shared: true,
        );
        actualPort = _localServer!.port;
        print('使用替代端口: $actualPort');
      } catch (e2) {
        throw Exception('无法绑定任何端口: $e2');
      }
    }
    
    // 监听连接并转发
    _localServer!.listen(
      (localSocket) async {
        try {
          print('收到本地连接，转发到 $remoteHost:$remotePort');
          final forward = await _sshClient!.forwardLocal(remoteHost, remotePort);
          
          // 双向转发
          forward.stream.listen(
            (data) => localSocket.add(data),
            onError: (e) => print('Forward error: $e'),
            onDone: () => localSocket.close(),
          );
          
          localSocket.listen(
            (data) => forward.sink.add(data),
            onError: (e) => print('Socket error: $e'),
            onDone: () => forward.close(),
          );
          
        } catch (e) {
          print('端口转发错误: $e');
          localSocket.close();
        }
      },
      onError: (e) => print('ServerSocket error: $e'),
    );
    
    return actualPort;
  }

  Future<void> disconnect() async {
    try {
      await _localServer?.close();
    } catch (e) {
      print('关闭本地服务器错误: $e');
    }
    _localServer = null;
    
    try {
      _sshClient?.close();
    } catch (e) {
      print('关闭 SSH 客户端错误: $e');
    }
    _sshClient = null;
    
    _updateState(SshConnectionState.disconnected);
  }

  bool get isConnected => 
      _currentState == SshConnectionState.forwarding &&
      _sshClient != null;

  int? get localPort => _localServer?.port;

  void _updateState(SshConnectionState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void dispose() {
    disconnect();
    _stateController.close();
  }
}