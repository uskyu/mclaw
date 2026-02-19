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
  int _maxTokens = 8000;
  
  final List<Conversation> _conversations = [];
  String _currentConversationId = 'main';
  
  // 当前正在流式输出的消息内容
  String _streamingContent = '';
  String? _currentRunId;

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

  /// 初始化
  Future<void> _init() async {
    _chatSubscription = _gatewayService.chatEventStream.listen(_handleChatEvent);
    _agentSubscription = _gatewayService.agentEventStream.listen(_handleAgentEvent);
    
    await _autoConnect();
  }

  /// 自动连接
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

  /// 连接到服务器
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

  /// 断开连接
  Future<void> disconnect() async {
    await _gatewayService.disconnect();
    _messages.clear();
    notifyListeners();
  }

  /// 发送消息
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

    final aiMessage = Message(
      id: 'loading_${DateTime.now().millisecondsSinceEpoch}',
      content: '',
      type: MessageType.ai,
      timestamp: DateTime.now(),
      isLoading: true,
    );
    _messages.add(aiMessage);
    _streamingContent = '';
    notifyListeners();

    try {
      final response = await _gatewayService.sendMessage(
        content.trim(),
        sessionKey: _currentSessionKey,
      );
      
      if (response == null) {
        _messages.removeWhere((m) => m.id == aiMessage.id);
        _errorMessage = '发送失败';
        notifyListeners();
      } else {
        _currentRunId = response.runId;
      }
      
    } catch (e) {
      _messages.removeWhere((m) => m.id == aiMessage.id);
      _errorMessage = '发送错误: $e';
      notifyListeners();
    }
  }

  /// 处理聊天事件
  void _handleChatEvent(ChatEventPayload event) {
    if (event.errorMessage != null) {
      _messages.removeWhere((m) => m.isLoading && m.type == MessageType.ai);
      _errorMessage = event.errorMessage;
      notifyListeners();
      return;
    }
    
    if (event.message != null) {
      final message = event.message!;
      final content = message['content'];
      String text = '';
      
      if (content is String) {
        text = content;
      } else if (content is List) {
        for (final item in content) {
          if (item is Map && item['text'] != null) {
            text += item['text'] as String;
          }
        }
      }
      
      if (text.isNotEmpty) {
        final role = message['role'] as String? ?? 'assistant';
        
        if (role == 'assistant') {
          _messages.removeWhere((m) => m.isLoading && m.type == MessageType.ai);
          
          final aiMessage = Message(
            id: event.runId ?? DateTime.now().millisecondsSinceEpoch.toString(),
            content: text,
            type: MessageType.ai,
            timestamp: DateTime.now(),
            isLoading: false,
          );
          _messages.add(aiMessage);
          notifyListeners();
        }
      }
    }
    
    if (event.state == 'done' || event.state == 'error') {
      _currentRunId = null;
      _messages.removeWhere((m) => m.isLoading && m.type == MessageType.ai);
      notifyListeners();
    }
  }

  /// 处理代理事件
  void _handleAgentEvent(AgentEventPayload event) {
    final stream = event.stream;
    final data = event.data;
    
    if (stream == 'content' || stream == 'text') {
      final text = data['text'] as String?;
      if (text != null && text.isNotEmpty) {
        _streamingContent += text;
        
        final loadingMessages = _messages.where((m) => m.isLoading && m.type == MessageType.ai).toList();
        if (loadingMessages.isNotEmpty) {
          final idx = _messages.indexOf(loadingMessages.last);
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
    } else if (stream == 'done') {
      _messages.removeWhere((m) => m.isLoading && m.type == MessageType.ai);
      
      if (_streamingContent.isNotEmpty) {
        final aiMessage = Message(
          id: event.runId,
          content: _streamingContent,
          type: MessageType.ai,
          timestamp: DateTime.now(),
          isLoading: false,
        );
        _messages.add(aiMessage);
      }
      _streamingContent = '';
      _currentRunId = null;
      notifyListeners();
    } else if (stream == 'usage') {
      final input = (data['input'] as num?)?.toInt() ?? 0;
      final output = (data['output'] as num?)?.toInt() ?? 0;
      _totalTokens = input + output;
      notifyListeners();
    }
  }

  /// 加载聊天历史
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
        
        String text = '';
        if (content is String) {
          text = content;
        } else if (content is List) {
          for (final item in content) {
            if (item is Map && item['text'] != null) {
              text += item['text'] as String;
            }
          }
        }
        
        if (text.isNotEmpty) {
          _messages.add(Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: text,
            type: role == 'user' ? MessageType.user : MessageType.ai,
            timestamp: timestamp != null 
                ? DateTime.fromMillisecondsSinceEpoch(timestamp.toInt())
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
