import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_logo.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          // 用户信息
          _buildUserSection(context),
          const Divider(),
          // 外观
          _buildSectionHeader(l10n.appearance),
          _buildDarkModeTile(l10n),
          const Divider(),
          // 通用
          _buildSectionHeader(l10n.general),
          _buildLanguageTile(context, l10n),
          _buildListTile(
            icon: Icons.notifications_outlined,
            title: l10n.notifications,
            onTap: () {},
          ),
          _buildListTile(
            icon: Icons.lock_outline,
            title: l10n.privacy,
            onTap: () {},
          ),
          const Divider(),
          // 关于
          _buildSectionHeader(l10n.about),
          _buildListTile(
            icon: Icons.info_outline,
            title: l10n.aboutApp,
            subtitle: 'v1.0.0',
            onTap: () {},
          ),
          _buildListTile(
            icon: Icons.help_outline,
            title: l10n.help,
            onTap: () {},
          ),
          const Divider(),
          // 危险区域
          _buildSectionHeader(l10n.dangerZone, isDanger: true),
          _buildDangerTile(
            icon: Icons.delete_outline,
            title: l10n.clearAllData,
            onTap: () => _showClearDataDialog(context, l10n),
          ),
          _buildDangerTile(
            icon: Icons.person_remove_outlined,
            title: l10n.deleteAccount,
            onTap: () => _showDeleteAccountDialog(context, l10n),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildUserSection(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.lobsterRed, AppTheme.lobsterOrange],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: AppLogo(
            size: 50,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      title: const Text(
        'User',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        'user@example.com',
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.appleGray),
      onTap: () {},
    );
  }

  Widget _buildSectionHeader(String title, {bool isDanger = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDanger ? AppTheme.appleRed : AppTheme.appleGray,
        ),
      ),
    );
  }

  Widget _buildDarkModeTile(AppLocalizations l10n) {
    return Consumer<ThemeProvider>(
      builder: (context, provider, child) {
        return SwitchListTile(
          secondary: const Icon(Icons.dark_mode_outlined, color: AppTheme.appleGray),
          title: Text(l10n.darkMode),
          value: provider.isDarkMode,
          onChanged: (value) => provider.setDarkMode(value),
        );
      },
    );
  }

  Widget _buildLanguageTile(BuildContext context, AppLocalizations l10n) {
    return Consumer<ThemeProvider>(
      builder: (context, provider, child) {
        final isZh = provider.locale.languageCode == 'zh';
        return ListTile(
          leading: const Icon(Icons.language, color: AppTheme.appleGray),
          title: Text(l10n.language),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isZh ? '中文' : 'English',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppTheme.appleGray),
            ],
          ),
          onTap: () {
            provider.toggleLocale();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isZh ? 'Switched to English' : '已切换到中文'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.appleGray),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right, color: AppTheme.appleGray),
      onTap: onTap,
    );
  }

  Widget _buildDangerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.appleRed),
      title: Text(
        title,
        style: const TextStyle(color: AppTheme.appleRed),
      ),
      onTap: onTap,
    );
  }

  void _showClearDataDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearAllData),
        content: Text('${l10n.clearAllData} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.clearAllData)),
              );
            },
            child: Text(l10n.clearAllData, style: const TextStyle(color: AppTheme.appleRed)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAccount),
        content: Text('${l10n.deleteAccount} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.deleteAccount)),
              );
            },
            child: Text(l10n.deleteAccount, style: const TextStyle(color: AppTheme.appleRed)),
          ),
        ],
      ),
    );
  }
}
