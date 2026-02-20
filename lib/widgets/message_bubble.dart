import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../l10n/app_localizations.dart';
import '../models/message.dart';
import '../theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isUser = message.type == MessageType.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasTextContent = message.content.trim().isNotEmpty;
    final hasWideMarkdown =
        hasTextContent && _needsHorizontalMarkdownScroll(message.content);
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.84;
    final timeText = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(message.timestamp),
      alwaysUse24HourFormat: true,
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isUser ? 36 : 12,
          right: isUser ? 12 : 36,
          top: 8,
          bottom: 8,
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (message.imagePaths.isNotEmpty) ...[
              _buildImageAttachmentCard(context, message.imagePaths),
              if (hasTextContent || message.isLoading)
                const SizedBox(height: 8),
            ],
            if (hasTextContent || message.isLoading)
              GestureDetector(
                onLongPress: () => _copyMessage(
                  context,
                  message.content,
                  successText: '已复制消息',
                ),
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppTheme.userBubble
                        : (isDark ? AppTheme.darkAiBubble : AppTheme.aiBubble),
                    border: Border.all(
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.15)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.2 : 0.06,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                  ),
                  child: message.isLoading
                      ? _buildLoadingIndicator(l10n)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser && _containsCodeFence(message.content))
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: InkWell(
                                    onTap: () => _copyMessage(
                                      context,
                                      _extractCodeForCopy(message.content),
                                      successText: '已复制代码',
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.08,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.04,
                                              ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.copy_rounded,
                                            size: 14,
                                            color: AppTheme.appleGray,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            '复制代码',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.appleGray,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (hasWideMarkdown)
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: constraints.maxWidth,
                                      ),
                                      child: _buildMarkdown(context, isUser),
                                    ),
                                  );
                                },
                              )
                            else
                              _buildMarkdown(context, isUser),
                          ],
                        ),
                ),
              ),
            if (!message.isLoading) ...[
              const SizedBox(height: 4),
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withValues(alpha: 0.65),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdown(BuildContext context, bool isUser) {
    return MarkdownBody(
      data: message.content,
      selectable: false,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: TextStyle(
          fontSize: 14,
          color: isUser ? Colors.white : null,
          height: 1.4,
        ),
        code: TextStyle(
          fontSize: 12.5,
          color: isUser ? Colors.white : null,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: isUser
              ? Colors.white.withValues(alpha: 0.14)
              : Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        blockquote: TextStyle(
          color: isUser
              ? Colors.white70
              : Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
    );
  }

  Widget _buildImageAttachmentCard(
    BuildContext context,
    List<String> imagePaths,
  ) {
    final previews = imagePaths.take(3).toList();
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkAiBubble
            : Colors.white,
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: previews.map((path) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 92,
              height: 92,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkSurface
                  : Colors.white,
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 24,
                    color: AppTheme.appleGray,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _containsMarkdownTable(String text) {
    final hasPipeLine = RegExp(
      r'^\s*\|.*\|\s*$',
      multiLine: true,
    ).hasMatch(text);
    final hasSeparator = RegExp(
      r'^\s*\|?\s*:?-{3,}',
      multiLine: true,
    ).hasMatch(text);
    return hasPipeLine && hasSeparator;
  }

  bool _needsHorizontalMarkdownScroll(String text) {
    return _containsMarkdownTable(text) || text.contains('```');
  }

  bool _containsCodeFence(String text) {
    return text.contains('```');
  }

  String _extractCodeForCopy(String text) {
    final match = RegExp(r'```[a-zA-Z0-9_-]*\n([\s\S]*?)```').firstMatch(text);
    if (match != null) {
      final code = match.group(1)?.trim();
      if (code != null && code.isNotEmpty) {
        return code;
      }
    }
    return text;
  }

  Future<void> _copyMessage(
    BuildContext context,
    String text, {
    required String successText,
  }) async {
    final value = text.trim();
    if (value.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successText),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildLoadingIndicator(AppLocalizations l10n) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppTheme.appleGray.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          l10n.thinking,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.appleGray.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
