import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/inventory_providers.dart';
import 'widgets/inventory_export_button.dart';
import 'widgets/inventory_widgets.dart';

class InventoryIssuesPage extends ConsumerStatefulWidget {
  const InventoryIssuesPage({super.key});

  @override
  ConsumerState<InventoryIssuesPage> createState() =>
      _InventoryIssuesPageState();
}

class _InventoryIssuesPageState extends ConsumerState<InventoryIssuesPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _type = 'all';

  @override
  Widget build(BuildContext context) {
    final issues = ref.watch(inventoryIssuesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('${_month.month}月领用出库'),
        actions: [
          IconButton(
            key: const Key('inventory-issue-add'),
            tooltip: '新增出库',
            onPressed: () => context.push('/inventory/issues/new'),
            icon: const Icon(Icons.add_circle_outline),
          ),
          PopupMenuButton<String>(
            tooltip: '人员与类型筛选',
            icon: const Icon(Icons.people_outline),
            onSelected: (value) => setState(() => _type = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'all', child: Text('全部类型')),
              PopupMenuItem(value: 'employee_claim', child: Text('员工领用')),
              PopupMenuItem(value: 'department_use', child: Text('部门领用')),
              PopupMenuItem(value: 'other', child: Text('其他出库')),
              PopupMenuItem(value: 'transfer_out', child: Text('调拨出库')),
            ],
          ),
          const InventoryExportButton(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                InventoryMonthPicker(
                  month: _month,
                  onChanged: (value) => setState(() => _month = value),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _type == 'all' ? '全部类型' : _issueType(_type),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: issues.when(
              loading: () => const InventoryLoadingState(),
              error: (_, _) => InventoryErrorState(
                onRetry: () => ref.invalidate(inventoryIssuesProvider),
              ),
              data: (allIssues) {
                final filtered = allIssues.where((issue) {
                  final sameMonth =
                      issue.issueDate.year == _month.year &&
                      issue.issueDate.month == _month.month;
                  return sameMonth &&
                      (_type == 'all' || issue.issueType == _type);
                }).toList();
                final receiverCount = filtered.where(_hasReceiver).length;
                final itemResults = filtered
                    .map(
                      (issue) =>
                          ref.watch(inventoryIssueItemsProvider(issue.id)),
                    )
                    .toList(growable: false);
                final detailCount = _detailCountLabel(itemResults);
                final quantityByUnit = _quantityByUnitLabel(itemResults);
                if (filtered.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InventoryMetricCard(
                              key: const Key('inventory-issue-quantity'),
                              compact: true,
                              label: '本月出库',
                              value: '0',
                              valueMaxLines: 3,
                              icon: Icons.inventory_2_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InventoryMetricCard(
                              key: const Key('inventory-issue-receiver-count'),
                              compact: true,
                              label: '领取人次',
                              value: '0',
                              icon: Icons.person_outline,
                              color: AppColors.techBlue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InventoryMetricCard(
                              key: const Key('inventory-issue-detail-count'),
                              compact: true,
                              label: '条目条数',
                              value: '0',
                              icon: Icons.list_alt_rounded,
                              color: const Color(0xFFE98500),
                            ),
                          ),
                        ],
                      ),
                      InventoryEmptyState(
                        title: allIssues.isEmpty ? '暂无出库记录' : '本月暂无出库记录',
                        message: allIssues.isEmpty
                            ? '员工领取或其他领用完成后会在此显示。'
                            : '调整月份或类型筛选后再试。',
                        action: FilledButton.icon(
                          onPressed: () =>
                              context.push('/inventory/issues/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('登记领用'),
                        ),
                      ),
                    ],
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(inventoryIssuesProvider),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InventoryMetricCard(
                              key: const Key('inventory-issue-quantity'),
                              compact: true,
                              label: '本月出库',
                              value: quantityByUnit,
                              valueMaxLines: 3,
                              icon: Icons.inventory_2_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InventoryMetricCard(
                              key: const Key('inventory-issue-receiver-count'),
                              compact: true,
                              label: '领取人次',
                              value: '$receiverCount',
                              icon: Icons.person_outline,
                              color: AppColors.techBlue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InventoryMetricCard(
                              key: const Key('inventory-issue-detail-count'),
                              compact: true,
                              label: '条目条数',
                              value: detailCount,
                              icon: Icons.list_alt_rounded,
                              color: const Color(0xFFE98500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final issue in filtered) ...[
                        _IssueCard(issue: issue),
                        const SizedBox(height: 10),
                      ],
                      InventorySummaryPanel(
                        title: '本月领用汇总',
                        icon: Icons.bar_chart_rounded,
                        metrics: [
                          ('记录组数', '${filtered.length}'),
                          ('条目条数', detailCount),
                          ('领取人次', '$receiverCount'),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _detailCountLabel<T>(List<AsyncValue<List<T>>> itemResults) {
  if (itemResults.any((result) => result.hasError)) return '—';
  if (itemResults.any((result) => !result.hasValue)) return '…';
  return '${itemResults.fold<int>(0, (total, result) => total + result.requireValue.length)}';
}

String _quantityByUnitLabel(
  List<AsyncValue<List<InventoryIssueItem>>> itemResults,
) {
  if (itemResults.any((result) => result.hasError)) return '—';
  if (itemResults.any((result) => !result.hasValue)) return '…';
  final totals = <String, double>{};
  for (final result in itemResults) {
    for (final item in result.requireValue) {
      totals.update(
        item.unitSnapshot,
        (quantity) => quantity + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }
  }
  if (totals.isEmpty) return '0';
  return totals.entries
      .map((entry) => '${_formatQuantity(entry.value)}${entry.key}')
      .join('\n');
}

String _formatQuantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

bool _hasReceiver(InventoryIssue issue) => switch (issue.receiverType) {
  'employee' => (issue.employeeNameSnapshot ?? '').trim().isNotEmpty,
  'manual' => (issue.manualReceiverName ?? '').trim().isNotEmpty,
  'department' => (issue.departmentNameSnapshot ?? '').trim().isNotEmpty,
  'public' => true,
  _ => false,
};

class _IssueCard extends ConsumerWidget {
  const _IssueCard({required this.issue});
  final InventoryIssue issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(inventoryIssueItemsProvider(issue.id));
    return Card(
      child: InkWell(
        key: Key('inventory-issue-${issue.id}'),
        onTap: () => context.push('/inventory/issues/${issue.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.event_available_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _dateLabel(issue.issueDate),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.person_outline,
                    color: AppColors.primary,
                    size: 19,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _receiverName(issue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _issueType(issue.issueType),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                    tooltip: '更多操作',
                    onSelected: (value) {
                      if (value == 'detail') {
                        context.push('/inventory/issues/${issue.id}');
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'detail', child: Text('查看详情')),
                    ],
                    icon: const Icon(Icons.more_horiz, color: AppColors.helper),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Text(
                    '单号：${issue.issueNo}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F5F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 4, child: Text('物品名称')),
                    Expanded(flex: 2, child: Text('型号')),
                    Expanded(flex: 1, child: Text('单位')),
                    Expanded(
                      flex: 2,
                      child: Text('领取数量', textAlign: TextAlign.center),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('备注', textAlign: TextAlign.right),
                    ),
                  ],
                ),
              ),
              lines.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                ),
                error: (_, _) => const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('物资明细暂时无法读取'),
                ),
                data: (items) => Column(
                  children: [
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                item.materialNameSnapshot,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                item.modelSnapshot ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                item.unitSnapshot,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _quantity(item.quantity),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.remark ?? issue.purpose ?? '—',
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              lines.maybeWhen(
                data: (items) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FAF6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '共 ${items.length} 条明细',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: AppColors.primary),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _receiverName(InventoryIssue issue) =>
    issue.employeeNameSnapshot ??
    issue.manualReceiverName ??
    issue.departmentNameSnapshot ??
    '公用';
String _issueType(String value) => switch (value) {
  'employee_claim' => '员工领用',
  'department_use' => '部门领用',
  'transfer_out' => '调拨出库',
  'stocktake_loss' => '盘亏出库',
  _ => '其他出库',
};
String _dateLabel(DateTime value) => '${value.month}月${value.day}日';
String _quantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
