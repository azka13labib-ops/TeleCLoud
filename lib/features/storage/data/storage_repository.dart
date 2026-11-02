import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/local_database_service.dart';
import '../domain/models/file_model.dart';
import '../domain/models/folder_model.dart';

/// Repository managing cloud storage hierarchy and files with offline-first synchronization
class StorageRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalDatabaseService _localDb = LocalDatabaseService.instance;

  static const String foldersCollection = 'folders';
  static const String filesCollection = 'files';

  // --- Folder Operations ---

  /// Creates a new folder in Firestore and updates local cache
  Future<FolderModel> createFolder({
    required String name,
    required String userId,
    String? parentId,
  }) async {
    final docRef = _firestore.collection(foldersCollection).doc();
    final folder = FolderModel(
      id: docRef.id,
      name: name.trim(),
      parentId: parentId,
      userId: userId,
      createdAt: DateTime.now(),
    );

    await docRef.set(folder.toFirestore());
    await _localDb.cacheFolders([folder]);

    return folder;
  }

  /// Fetches folders with offline-first approach (loads local SQLite cache immediately, syncs from Firestore)
  Future<List<FolderModel>> getFolders({
    required String userId,
    String? parentId,
  }) async {
    final localFolders = await _localDb.getCachedFolders(
      userId: userId,
      parentId: parentId,
    );

    try {
      final snapshot = await _firestore
          .collection(foldersCollection)
          .where('user_id', isEqualTo: userId)
          .where('parent_id', isEqualTo: parentId)
          .get();

      final freshFolders = snapshot.docs
          .map((doc) => FolderModel.fromMap(doc.data(), doc.id))
          .toList();

      await _localDb.cacheFolders(freshFolders);
      return freshFolders;
    } catch (_) {
      return localFolders;
    }
  }

  /// Fetches all folders for a user across all nesting levels (useful for Move Destination picker)
  Future<List<FolderModel>> getAllFolders({required String userId}) async {
    try {
      final snapshot = await _firestore
          .collection(foldersCollection)
          .where('user_id', isEqualTo: userId)
          .get();

      final list = snapshot.docs
          .map((doc) => FolderModel.fromMap(doc.data(), doc.id))
          .toList();

      await _localDb.cacheFolders(list);
      return list;
    } catch (_) {
      return await _localDb.getCachedFolders(userId: userId);
    }
  }

  /// Renames an existing folder
  Future<void> renameFolder({
    required String folderId,
    required String newName,
    required String userId,
  }) async {
    await _firestore.collection(foldersCollection).doc(folderId).update({
      'name': newName.trim(),
    });
    await _localDb.updateFolderName(folderId, newName.trim());
  }

  /// Deletes a folder and all its contents
  Future<void> deleteFolder({
    required String folderId,
    required String userId,
  }) async {
    await _firestore.collection(foldersCollection).doc(folderId).delete();

    final childFiles = await _firestore
        .collection(filesCollection)
        .where('folder_id', isEqualTo: folderId)
        .where('user_id', isEqualTo: userId)
        .get();

    final batch = _firestore.batch();
    for (final doc in childFiles.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    await _localDb.deleteCachedFolder(folderId);
  }

  // --- File Operations ---

  /// Registers an uploaded Telegram file's metadata into Firestore and local cache
  Future<FileModel> saveFileMetadata({
    required String filename,
    required String telegramFileId,
    required int size,
    required String mimeType,
    required String userId,
    String? folderId,
  }) async {
    final docRef = _firestore.collection(filesCollection).doc();
    final file = FileModel(
      id: docRef.id,
      filename: filename,
      telegramFileId: telegramFileId,
      size: size,
      mimeType: mimeType,
      folderId: folderId,
      userId: userId,
      uploadedAt: DateTime.now(),
    );

    await docRef.set(file.toFirestore());
    await _localDb.cacheFiles([file]);

    return file;
  }

  /// Fetches files with offline-first approach
  Future<List<FileModel>> getFiles({
    required String userId,
    String? folderId,
  }) async {
    final localFiles = await _localDb.getCachedFiles(
      userId: userId,
      folderId: folderId,
    );

    try {
      final snapshot = await _firestore
          .collection(filesCollection)
          .where('user_id', isEqualTo: userId)
          .where('folder_id', isEqualTo: folderId)
          .get();

      final freshFiles = snapshot.docs
          .map((doc) => FileModel.fromMap(doc.data(), doc.id))
          .toList();

      await _localDb.cacheFiles(freshFiles);
      return freshFiles;
    } catch (_) {
      return localFiles;
    }
  }

  /// Renames an existing file
  Future<void> renameFile({
    required String fileId,
    required String newName,
    required String userId,
  }) async {
    await _firestore.collection(filesCollection).doc(fileId).update({
      'filename': newName.trim(),
    });
    await _localDb.updateFileName(fileId, newName.trim());
  }

  /// Moves a file to a new folder (or root if newFolderId is null)
  Future<void> moveFile({
    required String fileId,
    required String? newFolderId,
    required String userId,
  }) async {
    await _firestore.collection(filesCollection).doc(fileId).update({
      'folder_id': newFolderId,
    });
    await _localDb.updateFileFolder(fileId, newFolderId);
  }

  /// Deletes a file record
  Future<void> deleteFile({
    required String fileId,
    required String userId,
  }) async {
    await _firestore.collection(filesCollection).doc(fileId).delete();
    await _localDb.deleteCachedFile(fileId);
  }

  /// Calculates total bytes used by user across the whole vault
  Future<int> getTotalVaultBytes({required String userId}) async {
    try {
      final snapshot = await _firestore
          .collection(filesCollection)
          .where('user_id', isEqualTo: userId)
          .get();

      int total = 0;
      for (final doc in snapshot.docs) {
        final size = doc.data()['size'];
        if (size is num) total += size.toInt();
      }
      return total;
    } catch (_) {
      final local = await _localDb.getAllUserFiles(userId);
      return local.fold<int>(0, (acc, f) => acc + f.size);
    }
  }
}
