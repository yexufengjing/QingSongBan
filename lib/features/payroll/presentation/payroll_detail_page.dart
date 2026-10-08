// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../insurance/application/insurance_providers.dart';
import '../../insurance/domain/insurance_options.dart';
import '../application/payroll_providers.dart';
import '../domain/payroll_calculator.dart';
import '../domain/payroll_models.dart';
import '../domain/payroll_options.dart';

class PayrollDetailPage extends ConsumerWidget {
  const PayrollDetailPage({required this.itemId, super.key});

  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(payrollRepositoryProvider).findItemWithEmployee(itemId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError)
            return Scaffold(
              body: Center(child: Text('工资明细加载失败：${snapshot.error}')),
            );
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _PayrollDetailContent(value: snapshot.data!);
      },
    );
  }
}

class _PayrollDetailContent extends ConsumerWidget {
  const _PayrollDetailContent({required this.value});

  final PayrollItemWithEmployee value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = value.item;
    final batch = ref.watch(payrollBatchProvider(item.payrollBatchId));
    final insurance = value.employee == null
        ? null
        : ref.watch(insuranceProfileProvider(value.employee!.id));
    final payrollMonth = batch.valueOrNull?.payrollMonth;
    final calculation = PayrollCalculator.calculate(
      attendanceHalfDays: item.attendanceHalfDaysSnapshot,
      dailyWage: item.dailyWage,
      subsidy: item.subsidy,
      insuranceDeduction: item.insuranceDeduction,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('${item.employeeNameSnapshot} 工资明细'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.lightGreen,
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppColors.success,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '最终工资',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${calculation.finalWage.toStringAsFixed(2)} 元',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const _SectionHeading('身份信息', Icons.person_outline),
                  const SizedBox(height: 12),
                  _Row('姓名', item.employeeNameSnapshot),
                  _Row('工号', item.employeeNoSnapshot),
                  _Row('工种', item.jobTypeNameSnapshot ?? '未配置'),
                  _Row(
                    '日薪来源',
                    PayrollOptions.dailyWageSourceLabel(item.dailyWageSource),
                  ),
                  if (insurance != null)
                    insurance.when(
                      loading: () => const _Row('保险状态', '加载中…'),
                      error: (_, _) => const _Row('保险状态', '读取失败'),
                      data: (profile) => _Row(
                        '保险状态',
                        profile == null
                            ? '未登记'
                            : profile.isInsured
                            ? '已参保${profile.insuranceType == null ? '' : ' · ${InsuranceOptions.typeLabel(profile.insuranceType!)}'}'
                            : '未参保',
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const _SectionHeading('核算明细', Icons.calculate_outlined),
                  const SizedBox(height: 12),
                  _Row(
                    '出勤天数',
                    '${calculation.attendanceDays.toStringAsFixed(1)} 天',
                  ),
                  _Row('日薪', '${item.dailyWage.toStringAsFixed(2)} 元'),
                  _Row('基础工资', '${calculation.baseWage.toStringAsFixed(2)} 元'),
                  _Row('补助', '${item.subsidy.toStringAsFixed(2)} 元'),
                  _Row(
                    '保险扣除',
                    '${item.insuranceDeduction.toStringAsFixed(2)} 元',
                  ),

                  const SizedBox(height: 14),
                  Card(
                    color: AppColors.lightBlue,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '${calculation.attendanceDays.toStringAsFixed(1)} × ${item.dailyWage.toStringAsFixed(2)} + ${item.subsidy.toStringAsFixed(2)} - ${item.insuranceDeduction.toStringAsFixed(2)} = ${calculation.finalWage.toStringAsFixed(2)}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push(
              payrollMonth == null
                  ? '/attendance/monthly-table'
                  : '/attendance/monthly-table?month=$payrollMonth',
            ),
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('查看本月考勤'),
          ),
          if (value.employee != null)
            OutlinedButton.icon(
              onPressed: () =>
                  context.push('/personnel/${value.employee!.id}/payroll'),
              icon: const Icon(Icons.history_outlined),
              label: const Text('查看历史工资'),
            ),
          if (item.remark?.trim().isNotEmpty == true) _Row('备注', item.remark!),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label, this.icon);
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.techBlue, size: 22),
      const SizedBox(width: 8),
      Text(label, style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}
