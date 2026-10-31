import 'package:flutter/material.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../storage/presentation/storage_home_screen.dart';
import 'dual_auth_screen.dart';

/// Routes user to StorageHomeScreen if both Firebase & Telegram MTProto are authenticated,
/// otherwise guides them into DualAuthScreen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (user == null) {
          return const DualAuthScreen();
        }

        // Firebase is authenticated. Proceed to main storage vault.
        return const StorageHomeScreen();
      },
    );
  }
}
