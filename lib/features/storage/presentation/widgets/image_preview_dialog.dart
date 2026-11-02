import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glass_card.dart';

class ImagePreviewDialog extends StatelessWidget {
  final String imagePath;
  final String filename;

  const ImagePreviewDialog({
    super.key,
    required this.imagePath,
    required this.filename,
  });

  static void show(BuildContext context, {required String imagePath, required String filename}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (_) => ImagePreviewDialog(imagePath: imagePath, filename: filename),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);
    final exists = file.existsSync();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                const Icon(Icons.image_outlined, color: AppTheme.accentCyan, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Zoomable Image Viewer
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: exists
                  ? InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.file(
                        file,
                        fit: BoxFit.contain,
                      ),
                    )
                  : const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'File gambar belum tersimpan di cache lokal.',
                          style: TextStyle(color: AppTheme.subtleText),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

