import 'package:shared_preferences/shared_preferences.dart';

class AdFrequencyLimiter {
  static const String _lastShownKey = 'ads_last_shown_ms';
  static const String _dailyCountKey = 'ads_daily_count';
  static const String _dailyKey = 'ads_daily_key';

  static const Duration _minInterval = Duration(minutes: 2);
  static const int _maxPerDay = 3;

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  bool canShow() {
    final prefs = _prefs;
    if (prefs == null) {
      return true;
    }

    final now = DateTime.now();
    final todayKey = _formatDayKey(now);
    final storedDay = prefs.getString(_dailyKey);
    int dailyCount = prefs.getInt(_dailyCountKey) ?? 0;

    if (storedDay != todayKey) {
      dailyCount = 0;
    }

    final lastShownMs = prefs.getInt(_lastShownKey) ?? 0;
    if (lastShownMs != 0) {
      final lastShown =
          DateTime.fromMillisecondsSinceEpoch(lastShownMs, isUtc: false);
      if (now.difference(lastShown) < _minInterval) {
        return false;
      }
    }

    if (dailyCount >= _maxPerDay) {
      return false;
    }

    return true;
  }

  Future<void> recordShown() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }

    final now = DateTime.now();
    final todayKey = _formatDayKey(now);
    final storedDay = prefs.getString(_dailyKey);
    int dailyCount = prefs.getInt(_dailyCountKey) ?? 0;

    if (storedDay != todayKey) {
      dailyCount = 0;
    }

    dailyCount += 1;
    await prefs.setString(_dailyKey, todayKey);
    await prefs.setInt(_dailyCountKey, dailyCount);
    await prefs.setInt(_lastShownKey, now.millisecondsSinceEpoch);
  }

  static String _formatDayKey(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
