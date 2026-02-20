import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../models/agent.dart';
import 'agent_selector.dart';
import 'attachment_menu.dart';
import 'right_drawers.dart';

class InputToolbar extends StatefulWidget {
  final Function(String) onSend;
  final Agent currentAgent;
  final Function(Agent) onAgentChanged;
  final double contextUsage;
  final bool isConnected;

  const InputToolbar({
    super.key,
    required this.onSend,
    required this.currentAgent,
    required this.onAgentChanged,
    required this.contextUsage,
    this.isConnected = true,
  });

  @override
  State<InputToolbar> createState() => _InputToolbarState();
}

class _InputToolbarState extends State<InputToolbar>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const List<MapEntry<String, String>> _quickCommands = [
    MapEntry('/help', '帮助'),
    MapEntry('/commands', '全部指令'),
    MapEntry('/status', '状态'),
    MapEntry('/new', '重置当前会话'),
    MapEntry('/reset', '重置会话'),
    MapEntry('/stop', '停止当前任务'),
    MapEntry('/context list', '上下文列表'),
    MapEntry('/context detail', '上下文详情'),
    MapEntry('/model', '模型菜单'),
    MapEntry('/model list', '模型列表'),
    MapEntry('/queue', '队列状态'),
    MapEntry('/whoami', '身份信息'),
    MapEntry('/think low', '低思考模式'),
    MapEntry('/verbose off', '关闭详细输出'),
    MapEntry('/usage tokens', '用量摘要'),
    MapEntry('/usage full', '用量完整'),
    MapEntry('/usage off', '关闭用量'),
  ];

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isAttachmentExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.125).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // 监听焦点变化，当输入框获得焦点时收起附件菜单
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _isAttachmentExpanded) {
        _closeAttachmentMenu();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // 监听键盘弹出/收起
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = View.of(context).viewInsets.bottom;
    if (bottomInset > 0 && _isAttachmentExpanded) {
      // 键盘弹出时收起附件菜单
      _closeAttachmentMenu();
    }
  }

  void _closeAttachmentMenu() {
    if (mounted) {
      setState(() {
        _isAttachmentExpanded = false;
        _animationController.reverse();
      });
    }
  }

  void _toggleAttachmentMenu() {
    setState(() {
      _isAttachmentExpanded = !_isAttachmentExpanded;
      if (_isAttachmentExpanded) {
        _animationController.forward();
        // 收起键盘
        _focusNode.unfocus();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _showAgentSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AgentSelector(
        currentAgent: widget.currentAgent,
        onAgentSelected: (agent) {
          widget.onAgentChanged(agent);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showOutlineDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const OutlineDrawer(),
    );
  }

  void _showContextDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ContextDrawer(
        usage: widget.contextUsage,
        currentTokens: 2450,
        maxTokens: 8000,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

    // 如果键盘可见，强制收起附件菜单
    if (isKeyboardVisible && _isAttachmentExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _closeAttachmentMenu();
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 输入框
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkSurface
                            : AppTheme.appleLightGray,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: null,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _sendMessage,
                        decoration: InputDecoration(
                          hintText: l10n.inputHint,
                          hintStyle: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSendButton(),
                ],
              ),
            ),
            // 工具栏按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _buildAgentButton(),
                  const SizedBox(width: 8),
                  _buildOutlineButton(),
                  const SizedBox(width: 8),
                  _buildContextButton(),
                  const SizedBox(width: 8),
                  _buildQuickCommandButton(),
                  const Spacer(),
                  _buildAnimatedAttachmentButton(),
                ],
              ),
            ),
            // 附件展开区域 - 键盘弹出时不显示
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: (_isAttachmentExpanded && !isKeyboardVisible)
                  ? AttachmentMenu(
                      onCompressHistory: () {
                        _toggleAttachmentMenu();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.compressHistory)),
                        );
                      },
                      onClearContext: () {
                        _toggleAttachmentMenu();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.clearContext)),
                        );
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedAttachmentButton() {
    return InkWell(
      onTap: _toggleAttachmentMenu,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationAnimation.value * 2 * 3.14159,
              child: Icon(
                _isAttachmentExpanded ? Icons.close : Icons.add,
                size: 22,
                color: _isAttachmentExpanded
                    ? AppTheme.appleRed
                    : AppTheme.appleGray,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAgentButton() {
    return InkWell(
      onTap: _showAgentSelector,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.lobsterRed, AppTheme.lobsterOrange],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🦞', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text(
              widget.currentAgent.name.substring(0, 1),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutlineButton() {
    return InkWell(
      onTap: _showOutlineDrawer,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: const Icon(
          Icons.format_list_bulleted,
          size: 20,
          color: AppTheme.appleGray,
        ),
      ),
    );
  }

  Widget _buildContextButton() {
    final percentage = (widget.contextUsage * 100).toInt();
    return InkWell(
      onTap: _showContextDrawer,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: widget.contextUsage,
                strokeWidth: 3,
                backgroundColor: AppTheme.appleLightGray,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.appleBlue,
                ),
              ),
            ),
            Text(
              '$percentage%',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppTheme.appleBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCommandButton() {
    return PopupMenuButton<String>(
      tooltip: '快捷指令',
      onSelected: (command) => _sendMessage(command),
      itemBuilder: (context) => _quickCommands
          .map(
            (entry) => PopupMenuItem<String>(
              value: entry.key,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.appleGray,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkSurface
              : AppTheme.appleLightGray,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flash_on_rounded, size: 18, color: AppTheme.appleBlue),
            SizedBox(width: 4),
            Text(
              '指令',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.appleBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return InkWell(
      onTap: () => _sendMessage(_controller.text),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppTheme.appleBlue,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
      ),
    );
  }

  void _sendMessage(String text) {
    if (text.trim().isNotEmpty) {
      if (!widget.isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('未连接到服务器，请先配置服务器'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      widget.onSend(text.trim());
      _controller.clear();
    }
  }
}
