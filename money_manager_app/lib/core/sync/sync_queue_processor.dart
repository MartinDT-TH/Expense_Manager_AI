import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/local_database.dart';
import '../error/exceptions.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';

/// Regex: GUID format 8-4-4-4-12 hex (lowercase or uppercase).
final RegExp _guidRegex = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool _isValidGuid(String? s) {
  if (s == null || s.isEmpty) return false;
  return _guidRegex.hasMatch(s);
}

/// Thứ tự sync bắt buộc: Wallet → Category → Transaction (tránh lỗi FK).
/// Budget/Group sau nếu có.
const List<String> _syncEntityOrder = [
  'wallet',
  'category',
  'transaction',
  'budget',
  'group',
];

/// Sync Queue Processor
/// Handles offline-first data synchronization
class SyncQueueProcessor {
  final LocalDatabase database;
  final ApiClient apiClient;
  final NetworkInfo networkInfo;
  
  bool _isProcessing = false;

  SyncQueueProcessor({
    required this.database,
    required this.apiClient,
    required this.networkInfo,
  });

  /// Add item to sync queue
  Future<void> addToQueue({
    required String entityType,
    required String entityId,
    required SyncAction action,
    required Map<String, dynamic> data,
  }) async {
    final db = await database.database;
    await db.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action.name,
      'data': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Process all pending sync items in FK-safe order: Wallet → Category → Transaction → Budget → Group.
  /// Dùng [refResolutionMap] để resolve temp_ walletId/categoryId khi sync transaction.
  Future<SyncResult> processQueue() async {
    if (_isProcessing) {
      return SyncResult(success: false, message: 'Đồng bộ đang diễn ra');
    }
    if (!await networkInfo.checkConnection()) {
      return SyncResult(success: false, message: 'Không có kết nối mạng');
    }

    _isProcessing = true;
    int synced = 0;
    int failed = 0;
    final errors = <String>[];

    final queueStart = DateTime.now();

    try {
      final db = await database.database;
      final allItems = await db.query(
        'sync_queue',
        orderBy: 'created_at ASC',
      );

      if (kDebugMode) {
        final byType = <String, int>{};
        for (final e in allItems) {
          final t = e['entity_type'] as String? ?? '?';
          byType[t] = (byType[t] ?? 0) + 1;
        }
        debugPrint(
          '[SyncQueue] start items=${allItems.length} byType=$byType at ${queueStart.toIso8601String()}',
        );
      }

      /// tempId/categoryId → serverId sau khi replace (key: "wallet:temp_1" hoặc "category:temp_2")
      final refResolutionMap = <String, String>{};

      for (final entityType in _syncEntityOrder) {
        final batch = allItems
            .where((e) => (e['entity_type'] as String?) == entityType)
            .toList();

        for (final item in batch) {
          try {
            final success = await _processSyncItem(
              entityType: item['entity_type'] as String,
              entityId: item['entity_id'] as String,
              action: SyncAction.values.byName(item['action'] as String),
              data: jsonDecode(item['data'] as String) as Map<String, dynamic>,
              refResolutionMap: refResolutionMap,
            );

            if (success) {
              await db.delete(
                'sync_queue',
                where: 'id = ?',
                whereArgs: [item['id']],
              );
              synced++;
            } else {
              failed++;
              errors.add('Không thể đồng bộ ${item['entity_type']}:${item['entity_id']}');
            }
          } catch (e) {
            failed++;
            errors.add('Lỗi đồng bộ ${item['entity_type']}:${item['entity_id']}: $e');
          }
        }
      }

      final queueEnd = DateTime.now();
      final durationMs = queueEnd.difference(queueStart).inMilliseconds;
      if (kDebugMode) {
        debugPrint(
          '[SyncQueue] end duration=${durationMs}ms synced=$synced failed=$failed at ${queueEnd.toIso8601String()}',
        );
      }

      return SyncResult(
        success: failed == 0,
        synced: synced,
        failed: failed,
        errors: errors,
        message: 'Đã đồng bộ $synced mục, thất bại $failed',
      );
    } finally {
      _isProcessing = false;
    }
  }

  /// Process a single sync item.
  /// [refResolutionMap]: tempId → serverId cho wallet/category; dùng để resolve FK khi sync transaction.
  Future<bool> _processSyncItem({
    required String entityType,
    required String entityId,
    required SyncAction action,
    required Map<String, dynamic> data,
    required Map<String, String> refResolutionMap,
  }) async {
    final endpoint = _getEndpoint(entityType);

    try {
      switch (action) {
        case SyncAction.create:
          final createData = Map<String, dynamic>.from(data);
          if (entityId.startsWith('temp_')) {
            createData.remove('id');
          }

          // Transaction: resolve walletId/categoryId từ refResolutionMap (Wallet/Category đã sync trước trong cùng lượt).
          if (entityType == 'transaction') {
            String? walletIdVal = createData['walletId']?.toString();
            String? catId = createData['categoryId']?.toString();
            if (walletIdVal != null && walletIdVal.startsWith('temp_')) {
              walletIdVal = refResolutionMap['wallet:$walletIdVal'] ?? walletIdVal;
            }
            if (catId != null && catId.startsWith('temp_')) {
              catId = refResolutionMap['category:$catId'] ?? catId;
            }
            if (!_isValidGuid(catId) || !_isValidGuid(walletIdVal)) {
              if (kDebugMode) {
                debugPrint(
                  'Sync transaction create skipped: categoryId hoặc walletId chưa sync '
                  '(categoryId=$catId, walletId=$walletIdVal). Wallet/Category phải sync trước.',
                );
              }
              return false;
            }
            final amount = createData['amount'];
            final numAmount = amount is num ? amount : (double.tryParse(amount?.toString() ?? '') ?? 0.0);
            final transactionDate = createData['transactionDate']?.toString() ?? DateTime.now().toUtc().toIso8601String();
            final payload = <String, dynamic>{
              'amount': numAmount,
              'categoryId': catId,
              'walletId': walletIdVal,
              'transactionDate': transactionDate,
              'note': createData['note']?.toString(),
            };
            final groupId = createData['groupId']?.toString();
            if (groupId != null && groupId.isNotEmpty && _isValidGuid(groupId)) {
              payload['groupId'] = groupId;
            }
            final billImageUrl = createData['billImageUrl']?.toString();
            if (billImageUrl != null && billImageUrl.isNotEmpty) {
              payload['billImageUrl'] = billImageUrl;
            }
            createData.clear();
            createData.addAll(payload);
          }

          final response = await apiClient.post(endpoint, data: createData);

          Object? rawData = response.data;
          Map<String, dynamic>? responseMap;
          if (rawData is Map<String, dynamic>) {
            responseMap = rawData;
          } else if (rawData is Map) {
            responseMap = Map<String, dynamic>.from(rawData);
          }
          if (responseMap == null || responseMap.isEmpty) {
            if (entityId.startsWith('temp_')) {
              if (kDebugMode) {
                debugPrint('Sync create: server response không có body object (temp_ $entityId). Không xóa queue.');
              }
              return false;
            }
            return true;
          }
          final serverId = responseMap['id'] ?? responseMap['Id'];
          final serverIdStr = serverId?.toString();

          if (entityId.startsWith('temp_')) {
            if (serverIdStr == null || serverIdStr.isEmpty) {
              if (kDebugMode) {
                debugPrint('Sync create: server response thiếu id (temp_ $entityId). Không xóa queue.');
              }
              return false;
            }
            await _replaceTempIdWithServerId(entityType, entityId, serverIdStr);
            if (entityType == 'wallet' || entityType == 'category') {
              refResolutionMap['$entityType:$entityId'] = serverIdStr;
            }
          } else {
            await _markAsSynced(entityType, entityId);
          }
          break;
        case SyncAction.update:
          await apiClient.put('$endpoint/$entityId', data: data);
          await _markAsSynced(entityType, entityId);
          break;
        case SyncAction.delete:
          await apiClient.delete('$endpoint/$entityId');
          await _deleteFromLocal(entityType, entityId);
          break;
      }

      return true;
    } catch (e, st) {
      if (e is AppException && e.statusCode == 409) {
        await _handleConflict(entityType, entityId);
        return true;
      }
      if (kDebugMode) {
        final code = e is AppException ? e.statusCode : null;
        debugPrint('Sync failed $entityType/$entityId ${action.name}: ${code != null ? "[$code] " : ""}$e');
        debugPrint('$st');
      }
      return false;
    }
  }
  
  /// Replace temp ID with server ID after successful create
  Future<void> _replaceTempIdWithServerId(String entityType, String tempId, String serverId) async {
    final db = await database.database;
    final tableName = _getTableName(entityType);
    
    // Get existing record
    final existing = await db.query(tableName, where: 'id = ?', whereArgs: [tempId]);
    if (existing.isEmpty) return;
    
    // Delete temp record
    await db.delete(tableName, where: 'id = ?', whereArgs: [tempId]);
    
    // Insert with server ID and mark as synced
    final newData = Map<String, dynamic>.from(existing.first);
    newData['id'] = serverId;
    newData['is_synced'] = 1;
    await db.insert(tableName, newData, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  /// Delete entity from local database
  Future<void> _deleteFromLocal(String entityType, String entityId) async {
    final db = await database.database;
    final tableName = _getTableName(entityType);
    await db.delete(tableName, where: 'id = ?', whereArgs: [entityId]);
  }

  String _getEndpoint(String entityType) {
    switch (entityType) {
      case 'wallet':
        return '/Wallet';
      case 'transaction':
        return '/Transaction';
      case 'category':
        return '/Category';
      case 'budget':
        return '/Budget';
      case 'group':
        return '/Group';
      default:
        throw Exception('Unknown entity type: $entityType');
    }
  }

  Future<void> _markAsSynced(String entityType, String entityId) async {
    final db = await database.database;
    final tableName = _getTableName(entityType);
    
    await db.update(
      tableName,
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [entityId],
    );
  }

  String _getTableName(String entityType) {
    switch (entityType) {
      case 'wallet':
        return 'wallets';
      case 'transaction':
        return 'transactions';
      case 'category':
        return 'categories';
      case 'budget':
        return 'budgets';
      case 'group':
        return 'groups';
      default:
        return entityType;
    }
  }

  Future<void> _handleConflict(String entityType, String entityId) async {
    // Fetch latest from server and update local
    final endpoint = _getEndpoint(entityType);
    
    try {
      final response = await apiClient.get('$endpoint/$entityId');
      if (response.statusCode == 200) {
        final db = await database.database;
        final tableName = _getTableName(entityType);

        final responseData = response.data;
        if (responseData is! Map) {
          return;
        }

        await db.update(
          tableName,
          {...Map<String, dynamic>.from(responseData), 'is_synced': 1},
          where: 'id = ?',
          whereArgs: [entityId],
        );
      }
    } catch (e) {
      // Item might have been deleted on server
      final db = await database.database;
      final tableName = _getTableName(entityType);
      await db.update(
        tableName,
        {'is_deleted': 1, 'is_synced': 1},
        where: 'id = ?',
        whereArgs: [entityId],
      );
    }
  }

  /// Get pending sync count
  Future<int> getPendingCount() async {
    final db = await database.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM sync_queue');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clear all pending sync items
  Future<void> clearQueue() async {
    final db = await database.database;
    await db.delete('sync_queue');
  }
}

enum SyncAction { create, update, delete }

class SyncResult {
  final bool success;
  final int synced;
  final int failed;
  final List<String> errors;
  final String message;

  SyncResult({
    required this.success,
    this.synced = 0,
    this.failed = 0,
    this.errors = const [],
    this.message = '',
  });
}
