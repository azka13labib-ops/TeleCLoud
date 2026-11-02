import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/services/telegram_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
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
