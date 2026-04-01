import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

/// Network connectivity status
enum NetworkStatus { online, offline, unknown }

/// Network connectivity provider
class NetworkConnectivity extends StateNotifier<NetworkStatus> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  NetworkConnectivity() : super(NetworkStatus.unknown) {
    _initConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      print('⚠️ Failed to get connectivity: $e');
      state = NetworkStatus.unknown;
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      if (state != NetworkStatus.online) {
        print('🌐 Network: Online');
        state = NetworkStatus.online;
      }
    } else {
      if (state != NetworkStatus.offline) {
        print('📡 Network: Offline');
        state = NetworkStatus.offline;
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider for network connectivity
final networkConnectivityProvider =
    StateNotifierProvider<NetworkConnectivity, NetworkStatus>((ref) {
      return NetworkConnectivity();
    });

/// Simple boolean provider for offline status
final isOfflineProvider = Provider<bool>((ref) {
  final networkStatus = ref.watch(networkConnectivityProvider);
  return networkStatus == NetworkStatus.offline;
});

/// Simple boolean provider for online status
final isOnlineProvider = Provider<bool>((ref) {
  final networkStatus = ref.watch(networkConnectivityProvider);
  return networkStatus == NetworkStatus.online;
});
