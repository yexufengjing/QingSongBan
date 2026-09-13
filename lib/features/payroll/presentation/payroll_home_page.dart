// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_enums.dart';
import '../../reminders/application/reminder_providers.dart';
import '../application/payroll_providers.dart';
import '../domain/payroll_options.dart';

class PayrollHomePage extends ConsumerWidget {
  const PayrollHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(payrollMonthProvider);
    final batches = ref.watch(payrollBatchesProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: '返回汇总',
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '临时工薪资',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '按月造资、核算、确认和导出',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.push('/reports/payroll/settings'),
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: '工种与日薪设置',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _MonthSelector(
              month: month,
              onChanged: (value) =>
                  ref.read(payrollMonthProvider.notifier).state = value,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: batches.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('工资批次加载失败：$error')),
                data: (values) {
                  final yearMonth = payrollYearMonth(month);
                  final batch = values.cast<dynamic>().firstWhere(
                    (value) => value.payrollMonth == yearMonth,
                    orElse: () => null,
                  );
                  if (batch == null) return _NoBatch(month: month);
                  return _BatchContent(batch: batch, ref: ref);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.month, required this.onChanged});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Row(
        children: [
          IconButton(
            onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(
                payrollMonthLabel(month),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          IconButton(
            onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _NoBatch extends ConsumerWidget {
  const _NoBatch({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.payments_outlined,
                size: 48,
                color: AppColors.techBlue,
              ),
              const SizedBox(height: 12),
              Text('本月尚未生成工资批次', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                '系统会读取本月临时工实际出勤，自动生成默认工资名单。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => _start(context, ref),
                icon: const Icon(Icons.playlist_add_check_outlined),
                label: const Text('开始造资'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.push('/reports/payroll/history'),
                child: const Text('查看工资历史'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(payrollRepositoryProvider);
      final batch = await repo.ensureDraft(payrollYearMonth(month));
      await repo.generateRoster(batch.id);
      final reminder = await ref
          .read(reminderRepositoryProvider)
          .findBySource('payroll_batch', batch.id);
      if (reminder != null) {
        await ref.read(notificationServiceProvider).sync(reminder);
      }
      ref.invalidate(payrollBatchesProvider);
      if (context.mounted) context.push('/reports/payroll/edit/${batch.id}');
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('生成工资名单失败：$error')));
    }
  }
}

class _BatchContent extends StatelessWidget {
  const _BatchContent({required this.batch, required this.ref});

  final dynamic batch;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final validation = ref.watch(payrollValidationProvider(batch.id));
    return ListView(
      children: [
        Card(
          color: _statusColor(batch.status).withValues(alpha: 0.1),
          child: ListTile(
            leading: Icon(
              Icons.payments_outlined,
              color: _statusColor(batch.status),
            ),
            title: Text(PayrollOptions.statusLabel(batch.status)),
            subtitle: Text(
              '${batch.employeeCount} 人 · ${_days(batch.attendanceHalfDaysTotal)} · 工资 ${_money(batch.finalWageTotal)}',
            ),
            trailing: FilledButton(
              onPressed: () =>
                  GoRouter.of(context)
                      .push('/reports/payroll/edit/${batch.id}'),
              child: const Text('打开'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Stat(label: '人数', value: '${batch.employeeCount}人'),
            _Stat(label: '出勤', value: _days(batch.attendanceHalfDaysTotal)),
            _Stat(label: '基础工资', value: _money(batch.baseWageTotal)),
            _Stat(label: '补助', value: _money(batch.subsidyTotal)),
            _Stat(label: '保险扣除', value: _money(batch.insuranceDeductionTotal)),
            _Stat(label: '最终工资', value: _money(batch.finalWageTotal)),
            _Stat(
              label: '异常',
              value: validation.when(
                loading: () => '检查中',
                error: (_, _) => '未知',
                data: (result) =>
                    '${result.errors.length + result.warnings.length}项',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () =>
              GoRouter.of(context).push('/reports/payroll/edit/${batch.id}'),
          icon: const Icon(Icons.edit_note_outlined),
          label: const Text('进入工资造资'),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              GoRouter.of(context).push('/reports/payroll/history'),
          icon: const Icon(Icons.history),
          label: const Text('查看工资历史'),
        ),
      ],
    );
  }

  Color _statusColor(PayrollStatus status) => switch (status) {
    PayrollStatus.draft => AppColors.helper,
    PayrollStatus.pendingReview => AppColors.techBlue,
    PayrollStatus.confirmed => AppColors.primary,
    PayrollStatus.locked => AppColors.purple,
  };

  String _days(int halfDays) => halfDays.isEven
      ? '${halfDays ~/ 2}天'
      : '${(halfDays / 2).toStringAsFixed(1)}天';

  String _money(double value) => value.toStringAsFixed(2);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 3),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
