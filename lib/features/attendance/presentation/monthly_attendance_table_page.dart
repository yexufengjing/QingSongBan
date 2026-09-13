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
    final groups = ref.watch(monthlyAttendanceTableGroupsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('月考勤表'),
        actions: [
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
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
        if (!selectedGroup.isEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Card(
              color: AppColors.lightOrange,
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.history_outlined, color: Color(0xFFE98500)),
                    SizedBox(width: 10),
                    Expanded(child: Text('当前考勤组已停用，仅保留历史月度考勤表查看。')),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: table.when(
            loading: () => const _MonthlyTableSummaryPlaceholder(),
            error: (_, _) => const SizedBox.shrink(),
            data: (value) => _MonthlyTableSummary(table: value),
          ),
        ),
        Expanded(
          child: table.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _MonthlyTableError(
              onRetry: () => ref.invalidate(monthlyAttendanceTableProvider),
            ),
            data: (value) {
              if (value.rows.isEmpty) {
                return const _NoMonthlyRoster();
              }
              return _MonthlyAttendanceTable(
                month: month,
                table: value,
                onCellTap: (row, cell) =>
                    _editCell(context, ref, row: row, cell: cell),
              );
            },
          ),
        ),
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
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          children: [
            Row(
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
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      '${month.year}年${month.month.toString().padLeft(2, '0')}月',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  key: const Key('monthly-attendance-table-current-month'),
                  onPressed: () {
                    final now = DateTime.now();
                    onMonthChanged(DateTime(now.year, now.month));
                  },
                  child: const Text('本月'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              key: const Key('monthly-attendance-table-group-field'),
              initialValue: selectedGroup.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '考勤组',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
              items: [
                for (final group in groups)
                  DropdownMenuItem(
                    value: group.id,
                    child: Text(
                      '${group.name}${group.isEnabled ? '' : '（已停用）'}',
                    ),
                  ),
              ],
              onChanged: onGroupChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyTableSummary extends StatelessWidget {
  const _MonthlyTableSummary({required this.table});

  final MonthlyAttendanceTableView table;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MonthlySummaryCard(
            label: '人员',
            value: '${table.rows.length} 人',
            color: AppColors.techBlue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MonthlySummaryCard(
            label: '出勤合计',
            value: _formatDays(table.totalAttendanceDays),
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MonthlySummaryCard(
            label: '请假合计',
            value: _formatDays(table.totalLeaveDays),
            color: AppColors.purple,
          ),
        ),
      ],
    );
  }
}

class _MonthlyTableSummaryPlaceholder extends StatelessWidget {
  const _MonthlyTableSummaryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 60);
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  const _MonthlySummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyAttendanceTable extends StatelessWidget {
  const _MonthlyAttendanceTable({
    required this.month,
    required this.table,
    required this.onCellTap,
  });

  static const nameWidth = 142.0;
  static const dayWidth = 56.0;
  static const tailWidth = 78.0;
  static const headerHeight = 58.0;
  static const rowHeight = 70.0;
  static const totalHeight = 62.0;

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
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      row.employee.employeeNo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
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
                  child: Center(child: Text('$day日')),
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
              color: statusColor.withValues(alpha: 0.09),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              cell.symbol,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: statusColor, fontWeight: FontWeight.w700),
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
    if (cell.leaveDays > 0) return AppColors.purple;
    if (cell.morningStatus == AttendanceHalfStatus.rest &&
        cell.afternoonStatus == AttendanceHalfStatus.rest) {
      return AppColors.techBlue;
    }
    if (cell.morningStatus == AttendanceHalfStatus.stopped &&
        cell.afternoonStatus == AttendanceHalfStatus.stopped) {
      return AppColors.danger;
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
