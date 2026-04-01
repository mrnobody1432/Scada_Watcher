import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Connectivity state
class ConnectivityState {
  final bool isOnline;
  final DateTime lastCheck;
  final String? errorMessage;

  ConnectivityState({
    required this.isOnline,
    required this.lastCheck,
    this.errorMessage,
  });

  ConnectivityState copyWith({
    bool? isOnline,
    DateTime? lastCheck,
    String? errorMessage,
  }) {
    return ConnectivityState(
      isOnline: isOnline ?? this.isOnline,
      lastCheck: lastCheck ?? this.lastCheck,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Connectivity notifier
class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  final FirebaseFirestore _firestore;

  ConnectivityNotifier(this._firestore)
    : super(ConnectivityState(isOnline: true, lastCheck: DateTime.now())) {
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    try {
      // Try to read a system document to check connection
      await _firestore
          .collection('_system')
          .doc('heartbeat')
          .get()
          .timeout(Duration(seconds: 5));

      state = state.copyWith(
        isOnline: true,
        lastCheck: DateTime.now(),
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isOnline: false,
        lastCheck: DateTime.now(),
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> retry() async {
    await _checkConnectivity();
  }
}

// Provider
final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
      return ConnectivityNotifier(FirebaseFirestore.instance);
    });
