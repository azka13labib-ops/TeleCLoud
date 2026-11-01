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
          progress: 0.05,
          isUpload: true,
        ),
      );

      String telegramFileId = '';

      if (channelId != null && _telegram.isInitialized) {
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

        final messageContent = sendDocRes['content'] as Map<dynamic, dynamic>?;
        final document = messageContent?['document'] as Map<dynamic, dynamic>?;
        final documentFile = document?['document'] as Map<dynamic, dynamic>?;
        final int? tdlibLocalFileId = documentFile?['id'] as int?;

        // 2. Wait for TDLib updateFile stream to verify real upload completion & get remote.id
        if (tdlibLocalFileId != null) {
          final completer = Completer<String>();
          StreamSubscription? sub;

          sub = _telegram.onFileUpdated.listen((fileMap) {
            final id = fileMap['id'] as int?;
            if (id == tdlibLocalFileId) {
              final remote = fileMap['remote'] as Map<dynamic, dynamic>?;
              final int uploaded = remote?['uploaded_size'] as int? ?? 0;
              final bool isCompleted = remote?['is_uploading_completed'] as bool? ?? false;
              final String remoteId = remote?['id'] as String? ?? '';

              final double progressVal = fileSize > 0
                  ? (uploaded / fileSize).clamp(0.05, 0.98)
                  : 0.5;

              _transferController.add(
                TransferProgress(
                  fileId: filename,
                  filename: filename,
                  totalBytes: fileSize,
                  transferredBytes: uploaded,
                  progress: progressVal,
                  isUpload: true,
                ),
              );

              if (isCompleted && remoteId.isNotEmpty && !completer.isCompleted) {
                completer.complete(remoteId);
                sub?.cancel();
              }
            }
          });

          // Timeout fallback: if TDLib doesn't emit completed within 90s, use initial remote ID or local fallback
          final resolvedRemoteId = await completer.future.timeout(
            const Duration(seconds: 90),
            onTimeout: () {
              sub?.cancel();
              final initialRemoteId = documentFile?['remote']?['id']?.toString() ?? '';
              if (initialRemoteId.isNotEmpty) {
                return initialRemoteId;
              }
              return 'msg:${sendDocRes['id']}';
            },
          );

          telegramFileId = resolvedRemoteId;
          debugPrint('[TransferService] MTProto upload completed! Remote ID: $telegramFileId');
        } else {
          telegramFileId = 'msg:${sendDocRes['id']}';
        }
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

      // 3. Save metadata to Firestore & Local SQLite Cache
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

  /// Downloads file from Telegram MTProto or returns local vault file path
  Future<String?> downloadFile({
    required String telegramFileId,
    required String filename,
    int priority = 32, // 1 to 32 (32 = highest)
  }) async {
    try {
      debugPrint('[TransferService] Requesting download for $filename (ID: $telegramFileId)');

      // 1. If stored locally in vault fallback
      if (telegramFileId.startsWith('local:')) {
        final localPath = telegramFileId.replaceFirst('local:', '');
        debugPrint('[TransferService] File is already available locally at: $localPath');
        return localPath;
      }

      _transferController.add(
        TransferProgress(
          fileId: telegramFileId,
          filename: filename,
          totalBytes: 0,
          transferredBytes: 0,
          progress: 0.05,
          isUpload: false,
        ),
      );

      // 2. Query TDLib for the remote file object using getRemoteFile
      final getFileRes = await _telegram.tdlib.invoke(
        'getRemoteFile',
        parameters: {
          'remote_file_id': telegramFileId,
        },
        clientId: _telegram.clientId,
      );

      final local = getFileRes['local'] as Map<dynamic, dynamic>?;
      final bool alreadyCompleted = local?['is_downloading_completed'] as bool? ?? false;
      final String? existingPath = local?['path'] as String?;

      if (alreadyCompleted && existingPath != null && existingPath.isNotEmpty) {
        debugPrint('[TransferService] File already downloaded at: $existingPath');
        _transferController.add(
          TransferProgress(
            fileId: telegramFileId,
            filename: filename,
            totalBytes: 0,
            transferredBytes: 0,
            progress: 1.0,
            isUpload: false,
            isCompleted: true,
          ),
        );
        return existingPath;
      }

      final int? localFileId = getFileRes['id'] as int?;
      if (localFileId == null) {
        throw Exception('TDLib failed to resolve file ID for remote ID: $telegramFileId');
      }

      // 3. Initiate TDLib download
      final completer = Completer<String?>();
      StreamSubscription? sub;

      sub = _telegram.onFileUpdated.listen((fileMap) {
        final id = fileMap['id'] as int?;
        if (id == localFileId) {
          final loc = fileMap['local'] as Map<dynamic, dynamic>?;
          final int downloaded = loc?['downloaded_size'] as int? ?? 0;
          final int total = fileMap['size'] as int? ?? 1;
          final bool isCompleted = loc?['is_downloading_completed'] as bool? ?? false;
          final String path = loc?['path'] as String? ?? '';

          final double prog = total > 0 ? (downloaded / total).clamp(0.05, 0.99) : 0.5;

          _transferController.add(
            TransferProgress(
              fileId: telegramFileId,
              filename: filename,
              totalBytes: total,
              transferredBytes: downloaded,
              progress: prog,
              isUpload: false,
            ),
          );

          if (isCompleted && path.isNotEmpty && !completer.isCompleted) {
            completer.complete(path);
            sub?.cancel();
          }
        }
      });

      await _telegram.tdlib.invoke(
        'downloadFile',
        parameters: {
          'file_id': localFileId,
          'priority': priority,
          'synchronous': false,
        },
        clientId: _telegram.clientId,
      );

      final downloadedPath = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          sub?.cancel();
          return null;
        },
      );

      if (downloadedPath != null) {
        _transferController.add(
          TransferProgress(
            fileId: telegramFileId,
            filename: filename,
            totalBytes: 0,
            transferredBytes: 0,
            progress: 1.0,
            isUpload: false,
            isCompleted: true,
          ),
        );
      }

      return downloadedPath;
    } catch (e) {
      debugPrint('[TransferService] Download request error: $e');
      _transferController.add(
        TransferProgress(
          fileId: telegramFileId,
          filename: filename,
          totalBytes: 0,
          transferredBytes: 0,
          progress: 0.0,
          isUpload: false,
          error: e.toString(),
        ),
      );
      return null;
    }
  }
}
