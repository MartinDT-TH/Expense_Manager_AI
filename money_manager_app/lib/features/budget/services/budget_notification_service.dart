import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../../core/database/local_database.dart';
import '../data/models/budget_model.dart';

/// Service for handling budget-related notifications
class BudgetNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = 
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  // Notification channel IDs
  static const String _budgetWarningChannelId = 'budget_warning';
  static const String _budgetExceededChannelId = 'budget_exceeded';
  static const String _dailyReminderChannelId = 'daily_reminder';

  // Notification IDs
  static const int _dailyReminderNotificationId = 9000;
  static const int _budgetWarningBaseId = 1000;
  static const int _budgetExceededBaseId = 2000;

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

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
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create notification channels for Android
    await _createNotificationChannels();

    _isInitialized = true;
    debugPrint('BudgetNotificationService initialized');
  }

  static Future<void> _createNotificationChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (android != null) {
      // Budget Warning Channel
      await android.createNotificationChannel(const AndroidNotificationChannel(
        _budgetWarningChannelId,
        'Cảnh báo ngân sách',
        description: 'Cảnh báo khi bạn sắp chạm hạn mức ngân sách',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      ));

      // Budget Exceeded Channel
      await android.createNotificationChannel(const AndroidNotificationChannel(
        _budgetExceededChannelId,
        'Vượt ngân sách',
        description: 'Cảnh báo khi bạn vượt ngân sách',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      ));

      // Daily Reminder Channel
      await android.createNotificationChannel(const AndroidNotificationChannel(
        _dailyReminderChannelId,
        'Nhắc nhở hằng ngày',
        description: 'Nhắc nhở chi tiêu hằng ngày',
        importance: Importance.defaultImportance,
      ));
    }
  }

  /// Request notification permissions
  static Future<bool> requestPermission() async {
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

    return true;
  }

  /// Check budgets and send appropriate notifications
  static Future<void> checkBudgetsAndNotify(List<BudgetModel> budgets) async {
    for (final budget in budgets) {
      if (budget.isExceeded) {
        await showBudgetExceededNotification(budget);
      } else if (budget.isWarning) {
        await showBudgetWarningNotification(budget);
      }
    }
  }

  /// Show warning notification when budget is at 80%+
  static Future<void> showBudgetWarningNotification(BudgetModel budget) async {
    final categoryName = budget.categoryId == null 
        ? 'Tháng' 
        : budget.categoryName;
    
    final percentage = budget.percentUsed.round();
    final remaining = budget.amountRemaining;

    await _showNotification(
      id: _budgetWarningBaseId + budget.id.hashCode.abs() % 1000,
      channelId: _budgetWarningChannelId,
      title: '⚡ Cảnh báo ngân sách',
      body: 'Bạn đã dùng $percentage% ngân sách $categoryName. '
            'Còn lại ₫${_formatNumber(remaining)}.',
      payload: 'budget_warning:${budget.id}',
      color: const Color(0xFFF39C12),
    );
  }

  /// Show alert notification when budget is exceeded
  static Future<void> showBudgetExceededNotification(BudgetModel budget) async {
    final categoryName = budget.categoryId == null 
        ? 'Tháng' 
        : budget.categoryName;
    
    final overAmount = budget.amountSpent - budget.amountLimit;

    await _showNotification(
      id: _budgetExceededBaseId + budget.id.hashCode.abs() % 1000,
      channelId: _budgetExceededChannelId,
      title: '⚠️ Vượt ngân sách!',
      body: 'Bạn đã vượt ngân sách $categoryName thêm ₫${_formatNumber(overAmount)}.',
      payload: 'budget_exceeded:${budget.id}',
      color: const Color(0xFFE74C3C),
    );
  }

  /// Show notification when a transaction pushes budget over limit
  static Future<void> showTransactionOverBudgetAlert({
    required String budgetName,
    required double transactionAmount,
    required double amountOverBudget,
  }) async {
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch % 10000 + 5000,
      channelId: _budgetExceededChannelId,
      title: '💰 Cảnh báo giao dịch',
      body: 'Giao dịch này (₫${_formatNumber(transactionAmount)}) khiến bạn '
            'vượt ₫${_formatNumber(amountOverBudget)} so với ngân sách $budgetName.',
      payload: 'transaction_alert',
      color: const Color(0xFFE74C3C),
    );
  }

  /// Schedule daily spending summary notification
  static Future<void> scheduleDailySummaryNotification({
    int hour = 20,
    int minute = 0,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    
    // If scheduled time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _dailyReminderNotificationId,
      '📊 Tổng kết chi tiêu hằng ngày',
      'Nhấn để xem chi tiêu hôm nay',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _dailyReminderChannelId,
          'Nhắc nhở hằng ngày',
          channelDescription: 'Nhắc nhở chi tiêu hằng ngày',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: const BigTextStyleInformation(
            'Xem chi tiêu hôm nay và bám sát mục tiêu ngân sách.',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'daily_summary',
    );

    debugPrint('Daily summary notification scheduled for $hour:$minute');
  }

  /// Cancel daily summary notification
  static Future<void> cancelDailySummaryNotification() async {
    await _plugin.cancel(_dailyReminderNotificationId);
  }

  /// Show high spending alert
  static Future<void> showHighSpendingAlert({
    required double todaySpending,
    required double averageDaily,
  }) async {
    if (todaySpending <= averageDaily * 1.5) return;

    await _showNotification(
      id: DateTime.now().day + 8000,
      channelId: _budgetWarningChannelId,
      title: '📈 High Spending Today',
      body: 'You\'ve spent ₫${_formatNumber(todaySpending)} today, '
            'which is ${((todaySpending / averageDaily - 1) * 100).round()}% '
            'more than your daily average.',
      payload: 'high_spending',
      color: const Color(0xFFF39C12),
    );
  }

  /// Internal method to show notification
  static Future<void> _showNotification({
    required int id,
    required String channelId,
    required String title,
    required String body,
    String? payload,
    Color? color,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == _budgetExceededChannelId 
          ? 'Budget Exceeded' 
          : channelId == _budgetWarningChannelId 
              ? 'Budget Warnings' 
              : 'Daily Reminders',
      channelDescription: 'Budget notifications',
      importance: channelId == _budgetExceededChannelId 
          ? Importance.max 
          : Importance.high,
      priority: channelId == _budgetExceededChannelId 
          ? Priority.max 
          : Priority.high,
      color: color,
      styleInformation: BigTextStyleInformation(body),
      category: AndroidNotificationCategory.reminder,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
    
    // Also save to local database for history
    await _saveNotificationToDb(title, body, payload);
  }

  static Future<void> _saveNotificationToDb(String title, String body, String? payload) async {
    try {
      final db = LocalDatabase();
      final database = await db.database;
      
      await database.insert('notifications', {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title,
        'body': body,
        'type': payload?.split(':').first ?? 'budget',
        'data': payload,
        'is_read': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to save notification to DB: $e');
    }
  }

  static String _formatNumber(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    debugPrint('Notification tapped: $payload');
    
    // TODO: Navigate to relevant screen based on payload
    // Example: Use a navigation service or callback
    if (payload != null) {
      if (payload.startsWith('budget_warning:') || payload.startsWith('budget_exceeded:')) {
        // Navigate to budget screen
      } else if (payload == 'daily_summary') {
        // Navigate to daily summary/home screen
      }
    }
  }

  /// Cancel all budget notifications
  static Future<void> cancelAllBudgetNotifications() async {
    // Cancel warning notifications
    for (int i = 0; i < 1000; i++) {
      await _plugin.cancel(_budgetWarningBaseId + i);
      await _plugin.cancel(_budgetExceededBaseId + i);
    }
  }
}
