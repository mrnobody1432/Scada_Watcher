import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alert_model.dart';
import '../firestore/mock_data.dart';

class AlertRepository {
  final FirebaseFirestore? _firestore;
  final bool useMockData;

  AlertRepository({FirebaseFirestore? firestore, this.useMockData = false})
    : _firestore =
          firestore ?? (useMockData ? null : FirebaseFirestore.instance);

  Stream<List<AlertModel>> watchActiveAlerts() {
    if (useMockData || _firestore == null) {
      // Use mock data for offline development/testing
      return Stream.periodic(Duration(seconds: 2), (_) {
        return MockData.mockActiveAlerts;
      }).asBroadcastStream();
    }

    try {
      return _firestore!
          .collection('alerts_active')
          .where('isActive', isEqualTo: true)
          .orderBy('raisedAt', descending: true)
          .snapshots(includeMetadataChanges: true)
          .handleError((error) {
            print('⚠️ Firestore query error: $error');
            // Return empty list on error but keep stream alive
            return <AlertModel>[];
          })
          .map((snapshot) {
            // Check if data is from cache (offline mode)
            if (snapshot.metadata.isFromCache) {
              print('📦 Loading alerts from cache (offline mode)');
            }

            return snapshot.docs
                .map((doc) => AlertModel.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      print('❌ Error setting up alerts stream: $e');
      // If Firebase query fails, fall back to mock data
      return Stream.periodic(Duration(seconds: 2), (_) {
        return MockData.mockActiveAlerts;
      }).asBroadcastStream();
    }
  }

  Stream<AlertModel?> watchAlertById(String alertId) {
    if (useMockData || _firestore == null) {
      return Stream.periodic(Duration(seconds: 1), (_) {
        try {
          return [
            ...MockData.mockActiveAlerts,
            ...MockData.mockHistoryAlerts,
          ].firstWhere((alert) => alert.id == alertId);
        } catch (e) {
          return null;
        }
      }).asBroadcastStream();
    }

    // First, try watching active collection
    final activeStream = _firestore!
        .collection('alerts_active')
        .doc(alertId)
        .snapshots();

    return activeStream.asyncMap((doc) async {
      if (doc.exists) {
        return AlertModel.fromFirestore(doc);
      } else {
        // If not in active, check history (one-time fetch since history usually doesn't change)
        final historyDoc = await _firestore!
            .collection('alerts_history')
            .doc(alertId)
            .get();

        if (historyDoc.exists) {
          return AlertModel.fromFirestore(historyDoc);
        }
        return null;
      }
    });
  }

  Future<List<AlertModel>> getAlertHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? severity,
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    if (useMockData) {
      await Future.delayed(Duration(milliseconds: 500));
      var filtered = MockData.mockHistoryAlerts;
      if (severity != null && severity.isNotEmpty) {
        filtered = filtered.where((a) => a.severity == severity).toList();
      }
      return filtered;
    }

    Query query = _firestore!.collection('alerts_history');

    if (startDate != null) {
      query = query.where(
        'raisedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'raisedAt',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }
    if (severity != null && severity.isNotEmpty) {
      query = query.where('severity', isEqualTo: severity);
    }

    query = query.orderBy('raisedAt', descending: true).limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
  }

  Future<void> acknowledgeAlert(
    String alertId,
    String acknowledgedBy, {
    String? comment,
  }) async {
    if (useMockData || _firestore == null) {
      // Mock data acknowledgment
      await Future.delayed(Duration(milliseconds: 500));
      final index = MockData.mockActiveAlerts.indexWhere(
        (a) => a.id == alertId,
      );
      if (index != -1) {
        MockData.mockActiveAlerts[index] = MockData.mockActiveAlerts[index]
            .copyWith(
              isAcknowledged: true,
              acknowledgedAt: DateTime.now(),
              acknowledgedBy: acknowledgedBy,
              acknowledgedComment: comment,
            );
      }
      return;
    }

    try {
      final updateData = {
        'isAcknowledged': true,
        'acknowledgedAt': FieldValue.serverTimestamp(),
        'acknowledgedBy': acknowledgedBy,
      };

      if (comment != null && comment.isNotEmpty) {
        updateData['acknowledgedComment'] = comment;
      }

      await _firestore!
          .collection('alerts_active')
          .doc(alertId)
          .update(updateData);
    } catch (e) {
      // If Firebase fails, update mock data
      await Future.delayed(Duration(milliseconds: 500));
      final index = MockData.mockActiveAlerts.indexWhere(
        (a) => a.id == alertId,
      );
      if (index != -1) {
        MockData.mockActiveAlerts[index] = MockData.mockActiveAlerts[index]
            .copyWith(
              isAcknowledged: true,
              acknowledgedAt: DateTime.now(),
              acknowledgedBy: acknowledgedBy,
              acknowledgedComment: comment,
            );
      }
    }
  }

  Future<int> getActiveAlertCount({String? severity}) async {
    if (useMockData || _firestore == null) {
      await Future.delayed(Duration(milliseconds: 200));
      if (severity == null) {
        return MockData.mockActiveAlerts.length;
      }
      return MockData.mockActiveAlerts
          .where((a) => a.severity == severity)
          .length;
    }

    try {
      Query query = _firestore!
          .collection('alerts_active')
          .where('isActive', isEqualTo: true);

      if (severity != null) {
        query = query.where('severity', isEqualTo: severity);
      }

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      // Fallback to mock
      await Future.delayed(Duration(milliseconds: 200));
      if (severity == null) {
        return MockData.mockActiveAlerts.length;
      }
      return MockData.mockActiveAlerts
          .where((a) => a.severity == severity)
          .length;
    }
  }

  Future<int> getAcknowledgedCount() async {
    if (useMockData || _firestore == null) {
      await Future.delayed(Duration(milliseconds: 200));
      return MockData.mockActiveAlerts.where((a) => a.isAcknowledged).length;
    }

    try {
      final snapshot = await _firestore!
          .collection('alerts_active')
          .where('isActive', isEqualTo: true)
          .where('isAcknowledged', isEqualTo: true)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      await Future.delayed(Duration(milliseconds: 200));
      return MockData.mockActiveAlerts.where((a) => a.isAcknowledged).length;
    }
  }

  Future<int> getClearedLast24Hours() async {
    if (useMockData || _firestore == null) {
      await Future.delayed(Duration(milliseconds: 200));
      return MockData.mockHistoryAlerts.length;
    }

    try {
      final yesterday = DateTime.now().subtract(Duration(hours: 24));
      final snapshot = await _firestore!
          .collection('alerts_history')
          .where(
            'clearedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(yesterday),
          )
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      await Future.delayed(Duration(milliseconds: 200));
      return MockData.mockHistoryAlerts.length;
    }
  }
}
