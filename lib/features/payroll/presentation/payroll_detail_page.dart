// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/payroll_providers.dart';
import '../domain/payroll_calculator.dart';
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
        final value = snapshot.data!;
        final item = value.item;
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
            padding: const EdgeInsets.all(20),
            children: [
              _Row('姓名', item.employeeNameSnapshot),
              _Row('工号', item.employeeNoSnapshot),
              _Row('工种', item.jobTypeNameSnapshot ?? '未配置'),
              _Row(
                '日薪来源',
                PayrollOptions.dailyWageSourceLabel(item.dailyWageSource),
              ),
              const Divider(height: 28),
              _Row(
                '出勤天数',
                '${calculation.attendanceDays.toStringAsFixed(1)} 天',
              ),
              _Row('日薪', '${item.dailyWage.toStringAsFixed(2)} 元'),
              _Row('基础工资', '${calculation.baseWage.toStringAsFixed(2)} 元'),
              _Row('补助', '${item.subsidy.toStringAsFixed(2)} 元'),
              _Row('保险扣除', '${item.insuranceDeduction.toStringAsFixed(2)} 元'),
              _Row('最终工资', '${calculation.finalWage.toStringAsFixed(2)} 元'),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${calculation.attendanceDays.toStringAsFixed(1)} × ${item.dailyWage.toStringAsFixed(2)} + ${item.subsidy.toStringAsFixed(2)} - ${item.insuranceDeduction.toStringAsFixed(2)} = ${calculation.finalWage.toStringAsFixed(2)}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/attendance/monthly-table'),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('查看本月考勤'),
              ),
              if (item.remark?.trim().isNotEmpty == true)
                _Row('备注', item.remark!),
            ],
          ),
        );
      },
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
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
