// 更新后的自动检测逻辑代码片段
// 这段代码应该替换掉原来的 onPressed 处理函数

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
          // 1. 检测 Gateway 配置
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

          // 2. 检查 CORS 配置
          if (result['needsCorsFix'] == true) {
            final shouldFix = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('⚠️ CORS 配置缺失'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('检测到 Gateway 缺少跨域配置，会导致连接失败。'),
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

              // 修复 CORS
              final fixResult = await SshConfigService.fixCorsConfig(
                host: sshHostController.text.trim(),
                port: int.tryParse(sshPortController.text) ?? 22,
                username: sshUsernameController.text.trim(),
                password: sshPasswordController.text,
                configPath: result['configPath'],
                currentConfig: fullConfig,
              );

              setDialogState(() => isDetecting = false);

              if (fixResult['success'] != true) {
                setDialogState(() {
                  detectionError = '修复失败: ${fixResult['error']}';
                });
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✓ ${fixResult['message']}'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }

          // 3. 填充配置
          remotePortController.text = result['port']?.toString() ?? '18789';
          gatewayTokenController.text = result['token']?.toString() ?? '';
          if (nameController.text.isEmpty) {
            nameController.text = 'OpenClaw ${sshHostController.text}';
          }

          // 4. 显示成功
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('✓ 检测成功'),
              content: Text('配置已获取，点击"添加并连接"开始使用'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('确定'),
                ),
              ],
            ),
          );

        } catch (e) {
          setDialogState(() {
            isDetecting = false;
            detectionError = '检测失败: $e';
          });
        }
      },
