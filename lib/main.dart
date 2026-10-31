import 'dart:async';
import 'package:flutter/material.dart';

import 'core/services/firebase_service.dart';
import 'core/services/telegram_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase before runApp to ensure Auth & Firestore providers are ready
  try {
    await FirebaseService.instance.initialize(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[Main] Firebase initialized successfully.');
  } catch (e, stack) {
    debugPrint('[Main] Error initializing Firebase: $e\n$stack');
  }

  // Initialize Telegram TDLib in background without blocking startup
  unawaited(
    TelegramService.instance.initialize().catchError((e, stack) {
      debugPrint('[Main] Error initializing Telegram TDLib: $e\n$stack');
    }),
  );

  runApp(const TeraBoxTelegramApp());
}

class TeraBoxTelegramApp extends StatelessWidget {
  const TeraBoxTelegramApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Cloud Vault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}
