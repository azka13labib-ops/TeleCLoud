import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_service.dart';

/// Singleton service handling Firebase Authentication (Email/Password & Google Sign-In)
class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  FirebaseAuth get _auth => FirebaseService.instance.auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleSignInInitialized = false;

  /// Current authenticated Firebase user
  User? get currentUser => _auth.currentUser;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Ensures GoogleSignIn is initialized once
  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_isGoogleSignInInitialized) {
      await _googleSignIn.initialize();
      _isGoogleSignInInitialized = true;
    }
  }

  /// Sign In with Email and Password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      debugPrint('[FirebaseAuthService] Signed in user: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('[FirebaseAuthService] FirebaseAuthException [${e.code}]: ${e.message}');
      rethrow;
    } catch (e, stack) {
      debugPrint('[FirebaseAuthService] Unexpected error during sign in: $e\n$stack');
      rethrow;
    }
  }

  /// Register / Create user with Email and Password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      debugPrint('[FirebaseAuthService] Registered new user: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('[FirebaseAuthService] FirebaseAuthException [${e.code}]: ${e.message}');
      rethrow;
    } catch (e, stack) {
      debugPrint('[FirebaseAuthService] Unexpected error during registration: $e\n$stack');
      rethrow;
    }
  }

  /// Sign In with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _ensureGoogleSignInInitialized();

      final GoogleSignInAccount googleAccount = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleAccount.authentication;
      final GoogleSignInClientAuthorization? clientAuth =
          await googleAccount.authorizationClient.authorizationForScopes(['email']);

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: clientAuth?.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint('[FirebaseAuthService] Google Sign-In successful for: ${userCredential.user?.email}');
      return userCredential;
    } on GoogleSignInException catch (e) {
      debugPrint('[FirebaseAuthService] GoogleSignInException: ${e.code} - ${e.description}');
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('[FirebaseAuthService] FirebaseAuthException during Google Sign-In [${e.code}]: ${e.message}');
      rethrow;
    } catch (e, stack) {
      debugPrint('[FirebaseAuthService] Unexpected error during Google Sign-In: $e\n$stack');
      rethrow;
    }
  }

  /// Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      debugPrint('[FirebaseAuthService] Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('[FirebaseAuthService] FirebaseAuthException [${e.code}]: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[FirebaseAuthService] Error sending password reset email: $e');
      rethrow;
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      debugPrint('[FirebaseAuthService] User signed out successfully.');
    } catch (e) {
      debugPrint('[FirebaseAuthService] Error signing out: $e');
      rethrow;
    }
  }
}
