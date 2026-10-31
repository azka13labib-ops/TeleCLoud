import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/services/telegram_service.dart';
import '../../storage/data/storage_repository.dart';
import '../../storage/domain/models/file_model.dart';

class TransferProgress {
  final String fileId;
  final String filename;
  final int totalBytes;
  final int transferredBytes;
  final double progress; // 0.0 to 1.0
  final bool isUpload;
  final bool isCompleted;
  final String? error;

  TransferProgress({
    required this.fileId,
    required this.filename,
    required this.totalBytes,
    required this.transferredBytes,
    required this.progress,
    required this.isUpload,
    this.isCompleted = false,
    this.error,
  });
}

/// Service managing Telegram MTProto 2GB chunked file upload and download
class TelegramTransferService {
  TelegramTransferService._();
  static final TelegramTransferService instance = TelegramTransferService._();

  final TelegramService _telegram = TelegramService.instance;
  final StorageRepository _storageRepo = StorageRepository();

  final StreamController<TransferProgress> _transferController =
      StreamController<TransferProgress>.broadcast();

  Stream<TransferProgress> get onTransferProgress => _transferController.stream;

  /// Uploads file: to user's Telegram Private Vault Channel if connected,
  /// or safely stores locally in App Vault if Telegram is pending activation.
  Future<FileModel> uploadFile({
    required File file,
    required String filename,
    required String mimeType,
    required String userId,
    String? folderId,
  }) async {
    final int? channelId = _telegram.vaultChannelId;
    final fileSize = await file.length();
    debugPrint('[TransferService] Starting upload for: $filename ($fileSize bytes)');

    try {
      _transferController.add(
        TransferProgress(
          fileId: filename,
          filename: filename,
          totalBytes: fileSize,
          transferredBytes: 0,
          progress: 0.1,
          isUpload: true,
        ),
      );

      String telegramFileId = '';

      if (channelId != null) {
        // 1. Send Document message via TDLib to the private channel
        final sendDocRes = await _telegram.tdlib.invoke(
          'sendMessage',
          parameters: {
            'chat_id': channelId,
            'input_message_content': {
              '@type': 'inputMessageDocument',
              'document': {
                '@type': 'inputFileLocal',
                'path': file.path,
              },
              'caption': {
                '@type': 'formattedText',
                'text': filename,
              },
            },
          },
          clientId: _telegram.clientId,
        );

        // Extract Telegram remote file ID
        final messageContent = sendDocRes['content'] as Map<dynamic, dynamic>?;
        final document = messageContent?['document'] as Map<dynamic, dynamic>?;
        final documentFile = document?['document'] as Map<dynamic, dynamic>?;
        telegramFileId =
            documentFile?['remote']?['id']?.toString() ??
            documentFile?['id']?.toString() ??
            sendDocRes['id']?.toString() ??
            '';
        debugPrint('[TransferService] MTProto upload completed! Remote ID: $telegramFileId');
      } else {
        // Safe offline-first fallback: Store file locally in vault storage directory
        final appDocDir = await getApplicationDocumentsDirectory();
        final vaultDir = Directory(p.join(appDocDir.path, 'local_vault_files'));
        if (!await vaultDir.exists()) {
          await vaultDir.create(recursive: true);
        }

        final localSavedPath = p.join(
          vaultDir.path,
          '${DateTime.now().millisecondsSinceEpoch}_$filename',
        );
        await file.copy(localSavedPath);
        telegramFileId = 'local:$localSavedPath';
        debugPrint('[TransferService] Telegram not connected. File safely stored in Local Vault: $localSavedPath');
      }

      // 2. Save metadata to Firestore & Local SQLite Cache
      final savedFile = await _storageRepo.saveFileMetadata(
        filename: filename,
        telegramFileId: telegramFileId,
        size: fileSize,
        mimeType: mimeType,
        userId: userId,
        folderId: folderId,
      );

      _transferController.add(
        TransferProgress(
          fileId: savedFile.id,
          filename: filename,
          totalBytes: fileSize,
          transferredBytes: fileSize,
          progress: 1.0,
          isUpload: true,
          isCompleted: true,
        ),
      );

      return savedFile;
    } catch (e, stack) {
      debugPrint('[TransferService] Error uploading file: $e\n$stack');
      _transferController.add(
        TransferProgress(
          fileId: filename,
          filename: filename,
          totalBytes: fileSize,
          transferredBytes: 0,
          progress: 0.0,
          isUpload: true,
          error: e.toString(),
        ),
      );
      rethrow;
    }
  }

  /// Downloads file from Telegram or fetches from local vault
  Future<String?> downloadFile({
    required String telegramFileId,
    required String filename,
    required int priority, // 1 to 32
  }) async {
    try {
      debugPrint('[TransferService] Requesting download for $filename (ID: $telegramFileId)');

      // If stored locally in vault fallback
      if (telegramFileId.startsWith('local:')) {
        final localPath = telegramFileId.replaceFirst('local:', '');
        debugPrint('[TransferService] File is already available locally at: $localPath');
        return localPath;
      }

      final fileIdInt = int.tryParse(telegramFileId);
      if (fileIdInt != null && _telegram.vaultChannelId != null) {
        await _telegram.tdlib.invoke(
          'downloadFile',
          parameters: {
            'file_id': fileIdInt,
            'priority': priority,
            'synchronous': false,
          },
          clientId: _telegram.clientId,
        );
      }
      return null;
    } catch (e) {
      debugPrint('[TransferService] Download request error: $e');
      return null;
    }
  }
}

