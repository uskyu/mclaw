import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/agent.dart';
import '../models/server.dart';
import '../services/gateway_service.dart';
import '../services/gateway_protocol_service.dart';
import '../services/secure_storage_service.dart';

class ChatProvider with ChangeNotifier {
  static const int _historyFetchLimit = 80;

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
  Timer? _conversationRefreshTimer;

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
    _chatSubscription = _gatewayService.chatEventStream.listen(
      _handleChatEvent,
    );
    _agentSubscription = _gatewayService.agentEventStream.listen(
      _handleAgentEvent,
    );

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
          orElse: () => servers.isNotEmpty
              ? servers.first
              : Server(id: 'default', name: '未配置', type: ServerType.openclaw),
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
        await _loadConversations();
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
    _conversationRefreshTimer?.cancel();
    notifyListeners();
  }

  Future<void> refreshConversations() async {
    await _loadConversations();
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
    _touchConversationOnUserMessage(content.trim());
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
    _upsertMessage(aiMessage);
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
        // 只有在明确的权限错误时才移除 loading
        // 超时可能意味着消息已发送，等待 agent 事件
        if (result.errorCode != null) {
          _messages.removeWhere((m) => m.id == loadingId);
          final errorCode = result.errorCode ?? '';
          final errorMsg = result.errorMessage ?? '发送失败';
          _errorMessage = errorCode.isNotEmpty
              ? '[$errorCode] $errorMsg'
              : errorMsg;
          notifyListeners();
        } else {
          // 超时等错误，保持 loading 状态，等待可能的 agent 事件
          print('chat.send 可能超时，保持 loading 状态等待响应');
          // 5秒后如果还没收到响应，再移除 loading
          Future.delayed(const Duration(seconds: 10), () {
            if (_messages.any((m) => m.id == loadingId && m.isLoading)) {
              _messages.removeWhere((m) => m.id == loadingId);
              _errorMessage = '响应超时，请重试';
              notifyListeners();
            }
          });
        }
      }
    } catch (e) {
      _messages.removeWhere((m) => m.id == loadingId);
      _errorMessage = '发送错误: $e';
      notifyListeners();
    }
  }

  /// 处理 chat 事件
  void _handleChatEvent(ChatEventPayload event) {
    print(
      'chat 事件: state=${event.state}, runId=${event.runId}, sessionKey=${event.sessionKey}',
    );

    final isOurRun = event.runId != null && _pendingRuns.contains(event.runId!);

    // 检查 sessionKey 是否匹配
    if (event.sessionKey != null &&
        !_matchesCurrentSessionKey(event.sessionKey!) &&
        !isOurRun) {
      print('sessionKey 不匹配，忽略: ${event.sessionKey}');
      return;
    }

    // 处理错误
    if (event.state == 'error') {
      print('chat 错误: ${event.errorMessage}');
      _errorMessage = event.errorMessage ?? '聊天失败';
      _clearPendingRun(event.runId);
      _removeLoadingMessage();
      _scheduleConversationRefresh();
      notifyListeners();
      return;
    }

    if (event.state == 'delta' && event.message != null) {
      final role = event.message!['role'] as String? ?? '';
      if (role == 'assistant') {
        final text = _extractText(event.message!['content']);
        if (text.isNotEmpty) {
          _streamingContent = text;
          _updateStreamingMessage();
        }
      }
      return;
    }

    // 处理完成状态
    if (event.state == 'final' || event.state == 'aborted') {
      print('chat 完成: ${event.state}');
      var committed = false;
      if (event.message != null) {
        committed = _processChatMessage(event.message!, event.runId);
      }
      if (!committed) {
        committed = _finalizeStreamingMessage(event.runId);
      }
      _removeLoadingMessage();
      _clearPendingRun(event.runId);
      if (!committed && event.state == 'final') {
        unawaited(_refreshHistoryAfterRun());
      } else {
        notifyListeners();
      }
      _scheduleConversationRefresh();
      return;
    }
  }

  bool _processChatMessage(Map<String, dynamic> message, String? runId) {
    final role = message['role'] as String? ?? '';
    if (role != 'assistant') {
      return false;
    }

    final content = message['content'];
    String text = _extractText(content);
    text = _formatQuickCommandResponse(text);
    _updateContextUsageFromText(text);

    if (text.isEmpty) {
      return false;
    }

    final aiMessage = Message(
      id: runId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      type: MessageType.ai,
      timestamp: DateTime.now(),
      isLoading: false,
    );
    _upsertMessage(aiMessage);
    _streamingContent = '';
    return true;
  }

  bool _finalizeStreamingMessage(String? runId) {
    if (_streamingContent.isEmpty) {
      return false;
    }

    final formatted = _formatQuickCommandResponse(_streamingContent);
    if (formatted.trim().isEmpty) {
      _streamingContent = '';
      return false;
    }

    _updateContextUsageFromText(formatted);
    final aiMessage = Message(
      id: runId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: formatted,
      type: MessageType.ai,
      timestamp: DateTime.now(),
      isLoading: false,
    );
    _upsertMessage(aiMessage);
    _streamingContent = '';
    return true;
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

    print('agent 事件: stream=$stream, runId=${event.runId}');

    switch (stream) {
      case 'assistant':
        // 流式文本输出
        final text = data['text'];
        final delta = data['delta'];
        if (text != null || delta != null) {
          final incoming = text?.toString() ?? '';
          final deltaText = delta?.toString() ?? '';
          if (_streamingContent.isEmpty) {
            _streamingContent = incoming.isNotEmpty ? incoming : deltaText;
          } else if (incoming.startsWith(_streamingContent)) {
            _streamingContent = incoming;
          } else if (incoming.isNotEmpty) {
            _streamingContent += incoming;
          } else if (deltaText.isNotEmpty) {
            _streamingContent += deltaText;
          } else {
            _streamingContent = incoming;
          }
          _updateStreamingMessage();
        }
        break;

      case 'lifecycle':
        final phase = data['phase']?.toString();
        if (phase == 'end') {
          final committed = _finalizeStreamingMessage(event.runId);
          _removeLoadingMessage();
          _clearPendingRun(event.runId);
          _scheduleConversationRefresh();
          if (committed) {
            notifyListeners();
          }
        } else if (phase == 'error') {
          final error = data['error'];
          if (error != null) {
            _errorMessage = error.toString();
          }
          _streamingContent = '';
          _removeLoadingMessage();
          _clearPendingRun(event.runId);
          _scheduleConversationRefresh();
          notifyListeners();
        }
        break;

      case 'done':
        // 流式完成
        print('agent done, content length: ${_streamingContent.length}');
        _finalizeStreamingMessage(event.runId);
        _removeLoadingMessage();
        _clearPendingRun(event.runId);
        _scheduleConversationRefresh();
        notifyListeners();
        break;

      case 'usage':
        // Token 使用统计
        final input = (data['input'] as num?)?.toInt() ?? 0;
        final output = (data['output'] as num?)?.toInt() ?? 0;
        _totalTokens = input + output;
        final contextTokens = (data['contextTokens'] as num?)?.toInt();
        final maxContextTokens = (data['maxContextTokens'] as num?)?.toInt();
        final contextPct = (data['contextUsagePct'] as num?)?.toDouble();
        if (contextPct != null) {
          _contextUsage = (contextPct / 100).clamp(0.0, 1.0);
          notifyListeners();
        } else if (contextTokens != null &&
            contextTokens > 0 &&
            maxContextTokens != null &&
            maxContextTokens > 0) {
          _contextUsage = (contextTokens / maxContextTokens).clamp(0.0, 1.0);
          notifyListeners();
        }
        break;
    }
  }

  void _updateStreamingMessage() {
    final loadingMessages = _messages
        .where((m) => m.isLoading && m.type == MessageType.ai)
        .toList();
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

  void _upsertMessage(Message message) {
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      _messages[index] = message;
    } else {
      _messages.add(message);
    }
  }

  void _clearPendingRun(String? runId) {
    if (runId != null) {
      _pendingRuns.remove(runId);
    }
    if (runId == _currentRunId) {
      _currentRunId = null;
    }
  }

  String _normalizeSessionKey(String key) {
    final normalized = key.toLowerCase().trim();
    if (normalized == 'agent:main:main') {
      return 'main';
    }
    return normalized;
  }

  bool _isSameSessionKey(String a, String b) {
    return _normalizeSessionKey(a) == _normalizeSessionKey(b);
  }

  String _fallbackTitleForSessionKey(String key) {
    final normalized = key.trim();
    if (normalized.isEmpty) {
      return '新对话';
    }
    if (_isSameSessionKey(normalized, 'main')) {
      return '主对话';
    }
    if (normalized.startsWith('agent:main:session_')) {
      return '新对话';
    }
    final parts = normalized.split(':').where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? '新对话' : parts.last;
  }

  String _resolveConversationTitle(Map<String, dynamic> row) {
    final preferredFields = [
      row['derivedTitle'],
      row['displayName'],
      row['label'],
      row['lastMessagePreview'],
    ];
    for (final value in preferredFields) {
      if (value is String && value.trim().isNotEmpty) {
        final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
        return text.length > 24 ? '${text.substring(0, 24)}...' : text;
      }
    }
    final key = row['key']?.toString() ?? '';
    return _fallbackTitleForSessionKey(key);
  }

  DateTime _resolveConversationUpdatedAt(Map<String, dynamic> row) {
    final raw = row['updatedAt'];
    if (raw is num && raw.toInt() > 0) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    if (raw is String) {
      final parsedInt = int.tryParse(raw);
      if (parsedInt != null && parsedInt > 0) {
        return DateTime.fromMillisecondsSinceEpoch(parsedInt);
      }
      final parsedDate = DateTime.tryParse(raw);
      if (parsedDate != null) {
        return parsedDate;
      }
    }
    return DateTime.now();
  }

  String _deriveConversationTitleFromInput(String text) {
    final cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) {
      return '新对话';
    }
    if (cleaned.startsWith('/')) {
      return '命令会话';
    }
    return cleaned.length > 20 ? '${cleaned.substring(0, 20)}...' : cleaned;
  }

  void _touchConversationOnUserMessage(String text) {
    final now = DateTime.now();
    final index = _conversations.indexWhere(
      (c) => _isSameSessionKey(c.id, _currentSessionKey),
    );
    final titleHint = _deriveConversationTitleFromInput(text);

    if (index >= 0) {
      final existing = _conversations.removeAt(index);
      final shouldReplaceTitle =
          existing.title == '新对话' ||
          existing.title == '主对话' ||
          existing.title.isEmpty;
      _conversations.insert(
        0,
        Conversation(
          id: existing.id,
          title: shouldReplaceTitle ? titleHint : existing.title,
          lastUpdated: now,
          messages: existing.messages,
        ),
      );
      _currentConversationId = existing.id;
      _currentSessionKey = existing.id;
      return;
    }

    _conversations.insert(
      0,
      Conversation(id: _currentSessionKey, title: titleHint, lastUpdated: now),
    );
    _currentConversationId = _currentSessionKey;
  }

  void _scheduleConversationRefresh() {
    _conversationRefreshTimer?.cancel();
    _conversationRefreshTimer = Timer(const Duration(milliseconds: 700), () {
      if (!_gatewayService.isConnected) {
        return;
      }
      unawaited(_loadConversations());
    });
  }

  Future<void> _loadConversations() async {
    if (!_gatewayService.isConnected) {
      return;
    }

    try {
      final rows = await _gatewayService.getSessionsList(
        limit: 200,
        includeDerivedTitles: true,
        includeLastMessage: true,
      );

      final merged = <Conversation>[];
      final seen = <String>{};

      for (final row in rows) {
        final key = (row['key']?.toString() ?? '').trim();
        if (key.isEmpty) {
          continue;
        }
        final normalizedKey = _normalizeSessionKey(key);
        if (!seen.add(normalizedKey)) {
          continue;
        }

        merged.add(
          Conversation(
            id: key,
            title: _resolveConversationTitle(row),
            lastUpdated: _resolveConversationUpdatedAt(row),
          ),
        );
      }

      for (final local in _conversations) {
        final normalizedKey = _normalizeSessionKey(local.id);
        if (!seen.add(normalizedKey)) {
          continue;
        }
        merged.add(local);
      }

      final currentNormalized = _normalizeSessionKey(_currentSessionKey);
      if (!seen.contains(currentNormalized)) {
        merged.add(
          Conversation(
            id: _currentSessionKey,
            title: _fallbackTitleForSessionKey(_currentSessionKey),
            lastUpdated: DateTime.now(),
          ),
        );
      }

      merged.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

      _conversations
        ..clear()
        ..addAll(merged);

      for (final conversation in _conversations) {
        if (_isSameSessionKey(conversation.id, _currentSessionKey)) {
          _currentSessionKey = conversation.id;
          _currentConversationId = conversation.id;
          break;
        }
      }

      notifyListeners();
    } catch (e) {
      print('加载会话列表失败: $e');
    }
  }

  String _formatQuickCommandResponse(String text) {
    if (!text.contains('Context:') || !text.contains('Session:')) {
      return text;
    }
    final compact = text
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final parts = compact
        .replaceAll(' • ', ' · ')
        .split(' · ')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final head = parts.first;
    final tail = parts.skip(1).map((p) => '- $p').join('\n');
    return tail.isEmpty ? head : '$head\n$tail';
  }

  void _updateContextUsageFromText(String text) {
    final match = RegExp(r'Context:\s*[^\n\r]*\((\d{1,3})%\)').firstMatch(text);
    if (match == null) return;

    final pct = int.tryParse(match.group(1) ?? '');
    if (pct == null) return;

    final clamped = pct.clamp(0, 100) / 100.0;
    if ((clamped - _contextUsage).abs() > 0.001) {
      _contextUsage = clamped;
      notifyListeners();
    }
  }

  Future<void> _refreshHistoryAfterRun() async {
    _streamingContent = '';
    _removeLoadingMessage();
    await _loadChatHistory();

    // Gateway may emit `chat final` before history index is fully visible.
    // Retry once after a short delay to avoid false timeout/error UX.
    await Future.delayed(const Duration(milliseconds: 800));
    await _loadChatHistory();
  }

  bool _matchesCurrentSessionKey(String incoming) {
    return _isSameSessionKey(incoming, _currentSessionKey);
  }

  Future<void> _loadChatHistory() async {
    try {
      final history = await _gatewayService.getChatHistory(
        sessionKey: _currentSessionKey,
        limit: _historyFetchLimit,
      );

      _messages.clear();
      DateTime latestMessageAt = DateTime.fromMillisecondsSinceEpoch(0);
      String? firstUserText;

      for (final entry in history) {
        final role = entry['role'] as String?;
        final content = entry['content'];
        final timestamp = (entry['timestamp'] as num?)?.toInt();

        final text = _extractText(content);

        if (text.isNotEmpty && role != null) {
          if (role == 'user' && firstUserText == null) {
            firstUserText = text;
          }
          final parsedTime = timestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(timestamp)
              : DateTime.now();
          if (parsedTime.isAfter(latestMessageAt)) {
            latestMessageAt = parsedTime;
          }
          _messages.add(
            Message(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              content: text,
              type: role == 'user' ? MessageType.user : MessageType.ai,
              timestamp: parsedTime,
              isLoading: false,
            ),
          );
        }
      }

      final existingIndex = _conversations.indexWhere(
        (c) => _isSameSessionKey(c.id, _currentSessionKey),
      );
      final fallbackTitle = _fallbackTitleForSessionKey(_currentSessionKey);
      final titleHint =
          (firstUserText != null && firstUserText.trim().isNotEmpty)
          ? _deriveConversationTitleFromInput(firstUserText)
          : fallbackTitle;
      final updatedAt = latestMessageAt.millisecondsSinceEpoch > 0
          ? latestMessageAt
          : DateTime.now();
      if (existingIndex >= 0) {
        final existing = _conversations[existingIndex];
        final shouldReplaceTitle =
            existing.title == '新对话' ||
            existing.title == '主对话' ||
            existing.title.isEmpty;
        _conversations[existingIndex] = Conversation(
          id: existing.id,
          title: shouldReplaceTitle ? titleHint : existing.title,
          lastUpdated: existing.lastUpdated.isAfter(updatedAt)
              ? existing.lastUpdated
              : updatedAt,
          messages: existing.messages,
        );
      } else {
        _conversations.insert(
          0,
          Conversation(
            id: _currentSessionKey,
            title: history.isEmpty ? fallbackTitle : titleHint,
            lastUpdated: updatedAt,
          ),
        );
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
    final matched = _conversations.where(
      (c) => _isSameSessionKey(c.id, conversationId),
    );
    final targetId = matched.isNotEmpty ? matched.first.id : conversationId;

    _currentConversationId = targetId;
    _currentSessionKey = targetId;
    _messages.clear();
    _streamingContent = '';
    _pendingRuns.clear();
    _currentRunId = null;
    _errorMessage = null;
    notifyListeners();

    unawaited(_loadChatHistory());
  }

  void createNewConversation() {
    final newId = 'agent:main:session_${DateTime.now().millisecondsSinceEpoch}';
    final newConversation = Conversation(
      id: newId,
      title: '新对话',
      lastUpdated: DateTime.now(),
      messages: [],
    );

    _conversations.removeWhere((c) => _isSameSessionKey(c.id, newId));
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
    _conversationRefreshTimer?.cancel();
    _chatSubscription?.cancel();
    _agentSubscription?.cancel();
    super.dispose();
  }
}
