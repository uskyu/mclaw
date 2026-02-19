import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class AttachmentMenu extends StatelessWidget {
  final VoidCallback onCompressHistory;
  final VoidCallback onClearContext;

  const AttachmentMenu({
    super.key,
    required this.onCompressHistory,
    required this.onClearContext,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一行：拍照、相册、文件
          Row(
            children: [
              Expanded(
                child: _buildAttachmentCard(
                  context,
                  Icons.camera_alt_outlined,
                  l10n.takePicture,
                  () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAttachmentCard(
                  context,
                  Icons.photo_outlined,
                  l10n.photo,
                  () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAttachmentCard(
                  context,
                  Icons.insert_drive_file_outlined,
                  l10n.file,
                  () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 第二行：压缩历史、清空上下文
          _buildActionRow(
            context,
            Icons.folder_zip_outlined,
            l10n.compressHistory,
            onCompressHistory,
          ),
          const SizedBox(height: 8),
          _buildActionRow(
            context,
            Icons.delete_outline,
            l10n.clearContext,
            onClearContext,
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentCard(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkSurface
              : AppTheme.appleLightGray.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: AppTheme.appleGray),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppTheme.appleGray),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
