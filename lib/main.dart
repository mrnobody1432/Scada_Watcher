import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_navigation.dart';
import 'core/services/notification_service.dart';
import 'core/services/firebase_sync_service.dart';
import 'data/providers/sync_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Enable offline persistence with extra safety for web/platforms
    if (!kIsWeb) {
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        print('✅ Offline persistence enabled');
      } catch (e) {
        print('ℹ️ Persistence setup skipped: $e');
      }
    }

    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('⚠️ Firebase initialization failed: $e');
  }

  // Initialize push notifications
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    print('✅ Push notifications configured');
  } catch (e) {
    print('⚠️ Push notifications setup failed: $e');
  }

  // Lock orientation to portrait and landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const ProviderScope(child: ScadaAlarmApp()));
}

class ScadaAlarmApp extends ConsumerStatefulWidget {
  const ScadaAlarmApp({super.key});

  @override
  ConsumerState<ScadaAlarmApp> createState() => _ScadaAlarmAppState();
}

class _ScadaAlarmAppState extends ConsumerState<ScadaAlarmApp> {
  @override
  void initState() {
    super.initState();
    // Initialize services
    Future.microtask(() async {
      try {
        await ref.read(notificationServiceProvider).initialize();
        await ref.read(firebaseSyncServiceProvider).initialize();
      } catch (e) {
        debugPrint('⚠️ Service initialization failed: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    
    // Set system UI overlay style based on theme
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: themeMode == ThemeMode.dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: themeMode == ThemeMode.dark ? Brightness.light : Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'SCADA Alarm Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const AppNavigation(),
    );
  }
}
