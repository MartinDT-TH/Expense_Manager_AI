import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/file_service.dart';
import '../../../../core/utils/top_alert.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/report_data.dart';
import '../bloc/report_bloc.dart';
import '../bloc/report_event.dart';
import '../bloc/report_state.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ReportBloc>()..add(LoadQuickSummary()),
      child: const _StatisticsContent(),
    );
  }
}

class _StatisticsContent extends StatefulWidget {
  const _StatisticsContent();

  @override
  State<_StatisticsContent> createState() => _StatisticsContentState();
}

class _StatisticsContentState extends State<_StatisticsContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'week';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  double _scale(BuildContext context) {
    return (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = _scale(context);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C5CE7), Color(0xFF8B7CF7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        title: const Text(
          'Thống kê',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          BlocBuilder<ReportBloc, ReportState>(
            builder: (context, state) {
              if (state is ReportLoaded) {
                return IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.file_download_outlined,
                          color: Colors.white),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC107),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Cao cấp',
                            style: TextStyle(
                              fontSize: 8 * scale,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  onPressed: () => _showExportDialog(context, state),
                  tooltip: 'Xuất báo cáo',
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
      body: BlocConsumer<ReportBloc, ReportState>(
        listener: (context, state) async {
          if (state is ReportExported) {
            final result = state.result;
            final defaultExt = _defaultExtensionForFormat(result.format);
            final hasBase64 =
                result.base64Content != null && result.base64Content!.isNotEmpty;
            final hasUrl =
                result.downloadUrl != null && result.downloadUrl!.isNotEmpty;

            if (hasBase64 || hasUrl) {
              try {
                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                  ),
                );

                // Save and get file path
                final filePath = hasBase64
                    ? await FileService().saveFileFromBase64(
                        base64Content: result.base64Content!,
                        fileName: result.fileName,
                        defaultExtension: defaultExt,
                      )
                    : await FileService().saveFileFromUrl(
                        url: result.downloadUrl!,
                        fileName: result.fileName,
                        defaultExtension: defaultExt,
                      );

                // Close loading dialog
                if (context.mounted) {
                  Navigator.of(context).pop();
                }

                // Show success dialog with options
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 28),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Xuất báo cáo thành công',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('File đã được lưu:'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              result.fileName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            FileService().shareFile(
                              filePath: filePath,
                              subject: 'Báo cáo Smart Money - ${result.fileName}',
                            );
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('Chia sẻ'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            FileService().openFile(filePath);
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Mở file'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                // Close loading dialog if open
                if (context.mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                if (context.mounted) {
                  TopAlert.show(
                    context,
                    message: 'Lỗi lưu file: $e',
                    backgroundColor: Colors.red,
                    icon: Icons.error_outline,
                  );
                }
              }
            } else {
              TopAlert.show(
                context,
                message: 'Không có dữ liệu để xuất',
                backgroundColor: Colors.orange,
                icon: Icons.warning_amber_rounded,
              );
            }
          } else if (state is ReportExportError) {
            TopAlert.show(
              context,
                message: 'Xuất báo cáo thất bại: ${state.message}',
              backgroundColor: Colors.red,
              icon: Icons.error_outline,
            );
          }
        },
        builder: (context, state) {
          if (state is ReportLoading || state is ReportExporting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                  SizedBox(height: 16),
                  Text('Đang tải thống kê...'),
                ],
              ),
            );
          }

          if (state is ReportError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<ReportBloc>().add(LoadQuickSummary()),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          if (state is ReportLoaded) {
            return _buildContent(context, state);
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, ReportLoaded state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = _scale(context);

    return RefreshIndicator(
      onRefresh: () async {
        context.read<ReportBloc>().add(ChangeTimeFilter(filter: _selectedFilter));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time Filter
            _buildTimeFilter(context),
            SizedBox(height: 20 * scale),

            // Summary Cards
            _buildSummaryCards(context, state.summary),
            SizedBox(height: 24 * scale),

            // Tab Bar for Charts
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFF6C5CE7),
                    labelColor: const Color(0xFF6C5CE7),
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(text: 'Theo danh mục'),
                      Tab(text: 'Theo thời gian'),
                    ],
                  ),
                  SizedBox(
                    height: 340 * scale,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCategoryChart(context, state.categoryReport),
                        _buildTimeChart(context, state.timeReport),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24 * scale),

            // Top Categories List
            _buildTopCategoriesList(context, state.categoryReport),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFilter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = _scale(context);

    return Container(
      padding: EdgeInsets.all(4 * scale),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildFilterChip('Tuần', 'week', context),
          _buildFilterChip('Tháng', 'month', context),
          _buildFilterChip('Tùy chỉnh', 'custom', context),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, BuildContext context) {
    final isSelected = _selectedFilter == value;
    final scale = _scale(context);

    return Expanded(
      child: GestureDetector(
        onTap: () async {
          if (value == 'custom') {
            final result = await _showDateRangePicker(context);
            if (result != null) {
              setState(() {
                _selectedFilter = value;
                _customStartDate = result.start;
                _customEndDate = result.end;
              });
              context.read<ReportBloc>().add(ChangeTimeFilter(
                    filter: value,
                    customStartDate: result.start,
                    customEndDate: result.end,
                  ));
            }
          } else {
            setState(() => _selectedFilter = value);
            context.read<ReportBloc>().add(ChangeTimeFilter(filter: value));
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 10 * scale),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6C5CE7) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 12 * scale,
            ),
          ),
        ),
      ),
    );
  }

  Future<DateTimeRange?> _showDateRangePicker(BuildContext context) {
    return showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now(),
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF6C5CE7),
                ),
          ),
          child: child!,
        );
      },
    );
  }

  Widget _buildSummaryCards(BuildContext context, SummaryReport summary) {
    final netBalance = summary.totalIncome - summary.totalExpense;
    final scale = _scale(context);
    
    return Column(
      children: [
        // Net Balance Card
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(18 * scale),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: netBalance >= 0
                  ? [const Color(0xFF6C5CE7), const Color(0xFF8B7CF7)]
                  : [const Color(0xFFE17055), const Color(0xFFFF7675)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (netBalance >= 0 ? const Color(0xFF6C5CE7) : const Color(0xFFE17055)).withAlpha(80),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Số dư ròng',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 4 * scale),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${summary.transactionCount} giao dịch',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12 * scale),
              Text(
                '${netBalance >= 0 ? '+' : ''}${_formatCurrency(netBalance)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8 * scale),
              Row(
                children: [
                  Icon(
                    netBalance >= 0 ? Icons.trending_up : Icons.trending_down,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    netBalance >= 0 ? 'Tình hình chi tiêu ổn định!' : 'Chi tiêu vượt quá thu nhập',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16 * scale),
        // Income and Expense Cards
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Thu nhập',
                amount: summary.totalIncome,
                icon: Icons.arrow_downward,
                color: const Color(0xFF00B894),
              ),
            ),
            SizedBox(width: 12 * scale),
            Expanded(
              child: _SummaryCard(
                title: 'Chi tiêu',
                amount: summary.totalExpense,
                icon: Icons.arrow_upward,
                color: const Color(0xFFE17055),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryChart(BuildContext context, CategoryReport report) {
    if (report.items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No data for this period',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Category colors
    final List<Color> colors = [
      const Color(0xFF6C5CE7),
      const Color(0xFF00B894),
      const Color(0xFFE17055),
      const Color(0xFFFDCB6E),
      const Color(0xFF74B9FF),
      const Color(0xFFFF7675),
      const Color(0xFFA29BFE),
      const Color(0xFF55EFC4),
    ];

    final displayItems = report.items.take(6).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Pie Chart - Fixed size container
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: displayItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return PieChartSectionData(
                    color: colors[index % colors.length],
                    value: item.amount,
                    title: item.percentage >= 5 ? '${item.percentage.toStringAsFixed(0)}%' : '',
                    radius: 70,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    titlePositionPercentageOffset: 0.55,
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 35,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Legend - Horizontal wrap layout
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: displayItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return SizedBox(
                    width: 140,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colors[index % colors.length],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item.categoryName,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChart(BuildContext context, TimeReport report) {
    if (report.items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No data for this period',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Take all items, no limit
    final displayItems = report.items;

    // Calculate maxY from actual data
    final maxY = displayItems
        .map((e) => e.income > e.expense ? e.income : e.expense)
        .fold<double>(0, (a, b) => a > b ? a : b);
    
    // If all values are 0, use a default maxY
    final chartMaxY = maxY > 0 ? maxY * 1.2 : 1000.0;

    // Calculate bar width based on number of items
    final barWidth = displayItems.length <= 3 ? 20.0 
        : (displayItems.length <= 5 ? 16.0 
        : (displayItems.length <= 7 ? 12.0 : 10.0));

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 16, top: 16, bottom: 8),
      child: Column(
        children: [
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Income', const Color(0xFF00B894)),
              const SizedBox(width: 24),
              _buildLegendItem('Expense', const Color(0xFFE17055)),
            ],
          ),
          const SizedBox(height: 20),
          // Chart
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceEvenly,
                maxY: chartMaxY,
                minY: 0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipColor: (group) => Colors.grey[800]!,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      if (groupIndex >= displayItems.length) return null;
                      final isIncome = rodIndex == 0;
                      return BarTooltipItem(
                        '${isIncome ? "Income" : "Expense"}\n${_formatCurrency(rod.toY)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= displayItems.length) {
                          return const SizedBox.shrink();
                        }
                        
                        // Calculate interval to show labels
                        // If too many items, show only some labels
                        int interval = 1;
                        if (displayItems.length > 20) {
                          interval = 5; // Show every 5th label (6-7 labels for a month)
                        } else if (displayItems.length > 10) {
                          interval = 3; // Show every 3rd label
                        } else if (displayItems.length > 7) {
                          interval = 2; // Show every 2nd label
                        }
                        
                        // Always show first and last, and interval labels
                        final isFirst = index == 0;
                        final isLast = index == displayItems.length - 1;
                        final isInterval = index % interval == 0;
                        
                        if (!isFirst && !isLast && !isInterval) {
                          return const SizedBox.shrink();
                        }
                        
                        final item = displayItems[index];
                        final dateLabel = _formatDateLabel(item.date);
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            dateLabel,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                      reservedSize: 32,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      interval: chartMaxY > 0 ? chartMaxY / 4 : null,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('0', style: TextStyle(fontSize: 9));
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            _formatCompactCurrency(value),
                            style: const TextStyle(fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                    left: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: chartMaxY > 0 ? chartMaxY / 4 : null,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[300]!,
                      strokeWidth: 0.5,
                      dashArray: [5, 5],
                    );
                  },
                ),
                groupsSpace: displayItems.length <= 4 ? 28 : (displayItems.length <= 7 ? 16 : 10),
                barGroups: displayItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: item.income,
                        color: const Color(0xFF00B894),
                        width: barWidth,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: item.expense,
                        color: const Color(0xFFE17055),
                        width: barWidth,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildTopCategoriesList(BuildContext context, CategoryReport report) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (report.items.isEmpty) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Danh mục hàng đầu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...report.items.take(5).map((item) => _buildCategoryListItem(
                context,
                item,
                report.totalExpense > 0 ? report.totalExpense : 1,
              )),
        ],
      ),
    );
  }

  Widget _buildCategoryListItem(
    BuildContext context,
    CategoryReportItem item,
    double total,
  ) {
    final percentage = (item.amount / total * 100).clamp(0, 100);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getCategoryIcon(item.categoryName),
                        color: const Color(0xFF6C5CE7),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.categoryName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${item.transactionCount} giao dịch',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(item.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE17055),
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey[200],
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    final Map<String, IconData> icons = {
      'food': Icons.restaurant,
      'transport': Icons.directions_car,
      'shopping': Icons.shopping_bag,
      'entertainment': Icons.movie,
      'health': Icons.local_hospital,
      'education': Icons.school,
      'bills': Icons.receipt,
      'salary': Icons.attach_money,
      'investment': Icons.trending_up,
    };

    final lowerName = categoryName.toLowerCase();
    for (final entry in icons.entries) {
      if (lowerName.contains(entry.key)) {
        return entry.value;
      }
    }
    return Icons.category;
  }

  void _showExportDialog(BuildContext context, ReportLoaded state) {
    final reportBloc = context.read<ReportBloc>();
    final authState = context.read<AuthBloc>().state;
    final userIsPremium = authState is Authenticated && authState.user.isPremium;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => _ExportBottomSheet(
        startDate: state.startDate,
        endDate: state.endDate,
        userIsPremium: userIsPremium,
        onExport: (format) {
          reportBloc.add(ExportReport(
                startDate: state.startDate,
                endDate: state.endDate,
                format: format,
              ));
          Navigator.pop(bottomSheetContext);
        },
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String _formatCompactCurrency(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }

  String _formatDateLabel(DateTime date) {
    return DateFormat('dd/MM').format(date);
  }

  String? _defaultExtensionForFormat(String format) {
    final lower = format.toLowerCase();
    if (lower.contains('pdf')) return 'pdf';
    if (lower.contains('excel') || lower.contains('xls')) return 'xlsx';
    return null;
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);

    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                fontSize: 13 * scale,
                  ),
                ),
              ),
            ],
          ),
      SizedBox(height: 12 * scale),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
          fontSize: 18 * scale,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }
}

class _ExportBottomSheet extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final bool userIsPremium;
  final Function(String) onExport;

  const _ExportBottomSheet({
    required this.startDate,
    required this.endDate,
    required this.userIsPremium,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 12 * scale),
          Container(
            width: 40 * scale,
            height: 4 * scale,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 16 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Xuất báo cáo',
                style: TextStyle(
                  fontSize: 18 * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8 * scale),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8 * scale,
                  vertical: 2 * scale,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Cao cấp',
                  style: TextStyle(
                    fontSize: 10 * scale,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6 * scale),
          Text(
            '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13 * scale,
            ),
          ),
          SizedBox(height: 20 * scale),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20 * scale),
            child: Row(
              children: [
                Expanded(
                  child: _ExportOptionButton(
                    icon: Icons.table_chart,
                    label: 'Excel',
                    format: 'excel',
                    onTap: () => onExport('excel'),
                    color: const Color(0xFF217346),
                    requiresPremium: true,
                    userIsPremium: userIsPremium,
                  ),
                ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: _ExportOptionButton(
                    icon: Icons.picture_as_pdf,
                    label: 'PDF',
                    format: 'pdf',
                    onTap: () => onExport('pdf'),
                    color: const Color(0xFFE53935),
                    requiresPremium: true,
                    userIsPremium: userIsPremium,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 28 * scale),
        ],
      ),
    );
  }
}

class _ExportOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String format;
  final VoidCallback onTap;
  final Color color;
  final bool requiresPremium;
  final bool userIsPremium;

  const _ExportOptionButton({
    required this.icon,
    required this.label,
    required this.format,
    required this.onTap,
    required this.color,
    required this.requiresPremium,
    required this.userIsPremium,
  });

  @override
  Widget build(BuildContext context) {
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    return InkWell(
      onTap: requiresPremium && !userIsPremium
          ? () => _showPremiumRequiredDialog(context)
          : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 18 * scale),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 34 * scale, color: color),
            SizedBox(height: 6 * scale),
            Text(
              label,
              style: TextStyle(
                fontSize: 14 * scale,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (requiresPremium) ...[
              SizedBox(height: 6 * scale),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8 * scale,
                  vertical: 2 * scale,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Cao cấp',
                  style: TextStyle(
                    fontSize: 9 * scale,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPremiumRequiredDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE17055).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Color(0xFFE17055),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Tính năng cao cấp',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2D3436),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Xuất báo cáo ở định dạng ${label.toUpperCase()} để dễ dàng chia sẻ và phân tích dữ liệu tài chính.',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildPremiumFeatureRow(Icons.download_rounded, 'Xuất theo định dạng ${label}', isDark),
                  _buildPremiumFeatureRow(Icons.share_rounded, 'Chia sẻ với người khác', isDark),
                  _buildPremiumFeatureRow(Icons.cloud_download_rounded, 'Lưu lên đám mây', isDark),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Để sau',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              TopAlert.show(
                context,
                message: 'Nâng cấp Premium sắp có!',
                backgroundColor: const Color(0xFF6C5CE7),
                icon: Icons.workspace_premium,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE17055),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium, color: Colors.white, size: 16),
                SizedBox(width: 6 * scale),
                const Text(
                  'Nâng cấp ngay',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeatureRow(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFE17055)),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
