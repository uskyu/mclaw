import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/theme_provider.dart';
import '../services/background_runtime_service.dart';
import '../services/notification_service.dart';
import '../services/secure_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _repoUrl = 'https://github.com/uskyu/clawchat-app';
  bool _notificationsEnabled = true;
  bool _backgroundRunningEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final notifications = await SecureStorageService.loadNotificationsEnabled();
    final background = await SecureStorageService.loadBackgroundRunningEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      if (notifications != null) {
        _notificationsEnabled = notifications;
      }
      if (background != null) {
        _backgroundRunningEnabled = background;
      }
    });
  }

  bool _isZh(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'zh';
  }

  Future<void> _setNotificationsEnabled(bool enabled) async {
    if (enabled) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted && mounted) {
        final isZh = _isZh(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isZh
                  ? '通知权限未授予，可能无法收到完成提醒'
                  : 'Notification permission is not granted; completion alerts may be unavailable',
            ),
          ),
        );
      }
    }
    setState(() => _notificationsEnabled = enabled);
    await SecureStorageService.saveNotificationsEnabled(enabled);
  }

  Future<void> _setBackgroundRunningEnabled(bool enabled) async {
    setState(() => _backgroundRunningEnabled = enabled);
    await SecureStorageService.saveBackgroundRunningEnabled(enabled);
    if (enabled) {
      await BackgroundRuntimeService.instance.enable();
    } else {
      await BackgroundRuntimeService.instance.disable();
    }
  }

  Future<void> _copyRepoUrl() async {
    await Clipboard.setData(const ClipboardData(text: _repoUrl));
    if (!mounted) {
      return;
    }
    final isZh = _isZh(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isZh ? '项目地址已复制' : 'Repository URL copied'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _openRepoUrl() async {
    final uri = Uri.parse(_repoUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      final isZh = _isZh(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isZh ? '无法打开链接，请手动复制访问' : 'Unable to open link. Please copy and open manually.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isZh = _isZh(context);

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
          _buildUserSection(context, isZh),
          const Divider(),
          _buildSectionHeader(l10n.general),
          _buildLanguageTile(context, l10n),
          _buildNotificationsTile(context, l10n),
          _buildBackgroundRuntimeTile(context, isZh),
          _buildListTile(
            icon: Icons.lock_outline,
            title: l10n.privacy,
            onTap: () => _showPrivacyDialog(context, isZh),
          ),
          const Divider(),
          _buildSectionHeader(l10n.about),
          _buildListTile(
            icon: Icons.info_outline,
            title: l10n.aboutApp,
            subtitle: 'v1.0.0',
            onTap: () => _showAboutDialog(context, isZh),
          ),
          _buildListTile(
            icon: Icons.help_outline,
            title: l10n.help,
            onTap: () => _showHelpDialog(context, isZh),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildUserSection(BuildContext context, bool isZh) {
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
      title: Text(
        isZh ? 'MClaw 用户功能' : 'MClaw User Features',
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        isZh ? '待开发' : 'Coming soon',
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
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

  Widget _buildLanguageTile(BuildContext context, AppLocalizations l10n) {
    return Consumer<ThemeProvider>(
      builder: (context, provider, child) {
        final currentCode =
            provider.locale?.languageCode ?? Localizations.localeOf(context).languageCode;
        final isZh = currentCode == 'zh';
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
            provider.toggleLocale(Localizations.localeOf(context));
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

  Widget _buildNotificationsTile(BuildContext context, AppLocalizations l10n) {
    final isZh = _isZh(context);
    return ListTile(
      leading: const Icon(Icons.notifications_outlined, color: AppTheme.appleGray),
      title: Text(l10n.notifications),
      subtitle: Text(
        isZh
            ? '建议开启通知并关闭省电管理，保障后台任务提醒'
            : 'Enable notifications and disable battery optimization for reliable background alerts',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: isZh ? '通知权限说明' : 'Notification permission help',
            icon: const Icon(
              Icons.help_outline,
              size: 20,
              color: AppTheme.appleGray,
            ),
            onPressed: () => _showNotificationHelpDialog(context, isZh),
          ),
          Switch(
            value: _notificationsEnabled,
            onChanged: (value) => _setNotificationsEnabled(value),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundRuntimeTile(BuildContext context, bool isZh) {
    return SwitchListTile(
      secondary: const Icon(Icons.run_circle_outlined, color: AppTheme.appleGray),
      title: Text(isZh ? '后台运行' : 'Background Running'),
      subtitle: Text(isZh ? '保持连接与任务状态' : 'Keep connection and task state'),
      value: _backgroundRunningEnabled,
      onChanged: (value) => _setBackgroundRunningEnabled(value),
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

  void _showPrivacyDialog(BuildContext context, bool isZh) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isZh ? '隐私说明' : 'Privacy'),
        content: Text(
          isZh
              ? '项目开源地址:\n$_repoUrl\n\n所有聊天数据、配置与记录默认保存在本地设备，不会主动上传到第三方服务。'
              : 'Open-source repository:\n$_repoUrl\n\nAll chat data, settings, and records are stored locally on your device by default and are not uploaded to third-party services proactively.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isZh ? '我知道了' : 'Got it'),
          ),
        ],
      ),
    );
  }

  void _showNotificationHelpDialog(BuildContext context, bool isZh) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isZh ? '通知接收说明' : 'Notification Requirements'),
        content: Text(
          isZh
              ? '为确保及时收到任务完成提醒，请开启：\n1. 系统通知权限\n2. MClaw 的通知横幅/弹窗\n3. 允许后台运行（建议关闭电池优化）'
              : 'To reliably receive task completion alerts, enable:\n1. System notification permission\n2. Banner/pop-up notifications for MClaw\n3. Background running (battery optimization off is recommended)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isZh ? '知道了' : 'OK'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context, bool isZh) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isZh ? '关于开发者' : 'About Developer'),
        content: Text(
          isZh
              ? '应用名称: MClaw\n版本: 1.0.0\n开发者: uskyu\n定位: 面向 OpenClaw 的移动端客户端。\n\n项目地址:\n$_repoUrl'
              : 'App: MClaw\nVersion: 1.0.0\nDeveloper: uskyu\nPositioning: A mobile client for OpenClaw.\n\nProject URL:\n$_repoUrl',
        ),
        actions: [
          TextButton(
            onPressed: _copyRepoUrl,
            child: Text(isZh ? '复制链接' : 'Copy Link'),
          ),
          TextButton(
            onPressed: _openRepoUrl,
            child: Text(isZh ? '打开链接' : 'Open Link'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isZh ? '关闭' : 'Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context, bool isZh) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isZh ? '使用流程' : 'How to Use'),
        content: Text(
          isZh
              ? '1. 进入服务器管理，添加服务器。\n2. 点击自动检测/修复网关配置。\n3. 连接成功后返回聊天页。\n4. 输入消息或发送图片，等待流式响应。\n5. 需要时在侧边栏切换主题和管理会话。'
              : '1. Open Server Management and add a server.\n2. Run auto-detect/auto-fix for gateway config.\n3. Return to chat after connection succeeds.\n4. Send text or images and wait for streaming responses.\n5. Use the sidebar for theme switching and session management.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isZh ? '知道了' : 'OK'),
          ),
        ],
      ),
    );
  }
}
