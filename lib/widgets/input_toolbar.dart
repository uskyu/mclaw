import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../l10n/app_localizations.dart';
import '../models/chat_attachment.dart';
import '../theme/app_theme.dart';
import 'attachment_menu.dart';
import 'right_drawers.dart';

class InputToolbar extends StatefulWidget {
  final Future<void> Function(String, List<ChatAttachment>) onSend;
  final double contextUsage;
  final bool isConnected;
  final List<OutlineItem> outlineItems;
  final ValueChanged<int>? onOutlineSelected;

  const InputToolbar({
    super.key,
    required this.onSend,
    required this.contextUsage,
    this.isConnected = true,
    this.outlineItems = const [],
    this.onOutlineSelected,
  });

  @override
  State<InputToolbar> createState() => _InputToolbarState();
}

class _InputToolbarState extends State<InputToolbar>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const int _maxAttachmentBytes = 4_800_000;
  static const int _maxAttachmentCount = 3;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  final List<ChatAttachment> _pendingAttachments = [];
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

  void _showToast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  bool _isZhLocale() => Localizations.localeOf(context).languageCode == 'zh';

  List<MapEntry<String, String>> _quickCommands(bool isZh) {
    if (isZh) {
      return const [
        MapEntry('/status', '状态'),
        MapEntry('/new', '重置当前会话'),
        MapEntry('/stop', '停止当前任务'),
        MapEntry('/model', '模型菜单'),
        MapEntry('/help', '帮助'),
        MapEntry('/commands', '更多指令'),
        MapEntry('/usage tokens', '用量摘要'),
      ];
    }
    return const [
      MapEntry('/status', 'Status'),
      MapEntry('/new', 'Reset current session'),
      MapEntry('/stop', 'Stop current task'),
      MapEntry('/model', 'Model menu'),
      MapEntry('/help', 'Help'),
      MapEntry('/commands', 'More commands'),
      MapEntry('/usage tokens', 'Usage summary'),
    ];
  }

  String _mimeFromFileName(String fileName) {
    final ext = p.extension(fileName).toLowerCase().replaceFirst('.', '');
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _tryAddAttachmentFromPath(String path) async {
    final isZh = _isZhLocale();
    final file = File(path);
    if (!await file.exists()) {
      _showToast(isZh ? '文件不存在' : 'File does not exist');
      return;
    }

    final fileName = p.basename(path);
    final mimeType = _mimeFromFileName(fileName);
    if (!mimeType.startsWith('image/')) {
      _showToast(
        isZh ? '当前版本仅支持图片附件' : 'Only image attachments are supported',
      );
      return;
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      _showToast(isZh ? '文件为空，无法发送' : 'File is empty and cannot be sent');
      return;
    }
    if (bytes.length > _maxAttachmentBytes) {
      _showToast(
        isZh
            ? '图片过大，请选择 5MB 以内图片'
            : 'Image is too large. Please select one within 5MB',
      );
      return;
    }

    if (_pendingAttachments.length >= _maxAttachmentCount) {
      _showToast(
        isZh
            ? '最多附加 $_maxAttachmentCount 张图片'
            : 'Up to $_maxAttachmentCount images can be attached',
      );
      return;
    }

    final attachment = ChatAttachment(
      fileName: fileName,
      mimeType: mimeType,
      base64Data: base64Encode(bytes),
      bytes: bytes.length,
      localPath: path,
    );

    setState(() {
      _pendingAttachments.add(attachment);
      _isAttachmentExpanded = false;
      _animationController.reverse();
    });
  }

  Future<void> _pickFromCamera() async {
    final isZh = _isZhLocale();
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (picked == null) {
        return;
      }
      await _tryAddAttachmentFromPath(picked.path);
    } catch (e) {
      _showToast(isZh ? '拍照失败: $e' : 'Failed to take photo: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    final isZh = _isZhLocale();
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 86,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (picked == null) {
        return;
      }
      await _tryAddAttachmentFromPath(picked.path);
    } catch (e) {
      _showToast(isZh ? '选择相册失败: $e' : 'Failed to pick photo: $e');
    }
  }

  Future<void> _pickFromFile() async {
    _closeAttachmentMenu();
    final isZh = _isZhLocale();
    _showToast(
      isZh
          ? '文件上传开发中，当前接口暂仅支持图片'
          : 'File upload is under development; current API supports images only',
    );
  }

  void _removeAttachmentAt(int index) {
    if (index < 0 || index >= _pendingAttachments.length) {
      return;
    }
    setState(() {
      _pendingAttachments.removeAt(index);
    });
  }

  void _showOutlineDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OutlineDrawer(
        items: widget.outlineItems,
        onSelected: (item) {
          widget.onOutlineSelected?.call(item.messageIndex);
        },
      ),
    );
  }

  void _showQuickCommandSheet() {
    final isZh = _isZhLocale();
    final quickCommands = _quickCommands(isZh);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.appleGray.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: AppTheme.appleBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isZh ? '快捷指令' : 'Quick Commands',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(isZh ? '关闭' : 'Close'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: quickCommands.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Theme.of(context).dividerTheme.color,
                    ),
                    itemBuilder: (context, index) {
                      final entry = quickCommands[index];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 2,
                        ),
                        title: Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : AppTheme.appleLightGray.withValues(
                                    alpha: 0.75,
                                  ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _sendMessage(entry.key, includeAttachments: false);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showContextUsageHint() {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isZh ? '上下文用量说明' : 'Context Usage Note'),
        content: Text(
          isZh
              ? '官方暂未提供实时上下文用量接口，当前百分比仅会在每次状态查询时更新。'
              : 'The official API does not provide real-time context usage. This percentage only updates when status is queried.',
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pendingAttachments.isNotEmpty)
              SizedBox(
                height: 42,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  scrollDirection: Axis.horizontal,
                  itemCount: _pendingAttachments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = _pendingAttachments[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkSurface
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.1)
                              : AppTheme.appleLightGray,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.image_outlined,
                            size: 14,
                            color: AppTheme.appleBlue,
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(
                              item.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _removeAttachmentAt(index),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: AppTheme.appleGray,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            // 输入框
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkSurface
                            : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : AppTheme.appleLightGray,
                        ),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                children: [
                  _buildQuickCommandButton(),
                  const SizedBox(width: 10),
                  _buildOutlineButton(),
                  const SizedBox(width: 10),
                  _buildContextButton(),
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
                      onTakePicture: () {
                        unawaited(_pickFromCamera());
                      },
                      onPickPhoto: () {
                        unawaited(_pickFromGallery());
                      },
                      onPickFile: () {
                        unawaited(_pickFromFile());
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
      onTap: _showContextUsageHint,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: _showQuickCommandSheet,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : AppTheme.appleLightGray,
          ),
        ),
        child: const Icon(
          Icons.flash_on_rounded,
          size: 18,
          color: AppTheme.appleBlue,
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

  void _sendMessage(String text, {bool includeAttachments = true}) {
    final normalized = text.trim();
    final attachments = includeAttachments
        ? List<ChatAttachment>.from(_pendingAttachments)
        : <ChatAttachment>[];

    if (normalized.isEmpty && attachments.isEmpty) {
      return;
    }

    if (!widget.isConnected) {
      final isZh = _isZhLocale();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isZh
                ? '未连接到服务器，请先配置服务器'
                : 'Not connected. Please configure a server first',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(widget.onSend(normalized, attachments));
    _controller.clear();
    if (_pendingAttachments.isNotEmpty) {
      setState(() {
        _pendingAttachments.clear();
      });
    }
  }
}
