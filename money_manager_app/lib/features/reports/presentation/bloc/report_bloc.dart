import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/report_repository.dart';
import 'report_event.dart';
import 'report_state.dart';

class ReportBloc extends Bloc<ReportEvent, ReportState> {
  final ReportRepository repository;

  ReportBloc({required this.repository}) : super(ReportInitial()) {
    on<LoadReportData>(_onLoadReportData);
    on<LoadQuickSummary>(_onLoadQuickSummary);
    on<LoadMonthlySummary>(_onLoadMonthlySummary);
    on<ExportReport>(_onExportReport);
    on<ChangeTimeFilter>(_onChangeTimeFilter);
    on<ChangeChartGroupBy>(_onChangeChartGroupBy);
  }

  Future<void> _onLoadReportData(
    LoadReportData event,
    Emitter<ReportState> emit,
  ) async {
    emit(ReportLoading());
    try {
      final results = await Future.wait([
        repository.getSummary(
          startDate: event.startDate,
          endDate: event.endDate,
          walletId: event.walletId,
        ),
        repository.getByCategory(
          startDate: event.startDate,
          endDate: event.endDate,
          walletId: event.walletId,
        ),
        repository.getByTime(
          startDate: event.startDate,
          endDate: event.endDate,
          walletId: event.walletId,
          groupBy: event.timeGroupBy,
        ),
      ]);

      emit(ReportLoaded(
        summary: results[0] as dynamic,
        categoryReport: results[1] as dynamic,
        timeReport: results[2] as dynamic,
        currentFilter: _getFilterType(event.startDate, event.endDate),
        chartGroupBy: event.timeGroupBy,
        startDate: event.startDate,
        endDate: event.endDate,
      ));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  String _getFilterType(DateTime start, DateTime end) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    if (start.year == startOfWeek.year &&
        start.month == startOfWeek.month &&
        start.day == startOfWeek.day &&
        end.year == endOfWeek.year &&
        end.month == endOfWeek.month &&
        end.day == endOfWeek.day) {
      return 'week';
    } else if (start.year == startOfMonth.year &&
        start.month == startOfMonth.month &&
        start.day == startOfMonth.day &&
        end.year == endOfMonth.year &&
        end.month == endOfMonth.month &&
        end.day == endOfMonth.day) {
      return 'month';
    }
    return 'custom';
  }

  Future<void> _onLoadQuickSummary(
    LoadQuickSummary event,
    Emitter<ReportState> emit,
  ) async {
    emit(ReportLoading());
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));

      final results = await Future.wait([
        repository.getQuickSummary(),
        repository.getByCategory(
          startDate: startOfWeek,
          endDate: endOfWeek,
        ),
        repository.getByTime(
          startDate: startOfWeek,
          endDate: endOfWeek,
          groupBy: 'daily',
        ),
      ]);

      emit(ReportLoaded(
        summary: results[0] as dynamic,
        categoryReport: results[1] as dynamic,
        timeReport: results[2] as dynamic,
        currentFilter: 'week',
        chartGroupBy: 'daily',
        startDate: startOfWeek,
        endDate: endOfWeek,
      ));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  Future<void> _onLoadMonthlySummary(
    LoadMonthlySummary event,
    Emitter<ReportState> emit,
  ) async {
    emit(ReportLoading());
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      final results = await Future.wait([
        repository.getMonthlySummary(),
        repository.getByCategory(
          startDate: startOfMonth,
          endDate: endOfMonth,
        ),
        repository.getByTime(
          startDate: startOfMonth,
          endDate: endOfMonth,
          groupBy: 'daily',
        ),
      ]);

      emit(ReportLoaded(
        summary: results[0] as dynamic,
        categoryReport: results[1] as dynamic,
        timeReport: results[2] as dynamic,
        currentFilter: 'month',
        chartGroupBy: 'daily',
        startDate: startOfMonth,
        endDate: endOfMonth,
      ));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  Future<void> _onExportReport(
    ExportReport event,
    Emitter<ReportState> emit,
  ) async {
    final currentState = state;
    emit(ReportExporting());
    try {
      final result = await repository.exportReport(
        startDate: event.startDate,
        endDate: event.endDate,
        walletId: event.walletId,
        format: event.format,
      );
      emit(ReportExported(result));
      // Restore previous state after showing export result
      if (currentState is ReportLoaded) {
        emit(currentState);
      }
    } catch (e) {
      emit(ReportExportError(e.toString()));
      if (currentState is ReportLoaded) {
        emit(currentState);
      }
    }
  }

  Future<void> _onChangeTimeFilter(
    ChangeTimeFilter event,
    Emitter<ReportState> emit,
  ) async {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (event.filter) {
      case 'week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        endDate = startDate.add(const Duration(days: 6));
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0);
        break;
      case 'custom':
        startDate = event.customStartDate ?? now.subtract(const Duration(days: 30));
        endDate = event.customEndDate ?? now;
        break;
      default:
        startDate = now.subtract(Duration(days: now.weekday - 1));
        endDate = startDate.add(const Duration(days: 6));
    }

    final currentState = state;
    final chartGroupBy = currentState is ReportLoaded 
        ? currentState.chartGroupBy 
        : 'daily';

    add(LoadReportData(
      startDate: startDate,
      endDate: endDate,
      timeGroupBy: chartGroupBy,
    ));
  }

  Future<void> _onChangeChartGroupBy(
    ChangeChartGroupBy event,
    Emitter<ReportState> emit,
  ) async {
    final currentState = state;
    if (currentState is ReportLoaded) {
      add(LoadReportData(
        startDate: currentState.startDate,
        endDate: currentState.endDate,
        timeGroupBy: event.groupBy,
      ));
    }
  }
}
