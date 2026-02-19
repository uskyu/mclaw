import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../screens/server_management_screen.dart';
import '../screens/settings_screen.dart';

class Sidebar extends StatelessWidget {
  final VoidCallback onClose;

  const Sidebar({
    super.key,
    required this.onClose,
  });

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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.lobsterRed, AppTheme.lobsterOrange],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text(
                '🦞',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
            ),
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
    final conversations = [
      {'title': l10n.generalAssistant, 'time': l10n.today},
      {'title': 'React Native', 'time': l10n.yesterday},
      {'title': 'Flutter', 'time': l10n.yesterday},
      {'title': 'Python', 'time': l10n.past7Days},
      {'title': 'Machine Learning', 'time': l10n.past7Days},
    ];

    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return ListTile(
          leading: const Icon(Icons.chat_bubble_outline, size: 20),
          title: Text(
            conversation['title']!,
            style: const TextStyle(fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            onClose();
          },
        );
      },
    );
  }

  Widget _buildBottomActions(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(Icons.auto_awesome, 'AI', () {}),
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
