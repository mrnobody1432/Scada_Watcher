import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/alert_model.dart';
import '../../../data/repositories/alert_repository.dart';

final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  return AlertRepository();
});

final activeAlertsProvider = StreamProvider<List<AlertModel>>((ref) {
  final repository = ref.watch(alertRepositoryProvider);
  return repository.watchActiveAlerts();
});

final criticalAlertsProvider = Provider<AsyncValue<List<AlertModel>>>((ref) {
  final activeAlertsAsync = ref.watch(activeAlertsProvider);
  return activeAlertsAsync.whenData((alerts) => 
    alerts.where((a) => a.severity.toLowerCase() == 'critical').toList()
  );
});

final warningAlertsProvider = Provider<AsyncValue<List<AlertModel>>>((ref) {
  final activeAlertsAsync = ref.watch(activeAlertsProvider);
  return activeAlertsAsync.whenData((alerts) => 
    alerts.where((a) => a.severity.toLowerCase() == 'warning').toList()
  );
});

final alertByIdProvider = StreamProvider.family<AlertModel?, String>((
  ref,
  alertId,
) {
  final repository = ref.watch(alertRepositoryProvider);
  return repository.watchAlertById(alertId);
});

final activeCriticalCountProvider = FutureProvider<int>((ref) {
  final repository = ref.watch(alertRepositoryProvider);
  return repository.getActiveAlertCount(severity: 'critical');
});

final activeWarningCountProvider = FutureProvider<int>((ref) {
  final repository = ref.watch(alertRepositoryProvider);
  return repository.getActiveAlertCount(severity: 'warning');
});

final acknowledgedCountProvider = FutureProvider<int>((ref) {
  final repository = ref.watch(alertRepositoryProvider);
  return repository.getAcknowledgedCount();
});

final clearedLast24hCountProvider = FutureProvider<int>((ref) {
  final repository = ref.watch(alertRepositoryProvider);
  return repository.getClearedLast24Hours();
});
