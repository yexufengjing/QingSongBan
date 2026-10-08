import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/design_widgets.dart';
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
    final warnings = ref.watch(inventoryWarningsProvider);
    final transactions = ref.watch(inventoryTransactionsProvider);
    final receipts = ref.watch(inventoryReceiptsProvider);
    final issues = ref.watch(inventoryIssuesProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(12) > 14
            ? 64
            : 56,
        title: const Text('库存管理'),
        actions: [
          _HeaderAction(
            icon: Icons.add,
            label: '新增',
            onPressed: () => context.push('/inventory/materials/new'),
          ),
          _HeaderAction(
            icon: Icons.fact_check_outlined,
            label: '盘点',
            onPressed: () => context.push('/inventory/stocktake'),
          ),
          const InventoryExportButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(inventoryOverviewProvider);
          ref.invalidate(inventoryWarningsProvider);
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
                  backgroundColor: AppColors.lightBlue,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DesignSection(
              title: '库存预警',
              trailing: TextButton(
                onPressed: () => context.push('/inventory/warnings'),
                child: const Text('查看预警'),
              ),
              child: warnings.when(
                loading: () => const InventoryLoadingState(),
                error: (_, _) => InventoryErrorState(
                  onRetry: () => ref.invalidate(inventoryWarningsProvider),
                ),
                data: (rows) => rows.isEmpty
                    ? const Text(
                        '当前没有需要补充的物资',
                        style: TextStyle(color: AppColors.body),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${rows.length} 项需要补充',
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final row in rows.take(3))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const DesignIcon(
                                Icons.inventory_2_outlined,
                              ),
                              title: Text(row.material.materialName),
                              subtitle: Text(
                                '当前 ${row.material.currentStock} ${row.material.unitName} · 最低 ${row.material.minStock} ${row.material.unitName}',
                              ),
                              onTap: () => context.push(
                                '/inventory/materials/${row.material.id}',
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            const DesignSection(
              child: DesignGrid(
                columns: 3,
                children: [
                  _TaskAction(
                    '新增入库',
                    Icons.note_add_outlined,
                    '/inventory/receipts/new',
                    AppColors.techBlue,
                  ),
                  _TaskAction(
                    '登记领用',
                    Icons.outbox_outlined,
                    '/inventory/issues/new',
                    AppColors.success,
                  ),
                  _TaskAction(
                    '盘点',
                    Icons.assignment_outlined,
                    '/inventory/stocktake',
                    AppColors.warning,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DesignSection(
              title: '库存概览',
              child: overview.when(
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
                        key: const Key('inventory-home-warning-count'),
                        compact: true,
                        label: '库存预警',
                        value: warnings.when(
                          data: (rows) => '${rows.length}',
                          loading: () => '加载中',
                          error: (_, _) => '加载失败',
                        ),
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
            ),
            const SizedBox(height: 14),
            InventorySection(
              title: '快捷入口',
              icon: Icons.grid_view_rounded,
              child: DesignGrid(
                children: [
                  InventoryQuickAction(
                    title: '物资信息',
                    subtitle: '查看物资档案',
                    icon: Icons.inventory_2_outlined,
                    onTap: () => context.push('/inventory/materials'),
                  ),
                  InventoryQuickAction(
                    title: '入库管理',
                    subtitle: '物资入库登记',
                    icon: Icons.move_to_inbox_outlined,
                    color: AppColors.success,
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
                    color: AppColors.purple,
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
                  icon: Icons.fact_check_outlined,
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
    style: TextButton.styleFrom(minimumSize: const Size(48, 64)),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
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

class _TaskAction extends StatelessWidget {
  const _TaskAction(this.title, this.icon, this.route, this.color);
  final String title, route;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: .06),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.ink, fontSize: 16),
            ),
          ],
        ),
      ),
    ),
  );
}
