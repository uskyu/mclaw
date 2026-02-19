import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/gateway_service.dart';
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: true,
      drawer: Sidebar(
        onClose: () => _scaffoldKey.currentState?.closeDrawer(),
      ),
      appBar: _buildAppBar(l10n),
      body: Column(
        children: [
          // 连接状态指示器
          _buildConnectionStatus(),
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, child) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                
                if (provider.messages.isEmpty) {
                  return _buildEmptyState(l10n);
                }
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: provider.messages.length,
                  itemBuilder: (context, index) {
                    return MessageBubble(message: provider.messages[index]);
                  },
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

  /// 构建连接状态指示器
  Widget _buildConnectionStatus() {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        if (provider.isConnecting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: AppTheme.appleBlue.withOpacity(0.1),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.appleBlue),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '正在连接...',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.appleBlue,
                  ),
                ),
              ],
            ),
          );
        }

        if (provider.errorMessage != null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: AppTheme.appleRed.withOpacity(0.1),
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
                  color: AppTheme.lobsterRed.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '🦞',
                style: TextStyle(fontSize: 40),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.appTitle,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
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
