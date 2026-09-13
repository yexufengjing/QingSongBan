import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/payroll_providers.dart';
import '../domain/payroll_options.dart';

class PayrollHistoryPage extends ConsumerWidget {
  const PayrollHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(payrollBatchesProvider);
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('工资历史'),
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: batches.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('工资历史加载失败：$error')),
          data: (values) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final batch in values)
                Card(
                  child: ListTile(
                    title: Text(batch.name),
                    subtitle: Text(
                      '${PayrollOptions.statusLabel(batch.status)} · ${batch.employeeCount}人 · 出勤 ${(batch.attendanceHalfDaysTotal / 2).toStringAsFixed(1)}天',
                    ),
                    trailing: Text(
                      '${batch.finalWageTotal.toStringAsFixed(2)}元',
                    ),
                    onTap: () =>
                        context.push('/reports/payroll/edit/${batch.id}'),
                  ),
                ),
              if (values.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('尚无工资历史')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
