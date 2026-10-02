import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../application/daily_attendance_providers.dart';
import '../application/monthly_attendance_table_providers.dart';
import '../domain/daily_attendance_options.dart';
import '../domain/monthly_attendance_table_options.dart';

class MonthlyAttendanceTablePage extends ConsumerStatefulWidget {
  const MonthlyAttendanceTablePage({super.key, this.initialMonth});

  final DateTime? initialMonth;

  @override
  ConsumerState<MonthlyAttendanceTablePage> createState() =>
      _MonthlyAttendanceTablePageState();
}

class _MonthlyAttendanceTablePageState
    extends ConsumerState<MonthlyAttendanceTablePage> {
  void _applyInitialMonth() {
    final initialMonth = widget.initialMonth;
    if (initialMonth == null) return;
    final current = ref.read(monthlyAttendanceTableMonthProvider);
    if (current.year == initialMonth.year &&
        current.month == initialMonth.month) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(monthlyAttendanceTableMonthProvider);
      if (current.year != initialMonth.year ||
          current.month != initialMonth.month) {
        ref.read(monthlyAttendanceTableMonthProvider.notifier).state = DateTime(
          initialMonth.year,
          initialMonth.month,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _applyInitialMonth();
    final month = ref.watch(monthlyAttendanceTableMonthProvider);
    final groups = ref.watch(monthlyAttendanceTableGroupsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('月考勤表'),
        actions: [
          FilledButton.tonalIcon(
            key: const Key('monthly-attendance-export'),
            onPressed: () => context.push(
              '/settings/excel?month=${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}',
            ),
            icon: const Icon(Icons.download_outlined),
            label: const Text('导出表格'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.lightGreen,
              foregroundColor: AppColors.primary,
            ),
          ),
          IconButton(
            onPressed: () => context.push('/attendance/daily'),
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: '每日考勤',
          ),
        ],
      ),
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _MonthlyTableError(
          onRetry: () => ref.invalidate(monthlyAttendanceTableGroupsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _NoMonthlyTableGroup(
              onManage: () => context.push('/attendance/groups'),
            );
          }
          return _MonthlyAttendanceTableContent(groups: items);
        },
      ),
    );
  }
}

class _MonthlyAttendanceTableContent extends ConsumerWidget {
  const _MonthlyAttendanceTableContent({required this.groups});

  final List<AttendanceGroup> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(monthlyAttendanceTableMonthProvider);
    final selectedId = ref.watch(monthlyAttendanceTableGroupIdProvider);
    final selectedGroup = groups.firstWhere(
      (group) => group.id == selectedId,
      orElse: () => groups.first,
    );
    if (selectedId != selectedGroup.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(monthlyAttendanceTableGroupIdProvider) !=
            selectedGroup.id) {
          ref.read(monthlyAttendanceTableGroupIdProvider.notifier).state =
              selectedGroup.id;
        }
      });
    }

    final table = ref.watch(monthlyAttendanceTableProvider);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: _MonthlyTableSelectors(
            month: month,
            groups: groups,
            selectedGroup: selectedGroup,
            onMonthChanged: (value) =>
                ref.read(monthlyAttendanceTableMonthProvider.notifier).state =
                    value,
            onGroupChanged: (value) {
              if (value != null) {
                ref.read(monthlyAttendanceTableGroupIdProvider.notifier).state =
                    value;
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'daily',
                  label: Text('日登记'),
                  icon: Icon(Icons.fact_check_outlined),
                ),
                ButtonSegment(
                  value: 'monthly',
                  label: Text('月表'),
                  icon: Icon(Icons.calendar_view_month_outlined),
                ),
              ],
              selected: const {'monthly'},
              onSelectionChanged: (_) => context.push('/attendance/daily'),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.primary
                      : Colors.white,
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? Colors.white
                      : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
        if (!selectedGroup.isEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Card(
              color: AppColors.lightOrange,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Row(
                  children: [
                    Icon(Icons.history_outlined, color: Color(0xFFE98500)),
                    SizedBox(width: 8),
                    Expanded(child: Text('当前考勤组已停用，仅保留历史月度考勤表查看。')),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '考勤明细',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '← 左右滑动查看日期 →',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        table.when(
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => SizedBox(
            height: 200,
            child: _MonthlyTableError(
              onRetry: () => ref.invalidate(monthlyAttendanceTableProvider),
            ),
          ),
          data: (value) {
            if (value.rows.isEmpty) return const _NoMonthlyRoster();
            final screenHeight = MediaQuery.sizeOf(context).height;
            final maximumHeight = math.min(360.0, screenHeight * 0.46);
            final contentHeight =
                _MonthlyAttendanceTable.headerHeight +
                value.rows.length * _MonthlyAttendanceTable.rowHeight +
                _MonthlyAttendanceTable.totalHeight;
            return SizedBox(
              height: math.min(maximumHeight, contentHeight),
              child: _MonthlyAttendanceTable(
                month: month,
                table: value,
                onCellTap: (row, cell) =>
                    _editCell(context, ref, row: row, cell: cell),
              ),
            );
          },
        ),
        const _MonthlyAttendanceLegend(),
      ],
    );
  }

  Future<void> _editCell(
    BuildContext context,
    WidgetRef ref, {
    required MonthlyAttendanceTableRow row,
    required MonthlyAttendanceCell cell,
  }) async {
    if (!cell.isEditable) {
      _showMessage(context, cell.lockReason ?? '当前日期不可编辑');
      return;
    }
    final draft = await showDialog<DailyAttendanceDraft>(
      context: context,
      builder: (context) => _MonthlyCellEditor(
        employeeName: row.employee.name,
        employeeId: row.employee.id,
        cell: cell,
      ),
    );
    if (draft == null || !context.mounted) return;
    try {
      await ref.read(dailyAttendanceRepositoryProvider).save(draft);
    } catch (error) {
      if (context.mounted) _showMessage(context, '保存失败：$error');
    }
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MonthlyTableSelectors extends StatelessWidget {
  const _MonthlyTableSelectors({
    required this.month,
    required this.groups,
    required this.selectedGroup,
    required this.onMonthChanged,
    required this.onGroupChanged,
  });

  final DateTime month;
  final List<AttendanceGroup> groups;
  final AttendanceGroup selectedGroup;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<int?> onGroupChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('monthly-attendance-table-month-button'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: month,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2099),
                  helpText: '选择月份',
                );
                if (picked != null) {
                  onMonthChanged(DateTime(picked.year, picked.month));
                }
              },
              icon: const Icon(Icons.calendar_month_outlined, size: 19),
              label: Text(
                '${month.year}年${month.month.toString().padLeft(2, '0')}月',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int>(
              key: const Key('monthly-attendance-table-group-field'),
              initialValue: selectedGroup.id,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.groups_outlined, size: 19),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 9,
                ),
              ),
              items: [
                for (final group in groups)
                  DropdownMenuItem(
                    value: group.id,
                    child: Text(
                      '${group.name}${group.isEnabled ? '' : '（停用）'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: onGroupChanged,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MonthlyAttendanceLegend extends StatelessWidget {
  const _MonthlyAttendanceLegend();

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('符号说明', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: const [
              _LegendItem(symbol: '力', label: '全天出勤', color: AppColors.primary),
              _LegendItem(
                symbol: '半',
                label: '半天出勤',
                color: AppColors.techBlue,
              ),
              _LegendItem(symbol: '🔺', label: '缺勤', color: AppColors.danger),
              _LegendItem(symbol: '休', label: '公休', color: AppColors.body),
              _LegendItem(symbol: '停', label: '停工', color: Color(0xFFE98500)),
              _LegendItem(symbol: '假', label: '请假', color: AppColors.danger),
              _LegendItem(symbol: '·', label: '未登记', color: AppColors.helper),
              _LegendItem(symbol: '未', label: '入职前锁定', color: AppColors.helper),
              _LegendItem(symbol: '离', label: '离职后锁定', color: AppColors.helper),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('点击表格中的单元格，可编辑当日的上午/下午考勤状态。'),
          ),
        ],
      ),
    ),
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.symbol,
    required this.label,
    required this.color,
  });

  final String symbol;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        symbol,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _MonthlyAttendanceTable extends StatelessWidget {
  const _MonthlyAttendanceTable({
    required this.month,
    required this.table,
    required this.onCellTap,
  });

  static const nameWidth = 88.0;
  static const dayWidth = 40.0;
  static const tailWidth = 54.0;
  static const headerHeight = 46.0;
  static const rowHeight = 48.0;
  static const totalHeight = 44.0;

  final DateTime month;
  final MonthlyAttendanceTableView table;
  final Future<void> Function(
    MonthlyAttendanceTableRow row,
    MonthlyAttendanceCell cell,
  )
  onCellTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rightViewport = math
            .max(0.0, constraints.maxWidth - nameWidth)
            .toDouble();
        final rightContentWidth = table.daysInMonth * dayWidth + tailWidth * 2;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            key: const Key('monthly-attendance-table-vertical-scroll'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: nameWidth,
                  child: _FixedNameColumn(table: table),
                ),
                SizedBox(
                  width: rightViewport,
                  child: SingleChildScrollView(
                    key: const Key(
                      'monthly-attendance-table-horizontal-scroll',
                    ),
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: rightContentWidth,
                      child: _ScrollableDateColumn(
                        month: month,
                        table: table,
                        onCellTap: onCellTap,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FixedNameColumn extends StatelessWidget {
  const _FixedNameColumn({required this.table});

  final MonthlyAttendanceTableView table;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TableBox(
          height: _MonthlyAttendanceTable.headerHeight,
          background: AppColors.lightBlue,
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('姓名'),
            ),
          ),
        ),
        for (final row in table.rows)
          _TableBox(
            height: _MonthlyAttendanceTable.rowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.employee.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      row.employee.employeeNo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        _TableBox(
          height: _MonthlyAttendanceTable.totalHeight,
          background: AppColors.lightGreen,
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('合计'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScrollableDateColumn extends StatelessWidget {
  const _ScrollableDateColumn({
    required this.month,
    required this.table,
    required this.onCellTap,
  });

  final DateTime month;
  final MonthlyAttendanceTableView table;
  final Future<void> Function(
    MonthlyAttendanceTableRow row,
    MonthlyAttendanceCell cell,
  )
  onCellTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TableBox(
          height: _MonthlyAttendanceTable.headerHeight,
          background: AppColors.lightBlue,
          showBorder: false,
          child: Row(
            children: [
              for (var day = 1; day <= table.daysInMonth; day++)
                _TableBox(
                  width: _MonthlyAttendanceTable.dayWidth,
                  height: _MonthlyAttendanceTable.headerHeight,
                  background: AppColors.lightBlue,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          _weekdayShort(
                            DateTime(month.year, month.month, day).weekday,
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              _TableBox(
                width: _MonthlyAttendanceTable.tailWidth,
                height: _MonthlyAttendanceTable.headerHeight,
                background: AppColors.lightGreen,
                child: const Center(child: Text('出勤')),
              ),
              _TableBox(
                width: _MonthlyAttendanceTable.tailWidth,
                height: _MonthlyAttendanceTable.headerHeight,
                background: const Color(0xFFF0EAFF),
                child: const Center(child: Text('请假')),
              ),
            ],
          ),
        ),
        for (final row in table.rows)
          SizedBox(
            height: _MonthlyAttendanceTable.rowHeight,
            child: Row(
              children: [
                for (var day = 1; day <= table.daysInMonth; day++)
                  _MonthlyCell(
                    key: Key('monthly-attendance-cell-${row.employee.id}-$day'),
                    cell: row.cellForDay(month: month, day: day),
                    onTap: () =>
                        onCellTap(row, row.cellForDay(month: month, day: day)),
                  ),
                _TableBox(
                  width: _MonthlyAttendanceTable.tailWidth,
                  height: _MonthlyAttendanceTable.rowHeight,
                  background: AppColors.lightGreen,
                  child: Center(child: Text(_formatDays(row.attendanceDays))),
                ),
                _TableBox(
                  width: _MonthlyAttendanceTable.tailWidth,
                  height: _MonthlyAttendanceTable.rowHeight,
                  background: const Color(0xFFF0EAFF),
                  child: Center(child: Text(_formatDays(row.leaveDays))),
                ),
              ],
            ),
          ),
        _TableBox(
          height: _MonthlyAttendanceTable.totalHeight,
          showBorder: false,
          child: Row(
            children: [
              for (var day = 1; day <= table.daysInMonth; day++)
                _TableBox(
                  width: _MonthlyAttendanceTable.dayWidth,
                  height: _MonthlyAttendanceTable.totalHeight,
                  child: const SizedBox.shrink(),
                ),
              _TableBox(
                width: _MonthlyAttendanceTable.tailWidth,
                height: _MonthlyAttendanceTable.totalHeight,
                background: AppColors.lightGreen,
                child: Center(
                  child: Text(_formatDays(table.totalAttendanceDays)),
                ),
              ),
              _TableBox(
                width: _MonthlyAttendanceTable.tailWidth,
                height: _MonthlyAttendanceTable.totalHeight,
                background: const Color(0xFFF0EAFF),
                child: Center(child: Text(_formatDays(table.totalLeaveDays))),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthlyCell extends StatelessWidget {
  const _MonthlyCell({required this.cell, required this.onTap, super.key});

  final MonthlyAttendanceCell cell;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _cellColor(cell);
    return SizedBox(
      width: _MonthlyAttendanceTable.dayWidth,
      height: _MonthlyAttendanceTable.rowHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                cell.symbol,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: statusColor, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _cellColor(MonthlyAttendanceCell cell) {
    if (!cell.isEditable) return AppColors.helper;
    if (cell.attendanceDays == 1) return AppColors.primary;
    if (cell.attendanceDays > 0) return AppColors.techBlue;
    if (cell.leaveDays > 0) return AppColors.danger;
    if (cell.morningStatus == AttendanceHalfStatus.absent ||
        cell.afternoonStatus == AttendanceHalfStatus.absent) {
      return AppColors.danger;
    }
    if (cell.morningStatus == AttendanceHalfStatus.rest &&
        cell.afternoonStatus == AttendanceHalfStatus.rest) {
      return AppColors.body;
    }
    if (cell.morningStatus == AttendanceHalfStatus.stopped &&
        cell.afternoonStatus == AttendanceHalfStatus.stopped) {
      return const Color(0xFFE98500);
    }
    return AppColors.helper;
  }
}

class _TableBox extends StatelessWidget {
  const _TableBox({
    required this.child,
    this.width,
    this.height,
    this.background = AppColors.card,
    this.showBorder = true,
  });

  final Widget child;
  final double? width;
  final double? height;
  final Color background;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: background,
        border: showBorder ? Border.all(color: AppColors.divider) : null,
      ),
      child: child,
    );
  }
}

class _MonthlyCellEditor extends StatefulWidget {
  const _MonthlyCellEditor({
    required this.employeeName,
    required this.employeeId,
    required this.cell,
  });

  final String employeeName;
  final int employeeId;
  final MonthlyAttendanceCell cell;

  @override
  State<_MonthlyCellEditor> createState() => _MonthlyCellEditorState();
}

class _MonthlyCellEditorState extends State<_MonthlyCellEditor> {
  late AttendanceHalfStatus _morning;
  late AttendanceHalfStatus _afternoon;
  late final TextEditingController _remarkController;

  @override
  void initState() {
    super.initState();
    _morning = widget.cell.morningStatus;
    _afternoon = widget.cell.afternoonStatus;
    _remarkController = TextEditingController(text: widget.cell.remark ?? '');
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.cell.date;
    return AlertDialog(
      title: Text('${widget.employeeName} · ${date.month}月${date.day}日'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<AttendanceHalfStatus>(
              key: const Key('monthly-attendance-morning-field'),
              initialValue: _morning,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '上午'),
              items: [
                for (final status in DailyAttendanceOptions.editableStatuses)
                  DropdownMenuItem(
                    value: status,
                    child: Text(DailyAttendanceOptions.statusLabel(status)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _morning = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AttendanceHalfStatus>(
              key: const Key('monthly-attendance-afternoon-field'),
              initialValue: _afternoon,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '下午'),
              items: [
                for (final status in DailyAttendanceOptions.editableStatuses)
                  DropdownMenuItem(
                    value: status,
                    child: Text(DailyAttendanceOptions.statusLabel(status)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _afternoon = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('monthly-attendance-remark-field'),
              controller: _remarkController,
              decoration: const InputDecoration(
                labelText: '备注',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('monthly-attendance-save-cell'),
          onPressed: () => Navigator.of(context).pop(
            DailyAttendanceDraft(
              employeeId: widget.employeeId,
              attendanceDate: widget.cell.date,
              morningStatus: _morning,
              afternoonStatus: _afternoon,
              remark: _remarkController.text,
            ),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _NoMonthlyRoster extends StatelessWidget {
  const _NoMonthlyRoster();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.view_week_outlined,
              size: 42,
              color: AppColors.helper,
            ),
            const SizedBox(height: 12),
            Text('本月暂无考勤名单', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 7),
            Text(
              '请先在月度考勤名单中加入人员，再查看本月考勤表。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/attendance/monthly-roster'),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('去维护月度名单'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMonthlyTableGroup extends StatelessWidget {
  const _NoMonthlyTableGroup({required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.lightBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_outlined,
                color: AppColors.techBlue,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text('暂无考勤组', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '先建立考勤组和月度名单，再查看月考勤表。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onManage,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('去管理考勤组'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyTableError extends StatelessWidget {
  const _MonthlyTableError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
            const SizedBox(height: 12),
            Text('月考勤表暂时不可用', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '请重试；当前不会写入任何临时数据。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('重新加载')),
          ],
        ),
      ),
    );
  }
}

String _formatDays(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

String _weekdayShort(int weekday) => switch (weekday) {
  DateTime.monday => '一',
  DateTime.tuesday => '二',
  DateTime.wednesday => '三',
  DateTime.thursday => '四',
  DateTime.friday => '五',
  DateTime.saturday => '六',
  _ => '日',
};
