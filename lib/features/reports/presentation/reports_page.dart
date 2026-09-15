import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_enums.dart';
import '../application/monthly_summary_providers.dart';
import '../../excel/application/excel_providers.dart';
import '../domain/monthly_summary_options.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final month = ref.watch(monthlySummaryMonthProvider);
    final summary = ref.watch(monthlySummaryProvider);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  key: const Key('summary-back-to-attendance'),
                  onPressed: () => _backToAttendance(context),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: '返回考勤',
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '汇总',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '月度考勤、人员变动与异常检查',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('summary-generate-button'),
                  onPressed: () => _generate(context, ref, month),
                  icon: const Icon(Icons.refresh_outlined),
                  tooltip: '重新生成汇总',
                ),
                IconButton(
                  key: const Key('summary-export-button'),
                  onPressed: _exporting
                      ? null
                      : () => _export(context, ref, month),
                  icon: _exporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_download_outlined),
                  tooltip: '导出当前月份 Excel',
                ),
                IconButton(
                  key: const Key('summary-payroll-button'),
                  onPressed: () => context.push('/reports/payroll'),
                  icon: const Icon(Icons.payments_outlined),
                  tooltip: '临时工薪资',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SummaryMonthSelector(
              month: month,
              onChanged: (value) =>
                  ref.read(monthlySummaryMonthProvider.notifier).state = value,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: summary.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _SummaryError(
                message: error.toString(),
                onRetry: () => ref.invalidate(monthlySummaryProvider),
              ),
              data: (value) => _SummaryContent(
                value: value,
                onGenerate: () => _generate(context, ref, month),
                onStatus: (status, reason) =>
                    _setStatus(context, ref, value, status, reason),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _backToAttendance(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/attendance');
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    DateTime month,
  ) async {
    setState(() => _exporting = true);
    try {
      final yearMonth = _yearMonth(month);
      final file = await ref
          .read(excelServiceProvider)
          .exportToFile(yearMonth: yearMonth);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已导出 $yearMonth：${file.path}')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _generate(
    BuildContext context,
    WidgetRef ref,
    DateTime month,
  ) async {
    try {
      await ref
          .read(monthlySummaryRepositoryProvider)
          .generate(yearMonth: _yearMonth(month));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('月度汇总已生成，状态为待检查')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('生成失败：$error')));
      }
    }
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    MonthlySummaryView value,
    MonthlySummaryStatus status,
    String? reason,
  ) async {
    try {
      await ref
          .read(monthlySummaryRepositoryProvider)
          .setStatus(
            yearMonth: value.yearMonth,
            status: status,
            reason: reason,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '汇总状态已更新为${MonthlySummaryOptions.statusLabel(status)}',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('状态更新失败：$error')));
      }
    }
  }

  String _yearMonth(DateTime month) {
    return '${month.year}-${month.month.toString().padLeft(2, '0')}';
  }
}

class _SummaryMonthSelector extends StatelessWidget {
  const _SummaryMonthSelector({required this.month, required this.onChanged});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('summary-month-label'),
          onTap: () async {
            final selected = await showModalBottomSheet<DateTime>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => _MonthWheelSheet(initialMonth: month),
            );
            if (selected != null) onChanged(selected);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_month_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '汇总月份',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        monthlySummaryMonthLabel(month),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.unfold_more, color: AppColors.body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthWheelSheet extends StatefulWidget {
  const _MonthWheelSheet({required this.initialMonth});

  final DateTime initialMonth;

  @override
  State<_MonthWheelSheet> createState() => _MonthWheelSheetState();
}

class _MonthWheelSheetState extends State<_MonthWheelSheet> {
  late final List<int> _years;
  late final FixedExtentScrollController _yearController;
  late final FixedExtentScrollController _monthController;
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    final currentYear = DateTime.now().year;
    _years = <int>{
      for (var year = currentYear - 5; year <= currentYear + 2; year++) year,
      widget.initialMonth.year,
    }.toList()..sort();
    _selectedYear = widget.initialMonth.year;
    _selectedMonth = widget.initialMonth.month;
    _yearController = FixedExtentScrollController(
      initialItem: _years.indexOf(_selectedYear),
    );
    _monthController = FixedExtentScrollController(
      initialItem: _selectedMonth - 1,
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 370,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  Expanded(
                    child: Text(
                      '选择汇总月份',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      DateTime(_selectedYear, _selectedMonth),
                    ),
                    child: const Text('确定'),
                  ),
                ],
              ),
              Text(
                monthlySummaryMonthLabel(
                  DateTime(_selectedYear, _selectedMonth),
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _WheelColumn(
                        semanticLabel: '年份',
                        labels: [for (final year in _years) '$year年'],
                        selectedIndex: _years.indexOf(_selectedYear),
                        controller: _yearController,
                        onSelectedItemChanged: (index) =>
                            setState(() => _selectedYear = _years[index]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _WheelColumn(
                        semanticLabel: '月份',
                        labels: [
                          for (var month = 1; month <= 12; month++) '$month月',
                        ],
                        selectedIndex: _selectedMonth - 1,
                        controller: _monthController,
                        onSelectedItemChanged: (index) =>
                            setState(() => _selectedMonth = index + 1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.semanticLabel,
    required this.labels,
    required this.selectedIndex,
    required this.controller,
    required this.onSelectedItemChanged,
  });

  final String semanticLabel;
  final List<String> labels;
  final int selectedIndex;
  final FixedExtentScrollController controller;
  final ValueChanged<int> onSelectedItemChanged;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = labels[selectedIndex];
    return Semantics(
      label: semanticLabel,
      value: selectedLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.lightGreen.withValues(alpha: 0.55),
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ListWheelScrollView.useDelegate(
              controller: controller,
              itemExtent: 48,
              diameterRatio: 1.55,
              perspective: 0.003,
              squeeze: 1.12,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: onSelectedItemChanged,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: labels.length,
                builder: (context, index) {
                  final isSelected = index == selectedIndex;
                  return Center(
                    child: Text(
                      labels[index],
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isSelected ? AppColors.ink : AppColors.helper,
                        fontSize: isSelected ? 22 : 18,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayWheelSelection {
  const _DayWheelSelection({required this.day});

  final int? day;
}

class _DayWheelSheet extends StatefulWidget {
  const _DayWheelSheet({required this.daysInMonth, required this.selectedDay});

  final int daysInMonth;
  final int? selectedDay;

  @override
  State<_DayWheelSheet> createState() => _DayWheelSheetState();
}

class _DayWheelSheetState extends State<_DayWheelSheet> {
  late final FixedExtentScrollController _dayController;
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.selectedDay == null
        ? 1
        : widget.selectedDay!.clamp(1, widget.daysInMonth).toInt();
    _dayController = FixedExtentScrollController(initialItem: _selectedDay - 1);
  }

  @override
  void dispose() {
    _dayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 370,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  Expanded(
                    child: Text(
                      '选择异常日期',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      const _DayWheelSelection(day: null),
                    ),
                    child: const Text(
                      '清除',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _DayWheelSelection(day: _selectedDay),
                    ),
                    child: const Text('确定'),
                  ),
                ],
              ),
              Text(
                '上下滚动选择 1–${widget.daysInMonth} 日',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _WheelColumn(
                  semanticLabel: '日期',
                  labels: [
                    for (var day = 1; day <= widget.daysInMonth; day++) '$day日',
                  ],
                  selectedIndex: _selectedDay - 1,
                  controller: _dayController,
                  onSelectedItemChanged: (index) =>
                      setState(() => _selectedDay = index + 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({
    required this.value,
    required this.onGenerate,
    required this.onStatus,
  });

  final MonthlySummaryView value;
  final VoidCallback onGenerate;
  final Future<void> Function(MonthlySummaryStatus status, String? reason)
  onStatus;

  @override
  Widget build(BuildContext context) {
    if (value.rows.isEmpty) return _SummaryEmpty(onGenerate: onGenerate);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        _SummaryStatusCard(
          value: value,
          onGenerate: onGenerate,
          onStatus: onStatus,
        ),
        const SizedBox(height: 12),
        _SummaryStats(value: value),
        const SizedBox(height: 16),
        Text('人员汇总', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        for (final row in value.rows) ...[
          _SummaryRow(row: row),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        _AnomalyPanel(yearMonth: value.yearMonth, anomalies: value.anomalies),
      ],
    );
  }
}

class _SummaryStatusCard extends StatelessWidget {
  const _SummaryStatusCard({
    required this.value,
    required this.onGenerate,
    required this.onStatus,
  });

  final MonthlySummaryView value;
  final VoidCallback onGenerate;
  final Future<void> Function(MonthlySummaryStatus status, String? reason)
  onStatus;

  @override
  Widget build(BuildContext context) {
    final status = value.status;
    return Card(
      color: _statusColor(status).withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Icon(Icons.assessment_outlined, color: _statusColor(status)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('汇总状态', style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    MonthlySummaryOptions.statusLabel(status),
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(color: _statusColor(status)),
                  ),
                ],
              ),
            ),
            if (status != MonthlySummaryStatus.locked)
              TextButton(
                key: const Key('summary-regenerate-button'),
                onPressed: onGenerate,
                child: const Text('重新生成'),
              ),
            if (status == MonthlySummaryStatus.pendingReview)
              FilledButton(
                key: const Key('summary-confirm-button'),
                onPressed: () => onStatus(MonthlySummaryStatus.confirmed, null),
                child: const Text('确认'),
              ),
            if (status == MonthlySummaryStatus.confirmed)
              FilledButton(
                key: const Key('summary-lock-button'),
                onPressed: () => onStatus(MonthlySummaryStatus.locked, null),
                child: const Text('锁定'),
              ),
            if (status == MonthlySummaryStatus.locked)
              TextButton(
                key: const Key('summary-unlock-button'),
                onPressed: () => _unlock(context),
                child: const Text('解锁'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _unlock(BuildContext context) async {
    var reasonText = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解锁月度汇总'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => reasonText = value,
          decoration: const InputDecoration(labelText: '解锁原因'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(reasonText),
            child: const Text('确认解锁'),
          ),
        ],
      ),
    );
    if (reason != null && reason.trim().isNotEmpty) {
      await onStatus(MonthlySummaryStatus.pendingReview, reason);
    }
  }

  Color _statusColor(MonthlySummaryStatus status) {
    return switch (status) {
      MonthlySummaryStatus.notGenerated => AppColors.helper,
      MonthlySummaryStatus.pendingReview => AppColors.techBlue,
      MonthlySummaryStatus.confirmed => AppColors.primary,
      MonthlySummaryStatus.locked => AppColors.purple,
    };
  }
}

class _SummaryStats extends StatelessWidget {
  const _SummaryStats({required this.value});

  final MonthlySummaryView value;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Stat(
          label: '人员',
          value: '${value.rows.length}人',
          color: AppColors.techBlue,
        ),
        _Stat(
          label: '出勤',
          value: _days(value.attendanceDays),
          color: AppColors.primary,
        ),
        _Stat(
          label: '请假',
          value: _days(value.leaveDays),
          color: AppColors.purple,
        ),
        _Stat(
          label: '加班',
          value: _overtime(value.overtimeCount, value.overtimeMinutes),
          color: const Color(0xFFE98500),
        ),
      ],
    );
  }

  String _days(double value) {
    return value == value.roundToDouble()
        ? '${value.toInt()}天'
        : '${value.toStringAsFixed(1)}天';
  }

  String _overtime(int count, int minutes) {
    if (minutes < 60) return '$count段/$minutes分';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '$count段/$hours小时' : '$count段/$hours小时$remainder分';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 7),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.row});

  final MonthlySummaryRowView row;

  @override
  Widget build(BuildContext context) {
    final summary = row.summary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${row.employee.name} · ${row.employee.employeeNo}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (summary.anomalyCount > 0)
                  Text(
                    '${summary.anomalyCount}项异常',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.danger),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Metric('出勤', _days(summary.attendanceDays)),
                _Metric('请假', _days(summary.leaveDays)),
                _Metric('缺勤', _days(summary.absentDays)),
                _Metric('公休', _days(summary.restDays)),
                _Metric('停工', _days(summary.stoppedDays)),
                _Metric(
                  '加班',
                  '${summary.overtimeCount}段/${summary.overtimeMinutes}分',
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '月初 ${summary.monthStartStatus ?? '未知'} · 月末 ${summary.monthEndStatus ?? '未知'}${summary.joinedDuringMonth ? ' · 月内入职' : ''}${summary.terminatedDuringMonth ? ' · 月内离职' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _days(double value) {
    return value == value.roundToDouble()
        ? '${value.toInt()}天'
        : '${value.toStringAsFixed(1)}天';
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text('$label $value', style: Theme.of(context).textTheme.bodySmall);
  }
}

const _allAnomalyFilter = '__all__';

class _AnomalyPanel extends StatefulWidget {
  const _AnomalyPanel({required this.yearMonth, required this.anomalies});

  final String yearMonth;
  final List<MonthlySummaryAnomaly> anomalies;

  static const _warningColor = Color(0xFFE98500);

  @override
  State<_AnomalyPanel> createState() => _AnomalyPanelState();
}

class _AnomalyPanelState extends State<_AnomalyPanel> {
  bool _expanded = true;
  String _selectedDate = _allAnomalyFilter;
  String _selectedEmployee = _allAnomalyFilter;

  @override
  void didUpdateWidget(covariant _AnomalyPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.yearMonth != widget.yearMonth) {
      _selectedDate = _allAnomalyFilter;
      _selectedEmployee = _allAnomalyFilter;
      _expanded = true;
      return;
    }
    final dates = _dateOptions;
    final employees = _employeeOptions;
    if (_selectedDate != _allAnomalyFilter && !dates.contains(_selectedDate)) {
      _selectedDate = _allAnomalyFilter;
    }
    if (_selectedEmployee != _allAnomalyFilter &&
        !employees.contains(_selectedEmployee)) {
      _selectedEmployee = _allAnomalyFilter;
    }
  }

  List<String> get _dateOptions {
    final parts = widget.yearMonth.split('-');
    if (parts.length != 2) return const [];
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      return const [];
    }
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return [for (var day = 1; day <= daysInMonth; day++) '$day'];
  }

  List<String> get _employeeOptions {
    final values = <String>{
      for (final anomaly in widget.anomalies) anomaly.employee.name,
    }.toList();
    values.sort();
    return values;
  }

  List<MonthlySummaryAnomaly> get _filteredAnomalies {
    return widget.anomalies.where((anomaly) {
      final matchesDate =
          _selectedDate == _allAnomalyFilter ||
          (anomaly.date?.day.toString() == _selectedDate);
      final matchesEmployee =
          _selectedEmployee == _allAnomalyFilter ||
          anomaly.employee.name == _selectedEmployee;
      return matchesDate && matchesEmployee;
    }).toList();
  }

  bool get _hasFilters =>
      _selectedDate != _allAnomalyFilter ||
      _selectedEmployee != _allAnomalyFilter;

  void _clearFilters() {
    setState(() {
      _selectedDate = _allAnomalyFilter;
      _selectedEmployee = _allAnomalyFilter;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasAnomalies = widget.anomalies.isNotEmpty;
    final visibleAnomalies = _filteredAnomalies;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                child: Row(
                  children: [
                    Icon(
                      hasAnomalies
                          ? Icons.warning_amber_outlined
                          : Icons.check_circle_outline,
                      color: hasAnomalies
                          ? _AnomalyPanel._warningColor
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '异常检查',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    _AnomalyCountBadge(
                      visibleCount: visibleAnomalies.length,
                      totalCount: widget.anomalies.length,
                      warning: hasAnomalies,
                    ),
                    IconButton(
                      key: const Key('summary-anomaly-toggle'),
                      tooltip: _expanded ? '收起异常列表' : '展开异常列表',
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            if (hasAnomalies) ...[
              _AnomalyFilters(
                dates: _dateOptions,
                employees: _employeeOptions,
                selectedDate: _selectedDate,
                selectedEmployee: _selectedEmployee,
                hasFilters: _hasFilters,
                onDateChanged: (value) =>
                    setState(() => _selectedDate = value ?? _allAnomalyFilter),
                onEmployeeChanged: (value) => setState(
                  () => _selectedEmployee = value ?? _allAnomalyFilter,
                ),
                onClear: _clearFilters,
              ),
              const Divider(height: 1),
              if (visibleAnomalies.isEmpty)
                _AnomalyFilteredEmptyRow(onClear: _clearFilters)
              else
                for (
                  var index = 0;
                  index < visibleAnomalies.length;
                  index++
                ) ...[
                  _AnomalyRow(anomaly: visibleAnomalies[index]),
                  if (index != visibleAnomalies.length - 1)
                    const Divider(height: 1, indent: 68),
                ],
            ] else
              const _AnomalyEmptyRow(),
          ],
        ],
      ),
    );
  }
}

class _AnomalyFilters extends StatelessWidget {
  const _AnomalyFilters({
    required this.dates,
    required this.employees,
    required this.selectedDate,
    required this.selectedEmployee,
    required this.hasFilters,
    required this.onDateChanged,
    required this.onEmployeeChanged,
    required this.onClear,
  });

  final List<String> dates;
  final List<String> employees;
  final String selectedDate;
  final String selectedEmployee;
  final bool hasFilters;
  final ValueChanged<String?> onDateChanged;
  final ValueChanged<String?> onEmployeeChanged;
  final VoidCallback onClear;

  Future<void> _selectDate(BuildContext context) async {
    final result = await showModalBottomSheet<_DayWheelSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DayWheelSheet(
        daysInMonth: dates.length,
        selectedDay: selectedDate == _allAnomalyFilter
            ? null
            : int.tryParse(selectedDate),
      ),
    );
    if (result == null) return;
    onDateChanged(
      result.day == null ? _allAnomalyFilter : result.day.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _AnomalyFilterField(
                  label: '按日期',
                  value: selectedDate,
                  displayValue: selectedDate == _allAnomalyFilter
                      ? '全部日期'
                      : '$selectedDate日',
                  items: const [],
                  onChanged: onDateChanged,
                  onTap: () => _selectDate(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AnomalyFilterField(
                  label: '按姓名',
                  value: selectedEmployee,
                  items: [
                    const DropdownMenuItem(
                      value: _allAnomalyFilter,
                      child: Text('全部姓名'),
                    ),
                    for (final employee in employees)
                      DropdownMenuItem(value: employee, child: Text(employee)),
                  ],
                  onChanged: onEmployeeChanged,
                ),
              ),
            ],
          ),
          if (hasFilters)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('清除筛选'),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnomalyFilterField extends StatelessWidget {
  const _AnomalyFilterField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.displayValue,
    this.onTap,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  final String? displayValue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap != null) {
      return Semantics(
        button: true,
        label: label,
        value: displayValue,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                isDense: true,
                suffixIcon: const Icon(Icons.unfold_more),
              ),
              child: Text(
                displayValue ?? value,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      );
    }
    return InputDecorator(
      decoration: InputDecoration(labelText: label, isDense: true),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _AnomalyCountBadge extends StatelessWidget {
  const _AnomalyCountBadge({
    required this.visibleCount,
    required this.totalCount,
    required this.warning,
  });

  final int visibleCount;
  final int totalCount;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? _AnomalyPanel._warningColor : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: warning ? AppColors.lightOrange : AppColors.lightGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        visibleCount == totalCount
            ? '$totalCount项${warning ? '待检查' : ''}'
            : '$visibleCount/$totalCount项',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AnomalyRow extends StatelessWidget {
  const _AnomalyRow({required this.anomaly});

  final MonthlySummaryAnomaly anomaly;

  @override
  Widget build(BuildContext context) {
    final label = MonthlySummaryOptions.anomalyLabel(anomaly.kind);
    final employeeAndDate = [
      anomaly.employee.name,
      if (anomaly.dateLabel.isNotEmpty) anomaly.dateLabel,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _AnomalyPanel._warningColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_outlined,
              size: 20,
              color: _AnomalyPanel._warningColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightOrange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _AnomalyPanel._warningColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      employeeAndDate,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  anomaly.message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnomalyEmptyRow extends StatelessWidget {
  const _AnomalyEmptyRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('未发现异常'),
                SizedBox(height: 2),
                Text('当前月度考勤数据完整。'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnomalyFilteredEmptyRow extends StatelessWidget {
  const _AnomalyFilteredEmptyRow({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      child: Column(
        children: [
          const Icon(Icons.filter_alt_off_outlined, color: AppColors.helper),
          const SizedBox(height: 6),
          const Text('没有符合当前筛选的异常'),
          const SizedBox(height: 2),
          Text(
            '请更换日期或姓名，或清除筛选条件。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onClear, child: const Text('清除筛选')),
        ],
      ),
    );
  }
}

class _SummaryEmpty extends StatelessWidget {
  const _SummaryEmpty({required this.onGenerate});

  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.assessment_outlined,
              size: 46,
              color: AppColors.helper,
            ),
            const SizedBox(height: 14),
            Text('本月尚未生成汇总', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              '汇总会读取月度名单、每日考勤、请假和加班数据，并列出需要检查的异常。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('summary-generate-empty-button'),
              onPressed: onGenerate,
              icon: const Icon(Icons.playlist_add_check_outlined),
              label: const Text('生成本月汇总'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryError extends StatelessWidget {
  const _SummaryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 42),
            const SizedBox(height: 12),
            Text('月度汇总暂时不可用', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('重新加载')),
          ],
        ),
      ),
    );
  }
}
