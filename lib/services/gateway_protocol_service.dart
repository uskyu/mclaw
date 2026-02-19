import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

/// Gateway 连接状态
enum GatewayConnectionState {
  disconnected,
  connecting,
  handshaking,
  connected,
  error,
}

/// OpenClaw Gateway 协议消息
class GatewayMessage {
  final String type; // 'req', 'res', 'event'
  final String? id;
  final String? method;
  final Map<String, dynamic>? params;
  final bool? ok;
  final Map<String, dynamic>? payload;
  final Map<String, dynamic>? error;
  final String? event;

  GatewayMessage({
    required this.type,
    this.id,
    this.method,
    this.params,
    this.ok,
    this.payload,
    this.error,
    this.event,
  });

  factory GatewayMessage.fromJson(Map<String, dynamic> json) {
    return GatewayMessage(
      type: json['type'] as String,
      id: json['id'] as String?,
      method: json['method'] as String?,
      params: json['params'] as Map<String, dynamic>?,
      ok: json['ok'] as bool?,
      payload: json['payload'] as Map<String, dynamic>?,
      error: json['error'] as Map<String, dynamic>?,
      event: json['event'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'type': type};
    if (id != null) json['id'] = id;
    if (method != null) json['method'] = method;
    if (params != null) json['params'] = params;
    if (ok != null) json['ok'] = ok;
    if (payload != null) json['payload'] = payload;
    if (error != null) json['error'] = error;
    if (event != null) json['event'] = event;
    return json;
  }
}

/// OpenClaw Gateway 协议服务
/// 负责 WebSocket 连接和协议通信
class GatewayProtocolService {
  WebSocketChannel? _channel;
  final _stateController = StreamController<GatewayConnectionState>.broadcast();
  final _messageController = StreamController<GatewayMessage>.broadcast();
  final _pendingRequests = <String, Completer<GatewayMessage>>{};
  
  GatewayConnectionState _currentState = GatewayConnectionState.disconnected;
  String? _lastError;
  String? _deviceToken;

  Stream<GatewayConnectionState> get stateStream => _stateController.stream;
  Stream<GatewayMessage> get messageStream => _messageController.stream;
  GatewayConnectionState get currentState => _currentState;
  String? get lastError => _lastError;
  String? get deviceToken => _deviceToken;

  /// 连接到 Gateway WebSocket
  Future<void> connect(String wsUrl) async {
    try {
      _updateState(GatewayConnectionState.connecting);
      _lastError = null;

      _channel = IOWebSocketChannel.connect(wsUrl);
      
      // 监听消息
      _channel!.stream.listen(
        (data) => _handleMessage(data),
        onError: (error) {
          _lastError = 'WebSocket 错误: $error';
          _updateState(GatewayConnectionState.error);
        },
        onDone: () {
          _updateState(GatewayConnectionState.disconnected);
        },
      );

    } catch (e) {
      _lastError = '连接失败: $e';
      _updateState(GatewayConnectionState.error);
      rethrow;
    }
  }

  /// 执行协议握手
  Future<bool> handshake({
    required String clientId,
    required String clientVersion,
    required String platform,
    required String mode,
    required String token,
    String locale = 'zh-CN',
  }) async {
    try {
      _updateState(GatewayConnectionState.handshaking);

      // 等待 challenge
      final challengeMsg = await _waitForEvent('connect.challenge', timeout: Duration(seconds: 10));
      if (challengeMsg == null) {
        throw Exception('未收到 challenge');
      }

      final nonce = challengeMsg.payload?['nonce'] as String?;
      final ts = challengeMsg.payload?['ts'] as int?;

      if (nonce == null || ts == null) {
        throw Exception('challenge 数据无效');
      }

      // 发送 connect 请求
      final requestId = _generateRequestId();
      final connectRequest = GatewayMessage(
        type: 'req',
        id: requestId,
        method: 'connect',
        params: {
          'minProtocol': 3,
          'maxProtocol': 3,
          'client': {
            'id': clientId,
            'version': clientVersion,
            'platform': platform,
            'mode': mode,
          },
          'role': 'operator',
          'scopes': ['operator.read', 'operator.write'],
          'auth': {'token': token},
          'locale': locale,
          'userAgent': '$clientId/$clientVersion',
        },
      );

      final response = await _sendRequest(connectRequest);
      
      if (response.ok == true && response.payload?['type'] == 'hello-ok') {
        _deviceToken = response.payload?['auth']?['deviceToken'] as String?;
        _updateState(GatewayConnectionState.connected);
        return true;
      } else {
        _lastError = response.error?['message'] ?? '握手失败';
        _updateState(GatewayConnectionState.error);
        return false;
      }

    } catch (e) {
      _lastError = '握手失败: $e';
      _updateState(GatewayConnectionState.error);
      return false;
    }
  }

  /// 发送聊天消息
  Future<bool> chatSend(String message, String sessionKey) async {
    final request = GatewayMessage(
      type: 'req',
      id: _generateRequestId(),
      method: 'chat.send',
      params: {
        'message': message,
        'sessionKey': sessionKey,
      },
    );

    try {
      final response = await _sendRequest(request, timeout: Duration(seconds: 30));
      return response.ok == true;
    } catch (e) {
      return false;
    }
  }

  /// 获取聊天历史
  Future<List<Map<String, dynamic>>> chatHistory(String sessionKey) async {
    final request = GatewayMessage(
      type: 'req',
      id: _generateRequestId(),
      method: 'chat.history',
      params: {
        'sessionKey': sessionKey,
        'limit': 100,
      },
    );

    try {
      final response = await _sendRequest(request);
      if (response.ok == true && response.payload != null) {
        final entries = response.payload!['entries'] as List<dynamic>?;
        return entries?.cast<Map<String, dynamic>>() ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 发送请求并等待响应
  Future<GatewayMessage> _sendRequest(GatewayMessage request, {Duration? timeout}) async {
    if (_channel == null) {
      throw Exception('WebSocket 未连接');
    }

    final completer = Completer<GatewayMessage>();
    _pendingRequests[request.id!] = completer;

    _channel!.sink.add(jsonEncode(request.toJson()));

    if (timeout != null) {
      return completer.future.timeout(timeout, onTimeout: () {
        _pendingRequests.remove(request.id);
        throw TimeoutException('请求超时');
      });
    }

    return completer.future;
  }

  /// 等待特定事件
  Future<GatewayMessage?> _waitForEvent(String eventName, {Duration? timeout}) async {
    final completer = Completer<GatewayMessage>();
    
    late StreamSubscription subscription;
    subscription = _messageController.stream.listen((msg) {
      if (msg.type == 'event' && msg.event == eventName) {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete(msg);
        }
      }
    });

    try {
      if (timeout != null) {
        return await completer.future.timeout(timeout);
      }
      return await completer.future;
    } on TimeoutException {
      subscription.cancel();
      return null;
    }
  }

  /// 处理收到的消息
  void _handleMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final message = GatewayMessage.fromJson(json);
      
      _messageController.add(message);

      // 处理响应
      if (message.type == 'res' && message.id != null) {
        final completer = _pendingRequests.remove(message.id);
        if (completer != null && !completer.isCompleted) {
          completer.complete(message);
        }
      }
    } catch (e) {
      print('消息解析错误: $e');
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
    _deviceToken = null;
    _updateState(GatewayConnectionState.disconnected);
  }

  void _updateState(GatewayConnectionState state) {
    _currentState = state;
    _stateController.add(state);
  }

  String _generateRequestId() {
    return 'req_${Random().nextInt(999999).toString().padLeft(6, '0')}';
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _messageController.close();
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() => message;
}
