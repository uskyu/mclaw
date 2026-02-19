import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/agent.dart';
import '../models/server.dart';
import '../services/gateway_service.dart';
import '../services/gateway_protocol_service.dart';
import '../services/secure_storage_service.dart';

class ChatProvider with ChangeNotifier {
  final GatewayService _gatewayService;
  StreamSubscription? _chatSubscription;
  StreamSubscription? _agentSubscription;
  
  final List<Message> _messages = [];
  
  Agent _currentAgent = Agent.defaultAgents.first;
  String _currentSessionKey = 'main';
  
  bool _isConnecting = false;
  String? _errorMessage;
  
  double _contextUsage = 0.0;
  int _totalTokens = 0;
  final int _maxTokens = 8000;
  
  final List<Conversation> _conversations = [];
  String _currentConversationId = 'main';
  
  // 流式输出状态
  String _streamingContent = '';
  String? _currentRunId;
  final Set<String> _pendingRuns = {};

  ChatProvider({required GatewayService gatewayService}) 
      : _gatewayService = gatewayService {
    _init();
  }

  // Getters
  List<Message> get messages => _messages;
  List<Conversation> get conversations => _conversations;
  Agent get currentAgent => _currentAgent;
  String get currentSessionKey => _currentSessionKey;
  String get currentConversationId => _currentConversationId;
  bool get isConnected => _gatewayService.isConnected;
  bool get isConnecting => _isConnecting;
  String? get errorMessage => _errorMessage;
  double get contextUsage => _contextUsage;
  int get totalTokens => _totalTokens;
  int get maxTokens => _maxTokens;
  ConnectionStatus get connectionStatus => _gatewayService.status;
  bool get isStreaming => _streamingContent.isNotEmpty;

  Future<void> _init() async {
    _chatSubscription = _gatewayService.chatEventStream.listen(_handleChatEvent);
    _agentSubscription = _gatewayService.agentEventStream.listen(_handleAgentEvent);
    
    await _autoConnect();
  }

  Future<void> _autoConnect() async {
    final servers = await SecureStorageService.loadServers();
    final activeServerId = await SecureStorageService.loadActiveServerId();
    
    if (activeServerId != null) {
      final activeServer = servers.firstWhere(
        (s) => s.id == activeServerId,
        orElse: () => servers.firstWhere(
          (s) => s.isActive,
          orElse: () => servers.isNotEmpty ? servers.first : Server(
            id: 'default',
            name: '未配置',
            type: ServerType.openclaw,
          ),
        ),
      );
      
      if (activeServer.type == ServerType.openclaw && 
          activeServer.sshHost != null && 
          activeServer.sshHost!.isNotEmpty) {
        await connectToServer(activeServer);
      }
    }
  }

  Future<bool> connectToServer(Server server) async {
    if (server.type != ServerType.openclaw) {
      _errorMessage = '暂不支持此类型服务器';
      notifyListeners();
      return false;
    }

    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _gatewayService.connect(server);
      
      if (success) {
        await _loadChatHistory();
      } else {
        _errorMessage = _gatewayService.errorMessage ?? '连接失败';
      }
      
      _isConnecting = false;
      notifyListeners();
      return success;
      
    } catch (e) {
      _isConnecting = false;
      _errorMessage = '连接错误: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    await _gatewayService.disconnect();
    _messages.clear();
    _pendingRuns.clear();
    _currentRunId = null;
    notifyListeners();
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    
    if (!_gatewayService.isConnected) {
      _errorMessage = '未连接到服务器';
      notifyListeners();
      return;
    }

    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content.trim(),
      type: MessageType.user,
      timestamp: DateTime.now(),
    );
    _messages.add(userMessage);
    notifyListeners();

    // 添加加载中消息
    final loadingId = 'loading_${DateTime.now().millisecondsSinceEpoch}';
    final aiMessage = Message(
      id: loadingId,
      content: '',
      type: MessageType.ai,
      timestamp: DateTime.now(),
      isLoading: true,
    );
    _messages.add(aiMessage);
    _streamingContent = '';
    notifyListeners();

    try {
      final result = await _gatewayService.sendMessage(
        content.trim(),
        sessionKey: _currentSessionKey,
      );
      
      if (result.isSuccess && result.response != null) {
        _currentRunId = result.response!.runId;
        _pendingRuns.add(result.response!.runId);
      } else {
        _messages.removeWhere((m) => m.id == loadingId);
        final errorCode = result.errorCode ?? '';
        final errorMsg = result.errorMessage ?? '发送失败';
        _errorMessage = errorCode.isNotEmpty ? '[$errorCode] $errorMsg' : errorMsg;
        notifyListeners();
      }
      
    } catch (e) {
      _messages.removeWhere((m) => m.id == loadingId);
      _errorMessage = '发送错误: $e';
      notifyListeners();
    }
  }

  /// 处理 chat 事件
  void _handleChatEvent(ChatEventPayload event) {
    final isOurRun = event.runId != null && _pendingRuns.contains(event.runId!);
    
    // 检查 sessionKey 是否匹配
    if (event.sessionKey != null && !_matchesCurrentSessionKey(event.sessionKey!) && !isOurRun) {
      return;
    }
    
    // 处理错误
    if (event.state == 'error') {
      _errorMessage = event.errorMessage ?? '聊天失败';
      _clearPendingRun(event.runId);
      _removeLoadingMessage();
      notifyListeners();
      return;
    }
    
    // 处理完成状态
    if (event.state == 'final' || event.state == 'aborted') {
      _clearPendingRun(event.runId);
      // 刷新历史获取最终消息
      _refreshHistoryAfterRun();
      return;
    }
    
    // 处理消息
    if (event.message != null) {
      _processChatMessage(event.message!, event.runId);
    }
  }
  
  void _processChatMessage(Map<String, dynamic> message, String? runId) {
    final role = message['role'] as String? ?? '';
    
    if (role == 'assistant') {
      final content = message['content'];
      String text = _extractText(content);
      
      if (text.isNotEmpty) {
        _removeLoadingMessage();
        
        final aiMessage = Message(
          id: runId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          content: text,
          type: MessageType.ai,
          timestamp: DateTime.now(),
          isLoading: false,
        );
        _messages.add(aiMessage);
        _streamingContent = '';
        notifyListeners();
      }
    }
  }
  
  String _extractText(dynamic content) {
    if (content == null) return '';
    
    if (content is String) {
      return content;
    } else if (content is List) {
      final buffer = StringBuffer();
      for (final item in content) {
        if (item is Map) {
          final text = item['text'];
          if (text is String) {
            buffer.write(text);
          }
        }
      }
      return buffer.toString();
    }
    
    return '';
  }

  /// 处理 agent 事件 - 流式输出
  void _handleAgentEvent(AgentEventPayload event) {
    final stream = event.stream;
    final data = event.data;
    
    switch (stream) {
      case 'assistant':
        // 流式文本输出
        final text = data['text'];
        if (text != null) {
          _streamingContent = text.toString();
          _updateStreamingMessage();
        }
        break;
        
      case 'done':
        // 流式完成
        if (_streamingContent.isNotEmpty) {
          _removeLoadingMessage();
          final aiMessage = Message(
            id: event.runId,
            content: _streamingContent,
            type: MessageType.ai,
            timestamp: DateTime.now(),
            isLoading: false,
          );
          _messages.add(aiMessage);
          _streamingContent = '';
        }
        _clearPendingRun(event.runId);
        break;
        
      case 'usage':
        // Token 使用统计
        final input = (data['input'] as num?)?.toInt() ?? 0;
        final output = (data['output'] as num?)?.toInt() ?? 0;
        _totalTokens = input + output;
        break;
    }
  }
  
  void _updateStreamingMessage() {
    final loadingMessages = _messages.where((m) => m.isLoading && m.type == MessageType.ai).toList();
    if (loadingMessages.isNotEmpty) {
      final idx = _messages.indexOf(loadingMessages.last);
      if (idx >= 0) {
        _messages[idx] = Message(
          id: loadingMessages.last.id,
          content: _streamingContent,
          type: MessageType.ai,
          timestamp: loadingMessages.last.timestamp,
          isLoading: true,
        );
        notifyListeners();
      }
    }
  }
  
  void _removeLoadingMessage() {
    _messages.removeWhere((m) => m.isLoading && m.type == MessageType.ai);
  }
  
  void _clearPendingRun(String? runId) {
    if (runId != null) {
      _pendingRuns.remove(runId);
    }
    if (runId == _currentRunId) {
      _currentRunId = null;
    }
  }
  
  Future<void> _refreshHistoryAfterRun() async {
    _streamingContent = '';
    _removeLoadingMessage();
    await _loadChatHistory();
  }
  
  bool _matchesCurrentSessionKey(String incoming) {
    final incomingLower = incoming.toLowerCase().trim();
    final currentLower = _currentSessionKey.toLowerCase().trim();
    
    if (incomingLower == currentLower) return true;
    
    // 处理别名: "main" <-> "agent:main:main"
    if ((incomingLower == 'agent:main:main' && currentLower == 'main') ||
        (incomingLower == 'main' && currentLower == 'agent:main:main')) {
      return true;
    }
    
    return false;
  }

  Future<void> _loadChatHistory() async {
    try {
      final history = await _gatewayService.getChatHistory(
        sessionKey: _currentSessionKey,
      );
      
      _messages.clear();
      
      for (final entry in history) {
        final role = entry['role'] as String?;
        final content = entry['content'];
        final timestamp = (entry['timestamp'] as num?)?.toInt();
        
        final text = _extractText(content);
        
        if (text.isNotEmpty && role != null) {
          _messages.add(Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: text,
            type: role == 'user' ? MessageType.user : MessageType.ai,
            timestamp: timestamp != null 
                ? DateTime.fromMillisecondsSinceEpoch(timestamp)
                : DateTime.now(),
            isLoading: false,
          ));
        }
      }
      
      notifyListeners();
    } catch (e) {
      print('加载历史消息失败: $e');
    }
  }

  void setAgent(Agent agent) {
    _currentAgent = agent;
    notifyListeners();
  }

  void switchConversation(String conversationId) {
    _currentConversationId = conversationId;
    _currentSessionKey = conversationId;
    _messages.clear();
    notifyListeners();
    
    _loadChatHistory();
  }

  void createNewConversation() {
    final newId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    final newConversation = Conversation(
      id: newId,
      title: '新对话',
      lastUpdated: DateTime.now(),
      messages: [],
    );
    
    _conversations.insert(0, newConversation);
    switchConversation(newId);
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  void clearContext() {
    _contextUsage = 0.0;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _agentSubscription?.cancel();
    super.dispose();
  }
}
