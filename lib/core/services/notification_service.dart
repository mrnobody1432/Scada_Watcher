import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Background message: ${message.messageId}');
  }
}

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Use dynamic for the plugin to avoid web compilation issues with missing platform methods
  late final dynamic _localNotifications;

  NotificationService() {
    if (!kIsWeb) {
      _localNotifications = FlutterLocalNotificationsPlugin();
    }
  }

  // High Importance Channel for SCADA Alarms (Android only)
  static const _alarmChannelId = 'critical_alerts';
  static const _alarmChannelName = 'Critical SCADA Alarms';

  Future<void> initialize() async {
    // 1. Request Firebase Permissions
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Initialize Local Notifications (Mobile Only)
      if (!kIsWeb) {
        const initializationSettingsAndroid = AndroidInitializationSettings(
          '@mipmap/ic_launcher',
        );
        const initializationSettingsIOS = DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          requestCriticalPermission: true,
        );

        const initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

        await _localNotifications.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: (NotificationResponse details) {
            // Handle tap
          },
        );

        // 3. Create High-Priority Channel (Android only)
        if (defaultTargetPlatform == TargetPlatform.android) {
          final androidPlugin = _localNotifications
              .resolvePlatformSpecificPlugin<
                AndroidFlutterLocalNotificationsPlugin
              >();

          if (androidPlugin != null) {
            await androidPlugin.createNotificationChannel(
              const AndroidNotificationChannel(
                _alarmChannelId,
                _alarmChannelName,
                description: 'Used for mission-critical industrial alerts',
                importance: Importance.max,
                playSound: true,
                enableVibration: true,
                showBadge: true,
              ),
            );
          }
        }
      }

      // 4. Configure FCM
      final token = await _messaging.getToken();
      if (kDebugMode) print('FCM Token: $token');

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. LISTEN FOR FOREGROUND MESSAGES
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showForegroundNotification(message);
      });

      // Subscribe to topics (Mobile only)
      if (!kIsWeb) {
        await _messaging.subscribeToTopic('scada_alerts');
        await _messaging.subscribeToTopic('critical_alerts');
      }
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    if (kIsWeb) return;

    final notification = message.notification;
    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _alarmChannelId,
            _alarmChannelName,
            channelDescription: 'Used for mission-critical industrial alerts',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFFFF0000),
            playSound: true,
            fullScreenIntent: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.critical,
          ),
        ),
        payload: message.data['alertId'],
      );
    }
  }

  Future<void> subscribeToAlertTopics({
    bool critical = true,
    bool warning = true,
  }) async {
    if (kIsWeb) return;
    if (critical) await _messaging.subscribeToTopic('critical_alerts');
    if (warning) await _messaging.subscribeToTopic('warning_alerts');
  }

  Stream<RemoteMessage> get onMessageStream => FirebaseMessaging.onMessage;
  Stream<RemoteMessage> get onMessageOpenedAppStream =>
      FirebaseMessaging.onMessageOpenedApp;
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
