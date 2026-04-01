import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'alert_model.freezed.dart';
part 'alert_model.g.dart';

@freezed
class AlertModel with _$AlertModel {
  const AlertModel._();

  const factory AlertModel({
    required String id,
    required String name,
    required String description,
    required String severity,
    required String source,
    required String tagName,
    required double currentValue,
    required double threshold,
    required String condition,
    required DateTime raisedAt,
    DateTime? acknowledgedAt,
    String? acknowledgedBy,
    String? acknowledgedComment,
    DateTime? clearedAt,
    DateTime? escalatedAt,
    required bool isActive,
    required bool isAcknowledged,
    required bool isSuppressed,
    String? notes,
    @Default(0) int escalationLevel,
    @Default(0) int suppressionCount,
    @Default([]) List<String> relatedAlertIds,
    @Default([]) List<Map<String, dynamic>> trendData,

    // Diagnostic additions for Deep Analysis
    String? alertType,
    @Default(0) int escalationCount,
    DateTime? lastUpdatedTime,
    String? equipment,
    String? location,
  }) = _AlertModel;

  factory AlertModel.fromJson(Map<String, dynamic> json) =>
      _$AlertModelFromJson(json);

  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle both field naming conventions (camelCase from Flutter side, snake_case from C# side)
    return AlertModel(
      id: doc.id,
      name: data['name'] ?? data['title'] ?? 'SCADA Alarm',
      description: data['description'] ?? '',
      severity: data['severity'] ?? 'info',
      source: data['source'] ?? 'Unknown',
      tagName: data['tagName'] ?? data['nodeId'] ?? 'N/A',
      currentValue: (data['currentValue'] ?? data['triggerValue'] ?? 0)
          .toDouble(),
      threshold: (data['threshold'] ?? 0).toDouble(),
      condition: data['condition'] ?? data['alertType'] ?? '',
      raisedAt: _parseTimestamp(
        data['raisedAt'] ?? data['timestamp'] ?? data['created_at'],
      ),
      acknowledgedAt: _parseTimestamp(
        data['acknowledgedAt'] ?? data['acknowledged_at'],
      ),
      acknowledgedBy: data['acknowledgedBy'] ?? data['acknowledged_by'],
      acknowledgedComment: data['acknowledgedComment'] ?? data['notes'],
      clearedAt: _parseTimestamp(data['clearedAt'] ?? data['clearedTime']),
      escalatedAt: _parseTimestamp(data['escalatedAt']),
      isActive: data['isActive'] ?? (data['status'] == 'active'),
      isAcknowledged: data['isAcknowledged'] ?? (data['acknowledged'] == true),
      isSuppressed: data['isSuppressed'] ?? false,
      notes: data['notes'],
      escalationLevel: data['escalationLevel'] ?? data['escalationCount'] ?? 0,
      suppressionCount: data['suppressionCount'] ?? 0,
      relatedAlertIds: List<String>.from(data['relatedAlertIds'] ?? []),
      trendData: List<Map<String, dynamic>>.from(data['trendData'] ?? []),

      alertType: data['alertType'] ?? data['condition'],
      escalationCount: data['escalationCount'] ?? 0,
      lastUpdatedTime: _parseTimestamp(
        data['lastUpdatedTime'] ?? data['updated_at'],
      ),
      equipment: data['equipment'],
      location: data['location'],
    );
  }

  static DateTime _parseTimestamp(dynamic ts) {
    if (ts == null)
      return DateTime.now(); // Fallback but usually handled by nullable types
    if (ts is Timestamp) return ts.toDate();
    if (ts is String) return DateTime.tryParse(ts) ?? DateTime.now();
    return DateTime.now();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'severity': severity,
      'source': source,
      'tagName': tagName,
      'currentValue': currentValue,
      'threshold': threshold,
      'condition': condition,
      'raisedAt': Timestamp.fromDate(raisedAt),
      'acknowledgedAt': acknowledgedAt != null
          ? Timestamp.fromDate(acknowledgedAt!)
          : null,
      'acknowledgedBy': acknowledgedBy,
      'acknowledgedComment': acknowledgedComment,
      'clearedAt': clearedAt != null ? Timestamp.fromDate(clearedAt!) : null,
      'escalatedAt': escalatedAt != null
          ? Timestamp.fromDate(escalatedAt!)
          : null,
      'isActive': isActive,
      'isAcknowledged': isAcknowledged,
      'isSuppressed': isSuppressed,
      'notes': notes,
      'escalationLevel': escalationLevel,
      'suppressionCount': suppressionCount,
      'relatedAlertIds': relatedAlertIds,
      'trendData': trendData,
      'alertType': alertType,
      'escalationCount': escalationCount,
      'lastUpdatedTime': lastUpdatedTime != null
          ? Timestamp.fromDate(lastUpdatedTime!)
          : null,
      'equipment': equipment,
      'location': location,
    };
  }

  String get timeSinceRaised {
    final duration = DateTime.now().difference(raisedAt);
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  int get sortPriority {
    int severityPriority;
    switch (severity.toLowerCase()) {
      case 'critical':
        severityPriority = 1000;
        break;
      case 'warning':
        severityPriority = 500;
        break;
      case 'info':
        severityPriority = 100;
        break;
      default:
        severityPriority = 0;
    }

    return severityPriority + (isAcknowledged ? 0 : 10000);
  }
}
