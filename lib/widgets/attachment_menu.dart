import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class AttachmentMenu extends StatelessWidget {
  final VoidCallback onTakePicture;
  final VoidCallback onPickPhoto;
  final VoidCallback onPickFile;

  const AttachmentMenu({
    super.key,
    required this.onTakePicture,
    required this.onPickPhoto,
    required this.onPickFile,
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
          // 拍照、相册、文件
          Row(
            children: [
              Expanded(
                child: _buildAttachmentCard(
                  context,
                  Icons.camera_alt_outlined,
                  l10n.takePicture,
                  onTakePicture,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAttachmentCard(
                  context,
                  Icons.photo_outlined,
                  l10n.photo,
                  onPickPhoto,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAttachmentCard(
                  context,
                  Icons.insert_drive_file_outlined,
                  l10n.file,
                  onPickFile,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentCard(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
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
}
