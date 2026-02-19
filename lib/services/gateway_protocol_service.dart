import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

/// Gateway 消息
class GatewayMessage {
  final String type;
  final String? id;
  final String? method;
  final Map<String, dynamic>? params;
  final bool? ok;
  final Map<String, dynamic>? payload;
  final Map<String, dynamic>? error;
  final String? event;
  final int? seq;

  GatewayMessage({
    required this.type,
    this.id,
    this.method,
    this.params,
    this.ok,
    this.payload,
    this.error,
    this.event,
    this.seq,
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
      seq: json['seq'] as int?,
    );
  }
}

/// Chat 发送响应
class ChatSendResponse {
  final String runId;
  final String status;

  ChatSendResponse({required this.runId, required this.status});

  factory ChatSendResponse.fromJson(Map<String, dynamic> json) {
    return ChatSendResponse(
      runId: json['runId'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

/// Chat 发送结果
class ChatSendResult {
  final ChatSendResponse? response;
  final String? errorCode;
  final String? errorMessage;

  ChatSendResult({this.response, this.errorCode, this.errorMessage});
  
  bool get isSuccess => response != null && errorMessage == null;
}

/// Chat 事件负载
class ChatEventPayload {
  final String? runId;
  final String? sessionKey;
  final String? state;
  final Map<String, dynamic>? message;
  final String? errorMessage;

  ChatEventPayload({
    this.runId,
    this.sessionKey,
    this.state,
    this.message,
    this.errorMessage,
  });

  factory ChatEventPayload.fromJson(Map<String, dynamic> json) {
    return ChatEventPayload(
      runId: json['runId'] as String?,
      sessionKey: json['sessionKey'] as String?,
      state: json['state'] as String?,
      message: json['message'] as Map<String, dynamic>?,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

/// Agent 事件负载
class AgentEventPayload {
  final String runId;
  final int? seq;
  final String stream;
  final int? ts;
  final Map<String, dynamic> data;

  AgentEventPayload({
    required this.runId,
    this.seq,
    required this.stream,
    this.ts,
    required this.data,
  });

  factory AgentEventPayload.fromJson(Map<String, dynamic> json) {
    return AgentEventPayload(
      runId: json['runId'] as String? ?? '',
      seq: json['seq'] as int?,
      stream: json['stream'] as String? ?? '',
      ts: json['ts'] as int?,
      data: json['data'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// OpenClaw Gateway 协议服务
class GatewayProtocolService {
  WebSocketChannel? _channel;
  final _stateController = StreamController<GatewayConnectionState>.broadcast();
  final _messageController = StreamController<GatewayMessage>.broadcast();
  final _chatEventController = StreamController<ChatEventPayload>.broadcast();
  final _agentEventController = StreamController<AgentEventPayload>.broadcast();
  final _pendingRequests = <String, Completer<Map<String, dynamic>>>{};
  
  GatewayConnectionState _currentState = GatewayConnectionState.disconnected;
  String? _lastError;
  String? _deviceToken;
  int _tickIntervalMs = 15000;

  Stream<GatewayConnectionState> get stateStream => _stateController.stream;
  Stream<GatewayMessage> get messageStream => _messageController.stream;
  Stream<ChatEventPayload> get chatEventStream => _chatEventController.stream;
  Stream<AgentEventPayload> get agentEventStream => _agentEventController.stream;
  GatewayConnectionState get currentState => _currentState;
  String? get lastError => _lastError;
  String? get deviceToken => _deviceToken;
  bool get isConnected => _currentState == GatewayConnectionState.connected;
  int get tickIntervalMs => _tickIntervalMs;

  /// 连接到 Gateway WebSocket
  Future<void> connect(String wsUrl) async {
    try {
      _updateState(GatewayConnectionState.connecting);
      _lastError = null;

      final socket = await WebSocket.connect(
        wsUrl,
        headers: {
          'Origin': 'http://localhost:18789',
        },
      );
      
      _channel = IOWebSocketChannel(socket);
      
      _channel!.stream.listen(
        (data) => _handleMessage(data),
        onError: (error) {
          _lastError = 'WebSocket 错误: $error';
          _updateState(GatewayConnectionState.error);
        },
        onDone: () {
          if (_currentState == GatewayConnectionState.connected) {
            _lastError = '连接已断开';
          }
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
    String? deviceToken,
    String locale = 'zh-CN',
  }) async {
    try {
      _updateState(GatewayConnectionState.handshaking);

      final challengeMsg = await _waitForEvent('connect.challenge', timeout: Duration(seconds: 10));
      if (challengeMsg == null) {
        throw Exception('未收到 challenge');
      }

      final nonce = challengeMsg.payload?['nonce'] as String?;
      final ts = challengeMsg.payload?['ts'] as int?;

      if (nonce == null || ts == null) {
        throw Exception('challenge 数据无效');
      }

      final requestId = _generateRequestId();
      final connectParams = {
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
        'auth': {
          'token': token,
          if (deviceToken != null && deviceToken.isNotEmpty) 'deviceToken': deviceToken,
        },
      };

      print('发送 connect 参数: ${jsonEncode(connectParams)}');

      final response = await _sendRequest('connect', connectParams, requestId);
      
      if (response['ok'] == true) {
        final payload = response['payload'] as Map<String, dynamic>?;
        if (payload?['type'] == 'hello-ok') {
          _deviceToken = payload?['auth']?['deviceToken'] as String?;
          
          final policy = payload?['policy'] as Map<String, dynamic>?;
          if (policy != null && policy['tickIntervalMs'] != null) {
            _tickIntervalMs = policy['tickIntervalMs'] as int;
          }
          
          _updateState(GatewayConnectionState.connected);
          return true;
        }
      }
      
      final errorMsg = response['error']?['message'] ?? '握手失败';
      _lastError = errorMsg.toString();
      _updateState(GatewayConnectionState.error);
      return false;

    } catch (e) {
      _lastError = '握手失败: $e';
      _updateState(GatewayConnectionState.error);
      return false;
    }
  }

  /// 发送聊天消息
  Future<ChatSendResult> chatSend(
    String message, 
    String sessionKey, {
    String? thinking,
    List<Map<String, dynamic>>? attachments,
    int timeoutMs = 30000,
  }) async {
    final params = <String, dynamic>{
      'sessionKey': sessionKey,
      'message': message,
      'idempotencyKey': _generateRequestId(),
      'timeoutMs': timeoutMs,
    };
    
    if (thinking != null && thinking.isNotEmpty) {
      params['thinking'] = thinking;
    }
    
    if (attachments != null && attachments.isNotEmpty) {
      params['attachments'] = attachments;
    }

    try {
      final response = await _sendRequest('chat.send', params, null, timeoutSeconds: 35);
      
      if (response['ok'] == true && response['payload'] != null) {
        return ChatSendResult(
          response: ChatSendResponse.fromJson(response['payload'] as Map<String, dynamic>),
        );
      }
      
      final error = response['error'] as Map<String, dynamic>?;
      return ChatSendResult(
        errorCode: error?['code'] as String?,
        errorMessage: error?['message'] as String? ?? 'chat.send 失败',
      );
    } catch (e) {
      print('chat.send 错误: $e');
      return ChatSendResult(errorMessage: e.toString());
    }
  }

  /// 获取聊天历史
  Future<List<Map<String, dynamic>>> chatHistory(String sessionKey) async {
    final params = {'sessionKey': sessionKey};
    
    try {
      final response = await _sendRequest('chat.history', params, null, timeoutSeconds: 15);
      if (response['ok'] == true && response['payload'] != null) {
        final payload = response['payload'] as Map<String, dynamic>;
        final messages = payload['messages'] as List<dynamic>?;
        return messages?.cast<Map<String, dynamic>>() ?? [];
      }
      return [];
    } catch (e) {
      print('chat.history 错误: $e');
      return [];
    }
  }

  /// 健康检查
  Future<bool> health({int timeoutMs = 5000}) async {
    try {
      final response = await _sendRequest('health', null, null, timeoutSeconds: (timeoutMs / 1000).ceil());
      return response['ok'] == true || response['payload']?['ok'] == true;
    } catch (e) {
      return false;
    }
  }

  /// 发送请求
  Future<Map<String, dynamic>> _sendRequest(
    String method, 
    Map<String, dynamic>? params, 
    String? id, 
    {int timeoutSeconds = 30}
  ) async {
    if (_channel == null) {
      throw Exception('WebSocket 未连接');
    }

    final requestId = id ?? _generateRequestId();
    final request = <String, dynamic>{
      'type': 'req',
      'id': requestId,
      'method': method,
    };
    if (params != null) {
      request['params'] = params;
    }

    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[requestId] = completer;

    print('发送请求: $method, id: $requestId');
    _channel!.sink.add(jsonEncode(request));

    return completer.future.timeout(
      Duration(seconds: timeoutSeconds),
      onTimeout: () {
        _pendingRequests.remove(requestId);
        print('请求超时: $method, id: $requestId');
        throw TimeoutException('$method 请求超时');
      },
    );
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
      print('收到消息: ${json['type']} ${json['method'] ?? json['event'] ?? json['id'] ?? ''}');
      
      final message = GatewayMessage.fromJson(json);
      
      _messageController.add(message);

      // 处理响应
      if (message.type == 'res' && message.id != null) {
        final completer = _pendingRequests.remove(message.id);
        if (completer != null && !completer.isCompleted) {
          print('匹配到请求: ${message.id}, ok: ${message.ok}');
          if (message.ok != true) {
            print('错误响应: ${jsonEncode(json['error'])}');
          }
          completer.complete(json);
        } else {
          print('未找到请求: ${message.id}, pending: ${_pendingRequests.keys}');
        }
      }
      
      // 处理事件
      if (message.type == 'event') {
        _handleEvent(message);
      }
      
    } catch (e) {
      print('消息解析错误: $e');
    }
  }
  
  /// 处理事件
  void _handleEvent(GatewayMessage message) {
    switch (message.event) {
      case 'tick':
        // 心跳 tick 事件，可以用于 UI 更新
        break;
      case 'health':
        // 健康状态事件
        break;
      case 'chat':
        if (message.payload != null) {
          final chatEvent = ChatEventPayload.fromJson(message.payload!);
          _chatEventController.add(chatEvent);
        }
        break;
      case 'agent':
        if (message.payload != null) {
          final agentEvent = AgentEventPayload.fromJson(message.payload!);
          _agentEventController.add(agentEvent);
        }
        break;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
    _deviceToken = null;
    _pendingRequests.clear();
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
    _chatEventController.close();
    _agentEventController.close();
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() => message;
}
