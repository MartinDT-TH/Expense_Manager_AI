import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkInfo {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isConnected = true;

  bool get isConnected => _isConnected;

  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map((results) {
        _isConnected = results.isNotEmpty && !results.contains(ConnectivityResult.none);
        return _isConnected;
      });

  Future<bool> checkConnection() async {
    final results = await _connectivity.checkConnectivity();
    _isConnected = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    return _isConnected;
  }

  void dispose() {
    _subscription?.cancel();
  }
}
