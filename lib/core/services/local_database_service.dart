import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../features/storage/domain/models/file_model.dart';
import '../../features/storage/domain/models/folder_model.dart';

/// SQLite local offline cache service for instant directory traversal
class LocalDatabaseService {
  LocalDatabaseService._();
  static final LocalDatabaseService instance = LocalDatabaseService._();

  static const String _dbName = 'cloud_vault_cache.db';
  static const int _dbVersion = 1;

  static const String tableFolders = 'folders';
  static const String tableFiles = 'files';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, _dbName);

    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onOpen: (db) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
      onCreate: (db, version) async {
        // Table for Folders
        await db.execute('''
          CREATE TABLE $tableFolders (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parent_id TEXT,
            user_id TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');

        // Table for Files
        await db.execute('''
          CREATE TABLE $tableFiles (
            id TEXT PRIMARY KEY,
            filename TEXT NOT NULL,
            telegram_file_id TEXT NOT NULL,
            size INTEGER NOT NULL,
            mime_type TEXT NOT NULL,
            folder_id TEXT,
            user_id TEXT NOT NULL,
            uploaded_at INTEGER NOT NULL
          )
        ''');

        // Indexes for fast hierarchy queries
        await db.execute('CREATE INDEX idx_folders_parent ON $tableFolders (parent_id, user_id)');
        await db.execute('CREATE INDEX idx_files_folder ON $tableFiles (folder_id, user_id)');
      },
    );
  }

  // --- Settings / Key-Value Cache Operations ---

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final res = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return res.first['value'] as String?;
    }
    return null;
  }

  // --- Folder Cache Operations ---

  Future<void> cacheFolders(List<FolderModel> folders) async {
    final db = await database;
    final batch = db.batch();
    for (final folder in folders) {
      batch.insert(
        tableFolders,
        folder.toSqlite(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<FolderModel>> getCachedFolders({
    required String userId,
    String? parentId,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> results;

    if (parentId == null) {
      results = await db.query(
        tableFolders,
        where: 'user_id = ? AND parent_id IS NULL',
        whereArgs: [userId],
        orderBy: 'name ASC',
      );
    } else {
      results = await db.query(
        tableFolders,
        where: 'user_id = ? AND parent_id = ?',
        whereArgs: [userId, parentId],
        orderBy: 'name ASC',
      );
    }

    return results.map(FolderModel.fromSqlite).toList();
  }

  Future<void> deleteCachedFolder(String folderId) async {
    final db = await database;
    await db.delete(tableFolders, where: 'id = ?', whereArgs: [folderId]);
  }

  // --- File Cache Operations ---

  Future<void> cacheFiles(List<FileModel> files) async {
    final db = await database;
    final batch = db.batch();
    for (final file in files) {
      batch.insert(
        tableFiles,
        file.toSqlite(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<FileModel>> getCachedFiles({
    required String userId,
    String? folderId,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> results;

    if (folderId == null) {
      results = await db.query(
        tableFiles,
        where: 'user_id = ? AND folder_id IS NULL',
        whereArgs: [userId],
        orderBy: 'uploaded_at DESC',
      );
    } else {
      results = await db.query(
        tableFiles,
        where: 'user_id = ? AND folder_id = ?',
        whereArgs: [userId, folderId],
        orderBy: 'uploaded_at DESC',
      );
    }

    return results.map(FileModel.fromSqlite).toList();
  }

  Future<void> deleteCachedFile(String fileId) async {
    final db = await database;
    await db.delete(tableFiles, where: 'id = ?', whereArgs: [fileId]);
  }

  /// Clear all cache for user during logout
  Future<void> clearUserCache(String userId) async {
    final db = await database;
    await db.delete(tableFolders, where: 'user_id = ?', whereArgs: [userId]);
    await db.delete(tableFiles, where: 'user_id = ?', whereArgs: [userId]);
  }
}

