import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../screens/server_management_screen.dart';
import '../screens/settings_screen.dart';
import 'app_logo.dart';

class Sidebar extends StatelessWidget {
  final VoidCallback onClose;

  const Sidebar({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 280,
      color: isDark ? AppTheme.darkCard : AppTheme.appleCard,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, l10n),
            const Divider(),
            _buildSearchBar(context, l10n),
            const Divider(),
            _buildNewChatButton(context, l10n),
            Expanded(child: _buildConversationList(context, l10n)),
            const Divider(),
            _buildBottomActions(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16),
        child: Row(
          children: [
          const AppLogo(
            size: 40,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.appTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  l10n.online,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    size: 18,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.searchConversations,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNewChatButton(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: () {
          context.read<ChatProvider>().createNewConversation();
          onClose();
        },
        icon: const Icon(Icons.add, size: 20),
        label: Text(l10n.newChat),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.lobsterRed,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationList(BuildContext context, AppLocalizations l10n) {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        final conversations = provider.conversations;
        if (conversations.isEmpty) {
          return Center(
            child: Text(
              '暂无历史对话',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            final selected = _isSameSessionKey(
              provider.currentConversationId,
              conversation.id,
            );
            final displayTitle = provider.getConversationDisplayTitle(
              conversation.id,
              fallbackTitle: conversation.title,
            );
            final hasLocalNote =
                (provider.getConversationNote(conversation.id) ?? '')
                    .trim()
                    .isNotEmpty;
            return ListTile(
              dense: true,
              selected: selected,
              selectedTileColor: AppTheme.appleBlue.withValues(alpha: 0.1),
              leading: Icon(
                selected ? Icons.chat : Icons.chat_bubble_outline,
                size: 20,
                color: selected
                    ? AppTheme.appleBlue
                    : Theme.of(context).iconTheme.color,
              ),
              title: Text(
                displayTitle,
                style: const TextStyle(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _formatConversationTime(
                  context,
                  conversation.lastUpdated,
                  l10n,
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              trailing: PopupMenuButton<String>(
                tooltip: '会话操作',
                icon: Icon(
                  Icons.more_horiz,
                  size: 18,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                onSelected: (value) {
                  if (value == 'note') {
                    _renameConversation(context, provider, conversation);
                  } else if (value == 'clear_note') {
                    provider.clearConversationNote(conversation.id);
                  } else if (value == 'delete') {
                    _deleteConversation(context, provider, conversation);
                  }
                },
                itemBuilder: (context) {
                  final isMain = _isSameSessionKey(conversation.id, 'main');
                  final items = <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'note',
                      child: Text('本地备注'),
                    ),
                  ];
                  if (hasLocalNote) {
                    items.add(
                      const PopupMenuItem<String>(
                        value: 'clear_note',
                        child: Text('清除备注'),
                      ),
                    );
                  }
                  if (provider.canManageSessions && !isMain) {
                    items.add(
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('删除对话'),
                      ),
                    );
                  }
                  return items;
                },
              ),
              onTap: () {
                provider.switchConversation(conversation.id);
                onClose();
              },
            );
          },
        );
      },
    );
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

  Future<void> _renameConversation(
    BuildContext context,
    ChatProvider provider,
    Conversation conversation,
  ) async {
    final controller = TextEditingController(
      text: provider.getConversationNote(conversation.id) ?? '',
    );
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('本地备注'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 1,
          maxLength: 28,
          decoration: const InputDecoration(
            hintText: '输入备注（仅本机显示）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }

    await provider.setConversationNote(conversation.id, controller.text);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已保存备注'),
        backgroundColor: AppTheme.appleGreen,
      ),
    );
  }

  Future<void> _deleteConversation(
    BuildContext context,
    ChatProvider provider,
    Conversation conversation,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除对话'),
        content: Text(
          '确认删除「${provider.getConversationDisplayTitle(conversation.id, fallbackTitle: conversation.title)}」吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.appleRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    final ok = await provider.deleteConversation(conversation.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '已删除对话' : (provider.errorMessage ?? '删除失败')),
        backgroundColor: ok ? AppTheme.appleGreen : AppTheme.appleRed,
      ),
    );
  }

  String _formatConversationTime(
    BuildContext context,
    DateTime value,
    AppLocalizations l10n,
  ) {
    final now = DateTime.now();
    final date = DateTime(value.year, value.month, value.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(date).inDays;
    if (diff <= 0) {
      return l10n.today;
    }
    if (diff == 1) {
      return l10n.yesterday;
    }
    return '${value.month}/${value.day}';
  }

  Widget _buildBottomActions(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              final isDark = themeProvider.isDarkMode;
              return _buildActionButton(
                isDark ? Icons.light_mode : Icons.dark_mode,
                isDark ? '浅色' : '深色',
                () => themeProvider.toggleTheme(),
              );
            },
          ),
          _buildActionButton(Icons.settings, l10n.settings, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          }),
          _buildActionButton(Icons.wifi_tethering, l10n.aiServers, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ServerManagementScreen()),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: AppTheme.appleGray),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.appleGray),
          ),
        ],
      ),
    );
  }
}
