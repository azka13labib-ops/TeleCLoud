import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Service managing Firebase Core, Auth, and Firestore instances.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;

  bool _isInitialized = false;

  /// Global FirebaseAuth instance
  FirebaseAuth get auth {
    try {
      return _isInitialized ? _auth : FirebaseAuth.instance;
    } catch (_) {
      return FirebaseAuth.instance;
    }
  }

  /// Global FirebaseFirestore instance
  FirebaseFirestore get firestore {
    try {
      return _isInitialized ? _firestore : FirebaseFirestore.instance;
    } catch (_) {
      return FirebaseFirestore.instance;
    }
  }

  bool get isInitialized => _isInitialized;

  /// Initializes default Firebase App, FirebaseAuth, and FirebaseFirestore.
  /// Guards against double-initialization: if Firebase is already initialized
  /// (e.g. by a prior call), it skips [Firebase.initializeApp] and reuses the
  /// existing default app.
  Future<void> initialize({FirebaseOptions? options}) async {
    if (_isInitialized) return;

    try {
      // Only call initializeApp if no Firebase apps exist yet.
      if (Firebase.apps.isEmpty) {
        if (options != null) {
          await Firebase.initializeApp(options: options);
        } else {
          await Firebase.initializeApp();
        }
      }

      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;

      // Enable offline persistence settings for Firestore
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      _isInitialized = true;
      debugPrint('[FirebaseService] Firebase initialized successfully.');
    } catch (e, stackTrace) {
      debugPrint('[FirebaseService] Failed to initialize Firebase: $e\n$stackTrace');
      rethrow;
    }
  }
}

