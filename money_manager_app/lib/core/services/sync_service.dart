import 'dart:async';
import 'package:flutter/foundation.dart';
import '../network/network_info.dart';
import '../sync/sync_queue_processor.dart';

/// Service to manage data synchronization
/// Handles auto-sync when network becomes available
/// Provides sync status information to UI
class SyncService extends ChangeNotifier {
  final NetworkInfo networkInfo;
  final SyncQueueProcessor syncQueueProcessor;

  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _periodicSyncTimer;
  
  bool _isSyncing = false;
  int _pendingCount = 0;
  String? _lastSyncError;
  DateTime? _lastSyncTime;
  bool _isInitialized = false;

  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;
  String? get lastSyncError => _lastSyncError;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get hasPendingSync => _pendingCount > 0;

  SyncService({
    required this.networkInfo,
    required this.syncQueueProcessor,
  });

  /// Initialize sync service - call this after authentication
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    
    // Listen for network changes
    _connectivitySubscription = networkInfo.onConnectivityChanged.listen((isConnected) {
      if (isConnected) {
        // Auto-sync when network becomes available
        _performAutoSync();
      }
    });

    // Setup periodic sync (every 5 minutes when app is active)
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _performPeriodicSync();
    });

    // Initial sync check
    _updatePendingCount();
    _checkAndSync();
  }

  /// Dispose of resources
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
    super.dispose();
  }
  
  /// Reset sync service state (call on logout)
  void reset() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
    _connectivitySubscription = null;
    _periodicSyncTimer = null;
    _isSyncing = false;
    _pendingCount = 0;
    _lastSyncError = null;
    _lastSyncTime = null;
    _isInitialized = false;
    notifyListeners();
  }

  /// Manual sync trigger
  Future<SyncResult> syncNow() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Đồng bộ đang được thực hiện',
      );
    }

    // Check network first
    if (!await networkInfo.checkConnection()) {
      return SyncResult(
        success: false,
        message: 'Không có kết nối mạng',
      );
    }

    // Set syncing state BEFORE any async work
    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();
    
    // Small delay to ensure UI updates before heavy sync work
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      // Process sync queue (handles all entity types including transactions)
      final queueResult = await syncQueueProcessor.processQueue();

      // Update pending count
      await _updatePendingCount();

      _lastSyncTime = DateTime.now();
      _isSyncing = false;
      notifyListeners();

      return SyncResult(
        success: queueResult.success,
        synced: queueResult.synced,
        failed: queueResult.failed,
        message: _pendingCount == 0 
            ? 'Đồng bộ thành công!' 
            : 'Đồng bộ hoàn tất, còn $_pendingCount mục chờ',
      );
    } catch (e) {
      _lastSyncError = e.toString();
      _isSyncing = false;
      notifyListeners();

      return SyncResult(
        success: false,
        message: 'Lỗi đồng bộ: $e',
      );
    }
  }

  /// Get current pending sync count (from sync_queue)
  Future<int> getPendingCount() async {
    return await syncQueueProcessor.getPendingCount();
  }

  /// Check network and sync if possible
  Future<void> _checkAndSync() async {
    if (await networkInfo.checkConnection()) {
      await _performAutoSync();
    }
  }

  /// Auto-sync when network becomes available
  Future<void> _performAutoSync() async {
    if (_isSyncing) return;
    
    final pending = await getPendingCount();
    if (pending > 0) {
      await syncNow();
    }
  }

  /// Periodic sync (runs every 5 minutes)
  Future<void> _performPeriodicSync() async {
    if (!await networkInfo.checkConnection()) return;
    if (_isSyncing) return;
    
    final pending = await getPendingCount();
    if (pending > 0) {
      await syncNow();
    }
  }

  /// Update pending count and notify listeners
  Future<void> _updatePendingCount() async {
    final count = await getPendingCount();
    // Always update and notify to ensure UI is in sync
    _pendingCount = count;
    notifyListeners();
  }

  /// Refresh pending count (call this after adding transactions)
  Future<void> refreshPendingCount() async {
    await _updatePendingCount();
  }
}
