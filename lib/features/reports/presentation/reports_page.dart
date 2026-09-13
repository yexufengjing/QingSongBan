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
        Text('异常检查', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (value.anomalies.isEmpty)
          const _NoAnomalies()
        else
          for (final anomaly in value.anomalies) ...[
            _AnomalyCard(anomaly: anomaly),
            const SizedBox(height: 8),
          ],
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
