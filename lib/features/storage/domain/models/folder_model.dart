import 'package:cloud_firestore/cloud_firestore.dart';

class FolderModel {
  final String id;
  final String name;
  final String? parentId; // null indicates root level
  final String userId;
  final DateTime createdAt;

  const FolderModel({
    required this.id,
    required this.name,
    this.parentId,
    required this.userId,
    required this.createdAt,
  });

  /// Factory from Firestore DocumentSnapshot or MapX
  factory FolderModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedDate;
    final createdVal = map['created_at'];
    if (createdVal is Timestamp) {
      parsedDate = createdVal.toDate();
    } else if (createdVal is String) {
      parsedDate = DateTime.tryParse(createdVal) ?? DateTime.now();
    } else if (createdVal is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(createdVal);
    } else {
      parsedDate = DateTime.now();
    }

    return FolderModel(
      id: docId.isNotEmpty ? docId : (map['id'] ?? ''),
      name: map['name'] ?? '',
      parentId: map['parent_id'] as String?,
      userId: map['user_id'] ?? '',
      createdAt: parsedDate,
    );
  }

  /// Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'user_id': userId,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  /// Convert to SQLite Map
  Map<String, dynamic> toSqlite() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'user_id': userId,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Factory from SQLite row
  factory FolderModel.fromSqlite(Map<String, dynamic> map) {
    return FolderModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      parentId: map['parent_id'] as String?,
      userId: map['user_id'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
    );
  }

  FolderModel copyWith({
    String? id,
    String? name,
    String? parentId,
    String? userId,
    DateTime? createdAt,
  }) {
    return FolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

