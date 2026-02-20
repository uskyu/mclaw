import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/message.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/input_toolbar.dart';
import '../providers/chat_provider.dart';
import 'server_management_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _messageKeys = <int, GlobalKey>{};
  Timer? _scrollButtonsTimer;
  bool _showScrollButtons = false;
  int _lastMessageCount = 0;

  @override
  void dispose() {
    _scrollButtonsTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _setScrollButtonsVisible(bool visible) {
    if (_showScrollButtons == visible || !mounted) {
      return;
    }
    setState(() {
      _showScrollButtons = visible;
    });
  }

  void _scheduleHideScrollButtons() {
    _scrollButtonsTimer?.cancel();
    _scrollButtonsTimer = Timer(const Duration(milliseconds: 900), () {
      _setScrollButtonsVisible(false);
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification ||
        (notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle)) {
      _setScrollButtonsVisible(true);
      _scheduleHideScrollButtons();
      return false;
    }

    if (notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle)) {
      _scheduleHideScrollButtons();
    }

    return false;
  }

  void _syncMessageKeys(int messageCount) {
    _messageKeys.removeWhere((index, _) => index >= messageCount);
  }

  GlobalKey _messageKeyForIndex(int index) {
    return _messageKeys.putIfAbsent(
      index,
      () => GlobalKey(debugLabel: 'chat-msg-$index'),
    );
  }

  Future<void> _scrollToBottom() async {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    await _smoothScrollTo(target);
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _smoothScrollTo(0);
  }

  Future<void> _smoothScrollTo(double target) async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final clamped = target
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    final distance = (clamped - position.pixels).abs();
    if (distance < 1) {
      return;
    }

    final durationMs = (180 + (distance * 0.08)).clamp(180, 520).round();
    await _scrollController.animateTo(
      clamped,
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOutCubic,
    );
  }

  double? _offsetForMessageIndex(int index) {
    final keyContext = _messageKeys[index]?.currentContext;
    final renderObject = keyContext?.findRenderObject();
    if (renderObject == null ||
        !renderObject.attached ||
        !_scrollController.hasClients) {
      return null;
    }
    final viewport = RenderAbstractViewport.of(renderObject);
    final reveal = viewport.getOffsetToReveal(renderObject, 0).offset;
    final position = _scrollController.position;
    return reveal
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
  }

  int _resolveCurrentMessageIndex(int totalCount) {
    if (!_scrollController.hasClients || totalCount <= 1) {
      return 0;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) {
      return 0;
    }

    final ratio = (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0);
    final estimated = (ratio * (totalCount - 1)).round();

    var bestIndex = estimated;
    var bestDistance = double.infinity;
    final start = (estimated - 8).clamp(0, totalCount - 1);
    final end = (estimated + 8).clamp(0, totalCount - 1);
    for (var i = start; i <= end; i++) {
      final offset = _offsetForMessageIndex(i);
      if (offset == null) {
        continue;
      }
      final distance = (offset - position.pixels).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  Future<void> _scrollToMessageIndex({
    required int index,
    required int totalCount,
  }) {
    if (!_scrollController.hasClients || totalCount <= 0) {
      return Future.value();
    }

    final exactOffset = _offsetForMessageIndex(index);
    if (exactOffset != null) {
      return _smoothScrollTo(exactOffset);
    }

    final position = _scrollController.position;
    final normalized = totalCount <= 1 ? 0.0 : (index / (totalCount - 1));
    final estimated = position.maxScrollExtent * normalized;
    return _smoothScrollTo(estimated);
  }

  Future<void> _jumpConversation({
    required List<Message> messages,
    required bool forward,
  }) async {
    if (messages.isEmpty) {
      return;
    }

    final anchors = <int>[];
    for (var i = 0; i < messages.length; i++) {
      if (messages[i].type == MessageType.user) {
        anchors.add(i);
      }
    }
    if (anchors.isEmpty) {
      anchors.add(0);
    }

    final currentIndex = _resolveCurrentMessageIndex(messages.length);

    int? targetIndex;
    if (forward) {
      for (final anchor in anchors) {
        if (anchor > currentIndex) {
          targetIndex = anchor;
          break;
        }
      }
      if (targetIndex == null) {
        await _scrollToBottom();
        return;
      }
    } else {
      for (var i = anchors.length - 1; i >= 0; i--) {
        final anchor = anchors[i];
        if (anchor < currentIndex) {
          targetIndex = anchor;
          break;
        }
      }
      if (targetIndex == null) {
        await _scrollToTop();
        return;
      }
    }

    await _scrollToMessageIndex(
      index: targetIndex,
      totalCount: messages.length,
    );
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    return (_scrollController.position.maxScrollExtent -
            _scrollController.offset) <
        120;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: true,
      drawer: Sidebar(onClose: () => _scaffoldKey.currentState?.closeDrawer()),
      appBar: _buildAppBar(l10n),
      body: Column(
        children: [
          // 连接状态指示器
          _buildConnectionStatus(),
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, child) {
                final messageCount = provider.messages.length;
                _syncMessageKeys(messageCount);
                if (messageCount != _lastMessageCount) {
                  final shouldAutoScroll =
                      _lastMessageCount == 0 || _isNearBottom();
                  _lastMessageCount = messageCount;
                  if (shouldAutoScroll) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => unawaited(_scrollToBottom()),
                    );
                  }
                }

                if (provider.messages.isEmpty) {
                  return _buildEmptyState(l10n);
                }

                return Stack(
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: _onScrollNotification,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount: provider.messages.length,
                        itemBuilder: (context, index) {
                          return KeyedSubtree(
                            key: _messageKeyForIndex(index),
                            child: MessageBubble(
                              message: provider.messages[index],
                            ),
                          );
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IgnorePointer(
                        ignoring: !_showScrollButtons,
                        child: AnimatedOpacity(
                          opacity: _showScrollButtons ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildScrollButton(
                                  icon: Icons.vertical_align_top,
                                  tooltip: '顶部',
                                  onTap: () => unawaited(_scrollToTop()),
                                ),
                                const SizedBox(height: 8),
                                _buildScrollButton(
                                  icon: Icons.keyboard_arrow_up,
                                  tooltip: '上一对话',
                                  onTap: () => unawaited(
                                    _jumpConversation(
                                      messages: provider.messages,
                                      forward: false,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                _buildScrollButton(
                                  icon: Icons.keyboard_arrow_down,
                                  tooltip: '下一对话',
                                  onTap: () => unawaited(
                                    _jumpConversation(
                                      messages: provider.messages,
                                      forward: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildScrollButton(
                                  icon: Icons.vertical_align_bottom,
                                  tooltip: '底部',
                                  onTap: () => unawaited(_scrollToBottom()),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Consumer<ChatProvider>(
            builder: (context, provider, child) {
              return InputToolbar(
                onSend: (text) {
                  provider.sendMessage(text);
                },
                currentAgent: provider.currentAgent,
                onAgentChanged: (agent) {
                  provider.setAgent(agent);
                },
                contextUsage: provider.contextUsage,
                isConnected: provider.isConnected,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScrollButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.8),
        shape: const CircleBorder(),
        elevation: 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, color: Colors.black87, size: 22),
          ),
        ),
      ),
    );
  }

  /// 构建连接状态指示器
  Widget _buildConnectionStatus() {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        if (provider.isConnecting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: AppTheme.appleBlue.withValues(alpha: 0.1),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.appleBlue,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '正在连接...',
                  style: TextStyle(fontSize: 13, color: AppTheme.appleBlue),
                ),
              ],
            ),
          );
        }

        if (provider.errorMessage != null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: AppTheme.appleRed.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppTheme.appleRed,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    provider.errorMessage!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.appleRed,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    provider.clearError();
                    // 重试连接
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  PreferredSizeWidget _buildAppBar(AppLocalizations l10n) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Text(l10n.newChat),
      actions: [
        Consumer<ChatProvider>(
          builder: (context, provider, child) {
            final isConnected = provider.isConnected;
            final isConnecting = provider.isConnecting;

            return TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ServerManagementScreen(),
                  ),
                );
              },
              icon: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isConnecting
                      ? Colors.orange
                      : isConnected
                      ? AppTheme.appleGreen
                      : AppTheme.appleRed,
                  shape: BoxShape.circle,
                ),
              ),
              label: Text(
                isConnecting
                    ? '连接中'
                    : isConnected
                    ? l10n.online
                    : '离线',
                style: TextStyle(
                  fontSize: 15,
                  color: isConnecting
                      ? Colors.orange
                      : isConnected
                      ? AppTheme.appleGreen
                      : AppTheme.appleRed,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.lobsterRed, AppTheme.lobsterOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.lobsterRed.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text('🦞', style: TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.appTitle,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            '🦞 ${l10n.startConversation}',
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 32),
          _buildExampleCard(l10n.generalAssistantDesc, Icons.psychology),
          const SizedBox(height: 12),
          _buildExampleCard(l10n.codeAssistantDesc, Icons.code),
          const SizedBox(height: 12),
          _buildExampleCard(l10n.writingAssistantDesc, Icons.edit),
        ],
      ),
    );
  }

  Widget _buildExampleCard(String text, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.appleBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
