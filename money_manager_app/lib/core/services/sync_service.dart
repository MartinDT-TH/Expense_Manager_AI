import 'dart:async';
import 'package:flutter/foundation.dart';
import '../network/network_info.dart';
import '../sync/sync_queue_processor.dart';

/// Event để UI hiển thị toast khi auto-sync / periodic sync xong.
class SyncToastEvent {
  final String message;
  final bool success;

  SyncToastEvent(this.message, this.success);
}

/// Service to manage data synchronization
/// Handles auto-sync when network becomes available
/// Provides sync status information to UI
class SyncService extends ChangeNotifier {
  final NetworkInfo networkInfo;
  final SyncQueueProcessor syncQueueProcessor;

  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _periodicSyncTimer;
  final StreamController<SyncToastEvent> _syncToastController =
      StreamController<SyncToastEvent>.broadcast();

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

  /// Stream sự kiện toast khi auto-sync hoặc periodic sync hoàn tất (chỉ khi có pending > 0).
  Stream<SyncToastEvent> get syncToastStream => _syncToastController.stream;

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
    _syncToastController.close();
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

    if (!await networkInfo.checkConnection()) {
      return SyncResult(
        success: false,
        message: 'Không có kết nối mạng',
      );
    }

    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    final pendingBefore = await getPendingCount();
    final startTime = DateTime.now();
    if (kDebugMode) {
      debugPrint('[Sync] start pendingCount=$pendingBefore at ${startTime.toIso8601String()}');
    }

    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final queueResult = await syncQueueProcessor.processQueue();
      await _updatePendingCount();

      final endTime = DateTime.now();
      final durationMs = endTime.difference(startTime).inMilliseconds;
      _lastSyncTime = endTime;
      _isSyncing = false;
      notifyListeners();

      if (kDebugMode) {
        debugPrint(
          '[Sync] end at ${endTime.toIso8601String()} duration=${durationMs}ms '
          'synced=${queueResult.synced} failed=${queueResult.failed} pendingAfter=$_pendingCount',
        );
      }

      final message = _pendingCount == 0
          ? 'Đồng bộ thành công!'
          : 'Đồng bộ hoàn tất, còn $_pendingCount mục chờ';

      return SyncResult(
        success: queueResult.success,
        synced: queueResult.synced,
        failed: queueResult.failed,
        message: message,
      );
    } catch (e) {
      _lastSyncError = e.toString();
      _isSyncing = false;
      notifyListeners();
      final endTime = DateTime.now();
      if (kDebugMode) {
        debugPrint('[Sync] error after ${endTime.difference(startTime).inMilliseconds}ms: $e');
      }
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

  /// Auto-sync when network becomes available. Nếu có pending và sync xong thì gửi toast.
  Future<void> _performAutoSync() async {
    if (_isSyncing) return;
    final pending = await getPendingCount();
    if (pending == 0) return;
    final result = await syncNow();
    if (!_syncToastController.isClosed) {
      _syncToastController.add(SyncToastEvent(result.message, result.success));
    }
  }

  /// Periodic sync (every 5 min). Nếu có pending và sync xong thì gửi toast.
  Future<void> _performPeriodicSync() async {
    if (!await networkInfo.checkConnection()) return;
    if (_isSyncing) return;
    final pending = await getPendingCount();
    if (pending == 0) return;
    final result = await syncNow();
    if (!_syncToastController.isClosed) {
      _syncToastController.add(SyncToastEvent(result.message, result.success));
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
