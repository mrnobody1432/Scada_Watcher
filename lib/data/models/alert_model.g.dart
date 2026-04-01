// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AlertModelImpl _$$AlertModelImplFromJson(Map<String, dynamic> json) =>
    _$AlertModelImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      severity: json['severity'] as String,
      source: json['source'] as String,
      tagName: json['tagName'] as String,
      currentValue: (json['currentValue'] as num).toDouble(),
      threshold: (json['threshold'] as num).toDouble(),
      condition: json['condition'] as String,
      raisedAt: DateTime.parse(json['raisedAt'] as String),
      acknowledgedAt: json['acknowledgedAt'] == null
          ? null
          : DateTime.parse(json['acknowledgedAt'] as String),
      acknowledgedBy: json['acknowledgedBy'] as String?,
      acknowledgedComment: json['acknowledgedComment'] as String?,
      clearedAt: json['clearedAt'] == null
          ? null
          : DateTime.parse(json['clearedAt'] as String),
      escalatedAt: json['escalatedAt'] == null
          ? null
          : DateTime.parse(json['escalatedAt'] as String),
      isActive: json['isActive'] as bool,
      isAcknowledged: json['isAcknowledged'] as bool,
      isSuppressed: json['isSuppressed'] as bool,
      notes: json['notes'] as String?,
      escalationLevel: (json['escalationLevel'] as num?)?.toInt() ?? 0,
      suppressionCount: (json['suppressionCount'] as num?)?.toInt() ?? 0,
      relatedAlertIds:
          (json['relatedAlertIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      trendData:
          (json['trendData'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
      alertType: json['alertType'] as String?,
      escalationCount: (json['escalationCount'] as num?)?.toInt() ?? 0,
      lastUpdatedTime: json['lastUpdatedTime'] == null
          ? null
          : DateTime.parse(json['lastUpdatedTime'] as String),
      equipment: json['equipment'] as String?,
      location: json['location'] as String?,
    );

Map<String, dynamic> _$$AlertModelImplToJson(_$AlertModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'severity': instance.severity,
      'source': instance.source,
      'tagName': instance.tagName,
      'currentValue': instance.currentValue,
      'threshold': instance.threshold,
      'condition': instance.condition,
      'raisedAt': instance.raisedAt.toIso8601String(),
      'acknowledgedAt': instance.acknowledgedAt?.toIso8601String(),
      'acknowledgedBy': instance.acknowledgedBy,
      'acknowledgedComment': instance.acknowledgedComment,
      'clearedAt': instance.clearedAt?.toIso8601String(),
      'escalatedAt': instance.escalatedAt?.toIso8601String(),
      'isActive': instance.isActive,
      'isAcknowledged': instance.isAcknowledged,
      'isSuppressed': instance.isSuppressed,
      'notes': instance.notes,
      'escalationLevel': instance.escalationLevel,
      'suppressionCount': instance.suppressionCount,
      'relatedAlertIds': instance.relatedAlertIds,
      'trendData': instance.trendData,
      'alertType': instance.alertType,
      'escalationCount': instance.escalationCount,
      'lastUpdatedTime': instance.lastUpdatedTime?.toIso8601String(),
      'equipment': instance.equipment,
      'location': instance.location,
    };
