import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isUser = message.type == MessageType.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasWideMarkdown = _needsHorizontalMarkdownScroll(message.content);
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.78;
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
            Container(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.userBubble
                    : (isDark ? AppTheme.darkAiBubble : AppTheme.aiBubble),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: message.isLoading
                  ? _buildLoadingIndicator(l10n)
                  : (hasWideMarkdown
                        ? LayoutBuilder(
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
                        : _buildMarkdown(context, isUser)),
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
          fontSize: 16,
          color: isUser ? Colors.white : null,
          height: 1.45,
        ),
        code: TextStyle(
          fontSize: 14,
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
    if (_containsMarkdownTable(text) || text.contains('```')) {
      return true;
    }

    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.length < 72) {
        continue;
      }
      final hasManyBreaks = RegExp(r'\s').allMatches(trimmed).length >= 6;
      if (!hasManyBreaks) {
        return true;
      }
    }
    return false;
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
