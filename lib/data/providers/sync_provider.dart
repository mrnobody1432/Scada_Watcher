import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/services/firebase_sync_service.dart';

final firebaseSyncServiceProvider = Provider<FirebaseSyncService>((ref) {
  final service = FirebaseSyncService(
    firestore: FirebaseFirestore.instance,
    messaging: FirebaseMessaging.instance,
  );

  ref.onDispose(() => service.dispose());

  return service;
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final syncService = ref.watch(firebaseSyncServiceProvider);
  return syncService.syncStatus;
});

final isOnlineProvider = Provider<bool>((ref) {
  final syncStatus = ref.watch(syncStatusProvider);
  return syncStatus.maybeWhen(
    data: (status) => status.isOnline,
    orElse: () => false,
  );
});
