import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isUser = message.type == MessageType.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isUser ? 64 : 16,
          right: isUser ? 16 : 64,
          top: 8,
          bottom: 8,
        ),
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
            : Text(
                message.content,
                style: TextStyle(
                  fontSize: 16,
                  color: isUser ? Colors.white : null,
                ),
              ),
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
