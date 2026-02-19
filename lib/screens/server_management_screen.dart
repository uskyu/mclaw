import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../models/server.dart';
import '../services/secure_storage_service.dart';
import '../services/gateway_service.dart';
import '../services/ssh_config_service.dart';

class ServerManagementScreen extends StatefulWidget {
  const ServerManagementScreen({super.key});

  @override
  State<ServerManagementScreen> createState() => _ServerManagementScreenState();
}

class _ServerManagementScreenState extends State<ServerManagementScreen> {
  List<Server> servers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    final loadedServers = await SecureStorageService.loadServers();
    setState(() {
      servers = loadedServers;
      isLoading = false;
    });
  }

  Future<void> _saveServers() async {
    await SecureStorageService.saveServers(servers);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.aiServers),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadServers,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : servers.isEmpty
              ? _buildEmptyState(l10n)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: servers.length + 1,
                  itemBuilder: (context, index) {
                    if (index == servers.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: _buildAddButton(l10n),
                      );
                    }
                    return _buildServerCard(servers[index]);
                  },
                ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无服务器',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加 OpenClaw 服务器',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: _buildAddButton(l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildServerCard(Server server) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: server.isActive
              ? AppTheme.appleBlue.withValues(alpha: 0.5)
              : (Theme.of(context).dividerTheme.color ?? Colors.transparent),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: server.isActive ? AppTheme.appleGreen : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${server.sshHost}:${server.sshPort}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: AppTheme.appleBlue),
                onPressed: () => _showEditServerDialog(server),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: AppTheme.appleRed),
                onPressed: () => _deleteServer(server),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.router_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gateway: ${server.remoteHost}:${server.remotePort}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!server.isActive)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _activateServer(server),
                icon: const Icon(Icons.link, size: 18),
                label: const Text('连接'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.appleBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _testConnection(server),
                icon: const Icon(Icons.check_circle, size: 18, color: AppTheme.appleGreen),
                label: const Text('已连接'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.appleGreen,
                  side: const BorderSide(color: AppTheme.appleGreen),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddButton(AppLocalizations l10n) {
    return ElevatedButton.icon(
      onPressed: () => _showAddServerDialog(l10n),
      icon: const Icon(Icons.add),
      label: Text(l10n.addServer),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.appleBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _activateServer(Server server) async {
    setState(() {
      servers = servers.map((s) => s.copyWith(
        isActive: s.id == server.id,
      )).toList();
    });
    
    await _saveServers();
    await SecureStorageService.saveActiveServerId(server.id);

    if (server.type == ServerType.openclaw) {
      final gatewayService = context.read<GatewayService>();
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      final success = await gatewayService.connect(server);
      
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ 已连接到: ${server.name}'),
              backgroundColor: AppTheme.appleGreen,
            ),
          );
          Navigator.pop(context);
        } else {
          final errorMsg = gatewayService.errorMessage ?? '';
          
          // 检查是否是 CORS 相关错误
          if (_isCorsError(errorMsg)) {
            // 显示 CORS 修复对话框
            final shouldFix = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('⚠️ CORS 配置缺失'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('连接被拒绝：服务器缺少跨域配置。'),
                    const SizedBox(height: 8),
                    Text('错误: $errorMsg', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 16),
                    const Text(
                      '点击"自动修复"将自动修改服务器配置文件',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('自动修复'),
                  ),
                ],
              ),
            );

            if (shouldFix == true && mounted) {
              await _performCorsFix(server);
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✗ 连接失败: $errorMsg'),
                backgroundColor: AppTheme.appleRed,
              ),
            );
          }
        }
      }
    }
  }

  /// 检查错误是否是 CORS 相关
  bool _isCorsError(String errorMsg) {
    final lowerMsg = errorMsg.toLowerCase();
    return lowerMsg.contains('origin') || 
           lowerMsg.contains('cors') || 
           lowerMsg.contains('not allowed') ||
           lowerMsg.contains('403') ||
           lowerMsg.contains('403');
  }

  /// 执行 CORS 自动修复
  Future<void> _performCorsFix(Server server) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // 1. 检测配置
      final result = await SshConfigService.detectGatewayConfig(
        host: server.sshHost!,
        port: server.sshPort ?? 22,
        username: server.sshUsername!,
        password: server.sshPassword ?? '',
      );

      if (mounted) Navigator.pop(context);

      if (result['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✗ 配置检测失败: ${result['error']}'),
              backgroundColor: AppTheme.appleRed,
            ),
          );
        }
        return;
      }

      // 2. 读取完整配置
      final fullConfig = await SshConfigService.readFullConfig(
        host: server.sshHost!,
        port: server.sshPort ?? 22,
        username: server.sshUsername!,
        password: server.sshPassword ?? '',
        configPath: result['configPath'],
      );

      // 3. 修复 CORS
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final fixResult = await SshConfigService.fixCorsConfig(
        host: server.sshHost!,
        port: server.sshPort ?? 22,
        username: server.sshUsername!,
        password: server.sshPassword ?? '',
        configPath: result['configPath'],
        currentConfig: fullConfig,
      );

      if (mounted) Navigator.pop(context);

      if (fixResult['success'] == true) {
        // 重启 Gateway 服务
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ 配置已修复，正在重启 Gateway...'),
              backgroundColor: AppTheme.appleGreen,
              duration: Duration(seconds: 2),
            ),
          );
        }

        final restartResult = await SshConfigService.restartGateway(
          host: server.sshHost!,
          port: server.sshPort ?? 22,
          username: server.sshUsername!,
          password: server.sshPassword ?? '',
        );

        if (restartResult['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✓ ${restartResult['message']}，正在连接...'),
                backgroundColor: AppTheme.appleGreen,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          
          // 等待服务完全启动
          await Future.delayed(const Duration(seconds: 2));
          await _activateServer(server);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ ${restartResult['error']}'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✗ 配置修复失败: ${fixResult['error']}'),
              backgroundColor: AppTheme.appleRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ 修复过程出错: $e'),
            backgroundColor: AppTheme.appleRed,
          ),
        );
      }
    }
  }

  Future<void> _testConnection(Server server) async {
    final gatewayService = context.read<GatewayService>();
    
    // 显示加载中
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    // 尝试连接
    final success = await gatewayService.connect(server);
    
    if (mounted) Navigator.pop(context);
    
    if (mounted) {
      if (success) {
        // 更新服务器状态为活跃
        setState(() {
          servers = servers.map((s) => s.copyWith(
            isActive: s.id == server.id,
          )).toList();
        });
        await _saveServers();
        await SecureStorageService.saveActiveServerId(server.id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ 连接成功: ${server.name}'),
            backgroundColor: AppTheme.appleGreen,
          ),
        );
      } else {
        final errorMsg = gatewayService.errorMessage ?? '';
        
        // 检查是否是 CORS 相关错误
        if (_isCorsError(errorMsg)) {
          // 显示 CORS 修复对话框
          final shouldFix = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('⚠️ CORS 配置缺失'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('连接被拒绝：服务器缺少跨域配置。'),
                  const SizedBox(height: 8),
                  Text('错误: $errorMsg', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  const Text(
                    '点击"自动修复"将自动修改服务器配置文件',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('自动修复'),
                ),
              ],
            ),
          );

          if (shouldFix == true && mounted) {
            await _performCorsFix(server);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✗ 连接失败: $errorMsg'),
              backgroundColor: AppTheme.appleRed,
            ),
          );
        }
      }
    }
  }

  void _deleteServer(Server server) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text('确定要删除 "${server.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                servers.removeWhere((s) => s.id == server.id);
              });
              await _saveServers();
              
              if (server.isActive) {
                final gatewayService = context.read<GatewayService>();
                await gatewayService.disconnect();
              }
              
              if (mounted) Navigator.pop(context);
            },
            child: Text(l10n.delete, style: const TextStyle(color: AppTheme.appleRed)),
          ),
        ],
      ),
    );
  }

  void _showAddServerDialog(AppLocalizations l10n) {
    _showServerDialog(l10n);
  }

  void _showEditServerDialog(Server server) {
    final l10n = AppLocalizations.of(context)!;
    _showServerDialog(l10n, server: server);
  }

  void _showServerDialog(AppLocalizations l10n, {Server? server}) {
    final isEditing = server != null;
    
    // Controllers - 设置默认值
    final nameController = TextEditingController(text: server?.name ?? '');
    final sshHostController = TextEditingController(text: server?.sshHost ?? '');
    final sshPortController = TextEditingController(text: (server?.sshPort ?? 22).toString());
    final sshUsernameController = TextEditingController(text: server?.sshUsername ?? 'root');
    final sshPasswordController = TextEditingController(text: server?.sshPassword ?? '');
    final remotePortController = TextEditingController(text: (server?.remotePort ?? 18789).toString());
    final localPortController = TextEditingController(text: (server?.localPort ?? 18789).toString());
    final gatewayTokenController = TextEditingController(text: server?.gatewayToken ?? '');
    
    ServerType selectedType = server?.type ?? ServerType.openclaw;
    bool isDetecting = false;
    String? detectionError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
              maxWidth: 600,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.appleBlue.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.appleBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.dns, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? '编辑服务器' : '添加服务器',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '配置 OpenClaw Gateway 连接',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Server Name
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: '服务器名称（可选）',
                            hintText: '例如：我的 OpenClaw',
                            prefixIcon: const Icon(Icons.label_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // SSH Section - 简化版，突出 IP 和密码
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.withValues(alpha: 0.08), Colors.blue.withValues(alpha: 0.02)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.cloud, color: Colors.blue[700], size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '服务器连接',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue[800],
                                          ),
                                        ),
                                        Text(
                                          '输入 IP 地址和密码即可自动检测',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.blue[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              
                              // IP 地址 - 主要输入
                              TextField(
                                controller: sshHostController,
                                decoration: InputDecoration(
                                  labelText: '服务器 IP 地址 *',
                                  hintText: '例如：38.55.181.247',
                                  prefixIcon: const Icon(Icons.computer_outlined),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blue.withValues(alpha: 0.2)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blue, width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // 密码 - 主要输入
                              TextField(
                                controller: sshPasswordController,
                                decoration: InputDecoration(
                                  labelText: 'SSH 密码 *',
                                  hintText: '输入服务器密码',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blue.withValues(alpha: 0.2)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blue, width: 2),
                                  ),
                                ),
                                obscureText: true,
                              ),
                              const SizedBox(height: 16),
                              
                              // 展开高级选项
                              ExpansionTile(
                                title: Text(
                                  '高级选项',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                children: [
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: sshPortController,
                                          decoration: InputDecoration(
                                            labelText: 'SSH 端口',
                                            hintText: '22',
                                            prefixIcon: const Icon(Icons.settings_ethernet),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextField(
                                          controller: sshUsernameController,
                                          decoration: InputDecoration(
                                            labelText: '用户名',
                                            hintText: 'root',
                                            prefixIcon: const Icon(Icons.person_outline),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 自动检测按钮 - 突出显示
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: isDetecting
                                ? null
                                : () async {
                                    if (sshHostController.text.isEmpty) {
                                      setDialogState(() {
                                        detectionError = '请输入服务器 IP 地址';
                                      });
                                      return;
                                    }
                                    if (sshPasswordController.text.isEmpty) {
                                      setDialogState(() {
                                        detectionError = '请输入 SSH 密码';
                                      });
                                      return;
                                    }

                                    setDialogState(() {
                                      isDetecting = true;
                                      detectionError = null;
                                    });

                                    try {
                                      // 调用 SSH 配置检测（包含 CORS 检查）
                                      final result = await SshConfigService.detectGatewayConfig(
                                        host: sshHostController.text.trim(),
                                        port: int.tryParse(sshPortController.text) ?? 22,
                                        username: sshUsernameController.text.trim(),
                                        password: sshPasswordController.text,
                                      );
                                      
                                      setDialogState(() {
                                        isDetecting = false;
                                      });

                                      if (result['success'] != true) {
                                        setDialogState(() {
                                          detectionError = result['error'] ?? '检测失败';
                                        });
                                        return;
                                      }

                                      // 检查是否需要修复 CORS
                                      if (result['needsCorsFix'] == true) {
                                        if (mounted) {
                                          final shouldFix = await showDialog<bool>(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (context) => AlertDialog(
                                              title: const Text('⚠️ CORS 配置缺失'),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('检测到 Gateway 缺少跨域配置，会导致连接失败。'),
                                                  const SizedBox(height: 8),
                                                  Text('问题: ${result['corsIssue']}'),
                                                  const SizedBox(height: 16),
                                                  const Text(
                                                    '点击"自动修复"将自动修改服务器配置文件',
                                                    style: TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('跳过'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.orange,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                  child: const Text('自动修复'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (shouldFix == true) {
                                            setDialogState(() => isDetecting = true);

                                            // 读取完整配置
                                            final fullConfig = await SshConfigService.readFullConfig(
                                              host: sshHostController.text.trim(),
                                              port: int.tryParse(sshPortController.text) ?? 22,
                                              username: sshUsernameController.text.trim(),
                                              password: sshPasswordController.text,
                                              configPath: result['configPath'],
                                            );

                                            // 修复配置
                                            final fixResult = await SshConfigService.fixCorsConfig(
                                              host: sshHostController.text.trim(),
                                              port: int.tryParse(sshPortController.text) ?? 22,
                                              username: sshUsernameController.text.trim(),
                                              password: sshPasswordController.text,
                                              configPath: result['configPath'],
                                              currentConfig: fullConfig,
                                            );

                                            if (fixResult['success'] != true) {
                                              setDialogState(() {
                                                isDetecting = false;
                                                detectionError = '配置修复失败: ${fixResult['error']}';
                                              });
                                              return;
                                            }

                                            // 重启 Gateway
                                            final restartResult = await SshConfigService.restartGateway(
                                              host: sshHostController.text.trim(),
                                              port: int.tryParse(sshPortController.text) ?? 22,
                                              username: sshUsernameController.text.trim(),
                                              password: sshPasswordController.text,
                                            );

                                            setDialogState(() => isDetecting = false);

                                            if (restartResult['success'] != true) {
                                              setDialogState(() {
                                                detectionError = '${restartResult['error']}（配置已修复）';
                                              });
                                            } else if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('✓ 配置已修复，Gateway 已重启'),
                                                  backgroundColor: AppTheme.appleGreen,
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      }

                                      // 填充配置
                                      remotePortController.text = result['port']?.toString() ?? '18789';
                                      gatewayTokenController.text = result['token']?.toString() ?? '';
                                      
                                      if (nameController.text.isEmpty) {
                                        nameController.text = 'OpenClaw ${sshHostController.text}';
                                      }

                                      // 显示成功提示
                                      if (mounted) {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Row(
                                              children: [
                                                Icon(Icons.check_circle, color: AppTheme.appleGreen),
                                                const SizedBox(width: 8),
                                                const Text('检测成功'),
                                              ],
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('✓ Gateway 端口: ${result['port'] ?? 18789}'),
                                                if (result['token'] != null) 
                                                  Text('✓ Token 已自动填充'),
                                                if (result['hasCorsConfig'] == true || result['needsCorsFix'] == false)
                                                  Text('✓ CORS 配置正常'),
                                                const SizedBox(height: 8),
                                                Text(
                                                  '配置已自动填充，点击"添加并连接"即可',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('确定'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setDialogState(() {
                                        isDetecting = false;
                                        detectionError = '连接失败: ${e.toString()}';
                                      });
                                    }
                                  },
                            icon: isDetecting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.auto_fix_high, size: 24),
                            label: Text(
                              isDetecting ? '正在检测配置...' : '🔍 自动检测 Gateway 配置',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                        
                        // 错误提示
                        if (detectionError != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    detectionError!,
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 24),

                        // Gateway Section - 可折叠
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ExpansionTile(
                            title: Row(
                              children: [
                                Icon(Icons.settings, color: Colors.grey[700], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '手动配置（可选）',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: remotePortController,
                                      decoration: InputDecoration(
                                        labelText: 'Gateway 端口',
                                        hintText: '18789',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: localPortController,
                                      decoration: InputDecoration(
                                        labelText: '本地端口',
                                        hintText: '18789',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: gatewayTokenController,
                                decoration: InputDecoration(
                                  labelText: 'Gateway Token',
                                  hintText: '自动检测或手动输入',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Footer
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            // 验证必填项
                            if (sshHostController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('请输入服务器 IP 地址')),
                              );
                              return;
                            }
                            
                            final newServer = Server.openclaw(
                              id: isEditing ? server!.id : DateTime.now().millisecondsSinceEpoch.toString(),
                              name: nameController.text.isEmpty 
                                  ? 'OpenClaw ${sshHostController.text}' 
                                  : nameController.text,
                              sshHost: sshHostController.text.trim(),
                              sshPort: int.tryParse(sshPortController.text) ?? 22,
                              sshUsername: sshUsernameController.text.trim(),
                              sshPassword: sshPasswordController.text,
                              remotePort: int.tryParse(remotePortController.text) ?? 18789,
                              localPort: int.tryParse(localPortController.text) ?? 18789,
                              gatewayToken: gatewayTokenController.text,
                              isActive: true, // 新服务器默认设为活跃
                            );

                            setState(() {
                              if (isEditing) {
                                final index = servers.indexWhere((s) => s.id == server!.id);
                                if (index >= 0) {
                                  servers[index] = newServer;
                                }
                              } else {
                                // 新服务器：取消其他服务器的活跃状态
                                servers = servers.map((s) => s.copyWith(isActive: false)).toList();
                                servers.add(newServer);
                              }
                            });

                            await _saveServers();
                            await SecureStorageService.saveActiveServerId(newServer.id);

                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEditing ? '✓ 服务器已更新' : '✓ 服务器已添加，正在连接...'),
                                  backgroundColor: AppTheme.appleGreen,
                                ),
                              );
                              
                              // 自动连接
                              await _activateServer(newServer);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.appleBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(isEditing ? '保存并连接' : '添加并连接'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
