import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Service để quản lý kết nối SignalR với GroupHub
/// Cho phép real-time updates khi members trong group thêm transactions
class SignalRService {
  static final SignalRService _instance = SignalRService._internal();
  factory SignalRService() => _instance;
  SignalRService._internal();

  HubConnection? _hubConnection;
  final _storage = const FlutterSecureStorage();
  
  // Stream controllers cho các events
  final _newTransactionController = StreamController<Map<String, dynamic>>.broadcast();
  final _groupUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _memberJoinedController = StreamController<Map<String, dynamic>>.broadcast();
  final _memberLeftController = StreamController<Map<String, dynamic>>.broadcast();
  final _memberKickedController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<HubConnectionState>.broadcast();

  // Public streams
  Stream<Map<String, dynamic>> get onNewTransaction => _newTransactionController.stream;
  Stream<Map<String, dynamic>> get onGroupUpdated => _groupUpdatedController.stream;
  Stream<Map<String, dynamic>> get onMemberJoined => _memberJoinedController.stream;
  Stream<Map<String, dynamic>> get onMemberLeft => _memberLeftController.stream;
  Stream<Map<String, dynamic>> get onMemberKicked => _memberKickedController.stream;
  Stream<HubConnectionState> get onConnectionStateChanged => _connectionStateController.stream;

  bool get isConnected => _hubConnection?.state == HubConnectionState.Connected;
  HubConnectionState? get connectionState => _hubConnection?.state;

  /// Lấy Hub URL phù hợp với platform
  String get _hubUrl {
    if (kIsWeb) {
      return AppConstants.signalRHubUrl;
    }
    if (Platform.isAndroid) {
      // Check if running on emulator (usually 10.0.2.2)
      return AppConstants.signalRHubUrl; // Use real IP for real device
    }
    if (Platform.isIOS) {
      return AppConstants.signalRHubUrlIOS;
    }
    return AppConstants.signalRHubUrl;
  }

  /// Khởi tạo kết nối SignalR
  Future<void> initialize() async {
    if (_hubConnection != null) {
      debugPrint('[SignalR] Already initialized');
      return;
    }

    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) {
        debugPrint('[SignalR] No token found, skipping connection');
        return;
      }

      _hubConnection = HubConnectionBuilder()
          .withUrl(
            _hubUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () async => token,
            ),
          )
          .withAutomaticReconnect()
          .build();

      // Setup event handlers
      _setupEventHandlers();

      // Connect
      await _hubConnection!.start();
      debugPrint('[SignalR] Connected successfully');
      _connectionStateController.add(HubConnectionState.Connected);

    } catch (e) {
      debugPrint('[SignalR] Connection error: $e');
      _connectionStateController.add(HubConnectionState.Disconnected);
    }
  }

  /// Đăng ký các event handlers
  void _setupEventHandlers() {
    if (_hubConnection == null) return;

    // NewTransaction event
    _hubConnection!.on('NewTransaction', (arguments) {
      debugPrint('[SignalR] NewTransaction received: $arguments');
      if (arguments != null && arguments.isNotEmpty) {
        final data = arguments[0] as Map<String, dynamic>;
        _newTransactionController.add(data);
      }
    });

    // GroupUpdated event
    _hubConnection!.on('GroupUpdated', (arguments) {
      debugPrint('[SignalR] GroupUpdated received: $arguments');
      if (arguments != null && arguments.isNotEmpty) {
        final data = arguments[0] as Map<String, dynamic>;
        _groupUpdatedController.add(data);
      }
    });

    // MemberJoined event
    _hubConnection!.on('MemberJoined', (arguments) {
      debugPrint('[SignalR] MemberJoined received: $arguments');
      if (arguments != null && arguments.isNotEmpty) {
        final data = arguments[0] as Map<String, dynamic>;
        _memberJoinedController.add(data);
      }
    });

    // MemberLeft event
    _hubConnection!.on('MemberLeft', (arguments) {
      debugPrint('[SignalR] MemberLeft received: $arguments');
      if (arguments != null && arguments.isNotEmpty) {
        final data = arguments[0] as Map<String, dynamic>;
        _memberLeftController.add(data);
      }
    });

    // MemberKicked event
    _hubConnection!.on('MemberKicked', (arguments) {
      debugPrint('[SignalR] MemberKicked received: $arguments');
      if (arguments != null && arguments.isNotEmpty) {
        final data = arguments[0] as Map<String, dynamic>;
        _memberKickedController.add(data);
      }
    });

    // Connection state changes
    _hubConnection!.onclose(({error}) {
      debugPrint('[SignalR] Connection closed: $error');
      _connectionStateController.add(HubConnectionState.Disconnected);
    });

    _hubConnection!.onreconnecting(({error}) {
      debugPrint('[SignalR] Reconnecting: $error');
      _connectionStateController.add(HubConnectionState.Reconnecting);
    });

    _hubConnection!.onreconnected(({connectionId}) {
      debugPrint('[SignalR] Reconnected with id: $connectionId');
      _connectionStateController.add(HubConnectionState.Connected);
    });
  }

  /// Join vào group room để nhận notifications
  Future<void> joinGroup(String groupId) async {
    if (_hubConnection?.state != HubConnectionState.Connected) {
      debugPrint('[SignalR] Not connected, cannot join group');
      return;
    }

    try {
      await _hubConnection!.invoke('JoinGroup', args: [groupId]);
      debugPrint('[SignalR] Joined group: $groupId');
    } catch (e) {
      debugPrint('[SignalR] Error joining group: $e');
    }
  }

  /// Leave group room
  Future<void> leaveGroup(String groupId) async {
    if (_hubConnection?.state != HubConnectionState.Connected) {
      return;
    }

    try {
      await _hubConnection!.invoke('LeaveGroup', args: [groupId]);
      debugPrint('[SignalR] Left group: $groupId');
    } catch (e) {
      debugPrint('[SignalR] Error leaving group: $e');
    }
  }

  /// Disconnect và cleanup
  Future<void> disconnect() async {
    if (_hubConnection != null) {
      await _hubConnection!.stop();
      _hubConnection = null;
      debugPrint('[SignalR] Disconnected');
    }
  }

  /// Reconnect với token mới (sau khi refresh token)
  Future<void> reconnect() async {
    await disconnect();
    await initialize();
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _newTransactionController.close();
    _groupUpdatedController.close();
    _memberJoinedController.close();
    _memberLeftController.close();
    _memberKickedController.close();
    _connectionStateController.close();
  }
}
