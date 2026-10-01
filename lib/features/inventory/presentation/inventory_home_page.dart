import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/inventory_providers.dart';
import 'widgets/inventory_export_button.dart';
import 'widgets/inventory_widgets.dart';

class InventoryHomePage extends ConsumerStatefulWidget {
  const InventoryHomePage({super.key});

  @override
  ConsumerState<InventoryHomePage> createState() => _InventoryHomePageState();
}

class _InventoryHomePageState extends ConsumerState<InventoryHomePage> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _selectMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: '选择统计月份',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (selected != null && mounted) {
      setState(() => _selectedMonth = DateTime(selected.year, selected.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final overview = ref.watch(inventoryOverviewProvider);
    final transactions = ref.watch(inventoryTransactionsProvider);
    final receipts = ref.watch(inventoryReceiptsProvider);
    final issues = ref.watch(inventoryIssuesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('库存管理'),
        actions: [
          _HeaderAction(
            icon: Icons.add_circle,
            label: '新增',
            onPressed: () => context.push('/inventory/materials/new'),
          ),
          _HeaderAction(
            icon: Icons.bar_chart_rounded,
            label: '盘点',
            onPressed: () => context.push('/inventory/stocktake'),
          ),
          const InventoryExportButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(inventoryOverviewProvider);
          ref.invalidate(inventoryTransactionsProvider);
          ref.invalidate(inventoryReceiptsProvider);
          ref.invalidate(inventoryIssuesProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _selectMonth,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text('${_selectedMonth.year}年${_selectedMonth.month}月'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.lightGreen,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            overview.when(
              loading: () => const InventoryLoadingState(),
              error: (_, _) => InventoryErrorState(
                onRetry: () => ref.invalidate(inventoryOverviewProvider),
              ),
              data: (data) => Row(
                children: [
                  Expanded(
                    child: InventoryMetricCard(
                      compact: true,
                      label: '当前物资',
                      value: '${data.totalMaterialCount}种',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InventoryMetricCard(
                      compact: true,
                      label: '库存预警',
                      value: '${data.lowStockCount}',
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFE98500),
                      onTap: () => context.push('/inventory/warnings'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InventoryMetricCard(
                      compact: true,
                      label: '待补充',
                      value: '${data.pendingReplenishmentCount}',
                      icon: Icons.shopping_cart_outlined,
                      color: AppColors.techBlue,
                      onTap: () => context.push('/inventory/replenishment'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            InventorySection(
              title: '快捷入口',
              icon: Icons.grid_view_rounded,
              child: GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.72,
                children: [
                  InventoryQuickAction(
                    title: '物资信息',
                    subtitle: '查看物资档案',
                    icon: Icons.article_outlined,
                    onTap: () => context.push('/inventory/materials'),
                  ),
                  InventoryQuickAction(
                    title: '入库管理',
                    subtitle: '物资入库登记',
                    icon: Icons.move_to_inbox_outlined,
                    onTap: () => context.push('/inventory/receipts'),
                  ),
                  InventoryQuickAction(
                    title: '领用出库',
                    subtitle: '物资领用发放',
                    icon: Icons.exit_to_app_rounded,
                    color: const Color(0xFFE98500),
                    onTap: () => context.push('/inventory/issues'),
                  ),
                  InventoryQuickAction(
                    title: '当前库存',
                    subtitle: '实时库存查询',
                    icon: Icons.warehouse_outlined,
                    onTap: () => context.push('/inventory/stock'),
                  ),
                  InventoryQuickAction(
                    title: '库存盘点',
                    subtitle: '盘点任务管理',
                    icon: Icons.fact_check_outlined,
                    onTap: () => context.push('/inventory/stocktake'),
                  ),
                  InventoryQuickAction(
                    title: '库存预警',
                    subtitle: '预警物资查看',
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFE98500),
                    onTap: () => context.push('/inventory/warnings'),
                  ),
                  InventoryQuickAction(
                    title: '待采购',
                    subtitle: '采购需求管理',
                    icon: Icons.shopping_cart_outlined,
                    color: AppColors.techBlue,
                    onTap: () => context.push('/inventory/replenishment'),
                  ),
                  InventoryQuickAction(
                    title: '库存流水',
                    subtitle: '出入库记录',
                    icon: Icons.receipt_long_outlined,
                    onTap: () => context.push('/inventory/transactions'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            InventorySection(
              title: '最近记录',
              icon: Icons.schedule_rounded,
              trailing: TextButton.icon(
                onPressed: () => context.push('/inventory/transactions'),
                icon: const Icon(Icons.chevron_right),
                label: const Text('全部记录'),
              ),
              child: transactions.when(
                loading: () => const InventoryLoadingState(),
                error: (_, _) => InventoryErrorState(
                  onRetry: () => ref.invalidate(inventoryTransactionsProvider),
                ),
                data: (rows) => rows.isEmpty
                    ? const InventoryEmptyState(
                        title: '暂无库存流水',
                        message: '入库、出库、盘点或调整后会在这里显示。',
                      )
                    : Column(
                        children: [
                          for (final transaction
                              in rows
                                  .where(
                                    (item) => _inSelectedMonth(item.occurredAt),
                                  )
                                  .take(3))
                            _RecentTransactionCard(transaction: transaction),
                          if (!rows.any(
                            (item) => _inSelectedMonth(item.occurredAt),
                          ))
                            const InventoryEmptyState(
                              title: '本月暂无记录',
                              message: '选择其他月份查看库存变化。',
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),
            receipts.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (receiptRows) => issues.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (issueRows) => InventorySummaryPanel(
                  title: '本月出入库摘要',
                  icon: Icons.bar_chart_rounded,
                  metrics: [
                    (
                      '入库',
                      '${receiptRows.where((item) => _inSelectedMonth(item.receiptDate)).length} 次',
                    ),
                    (
                      '出库',
                      '${issueRows.where((item) => _inSelectedMonth(item.issueDate)).length} 次',
                    ),
                  ],
                  actionLabel: '总览',
                  onAction: () => context.push('/inventory/transactions'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _inSelectedMonth(DateTime date) =>
      date.year == _selectedMonth.year && date.month == _selectedMonth.month;
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 23),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}

class _RecentTransactionCard extends StatelessWidget {
  const _RecentTransactionCard({required this.transaction});
  final InventoryTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final inbound = transaction.quantityChange >= 0;
    final color = inbound ? AppColors.primary : AppColors.techBlue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAF2EF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.event_available_outlined, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                _dateLabel(transaction.occurredAt),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.primary,
                size: 19,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  transaction.materialNameSnapshot,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _transactionLabel(transaction.transactionType),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${transaction.modelSnapshot ?? '未填写规格'} · ${transaction.unitSnapshot}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${inbound ? '+' : ''}${transaction.quantityChange} ${transaction.unitSnapshot}',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _transactionLabel(String value) => switch (value) {
  'receipt' || 'return_in' || 'transfer_in' => '入库',
  'issue' || 'transfer_out' => '出库',
  'stocktake_gain' => '盘盈',
  'stocktake_loss' => '盘亏',
  'adjustment' => '调整',
  _ => value,
};

String _dateLabel(DateTime value) => '${value.month}月${value.day}日';
