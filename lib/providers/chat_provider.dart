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
  StreamSubscription? _messageSubscription;
  
  // 消息列表
  final List<Message> _messages = [];
  
  // 当前配置
  Agent _currentAgent = Agent.defaultAgents.first;
  String _currentSessionKey = 'main';
  
  // 连接状态
  bool _isConnecting = false;
  String? _errorMessage;
  
  // Token 使用情况（从 Gateway 获取）
  double _contextUsage = 0.0;
  int _totalTokens = 0;
  int _maxTokens = 8000;
  
  // 多会话支持
  final List<Conversation> _conversations = [];
  String _currentConversationId = 'main';

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
    // 监听 Gateway 消息
    _messageSubscription = _gatewayService.messageStream.listen(_handleGatewayMessage);
    
    // 尝试自动连接到之前的服务器
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
        // 加载历史消息
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
    
    // 检查连接状态
    if (!_gatewayService.isConnected) {
      _errorMessage = '未连接到服务器';
      notifyListeners();
      return;
    }

    // 添加用户消息到界面
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content.trim(),
      type: MessageType.user,
      timestamp: DateTime.now(),
    );
    _messages.add(userMessage);
    notifyListeners();

    // 添加 AI 加载中消息
    final aiMessage = Message(
      id: 'loading_${DateTime.now().millisecondsSinceEpoch}',
      content: '',
      type: MessageType.ai,
      timestamp: DateTime.now(),
      isLoading: true,
    );
    _messages.add(aiMessage);
    notifyListeners();

    // 通过 Gateway 发送消息
    try {
      final success = await _gatewayService.sendMessage(
        content.trim(),
        sessionKey: _currentSessionKey,
      );
      
      if (!success) {
        // 发送失败，移除加载消息并显示错误
        _messages.removeWhere((m) => m.id == aiMessage.id);
        _errorMessage = '发送失败';
        notifyListeners();
      }
      // 注意：成功的响应会通过 Gateway 事件返回，在 _handleGatewayMessage 中处理
      
    } catch (e) {
      _messages.removeWhere((m) => m.id == aiMessage.id);
      _errorMessage = '发送错误: $e';
      notifyListeners();
    }
  }

  /// 处理 Gateway 消息
  void _handleGatewayMessage(GatewayMessage message) {
    if (message.event == 'chat') {
      _handleChatEvent(message.payload);
    } else if (message.event == 'agent') {
      _handleAgentEvent(message.payload);
    }
  }

  /// 处理聊天事件
  void _handleChatEvent(Map<String, dynamic>? payload) {
    if (payload == null) return;
    
    final text = payload['text'] as String?;
    final role = payload['role'] as String?;
    
    if (text == null || text.isEmpty) return;
    
    // 移除加载中的消息
    _messages.removeWhere((m) => m.isLoading && m.type == MessageType.ai);
    
    // 添加 AI 回复
    final aiMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      type: role == 'user' ? MessageType.user : MessageType.ai,
      timestamp: DateTime.now(),
      isLoading: false,
    );
    _messages.add(aiMessage);
    notifyListeners();
  }

  /// 处理代理事件
  void _handleAgentEvent(Map<String, dynamic>? payload) {
    if (payload == null) return;
    
    final text = payload['text'] as String?;
    final thinking = payload['thinking'] as bool? ?? false;
    
    if (text == null || text.isEmpty) return;
    
    if (thinking) {
      // 显示思考过程（可选）
      print('Agent thinking: $text');
    } else {
      // 移除加载中的消息
      _messages.removeWhere((m) => m.isLoading && m.type == MessageType.ai);
      
      // 添加 AI 回复
      final aiMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: text,
        type: MessageType.ai,
        timestamp: DateTime.now(),
        isLoading: false,
      );
      _messages.add(aiMessage);
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
        final content = entry['content'] as String?;
        final timestamp = entry['timestamp'] as int?;
        
        if (content != null) {
          _messages.add(Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: content,
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

  /// 设置当前 Agent
  void setAgent(Agent agent) {
    _currentAgent = agent;
    notifyListeners();
  }

  /// 切换会话
  void switchConversation(String conversationId) {
    _currentConversationId = conversationId;
    _currentSessionKey = conversationId;
    _messages.clear();
    notifyListeners();
    
    // 加载新会话的历史
    _loadChatHistory();
  }

  /// 创建新会话
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

  /// 清空当前会话消息
  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  /// 清空上下文
  void clearContext() {
    _contextUsage = 0.0;
    notifyListeners();
  }

  /// 清除错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}
