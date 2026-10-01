import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../../insurance/application/insurance_providers.dart';
import '../../insurance/domain/insurance_options.dart';
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
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
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
                        '月度汇总',
                        style: Theme.of(context).textTheme.titleLarge,
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
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            IconButton(
              key: const Key('summary-previous-month'),
              onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left),
              tooltip: '上个月',
            ),
            Expanded(
              child: Center(
                child: Text(
                  monthlySummaryMonthLabel(month),
                  key: const Key('summary-month-label'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            IconButton(
              key: const Key('summary-next-month'),
              onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right),
              tooltip: '下个月',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryContent extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    if (value.rows.isEmpty) return _SummaryEmpty(onGenerate: onGenerate);
    final month = AppDateUtils.parseYearMonth(value.yearMonth);
    final changes = ref.watch(insuranceChangesForMonthProvider(month));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _SummaryStats(value: value),
        const SizedBox(height: 8),
        _SummaryTabs(value: value, insuranceChanges: changes),
        const SizedBox(height: 12),
        _SummaryOperationMenu(
          value: value,
          onGenerate: onGenerate,
          onStatus: onStatus,
        ),
        const SizedBox(height: 12),
        Text('异常汇总', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (value.anomalies.isEmpty)
          const _NoAnomalies()
        else
          for (final anomaly in value.anomalies) _AnomalyCard(anomaly: anomaly),
      ],
    );
  }
}

class _SummaryTabs extends StatefulWidget {
  const _SummaryTabs({required this.value, required this.insuranceChanges});

  final MonthlySummaryView value;
  final AsyncValue<List<InsuranceChangeView>> insuranceChanges;

  @override
  State<_SummaryTabs> createState() => _SummaryTabsState();
}

class _SummaryTabsState extends State<_SummaryTabs> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          for (final entry in const [(0, '考勤汇总'), (1, '人员变动'), (2, '保险变更')])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Center(child: Text(entry.$2)),
                  selected: _selected == entry.$1,
                  onSelected: (_) => setState(() => _selected = entry.$1),
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _selected == entry.$1 ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 4),
      switch (_selected) {
        0 => _AttendanceSummaryTable(rows: widget.value.rows),
        1 => _PersonnelChangesTable(rows: widget.value.rows),
        _ => widget.insuranceChanges.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, _) => const ListTile(
            leading: Icon(Icons.error_outline, color: AppColors.danger),
            title: Text('保险变更暂时不可用'),
          ),
          data: (items) => _InsuranceChangesTable(items: items),
        ),
      },
    ],
  );
}

class _AttendanceSummaryTable extends StatelessWidget {
  const _AttendanceSummaryTable({required this.rows});

  final List<MonthlySummaryRowView> rows;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 38,
        dataRowMinHeight: 42,
        dataRowMaxHeight: 48,
        columns: const [
          DataColumn(label: Text('姓名')),
          DataColumn(label: Text('实际出勤天数')),
          DataColumn(label: Text('请假天数')),
          DataColumn(label: Text('缺勤天数')),
          DataColumn(label: Text('加班小时')),
          DataColumn(label: Text('月末状态')),
          DataColumn(label: Text('数据完整')),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                DataCell(Text(row.employee.name)),
                DataCell(Text(_summaryDays(row.summary.attendanceDays))),
                DataCell(Text(_summaryDays(row.summary.leaveDays))),
                DataCell(Text(_summaryDays(row.summary.absentDays))),
                DataCell(
                  Text((row.summary.overtimeMinutes / 60).toStringAsFixed(1)),
                ),
                DataCell(Text(row.summary.monthEndStatus ?? '未知')),
                DataCell(Text(row.summary.isComplete ? '完整' : '待补充')),
              ],
            ),
        ],
      ),
    ),
  );
}

String _summaryDays(double value) => value == value.roundToDouble()
    ? '${value.toInt()}天'
    : '${value.toStringAsFixed(1)}天';

class _PersonnelChangesTable extends StatelessWidget {
  const _PersonnelChangesTable({required this.rows});

  final List<MonthlySummaryRowView> rows;

  @override
  Widget build(BuildContext context) {
    final changed = rows
        .where(
          (row) =>
              row.summary.joinedDuringMonth ||
              row.summary.terminatedDuringMonth,
        )
        .toList();
    if (changed.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.people_outline, color: AppColors.techBlue),
          title: Text('本月暂无人员变动记录'),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 38,
          dataRowMinHeight: 42,
          dataRowMaxHeight: 48,
          columns: const [
            DataColumn(label: Text('姓名')),
            DataColumn(label: Text('人员编号')),
            DataColumn(label: Text('月初状态')),
            DataColumn(label: Text('月末状态')),
            DataColumn(label: Text('变动')),
          ],
          rows: [
            for (final row in changed)
              DataRow(
                cells: [
                  DataCell(Text(row.employee.name)),
                  DataCell(Text(row.employee.employeeNo)),
                  DataCell(Text(row.summary.monthStartStatus ?? '未知')),
                  DataCell(Text(row.summary.monthEndStatus ?? '未知')),
                  DataCell(
                    Text(
                      [
                        if (row.summary.joinedDuringMonth) '本月入职',
                        if (row.summary.terminatedDuringMonth) '本月离职',
                      ].join('、'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _InsuranceChangesTable extends StatelessWidget {
  const _InsuranceChangesTable({required this.items});

  final List<InsuranceChangeView> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.shield_outlined, color: AppColors.primary),
          title: Text('本月暂无保险变更记录'),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 38,
          dataRowMinHeight: 42,
          dataRowMaxHeight: 48,
          columns: const [
            DataColumn(label: Text('姓名')),
            DataColumn(label: Text('生效月份')),
            DataColumn(label: Text('变更类型')),
            DataColumn(label: Text('办理状态')),
          ],
          rows: [
            for (final item in items)
              DataRow(
                cells: [
                  DataCell(Text(item.employee.name)),
                  DataCell(Text(item.change.effectiveMonth)),
                  DataCell(
                    Text(
                      InsuranceOptions.changeTypeLabel(item.change.changeType),
                    ),
                  ),
                  DataCell(
                    Text(
                      InsuranceOptions.statusLabel(
                        item.change.processingStatus,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryOperationMenu extends StatelessWidget {
  const _SummaryOperationMenu({
    required this.value,
    required this.onGenerate,
    required this.onStatus,
  });

  final MonthlySummaryView value;
  final VoidCallback onGenerate;
  final Future<void> Function(MonthlySummaryStatus, String?) onStatus;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      leading: const Icon(Icons.tune),
      title: Text('汇总操作 · ${MonthlySummaryOptions.statusLabel(value.status)}'),
      children: [
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.refresh),
              label: const Text('重新生成'),
            ),
            if (value.status == MonthlySummaryStatus.pendingReview)
              FilledButton(
                onPressed: () => onStatus(MonthlySummaryStatus.confirmed, null),
                child: const Text('确认汇总'),
              ),
            if (value.status == MonthlySummaryStatus.confirmed)
              FilledButton(
                onPressed: () => onStatus(MonthlySummaryStatus.locked, null),
                child: const Text('锁定汇总'),
              ),
            if (value.status == MonthlySummaryStatus.locked)
              TextButton(
                onPressed: () => _unlock(context),
                child: const Text('解锁汇总'),
              ),
          ],
        ),
      ],
    ),
  );

  Future<void> _unlock(BuildContext context) async {
    var reason = '';
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解锁月度汇总'),
        content: TextField(
          onChanged: (text) => reason = text,
          decoration: const InputDecoration(labelText: '解锁原因'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reason),
            child: const Text('确认解锁'),
          ),
        ],
      ),
    );
    if (value != null && value.trim().isNotEmpty) {
      await onStatus(MonthlySummaryStatus.pendingReview, value);
    }
  }
}

class _SummaryStats extends StatelessWidget {
  const _SummaryStats({required this.value});

  final MonthlySummaryView value;

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatData(
        label: '本月出勤人数',
        value:
            '${value.rows.where((row) => row.summary.attendanceDays > 0).length}人',
        icon: Icons.fact_check_outlined,
        color: AppColors.primary,
      ),
      _StatData(
        label: '请假人数',
        value:
            '${value.rows.where((row) => row.summary.leaveDays > 0).length}人',
        icon: Icons.event_busy_outlined,
        color: AppColors.purple,
      ),
      _StatData(
        label: '缺勤人数',
        value:
            '${value.rows.where((row) => row.summary.absentDays > 0).length}人',
        icon: Icons.person_off_outlined,
        color: AppColors.danger,
      ),
      _StatData(
        label: '加班小时',
        value: (value.overtimeMinutes / 60).toStringAsFixed(1),
        icon: Icons.more_time_outlined,
        color: const Color(0xFFE98500),
      ),
      _StatData(
        label: '数据完整率',
        value:
            '${(value.rows.where((row) => row.summary.isComplete).length * 100 / value.rows.length).round()}%',
        icon: Icons.verified_outlined,
        color: AppColors.techBlue,
      ),
    ];
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _Stat(data: stats[i])),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _Stat(data: stats[3])),
            const SizedBox(width: 8),
            Expanded(child: _Stat(data: stats[4])),
          ],
        ),
      ],
    );
  }
}

class _StatData {
  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.data});

  final _StatData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, color: data.color, size: 18),
            ),
            const SizedBox(height: 7),
            Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              data.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnomalyCard extends StatelessWidget {
  const _AnomalyCard({required this.anomaly});

  final MonthlySummaryAnomaly anomaly;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.lightOrange,
      child: ListTile(
        leading: const Icon(
          Icons.warning_amber_outlined,
          color: Color(0xFFE98500),
        ),
        title: Text(MonthlySummaryOptions.anomalyLabel(anomaly.kind)),
        subtitle: Text(
          '${anomaly.employee.name}${anomaly.dateLabel.isEmpty ? '' : ' · ${anomaly.dateLabel}'} · ${anomaly.message}',
        ),
      ),
    );
  }
}

class _NoAnomalies extends StatelessWidget {
  const _NoAnomalies();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.lightGreen,
      child: const ListTile(
        leading: Icon(Icons.check_circle_outline, color: AppColors.primary),
        title: Text('未发现异常'),
        subtitle: Text('当前月度考勤数据完整。'),
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
