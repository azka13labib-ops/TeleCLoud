import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/local_database_service.dart';
import '../domain/models/file_model.dart';
import '../domain/models/folder_model.dart';

/// Repository managing cloud storage hierarchy and files with offline-first synchronization
class StorageRepository {
  final FirebaseFirestore _firestore = FirebaseService.instance.firestore;
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
    // 1. Read from local SQLite cache first for instant UX
    final localFolders = await _localDb.getCachedFolders(
      userId: userId,
      parentId: parentId,
    );

    // 2. Fetch fresh updates from Firestore in the background
    try {
      Query query = _firestore
          .collection(foldersCollection)
          .where('user_id', isEqualTo: userId)
          .where('parent_id', isEqualTo: parentId);

      final snapshot = await query.get();
      final freshFolders = snapshot.docs
          .map((doc) => FolderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Update local SQLite cache with latest remote data
      await _localDb.cacheFolders(freshFolders);
      return freshFolders;
    } catch (_) {
      // Return cached results if offline
      return localFolders;
    }
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
      Query query = _firestore
          .collection(filesCollection)
          .where('user_id', isEqualTo: userId)
          .where('folder_id', isEqualTo: folderId);

      final snapshot = await query.get();
      final freshFiles = snapshot.docs
          .map((doc) => FileModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      await _localDb.cacheFiles(freshFiles);
      return freshFiles;
    } catch (_) {
      return localFiles;
    }
  }
}
