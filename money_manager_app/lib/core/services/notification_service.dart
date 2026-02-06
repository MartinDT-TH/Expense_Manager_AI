import 'package:flutter/material.dart';
// TODO: Add flutter_local_notifications to pubspec.yaml
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification Service for handling local notifications
/// 
/// Setup required:
/// 1. Add to pubspec.yaml: flutter_local_notifications: ^17.0.0
/// 2. Android: Add to AndroidManifest.xml:
///    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
///    <uses-permission android:name="android.permission.VIBRATE"/>
///    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
/// 3. iOS: Add to Info.plist for background modes
class NotificationService {
  // static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  /// Initialize notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    // TODO: Uncomment when flutter_local_notifications is added
    /*
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    */
    
    _isInitialized = true;
    debugPrint('Đã khởi tạo NotificationService');
  }

  /// Request notification permissions (Android 13+, iOS)
  static Future<bool> requestPermission() async {
    // TODO: Uncomment when flutter_local_notifications is added
    /*
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    */
    return true;
  }

  /// Show instant notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // TODO: Uncomment when flutter_local_notifications is added
    /*
    const androidDetails = AndroidNotificationDetails(
      'money_manager_channel',
      'Smart Money',
      channelDescription: 'Thông báo cho ứng dụng Smart Money',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _plugin.show(id, title, body, details, payload: payload);
    */
    debugPrint('Thông báo: $title - $body');
  }

  /// Show budget alert notification
  static Future<void> showBudgetAlert({
    required double spent,
    required double limit,
    required String categoryName,
  }) async {
    final percentage = (spent / limit * 100).round();
    String title;
    String body;
    
    if (percentage >= 100) {
      title = '⚠️ Vượt ngân sách!';
      body = 'Bạn đã vượt ngân sách $categoryName ${(spent - limit).toStringAsFixed(0)} ₫';
    } else if (percentage >= 80) {
      title = '⚡ Cảnh báo ngân sách';
      body = 'Bạn đã dùng $percentage% ngân sách $categoryName';
    } else {
      return; // Don't notify if under 80%
    }
    
    await showNotification(
      id: categoryName.hashCode,
      title: title,
      body: body,
      payload: 'budget:$categoryName',
    );
  }

  /// Show transaction reminder
  static Future<void> showTransactionReminder() async {
    await showNotification(
      id: 1001,
      title: '📝 Đừng quên!',
      body: 'Hôm nay bạn đã ghi chi tiêu chưa?',
      payload: 'reminder:transaction',
    );
  }

  /// Schedule daily reminder
  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    // TODO: Implement with flutter_local_notifications zonedSchedule
    debugPrint('Đã lên lịch nhắc nhở lúc $hour:$minute');
  }

  /// Cancel notification by id
  static Future<void> cancelNotification(int id) async {
    // await _plugin.cancel(id);
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    // await _plugin.cancelAll();
  }

  // ignore: unused_element
  static void _onNotificationTapped(dynamic response) {
    // Handle notification tap
    // Navigate to relevant screen based on payload
    // TODO: Implement navigation based on payload type
    debugPrint('Nhấn vào thông báo: ${response.payload}');
  }
}

