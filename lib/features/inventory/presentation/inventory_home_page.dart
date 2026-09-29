import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_models.dart';
import 'widgets/inventory_export_button.dart';
import 'widgets/inventory_widgets.dart';

class InventoryHomePage extends ConsumerWidget {
  const InventoryHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(inventoryOverviewProvider);
    final warnings = ref.watch(inventoryWarningsProvider);
    final transactions = ref.watch(inventoryTransactionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('库存管理'),
        actions: [const InventoryExportButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(inventoryOverviewProvider);
          ref.invalidate(inventoryWarningsProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            overview.when(
              loading: () => const InventoryLoadingState(),
              error: (_, _) => InventoryErrorState(
                onRetry: () => ref.invalidate(inventoryOverviewProvider),
              ),
              data: (data) => Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InventoryMetricCard(
                          label: '当前物资',
                          value: '${data.totalMaterialCount} 种',
                          icon: Icons.widgets_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InventoryMetricCard(
                          label: '库存预警',
                          value: '${data.lowStockCount}',
                          color: const Color(0xFFE98500),
                          icon: Icons.warning_amber_rounded,
                          onTap: () => context.push('/inventory/warnings'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InventoryMetricCard(
                          label: '缺货',
                          value: '${data.outOfStockCount}',
                          color: AppColors.danger,
                          icon: Icons.remove_shopping_cart_outlined,
                          onTap: () => context.push('/inventory/warnings'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InventoryMetricCard(
                          label: '待补充',
                          value: '${data.pendingReplenishmentCount}',
                          color: AppColors.techBlue,
                          icon: Icons.shopping_cart_outlined,
                          onTap: () => context.push('/inventory/replenishment'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InventoryMetricCard(
                          label: '本月入库',
                          value: '${data.monthlyReceiptCount} 次',
                          icon: Icons.south_west_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InventoryMetricCard(
                          label: '本月出库',
                          value: '${data.monthlyIssueCount} 次',
                          icon: Icons.north_east_rounded,
                          color: AppColors.techBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            InventorySection(
              title: '快捷入口',
              icon: Icons.grid_view_rounded,
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.25,
                children: const [
                  _InventoryShortcut(
                    title: '物资信息',
                    subtitle: '维护物资档案',
                    icon: Icons.inventory_2_outlined,
                    route: '/inventory/materials',
                  ),
                  _InventoryShortcut(
                    title: '入库管理',
                    subtitle: '登记物资入库',
                    icon: Icons.move_to_inbox_outlined,
                    route: '/inventory/receipts',
                  ),
                  _InventoryShortcut(
                    title: '领用出库',
                    subtitle: '登记员工领用',
                    icon: Icons.outbox_outlined,
                    route: '/inventory/issues',
                  ),
                  _InventoryShortcut(
                    title: '当前库存',
                    subtitle: '查询和调整库存',
                    icon: Icons.warehouse_outlined,
                    route: '/inventory/stock',
                  ),
                  _InventoryShortcut(
                    title: '库存盘点',
                    subtitle: '登记实盘数量',
                    icon: Icons.fact_check_outlined,
                    route: '/inventory/stocktake',
                  ),
                  _InventoryShortcut(
                    title: '预警与待补充',
                    subtitle: '查看低库存物资',
                    icon: Icons.notifications_active_outlined,
                    route: '/inventory/warnings',
                  ),
                  _InventoryShortcut(
                    title: '待补充清单',
                    subtitle: '跟进采购和领取',
                    icon: Icons.shopping_cart_outlined,
                    route: '/inventory/replenishment',
                  ),
                  _InventoryShortcut(
                    title: '库存流水',
                    subtitle: '追溯库存变化',
                    icon: Icons.receipt_long_outlined,
                    route: '/inventory/transactions',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            InventorySection(
              title: '库存预警',
              icon: Icons.notifications_active_outlined,
              trailing: TextButton(
                onPressed: () => context.push('/inventory/warnings'),
                child: const Text('查看全部'),
              ),
              child: warnings.when(
                loading: () => const InventoryLoadingState(),
                error: (_, _) => InventoryErrorState(
                  onRetry: () => ref.invalidate(inventoryWarningsProvider),
                ),
                data: (rows) => rows.isEmpty
                    ? const InventoryEmptyState(
                        title: '库存充足',
                        message: '目前没有需要处理的低库存物资。',
                      )
                    : Column(
                        children: [
                          for (final row in rows.take(4))
                            _WarningListTile(row: row),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 18),
            InventorySection(
              title: '最近记录',
              icon: Icons.history_rounded,
              trailing: TextButton(
                onPressed: () => context.push('/inventory/transactions'),
                child: const Text('全部流水'),
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
                          for (final item in rows.take(3))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.materialNameSnapshot),
                              subtitle: Text(
                                '${_transactionLabel(item.transactionType)} · ${_dateLabel(item.occurredAt)}',
                              ),
                              trailing: Text(
                                '${item.quantityChange > 0 ? '+' : ''}${item.quantityChange} ${item.unitSnapshot}',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: item.quantityChange >= 0
                                          ? AppColors.primary
                                          : AppColors.danger,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              onTap: () =>
                                  context.push('/inventory/transactions'),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _transactionLabel(String value) => switch (value) {
  'receipt' => '入库',
  'issue' => '出库',
  'stocktake_gain' => '盘盈',
  'stocktake_loss' => '盘亏',
  'adjustment' => '库存调整',
  _ => value,
};

String _dateLabel(DateTime value) => '${value.month}月${value.day}日';

class _InventoryShortcut extends StatelessWidget {
  const _InventoryShortcut({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF4FAF7),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      key: Key('inventory-shortcut-$title'),
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WarningListTile extends StatelessWidget {
  const _WarningListTile({required this.row});

  final InventoryStockRow row;

  @override
  Widget build(BuildContext context) {
    final material = row.material;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(material.materialName),
      subtitle: Text(
        '${material.modelSpec ?? '未填型号'} · 当前 ${material.currentStock} ${material.unitName} · 最低 ${material.minStock}',
      ),
      trailing: InventoryStatusChip(
        label: row.status == InventoryStockStatus.outOfStock ? '缺货' : '库存不足',
        color: row.status == InventoryStockStatus.outOfStock
            ? AppColors.danger
            : const Color(0xFFE98500),
      ),
      onTap: () => context.push('/inventory/materials/${material.id}'),
    );
  }
}
