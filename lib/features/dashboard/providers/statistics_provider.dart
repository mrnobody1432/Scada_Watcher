import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/alert_model.dart';

class AlertStatistics {
  final int totalAlerts;
  final int criticalCount;
  final int warningCount;
  final int infoCount;
  final int acknowledgedCount;
  final int unacknowledgedCount;
  final double acknowledgmentRate;
  final Duration averageResponseTime;
  final Map<String, int> alertsBySource;
  final Map<String, int> alertsBySeverity;
  final List<AlertTrend> hourlyTrends;

  AlertStatistics({
    required this.totalAlerts,
    required this.criticalCount,
    required this.warningCount,
    required this.infoCount,
    required this.acknowledgedCount,
    required this.unacknowledgedCount,
    required this.acknowledgmentRate,
    required this.averageResponseTime,
    required this.alertsBySource,
    required this.alertsBySeverity,
    required this.hourlyTrends,
  });

  factory AlertStatistics.fromAlerts(List<AlertModel> alerts) {
    final total = alerts.length;
    final critical = alerts.where((a) => a.severity == 'critical').length;
    final warning = alerts.where((a) => a.severity == 'warning').length;
    final info = alerts.where((a) => a.severity == 'info').length;
    final acked = alerts.where((a) => a.isAcknowledged).length;
    final unacked = total - acked;
    final ackRate = total > 0 ? (acked / total) * 100 : 0.0;

    // Calculate average response time
    final responseTimes = alerts
        .where((a) => a.acknowledgedAt != null)
        .map((a) => a.acknowledgedAt!.difference(a.raisedAt))
        .toList();
    final avgResponse = responseTimes.isNotEmpty
        ? Duration(
            microseconds:
                (responseTimes
                            .map((d) => d.inMicroseconds)
                            .reduce((a, b) => a + b) /
                        responseTimes.length)
                    .round(),
          )
        : Duration.zero;

    // Group by source
    final sourceMap = <String, int>{};
    for (final alert in alerts) {
      sourceMap[alert.source] = (sourceMap[alert.source] ?? 0) + 1;
    }

    // Group by severity
    final severityMap = <String, int>{
      'critical': critical,
      'warning': warning,
      'info': info,
    };

    // Calculate hourly trends (last 24 hours)
    final now = DateTime.now();
    final trends = <AlertTrend>[];
    for (int i = 23; i >= 0; i--) {
      final hourStart = now.subtract(Duration(hours: i + 1));
      final hourEnd = now.subtract(Duration(hours: i));
      final count = alerts.where((a) {
        return a.raisedAt.isAfter(hourStart) && a.raisedAt.isBefore(hourEnd);
      }).length;
      trends.add(AlertTrend(hour: 23 - i, count: count, time: hourEnd));
    }

    return AlertStatistics(
      totalAlerts: total,
      criticalCount: critical,
      warningCount: warning,
      infoCount: info,
      acknowledgedCount: acked,
      unacknowledgedCount: unacked,
      acknowledgmentRate: ackRate,
      averageResponseTime: avgResponse,
      alertsBySource: sourceMap,
      alertsBySeverity: severityMap,
      hourlyTrends: trends,
    );
  }
}

class AlertTrend {
  final int hour;
  final int count;
  final DateTime time;

  AlertTrend({required this.hour, required this.count, required this.time});
}

final alertStatisticsProvider = Provider<AlertStatistics>((ref) {
  // This would normally combine active and recent historical alerts
  // For now, return empty statistics
  return AlertStatistics(
    totalAlerts: 0,
    criticalCount: 0,
    warningCount: 0,
    infoCount: 0,
    acknowledgedCount: 0,
    unacknowledgedCount: 0,
    acknowledgmentRate: 0.0,
    averageResponseTime: Duration.zero,
    alertsBySource: {},
    alertsBySeverity: {},
    hourlyTrends: [],
  );
});
