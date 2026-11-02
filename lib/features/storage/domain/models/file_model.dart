import 'package:cloud_firestore/cloud_firestore.dart';

class FileModel {
  final String id;
  final String filename;
  final String telegramFileId;
  final int size; // size in bytes
  final String mimeType;
  final String? folderId; // null indicates placed in root
  final String userId;
  final DateTime uploadedAt;

  const FileModel({
    required this.id,
    required this.filename,
    required this.telegramFileId,
    required this.size,
    required this.mimeType,
    this.folderId,
    required this.userId,
    required this.uploadedAt,
  });

  /// Factory from Firestore DocumentSnapshot or Map
  factory FileModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedDate;
    final uploadedVal = map['uploaded_at'];
    if (uploadedVal is Timestamp) {
      parsedDate = uploadedVal.toDate();
    } else if (uploadedVal is String) {
      parsedDate = DateTime.tryParse(uploadedVal) ?? DateTime.now();
    } else if (uploadedVal is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(uploadedVal);
    } else {
      parsedDate = DateTime.now();
    }

    return FileModel(
      id: docId.isNotEmpty ? docId : (map['id'] ?? ''),
      filename: map['filename'] ?? '',
      telegramFileId: map['telegram_file_id'] ?? '',
      size: (map['size'] is num) ? (map['size'] as num).toInt() : 0,
      mimeType: map['mime_type'] ?? 'application/octet-stream',
      folderId: map['folder_id'] as String?,
      userId: map['user_id'] ?? '',
      uploadedAt: parsedDate,
    );
  }

  /// Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'filename': filename,
      'telegram_file_id': telegramFileId,
      'size': size,
      'mime_type': mimeType,
      'folder_id': folderId,
      'user_id': userId,
      'uploaded_at': Timestamp.fromDate(uploadedAt),
    };
  }

  /// Convert to SQLite Map
  Map<String, dynamic> toSqlite() {
    return {
      'id': id,
      'filename': filename,
      'telegram_file_id': telegramFileId,
      'size': size,
      'mime_type': mimeType,
      'folder_id': folderId,
      'user_id': userId,
      'uploaded_at': uploadedAt.millisecondsSinceEpoch,
    };
  }

  /// Factory from SQLite row
  factory FileModel.fromSqlite(Map<String, dynamic> map) {
    return FileModel(
      id: map['id'] ?? '',
      filename: map['filename'] ?? '',
      telegramFileId: map['telegram_file_id'] ?? '',
      size: (map['size'] is num) ? (map['size'] as num).toInt() : 0,
      mimeType: map['mime_type'] ?? 'application/octet-stream',
      folderId: map['folder_id'] as String?,
      userId: map['user_id'] ?? '',
      uploadedAt: DateTime.fromMillisecondsSinceEpoch(map['uploaded_at'] ?? 0),
    );
  }

  /// Format bytes into human-readable string (e.g. 1.25 MB, 1.80 GB)
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double s = bytes.toDouble();
    while (s >= 1024 && i < suffixes.length - 1) {
      s /= 1024;
      i++;
    }
    return '${s.toStringAsFixed(s >= 100 ? 0 : 2)} ${suffixes[i]}';
  }

  /// Format file size into human-readable string
  String get formattedSize => formatBytes(size);

  /// File extension without dot, e.g. "pdf", "jpg"
  String get extension {
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < filename.length - 1) {
      return filename.substring(dotIndex + 1).toLowerCase();
    }
    return '';
  }

  FileModel copyWith({
    String? id,
    String? filename,
    String? telegramFileId,
    int? size,
    String? mimeType,
    String? folderId,
    String? userId,
    DateTime? uploadedAt,
  }) {
    return FileModel(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      telegramFileId: telegramFileId ?? this.telegramFileId,
      size: size ?? this.size,
      mimeType: mimeType ?? this.mimeType,
      folderId: folderId ?? this.folderId,
      userId: userId ?? this.userId,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }
}

