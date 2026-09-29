import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_models.dart';
import 'inventory_widgets.dart';

class InventoryEmployeeHistorySection extends ConsumerWidget {
  const InventoryEmployeeHistorySection({required this.employeeId, super.key});

  final int employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(employeeMaterialHistoryProvider(employeeId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '物资领取记录',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            history.when(
              loading: () => const InventoryLoadingState(),
              error: (_, _) => InventoryErrorState(
                onRetry: () =>
                    ref.invalidate(employeeMaterialHistoryProvider(employeeId)),
              ),
              data: (rows) => rows.isEmpty
                  ? const InventoryEmptyState(
                      title: '暂无物资领取记录',
                      message: '该人员的库存领用记录会显示在这里。',
                    )
                  : SingleChildScrollView(
                      key: const Key(
                        'inventory-employee-history-horizontal-scroll',
                      ),
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 22,
                        dataRowMinHeight: 48,
                        dataRowMaxHeight: 64,
                        columns: const [
                          DataColumn(label: Text('日期')),
                          DataColumn(label: Text('物品名称')),
                          DataColumn(label: Text('型号')),
                          DataColumn(label: Text('领取数量'), numeric: true),
                          DataColumn(label: Text('领取人')),
                          DataColumn(label: Text('备注')),
                        ],
                        rows: [for (final row in rows) _historyRow(row)],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _historyRow(InventoryEmployeeHistoryItem row) {
    final issue = row.issue;
    final item = row.item;
    final receiver =
        issue.employeeNameSnapshot ??
        issue.manualReceiverName ??
        issue.departmentNameSnapshot ??
        '公用';
    return DataRow(
      cells: [
        DataCell(Text(_dateLabel(issue.issueDate))),
        DataCell(Text(item.materialNameSnapshot)),
        DataCell(Text(item.modelSnapshot ?? '未填写')),
        DataCell(Text('${item.quantity} ${item.unitSnapshot}')),
        DataCell(Text(receiver)),
        DataCell(Text(item.remark ?? issue.remark ?? '')),
      ],
    );
  }
}

String _dateLabel(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
