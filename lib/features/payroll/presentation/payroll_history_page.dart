import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_enums.dart';
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
              for (var index = 0; index < values.length; index++) ...[
                if (index == 0 ||
                    values[index].payrollMonth !=
                        values[index - 1].payrollMonth)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
                    child: Text(
                      values[index].payrollMonth,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push(
                      '/reports/payroll/edit/${values[index].id}',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.lightGreen,
                            child: Icon(
                              Icons.account_balance_wallet_outlined,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  values[index].name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${values[index].employeeCount}人 · 出勤 ${(values[index].attendanceHalfDaysTotal / 2).toStringAsFixed(1)}天',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  PayrollOptions.statusLabel(
                                    values[index].status,
                                  ),
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color:
                                            values[index].status ==
                                                PayrollStatus.locked
                                            ? AppColors.purple
                                            : values[index].status ==
                                                  PayrollStatus.confirmed
                                            ? AppColors.success
                                            : AppColors.warning,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${values[index].finalWageTotal.toStringAsFixed(2)}元',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              const Icon(
                                Icons.chevron_right,
                                color: AppColors.body,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
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
