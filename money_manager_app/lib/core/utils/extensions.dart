import 'package:intl/intl.dart';

extension DateTimeExtension on DateTime {
  String toFormattedDate() {
    return DateFormat('dd/MM/yyyy').format(this);
  }

  String toFormattedDateTime() {
    return DateFormat('dd/MM/yyyy HH:mm').format(this);
  }

  String toMonthYear() {
    return DateFormat('MM/yyyy').format(this);
  }

  String toApiFormat() {
    return toIso8601String();
  }

  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  bool isSameMonth(DateTime other) {
    return year == other.year && month == other.month;
  }

  DateTime get startOfDay => DateTime(year, month, day);
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59);
  DateTime get startOfMonth => DateTime(year, month, 1);
  DateTime get endOfMonth => DateTime(year, month + 1, 0, 23, 59, 59);
  DateTime get startOfYear => DateTime(year, 1, 1);
  DateTime get endOfYear => DateTime(year, 12, 31, 23, 59, 59);
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  bool get isValidEmail {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(this);
  }

  bool get isValidPassword {
    return length >= 6;
  }
}

extension NumberExtension on num {
  String toVND() {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    return formatter.format(this);
  }

  String toCurrency(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return NumberFormat.currency(locale: 'en_US', symbol: '\$').format(this);
      case 'EUR':
        return NumberFormat.currency(locale: 'de_DE', symbol: '€').format(this);
      case 'VND':
      default:
        return toVND();
    }
  }

  String toCompact() {
    // Chỉ rút gọn khi >= 1 tỷ để tránh nhầm lẫn
    if (this >= 1000000000) {
      return '${(this / 1000000000).toStringAsFixed(1)}B';
    }
    // Hiển thị đầy đủ số cho số < 1 tỷ
    return toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
