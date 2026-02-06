import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class DatePickerSheet extends StatefulWidget {
  final DateTime selectedDate;
  final void Function(DateTime) onDateSelected;

  const DatePickerSheet({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<DatePickerSheet> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  int _selectedQuickOption = 0; // 0 = Hôm nay, 1 = 8 ngày gần nhất, 2 = Tháng trước

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[600] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Quick options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildQuickOption('Hôm nay', 0),
                const SizedBox(width: 8),
                _buildQuickOption('8 ngày gần nhất', 1),
                const SizedBox(width: 8),
                _buildQuickOption('Tháng trước', 2),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Month navigation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousMonth,
                ),
                Text(
                  _formatMonth(_displayedMonth),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),
          
          // Weekday headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7']
                  .map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Calendar grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCalendarGrid(),
          ),
          
          const SizedBox(height: 16),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Xóa'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onDateSelected(_selectedDate);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Áp dụng'),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildQuickOption(String label, int index) {
    final isSelected = _selectedQuickOption == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedQuickOption = index;
            switch (index) {
              case 0:
                _selectedDate = DateTime.now();
                break;
              case 1:
                _selectedDate = DateTime.now().subtract(const Duration(days: 8));
                break;
              case 2:
                _selectedDate = DateTime(
                  DateTime.now().year,
                  DateTime.now().month - 1,
                  DateTime.now().day,
                );
                break;
            }
            _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final lastDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday
    
    final days = <Widget>[];
    
    // Empty cells for days before the first day
    for (int i = 0; i < firstWeekday; i++) {
      days.add(const SizedBox());
    }
    
    // Days of the month
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
      final isSelected = _isSameDay(date, _selectedDate);
      final isToday = _isSameDay(date, DateTime.now());
      final isFuture = date.isAfter(DateTime.now());
      
      days.add(
        GestureDetector(
          onTap: isFuture ? null : () {
            setState(() {
              _selectedDate = date;
              _selectedQuickOption = -1;
            });
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : null,
              shape: BoxShape.circle,
              border: isToday && !isSelected
                  ? Border.all(color: AppColors.primary, width: 1)
                  : null,
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 14,
                  color: isFuture
                      ? Colors.grey[300]
                      : isSelected
                          ? Colors.white
                          : Colors.black87,
                  fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      children: days,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatMonth(DateTime date) {
    const months = [
      'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6',
      'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    });
  }
}
