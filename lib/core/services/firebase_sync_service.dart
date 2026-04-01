import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/models/alert_model.dart';

class FirebaseSyncService {
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final Connectivity _connectivity = Connectivity();

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  StreamSubscription? _connectivitySubscription;
  Timer? _heartbeatTimer;

  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  FirebaseSyncService({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _messaging = messaging ?? FirebaseMessaging.instance;

  Future<void> initialize() async {
    print('🔄 Initializing Firebase Sync Service...');

    // Check initial connectivity
    await _checkConnectivity();

    // Monitor connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
    );

    // Configure FCM
    await _configureFCM();

    // Start heartbeat
    _startHeartbeat();

    print('✅ Firebase Sync Service initialized');
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);
    _updateSyncStatus();
  }

  void _handleConnectivityChange(dynamic results) {
    // Cast to List<ConnectivityResult> safely for Web/Mobile compatibility
    final List<ConnectivityResult> connectivityResults = results is List 
        ? List<ConnectivityResult>.from(results)
        : [ConnectivityResult.none];
        
    final wasOnline = _isOnline;
    _isOnline = !connectivityResults.contains(ConnectivityResult.none);

    if (!wasOnline && _isOnline) {
      _updateSyncStatus(message: 'Connected to network - syncing data...');
      _performFullSync();
    } else if (wasOnline && !_isOnline) {
      _updateSyncStatus(
        message: 'Network disconnected - switching to offline mode',
      );
    }

    _updateSyncStatus();
  }

  Future<void> _configureFCM() async {
    try {
      // Request notification permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ FCM notifications authorized');

        // Get FCM token - wrapped in try catch for Web Offline/Installation errors
        try {
          final token = await _messaging.getToken();
          if (token != null) {
            print('📱 FCM Token retrieved');
            await _saveFCMToken(token);
          }
        } catch (e) {
          print('ℹ️ FCM Token retrieval skipped (likely offline or local dev): $e');
        }

        // Handle token refresh
        _messaging.onTokenRefresh.listen(_saveFCMToken);

        // Configure message handlers
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
      }
    } catch (e) {
      print('⚠️ FCM configuration error: $e');
    }
  }

  Future<void> _saveFCMToken(String token) async {
    try {
      await _firestore.collection('device_tokens').doc(token).set({
        'token': token,
        'platform': 'windows',
        'lastUpdated': FieldValue.serverTimestamp(),
        'active': true,
      }, SetOptions(merge: true));
    } catch (e) {
      print('⚠️ Error saving FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('📨 Foreground message: ${message.notification?.title}');
    _syncStatusController.add(
      SyncStatus(
        isOnline: _isOnline,
        lastSync: DateTime.now(),
        message: 'New alert: ${message.notification?.title}',
      ),
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    print('👆 Message tapped: ${message.notification?.title}');
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (_isOnline) {
        await _sendHeartbeat();
      }
    });
  }

  Future<void> _sendHeartbeat() async {
    try {
      await _firestore
          .collection('client_heartbeats')
          .doc('windows_client')
          .set({
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'online',
            'version': '1.2.0',
            'platform': 'windows',
          }, SetOptions(merge: true));
    } catch (e) {
      print('⚠️ Heartbeat error: $e');
      _isOnline = false;
      _updateSyncStatus();
    }
  }

  Future<void> _performFullSync() async {
    if (!_isOnline) return;

    try {
      _updateSyncStatus(message: 'Starting full sync...');

      // Sync active alerts
      await _syncActiveAlerts();

      _updateSyncStatus(message: 'Full sync completed');
    } catch (e) {
      _updateSyncStatus(message: 'Sync error: $e');
    }
  }

  Future<void> _syncActiveAlerts() async {
    final snapshot = await _firestore
        .collection('alerts_active')
        .where('isActive', isEqualTo: true)
        .orderBy('raisedAt', descending: true)
        .limit(100)
        .get();

    _updateSyncStatus(message: 'Synced ${snapshot.docs.length} active alerts');
  }

  Stream<List<AlertModel>> watchActiveAlerts() {
    return _firestore
        .collection('alerts_active')
        .where('isActive', isEqualTo: true)
        .orderBy('raisedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AlertModel.fromFirestore(doc))
              .toList();
        });
  }

  Future<void> acknowledgeAlert(
    String alertId,
    String acknowledgedBy, {
    String? comment,
  }) async {
    final updateData = {
      'isAcknowledged': true,
      'acknowledgedAt': FieldValue.serverTimestamp(),
      'acknowledgedBy': acknowledgedBy,
      'acknowledgedComment': comment,
    };

    await _firestore
        .collection('alerts_active')
        .doc(alertId)
        .update(updateData);

    // Log acknowledgment
    await _firestore.collection('acknowledgment_logs').add({
      'alertId': alertId,
      'acknowledgedBy': acknowledgedBy,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> syncAlertToHistory(AlertModel alert) async {
    final alertData = {
      'id': alert.id,
      'name': alert.name,
      'description': alert.description,
      'severity': alert.severity,
      'source': alert.source,
      'tagName': alert.tagName,
      'currentValue': alert.currentValue,
      'threshold': alert.threshold,
      'condition': alert.condition,
      'isActive': alert.isActive,
      'isAcknowledged': alert.isAcknowledged,
      'raisedAt': Timestamp.fromDate(alert.raisedAt),
      'archivedAt': FieldValue.serverTimestamp(),
    };

    if (alert.acknowledgedAt != null) {
      alertData['acknowledgedAt'] = Timestamp.fromDate(alert.acknowledgedAt!);
    }
    if (alert.acknowledgedBy != null) {
      alertData['acknowledgedBy'] = alert.acknowledgedBy!;
    }
    if (alert.acknowledgedComment != null) {
      alertData['acknowledgedComment'] = alert.acknowledgedComment!;
    }
    if (alert.clearedAt != null) {
      alertData['clearedAt'] = Timestamp.fromDate(alert.clearedAt!);
    }
    if (alert.escalatedAt != null) {
      alertData['escalatedAt'] = Timestamp.fromDate(alert.escalatedAt!);
    }

    await _firestore.collection('alerts_history').add(alertData);
  }

  Future<Map<String, int>> getAlertStatistics() async {
    final activeSnapshot = await _firestore
        .collection('alerts_active')
        .where('isActive', isEqualTo: true)
        .count()
        .get();

    final criticalSnapshot = await _firestore
        .collection('alerts_active')
        .where('isActive', isEqualTo: true)
        .where('severity', isEqualTo: 'Critical')
        .count()
        .get();

    final acknowledgedSnapshot = await _firestore
        .collection('alerts_active')
        .where('isActive', isEqualTo: true)
        .where('isAcknowledged', isEqualTo: true)
        .count()
        .get();

    return {
      'total': activeSnapshot.count ?? 0,
      'critical': criticalSnapshot.count ?? 0,
      'acknowledged': acknowledgedSnapshot.count ?? 0,
    };
  }

  void _updateSyncStatus({String? message}) {
    _syncStatusController.add(
      SyncStatus(
        isOnline: _isOnline,
        lastSync: DateTime.now(),
        message: message,
      ),
    );
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _heartbeatTimer?.cancel();
    _syncStatusController.close();
  }
}

class SyncStatus {
  final bool isOnline;
  final DateTime lastSync;
  final String? message;

  SyncStatus({required this.isOnline, required this.lastSync, this.message});

  @override
  String toString() {
    return 'SyncStatus(online: $isOnline, lastSync: $lastSync, message: $message)';
  }
}
