import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../theme/app_theme.dart';

/// Enhanced notification service with local notifications
class EnhancedNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Request permissions
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
      announcement: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ User granted notification permission');

      // Initialize local notifications (Mobile only)
      if (!kIsWeb) {
        await _initializeLocalNotifications();
      }

      // Get FCM token
      final token = await _messaging.getToken();
      debugPrint('📱 FCM Token: $token');

      // Subscribe to topics (Mobile only)
      if (!kIsWeb) {
        await _messaging.subscribeToTopic('all_alerts');
        await _messaging.subscribeToTopic('critical_alerts');
        await _messaging.subscribeToTopic('warning_alerts');
      }

      // Configure foreground notifications
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Listen for background message taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);

      // Check if app was opened from terminated state
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessageTap(initialMessage);
      }

      // Token refresh listener
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token refreshed: $newToken');
        // TODO: Send to backend
      });

      _initialized = true;
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    // Critical alerts channel
    const criticalChannel = AndroidNotificationChannel(
      'critical_alerts',
      'Critical Alerts',
      description: 'Critical SCADA system alerts requiring immediate attention',
      importance: Importance.max,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alert_critical'),
    );

    // Warning alerts channel
    const warningChannel = AndroidNotificationChannel(
      'warning_alerts',
      'Warning Alerts',
      description: 'Warning alerts from SCADA system',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    // Info alerts channel
    const infoChannel = AndroidNotificationChannel(
      'info_alerts',
      'Information Alerts',
      description: 'Informational alerts from SCADA system',
      importance: Importance.defaultImportance,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(criticalChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(warningChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(infoChannel);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📬 Foreground message: ${message.notification?.title}');

    // Show local notification
    final severity = message.data['severity'] ?? 'info';
    _showLocalNotification(
      title: message.notification?.title ?? 'SCADA Alert',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
      severity: severity,
    );
  }

  void _handleBackgroundMessageTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped: ${message.data}');
    // TODO: Navigate to alert details
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('👆 Local notification tapped: ${response.payload}');
    // TODO: Navigate to alert details
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String payload,
    required String severity,
  }) async {
    final channelId = _getChannelId(severity);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(severity),
      importance: _getImportance(severity),
      priority: _getPriority(severity),
      color: _getNotificationColor(severity),
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(body),
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  String _getChannelId(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'critical_alerts';
      case 'warning':
        return 'warning_alerts';
      default:
        return 'info_alerts';
    }
  }

  String _getChannelName(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'Critical Alerts';
      case 'warning':
        return 'Warning Alerts';
      default:
        return 'Information Alerts';
    }
  }

  Importance _getImportance(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Importance.max;
      case 'warning':
        return Importance.high;
      default:
        return Importance.defaultImportance;
    }
  }

  Priority _getPriority(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Priority.max;
      case 'warning':
        return Priority.high;
      default:
        return Priority.defaultPriority;
    }
  }

  Color _getNotificationColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return AppTheme.criticalColor;
      case 'warning':
        return AppTheme.warningColor;
      default:
        return AppTheme.infoColor;
    }
  }

  /// Show a custom local notification (for testing or manual triggers)
  Future<void> showAlertNotification({
    required String alertId,
    required String alertName,
    required String source,
    required String severity,
    String? description,
  }) async {
    await _showLocalNotification(
      title: '🚨 $alertName',
      body: '$source - ${description ?? "Alert triggered"}',
      payload: alertId,
      severity: severity,
    );
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }
}

final enhancedNotificationServiceProvider =
    Provider<EnhancedNotificationService>((ref) {
      return EnhancedNotificationService();
    });
