import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/glass_text_field.dart';
import '../../../transfers/data/telegram_transfer_service.dart';
import '../../data/storage_repository.dart';
import '../../domain/models/file_model.dart';
import 'image_preview_dialog.dart';

class FileActionsModal extends StatelessWidget {
  final FileModel file;
  final String userId;
  final VoidCallback onModified;

  const FileActionsModal({
    super.key,
    required this.file,
    required this.userId,
    required this.onModified,
  });

  static void show(
    BuildContext context, {
    required FileModel file,
    required String userId,
    required VoidCallback onModified,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FileActionsModal(
        file: file,
        userId: userId,
        onModified: onModified,
      ),
    );
  }

  bool get _isImage =>
      ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(file.extension.toLowerCase());

  void _showRenameDialog(BuildContext context) {
    Navigator.pop(context); // Close actions sheet
    final controller = TextEditingController(text: file.filename);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.glassBorder),
        ),
        title: const Text('Ganti Nama File', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: GlassTextField(
          controller: controller,
          hintText: 'Nama file baru',
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.subtleText)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != file.filename) {
                Navigator.pop(ctx);
                await StorageRepository().renameFile(
                  fileId: file.id,
                  newName: newName,
                  userId: userId,
                );
                onModified();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showMoveDialog(BuildContext context) async {
    Navigator.pop(context); // Close actions sheet
    final storageRepo = StorageRepository();
    final allFolders = await storageRepo.getAllFolders(userId: userId);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pindahkan File ke Folder',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.home_work_outlined, color: AppTheme.accentCyan),
                title: const Text('Root Vault (Tanpa Folder)', style: TextStyle(color: Colors.white, fontSize: 13)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await storageRepo.moveFile(fileId: file.id, newFolderId: null, userId: userId);
                  onModified();
                },
              ),
              const Divider(color: AppTheme.glassBorder, height: 8),
              if (allFolders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text('Belum ada folder lain yang dibuat', style: TextStyle(color: AppTheme.subtleText, fontSize: 12)),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: allFolders.length,
                    itemBuilder: (_, index) {
                      final folder = allFolders[index];
                      final isCurrent = folder.id == file.folderId;
                      return ListTile(
                        leading: const Icon(Icons.folder_rounded, color: AppTheme.accentPurple),
                        title: Text(folder.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        trailing: isCurrent
                            ? const Text('(Saat Ini)', style: TextStyle(color: AppTheme.subtleText, fontSize: 11))
                            : null,
                        enabled: !isCurrent,
                        onTap: () async {
                          Navigator.pop(ctx);
                          await storageRepo.moveFile(fileId: file.id, newFolderId: folder.id, userId: userId);
                          onModified();
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    Navigator.pop(context); // Close actions sheet
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.glassBorder),
        ),
        title: const Text('Hapus File?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'File "${file.filename}" akan dihapus permanen dari vault.',
          style: const TextStyle(color: AppTheme.subtleText, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.subtleText)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await StorageRepository().deleteFile(fileId: file.id, userId: userId);
              onModified();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLocal = file.telegramFileId.startsWith('local:');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GlassCard(
        blur: 24,
        opacity: 0.16,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // File Info Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isLocal ? AppTheme.accentPurple : AppTheme.accentCyan)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isLocal ? Icons.save_alt_rounded : Icons.cloud_done_rounded,
                    color: isLocal ? AppTheme.accentPurple : AppTheme.accentCyan,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${file.formattedSize} • ${isLocal ? "Local Vault" : "Telegram MTProto"}',
                        style: const TextStyle(color: AppTheme.subtleText, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: AppTheme.glassBorder, height: 1),
            const SizedBox(height: 10),

            // Action: Preview (If Image)
            if (_isImage) ...[
              ListTile(
                dense: true,
                leading: const Icon(Icons.remove_red_eye_outlined, color: AppTheme.accentCyan),
                title: const Text('Lihat Preview Gambar', style: TextStyle(color: Colors.white, fontSize: 13)),
                onTap: () async {
                  Navigator.pop(context);
                  String? path;
                  if (isLocal) {
                    path = file.telegramFileId.replaceFirst('local:', '');
                  } else {
                    path = await TelegramTransferService.instance.downloadFile(
                      telegramFileId: file.telegramFileId,
                      filename: file.filename,
                    );
                  }
                  if (path != null && context.mounted) {
                    ImagePreviewDialog.show(context, imagePath: path, filename: file.filename);
                  }
                },
              ),
            ],

            // Action: Download
            ListTile(
              dense: true,
              leading: const Icon(Icons.download_rounded, color: AppTheme.accentCyan),
              title: const Text('Unduh File ke Perangkat', style: TextStyle(color: Colors.white, fontSize: 13)),
              onTap: () async {
                Navigator.pop(context);
                final path = await TelegramTransferService.instance.downloadFile(
                  telegramFileId: file.telegramFileId,
                  filename: file.filename,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(path != null ? 'Tersimpan di: $path' : 'Sedang mengunduh ${file.filename}...'),
                      backgroundColor: AppTheme.surfaceDark,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
            ),

            // Action: Rename
            ListTile(
              dense: true,
              leading: const Icon(Icons.drive_file_rename_outline, color: Colors.white70),
              title: const Text('Ganti Nama (Rename)', style: TextStyle(color: Colors.white, fontSize: 13)),
              onTap: () => _showRenameDialog(context),
            ),

            // Action: Move
            ListTile(
              dense: true,
              leading: const Icon(Icons.drive_file_move_outlined, color: Colors.white70),
              title: const Text('Pindahkan ke Folder', style: TextStyle(color: Colors.white, fontSize: 13)),
              onTap: () => _showMoveDialog(context),
            ),

            // Action: Delete
            ListTile(
              dense: true,
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text('Hapus File', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
              onTap: () => _showDeleteDialog(context),
            ),
          ],
        ),
      ),
    );
  }
}
