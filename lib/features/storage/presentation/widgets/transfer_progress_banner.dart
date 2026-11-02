import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../transfers/data/telegram_transfer_service.dart';

class TransferProgressBanner extends StatelessWidget {
  const TransferProgressBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TransferProgress>(
      stream: TelegramTransferService.instance.onTransferProgress,
      builder: (context, snapshot) {
        final progress = snapshot.data;
        if (progress == null || progress.isCompleted || progress.error != null) {
          return const SizedBox.shrink();
        }

        final percent = (progress.progress * 100).toInt();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: GlassCard(
            blur: 20,
            opacity: 0.18,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    value: progress.progress > 0 ? progress.progress : null,
                    strokeWidth: 2.5,
                    color: AppTheme.accentCyan,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        progress.isUpload
                            ? 'Mengunggah: ${progress.filename}'
                            : 'Mengunduh: ${progress.filename}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.progress,
                          backgroundColor: Colors.white12,
                          color: AppTheme.accentCyan,
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    color: AppTheme.accentCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

