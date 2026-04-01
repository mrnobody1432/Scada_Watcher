// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'alert_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AlertModel _$AlertModelFromJson(Map<String, dynamic> json) {
  return _AlertModel.fromJson(json);
}

/// @nodoc
mixin _$AlertModel {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get severity => throw _privateConstructorUsedError;
  String get source => throw _privateConstructorUsedError;
  String get tagName => throw _privateConstructorUsedError;
  double get currentValue => throw _privateConstructorUsedError;
  double get threshold => throw _privateConstructorUsedError;
  String get condition => throw _privateConstructorUsedError;
  DateTime get raisedAt => throw _privateConstructorUsedError;
  DateTime? get acknowledgedAt => throw _privateConstructorUsedError;
  String? get acknowledgedBy => throw _privateConstructorUsedError;
  String? get acknowledgedComment => throw _privateConstructorUsedError;
  DateTime? get clearedAt => throw _privateConstructorUsedError;
  DateTime? get escalatedAt => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  bool get isAcknowledged => throw _privateConstructorUsedError;
  bool get isSuppressed => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  int get escalationLevel => throw _privateConstructorUsedError;
  int get suppressionCount => throw _privateConstructorUsedError;
  List<String> get relatedAlertIds => throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get trendData =>
      throw _privateConstructorUsedError; // Diagnostic additions for Deep Analysis
  String? get alertType => throw _privateConstructorUsedError;
  int get escalationCount => throw _privateConstructorUsedError;
  DateTime? get lastUpdatedTime => throw _privateConstructorUsedError;
  String? get equipment => throw _privateConstructorUsedError;
  String? get location => throw _privateConstructorUsedError;

  /// Serializes this AlertModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AlertModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AlertModelCopyWith<AlertModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AlertModelCopyWith<$Res> {
  factory $AlertModelCopyWith(
    AlertModel value,
    $Res Function(AlertModel) then,
  ) = _$AlertModelCopyWithImpl<$Res, AlertModel>;
  @useResult
  $Res call({
    String id,
    String name,
    String description,
    String severity,
    String source,
    String tagName,
    double currentValue,
    double threshold,
    String condition,
    DateTime raisedAt,
    DateTime? acknowledgedAt,
    String? acknowledgedBy,
    String? acknowledgedComment,
    DateTime? clearedAt,
    DateTime? escalatedAt,
    bool isActive,
    bool isAcknowledged,
    bool isSuppressed,
    String? notes,
    int escalationLevel,
    int suppressionCount,
    List<String> relatedAlertIds,
    List<Map<String, dynamic>> trendData,
    String? alertType,
    int escalationCount,
    DateTime? lastUpdatedTime,
    String? equipment,
    String? location,
  });
}

/// @nodoc
class _$AlertModelCopyWithImpl<$Res, $Val extends AlertModel>
    implements $AlertModelCopyWith<$Res> {
  _$AlertModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AlertModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? severity = null,
    Object? source = null,
    Object? tagName = null,
    Object? currentValue = null,
    Object? threshold = null,
    Object? condition = null,
    Object? raisedAt = null,
    Object? acknowledgedAt = freezed,
    Object? acknowledgedBy = freezed,
    Object? acknowledgedComment = freezed,
    Object? clearedAt = freezed,
    Object? escalatedAt = freezed,
    Object? isActive = null,
    Object? isAcknowledged = null,
    Object? isSuppressed = null,
    Object? notes = freezed,
    Object? escalationLevel = null,
    Object? suppressionCount = null,
    Object? relatedAlertIds = null,
    Object? trendData = null,
    Object? alertType = freezed,
    Object? escalationCount = null,
    Object? lastUpdatedTime = freezed,
    Object? equipment = freezed,
    Object? location = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            severity: null == severity
                ? _value.severity
                : severity // ignore: cast_nullable_to_non_nullable
                      as String,
            source: null == source
                ? _value.source
                : source // ignore: cast_nullable_to_non_nullable
                      as String,
            tagName: null == tagName
                ? _value.tagName
                : tagName // ignore: cast_nullable_to_non_nullable
                      as String,
            currentValue: null == currentValue
                ? _value.currentValue
                : currentValue // ignore: cast_nullable_to_non_nullable
                      as double,
            threshold: null == threshold
                ? _value.threshold
                : threshold // ignore: cast_nullable_to_non_nullable
                      as double,
            condition: null == condition
                ? _value.condition
                : condition // ignore: cast_nullable_to_non_nullable
                      as String,
            raisedAt: null == raisedAt
                ? _value.raisedAt
                : raisedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            acknowledgedAt: freezed == acknowledgedAt
                ? _value.acknowledgedAt
                : acknowledgedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            acknowledgedBy: freezed == acknowledgedBy
                ? _value.acknowledgedBy
                : acknowledgedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            acknowledgedComment: freezed == acknowledgedComment
                ? _value.acknowledgedComment
                : acknowledgedComment // ignore: cast_nullable_to_non_nullable
                      as String?,
            clearedAt: freezed == clearedAt
                ? _value.clearedAt
                : clearedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            escalatedAt: freezed == escalatedAt
                ? _value.escalatedAt
                : escalatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            isAcknowledged: null == isAcknowledged
                ? _value.isAcknowledged
                : isAcknowledged // ignore: cast_nullable_to_non_nullable
                      as bool,
            isSuppressed: null == isSuppressed
                ? _value.isSuppressed
                : isSuppressed // ignore: cast_nullable_to_non_nullable
                      as bool,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
            escalationLevel: null == escalationLevel
                ? _value.escalationLevel
                : escalationLevel // ignore: cast_nullable_to_non_nullable
                      as int,
            suppressionCount: null == suppressionCount
                ? _value.suppressionCount
                : suppressionCount // ignore: cast_nullable_to_non_nullable
                      as int,
            relatedAlertIds: null == relatedAlertIds
                ? _value.relatedAlertIds
                : relatedAlertIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            trendData: null == trendData
                ? _value.trendData
                : trendData // ignore: cast_nullable_to_non_nullable
                      as List<Map<String, dynamic>>,
            alertType: freezed == alertType
                ? _value.alertType
                : alertType // ignore: cast_nullable_to_non_nullable
                      as String?,
            escalationCount: null == escalationCount
                ? _value.escalationCount
                : escalationCount // ignore: cast_nullable_to_non_nullable
                      as int,
            lastUpdatedTime: freezed == lastUpdatedTime
                ? _value.lastUpdatedTime
                : lastUpdatedTime // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            equipment: freezed == equipment
                ? _value.equipment
                : equipment // ignore: cast_nullable_to_non_nullable
                      as String?,
            location: freezed == location
                ? _value.location
                : location // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AlertModelImplCopyWith<$Res>
    implements $AlertModelCopyWith<$Res> {
  factory _$$AlertModelImplCopyWith(
    _$AlertModelImpl value,
    $Res Function(_$AlertModelImpl) then,
  ) = __$$AlertModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String description,
    String severity,
    String source,
    String tagName,
    double currentValue,
    double threshold,
    String condition,
    DateTime raisedAt,
    DateTime? acknowledgedAt,
    String? acknowledgedBy,
    String? acknowledgedComment,
    DateTime? clearedAt,
    DateTime? escalatedAt,
    bool isActive,
    bool isAcknowledged,
    bool isSuppressed,
    String? notes,
    int escalationLevel,
    int suppressionCount,
    List<String> relatedAlertIds,
    List<Map<String, dynamic>> trendData,
    String? alertType,
    int escalationCount,
    DateTime? lastUpdatedTime,
    String? equipment,
    String? location,
  });
}

/// @nodoc
class __$$AlertModelImplCopyWithImpl<$Res>
    extends _$AlertModelCopyWithImpl<$Res, _$AlertModelImpl>
    implements _$$AlertModelImplCopyWith<$Res> {
  __$$AlertModelImplCopyWithImpl(
    _$AlertModelImpl _value,
    $Res Function(_$AlertModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AlertModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? severity = null,
    Object? source = null,
    Object? tagName = null,
    Object? currentValue = null,
    Object? threshold = null,
    Object? condition = null,
    Object? raisedAt = null,
    Object? acknowledgedAt = freezed,
    Object? acknowledgedBy = freezed,
    Object? acknowledgedComment = freezed,
    Object? clearedAt = freezed,
    Object? escalatedAt = freezed,
    Object? isActive = null,
    Object? isAcknowledged = null,
    Object? isSuppressed = null,
    Object? notes = freezed,
    Object? escalationLevel = null,
    Object? suppressionCount = null,
    Object? relatedAlertIds = null,
    Object? trendData = null,
    Object? alertType = freezed,
    Object? escalationCount = null,
    Object? lastUpdatedTime = freezed,
    Object? equipment = freezed,
    Object? location = freezed,
  }) {
    return _then(
      _$AlertModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        severity: null == severity
            ? _value.severity
            : severity // ignore: cast_nullable_to_non_nullable
                  as String,
        source: null == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as String,
        tagName: null == tagName
            ? _value.tagName
            : tagName // ignore: cast_nullable_to_non_nullable
                  as String,
        currentValue: null == currentValue
            ? _value.currentValue
            : currentValue // ignore: cast_nullable_to_non_nullable
                  as double,
        threshold: null == threshold
            ? _value.threshold
            : threshold // ignore: cast_nullable_to_non_nullable
                  as double,
        condition: null == condition
            ? _value.condition
            : condition // ignore: cast_nullable_to_non_nullable
                  as String,
        raisedAt: null == raisedAt
            ? _value.raisedAt
            : raisedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        acknowledgedAt: freezed == acknowledgedAt
            ? _value.acknowledgedAt
            : acknowledgedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        acknowledgedBy: freezed == acknowledgedBy
            ? _value.acknowledgedBy
            : acknowledgedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        acknowledgedComment: freezed == acknowledgedComment
            ? _value.acknowledgedComment
            : acknowledgedComment // ignore: cast_nullable_to_non_nullable
                  as String?,
        clearedAt: freezed == clearedAt
            ? _value.clearedAt
            : clearedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        escalatedAt: freezed == escalatedAt
            ? _value.escalatedAt
            : escalatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        isAcknowledged: null == isAcknowledged
            ? _value.isAcknowledged
            : isAcknowledged // ignore: cast_nullable_to_non_nullable
                  as bool,
        isSuppressed: null == isSuppressed
            ? _value.isSuppressed
            : isSuppressed // ignore: cast_nullable_to_non_nullable
                  as bool,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
        escalationLevel: null == escalationLevel
            ? _value.escalationLevel
            : escalationLevel // ignore: cast_nullable_to_non_nullable
                  as int,
        suppressionCount: null == suppressionCount
            ? _value.suppressionCount
            : suppressionCount // ignore: cast_nullable_to_non_nullable
                  as int,
        relatedAlertIds: null == relatedAlertIds
            ? _value._relatedAlertIds
            : relatedAlertIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        trendData: null == trendData
            ? _value._trendData
            : trendData // ignore: cast_nullable_to_non_nullable
                  as List<Map<String, dynamic>>,
        alertType: freezed == alertType
            ? _value.alertType
            : alertType // ignore: cast_nullable_to_non_nullable
                  as String?,
        escalationCount: null == escalationCount
            ? _value.escalationCount
            : escalationCount // ignore: cast_nullable_to_non_nullable
                  as int,
        lastUpdatedTime: freezed == lastUpdatedTime
            ? _value.lastUpdatedTime
            : lastUpdatedTime // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        equipment: freezed == equipment
            ? _value.equipment
            : equipment // ignore: cast_nullable_to_non_nullable
                  as String?,
        location: freezed == location
            ? _value.location
            : location // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AlertModelImpl extends _AlertModel {
  const _$AlertModelImpl({
    required this.id,
    required this.name,
    required this.description,
    required this.severity,
    required this.source,
    required this.tagName,
    required this.currentValue,
    required this.threshold,
    required this.condition,
    required this.raisedAt,
    this.acknowledgedAt,
    this.acknowledgedBy,
    this.acknowledgedComment,
    this.clearedAt,
    this.escalatedAt,
    required this.isActive,
    required this.isAcknowledged,
    required this.isSuppressed,
    this.notes,
    this.escalationLevel = 0,
    this.suppressionCount = 0,
    final List<String> relatedAlertIds = const [],
    final List<Map<String, dynamic>> trendData = const [],
    this.alertType,
    this.escalationCount = 0,
    this.lastUpdatedTime,
    this.equipment,
    this.location,
  }) : _relatedAlertIds = relatedAlertIds,
       _trendData = trendData,
       super._();

  factory _$AlertModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$AlertModelImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String description;
  @override
  final String severity;
  @override
  final String source;
  @override
  final String tagName;
  @override
  final double currentValue;
  @override
  final double threshold;
  @override
  final String condition;
  @override
  final DateTime raisedAt;
  @override
  final DateTime? acknowledgedAt;
  @override
  final String? acknowledgedBy;
  @override
  final String? acknowledgedComment;
  @override
  final DateTime? clearedAt;
  @override
  final DateTime? escalatedAt;
  @override
  final bool isActive;
  @override
  final bool isAcknowledged;
  @override
  final bool isSuppressed;
  @override
  final String? notes;
  @override
  @JsonKey()
  final int escalationLevel;
  @override
  @JsonKey()
  final int suppressionCount;
  final List<String> _relatedAlertIds;
  @override
  @JsonKey()
  List<String> get relatedAlertIds {
    if (_relatedAlertIds is EqualUnmodifiableListView) return _relatedAlertIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_relatedAlertIds);
  }

  final List<Map<String, dynamic>> _trendData;
  @override
  @JsonKey()
  List<Map<String, dynamic>> get trendData {
    if (_trendData is EqualUnmodifiableListView) return _trendData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_trendData);
  }

  // Diagnostic additions for Deep Analysis
  @override
  final String? alertType;
  @override
  @JsonKey()
  final int escalationCount;
  @override
  final DateTime? lastUpdatedTime;
  @override
  final String? equipment;
  @override
  final String? location;

  @override
  String toString() {
    return 'AlertModel(id: $id, name: $name, description: $description, severity: $severity, source: $source, tagName: $tagName, currentValue: $currentValue, threshold: $threshold, condition: $condition, raisedAt: $raisedAt, acknowledgedAt: $acknowledgedAt, acknowledgedBy: $acknowledgedBy, acknowledgedComment: $acknowledgedComment, clearedAt: $clearedAt, escalatedAt: $escalatedAt, isActive: $isActive, isAcknowledged: $isAcknowledged, isSuppressed: $isSuppressed, notes: $notes, escalationLevel: $escalationLevel, suppressionCount: $suppressionCount, relatedAlertIds: $relatedAlertIds, trendData: $trendData, alertType: $alertType, escalationCount: $escalationCount, lastUpdatedTime: $lastUpdatedTime, equipment: $equipment, location: $location)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AlertModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.severity, severity) ||
                other.severity == severity) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.tagName, tagName) || other.tagName == tagName) &&
            (identical(other.currentValue, currentValue) ||
                other.currentValue == currentValue) &&
            (identical(other.threshold, threshold) ||
                other.threshold == threshold) &&
            (identical(other.condition, condition) ||
                other.condition == condition) &&
            (identical(other.raisedAt, raisedAt) ||
                other.raisedAt == raisedAt) &&
            (identical(other.acknowledgedAt, acknowledgedAt) ||
                other.acknowledgedAt == acknowledgedAt) &&
            (identical(other.acknowledgedBy, acknowledgedBy) ||
                other.acknowledgedBy == acknowledgedBy) &&
            (identical(other.acknowledgedComment, acknowledgedComment) ||
                other.acknowledgedComment == acknowledgedComment) &&
            (identical(other.clearedAt, clearedAt) ||
                other.clearedAt == clearedAt) &&
            (identical(other.escalatedAt, escalatedAt) ||
                other.escalatedAt == escalatedAt) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.isAcknowledged, isAcknowledged) ||
                other.isAcknowledged == isAcknowledged) &&
            (identical(other.isSuppressed, isSuppressed) ||
                other.isSuppressed == isSuppressed) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.escalationLevel, escalationLevel) ||
                other.escalationLevel == escalationLevel) &&
            (identical(other.suppressionCount, suppressionCount) ||
                other.suppressionCount == suppressionCount) &&
            const DeepCollectionEquality().equals(
              other._relatedAlertIds,
              _relatedAlertIds,
            ) &&
            const DeepCollectionEquality().equals(
              other._trendData,
              _trendData,
            ) &&
            (identical(other.alertType, alertType) ||
                other.alertType == alertType) &&
            (identical(other.escalationCount, escalationCount) ||
                other.escalationCount == escalationCount) &&
            (identical(other.lastUpdatedTime, lastUpdatedTime) ||
                other.lastUpdatedTime == lastUpdatedTime) &&
            (identical(other.equipment, equipment) ||
                other.equipment == equipment) &&
            (identical(other.location, location) ||
                other.location == location));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    name,
    description,
    severity,
    source,
    tagName,
    currentValue,
    threshold,
    condition,
    raisedAt,
    acknowledgedAt,
    acknowledgedBy,
    acknowledgedComment,
    clearedAt,
    escalatedAt,
    isActive,
    isAcknowledged,
    isSuppressed,
    notes,
    escalationLevel,
    suppressionCount,
    const DeepCollectionEquality().hash(_relatedAlertIds),
    const DeepCollectionEquality().hash(_trendData),
    alertType,
    escalationCount,
    lastUpdatedTime,
    equipment,
    location,
  ]);

  /// Create a copy of AlertModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AlertModelImplCopyWith<_$AlertModelImpl> get copyWith =>
      __$$AlertModelImplCopyWithImpl<_$AlertModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AlertModelImplToJson(this);
  }
}

abstract class _AlertModel extends AlertModel {
  const factory _AlertModel({
    required final String id,
    required final String name,
    required final String description,
    required final String severity,
    required final String source,
    required final String tagName,
    required final double currentValue,
    required final double threshold,
    required final String condition,
    required final DateTime raisedAt,
    final DateTime? acknowledgedAt,
    final String? acknowledgedBy,
    final String? acknowledgedComment,
    final DateTime? clearedAt,
    final DateTime? escalatedAt,
    required final bool isActive,
    required final bool isAcknowledged,
    required final bool isSuppressed,
    final String? notes,
    final int escalationLevel,
    final int suppressionCount,
    final List<String> relatedAlertIds,
    final List<Map<String, dynamic>> trendData,
    final String? alertType,
    final int escalationCount,
    final DateTime? lastUpdatedTime,
    final String? equipment,
    final String? location,
  }) = _$AlertModelImpl;
  const _AlertModel._() : super._();

  factory _AlertModel.fromJson(Map<String, dynamic> json) =
      _$AlertModelImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get description;
  @override
  String get severity;
  @override
  String get source;
  @override
  String get tagName;
  @override
  double get currentValue;
  @override
  double get threshold;
  @override
  String get condition;
  @override
  DateTime get raisedAt;
  @override
  DateTime? get acknowledgedAt;
  @override
  String? get acknowledgedBy;
  @override
  String? get acknowledgedComment;
  @override
  DateTime? get clearedAt;
  @override
  DateTime? get escalatedAt;
  @override
  bool get isActive;
  @override
  bool get isAcknowledged;
  @override
  bool get isSuppressed;
  @override
  String? get notes;
  @override
  int get escalationLevel;
  @override
  int get suppressionCount;
  @override
  List<String> get relatedAlertIds;
  @override
  List<Map<String, dynamic>> get trendData; // Diagnostic additions for Deep Analysis
  @override
  String? get alertType;
  @override
  int get escalationCount;
  @override
  DateTime? get lastUpdatedTime;
  @override
  String? get equipment;
  @override
  String? get location;

  /// Create a copy of AlertModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AlertModelImplCopyWith<_$AlertModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
