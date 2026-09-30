import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/inventory_providers.dart';
import 'widgets/inventory_export_button.dart';
import 'widgets/inventory_widgets.dart';

class InventoryTransactionsPage extends ConsumerStatefulWidget {
  const InventoryTransactionsPage({super.key});

  @override
  ConsumerState<InventoryTransactionsPage> createState() =>
      _InventoryTransactionsPageState();
}

class _InventoryTransactionsPageState
    extends ConsumerState<InventoryTransactionsPage> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(inventoryTransactionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('库存流水'),
        actions: [
          const InventoryExportButton(),
          IconButton(
            tooltip: '当前库存',
            onPressed: () => context.push('/inventory/stock'),
            icon: const Icon(Icons.warehouse_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'all', label: Text('全部')),
                  ButtonSegment(value: 'receipt', label: Text('入库')),
                  ButtonSegment(value: 'issue', label: Text('出库')),
                  ButtonSegment(value: 'stocktake', label: Text('盘点')),
                  ButtonSegment(value: 'adjustment', label: Text('调整')),
                ],
                selected: {_filter},
                onSelectionChanged: (value) =>
                    setState(() => _filter = value.first),
              ),
            ),
          ),
          Expanded(
            child: transactions.when(
              loading: () => const InventoryLoadingState(),
              error: (_, _) => InventoryErrorState(
                onRetry: () => ref.invalidate(inventoryTransactionsProvider),
              ),
              data: (items) {
                final filtered = items.where((item) {
                  return switch (_filter) {
                    'receipt' =>
                      item.quantityChange > 0 && item.sourceType == 'receipt',
                    'issue' =>
                      item.quantityChange < 0 && item.sourceType == 'issue',
                    'stocktake' => item.sourceType.contains('stocktake'),
                    'adjustment' => item.transactionType == 'adjustment',
                    _ => true,
                  };
                }).toList();
                final now = DateTime.now();
                final currentMonth = items
                    .where(
                      (item) =>
                          item.occurredAt.year == now.year &&
                          item.occurredAt.month == now.month,
                    )
                    .toList();
                final inboundCount = currentMonth
                    .where((item) => item.quantityChange > 0)
                    .length;
                final outboundCount = currentMonth
                    .where((item) => item.quantityChange < 0)
                    .length;
                if (filtered.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InventoryMetricCard(
                              compact: true,
                              label: '本月变动',
                              value: '${currentMonth.length}',
                              icon: Icons.swap_vert_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InventoryMetricCard(
                              compact: true,
                              label: '入库',
                              value: '$inboundCount',
                              icon: Icons.north_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InventoryMetricCard(
                              compact: true,
                              label: '出库',
                              value: '$outboundCount',
                              icon: Icons.south_rounded,
                              color: AppColors.techBlue,
                            ),
                          ),
                        ],
                      ),
                      InventoryEmptyState(
                        title: items.isEmpty ? '还没有库存流水' : '该类型暂无流水',
                        message: items.isEmpty
                            ? '完成入库、出库、盘点或库存调整后会自动记录。'
                            : '选择其他类型查看。',
                      ),
                    ],
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(inventoryTransactionsProvider),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InventoryMetricCard(
                              compact: true,
                              label: '本月变动',
                              value: '${currentMonth.length}',
                              icon: Icons.swap_vert_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InventoryMetricCard(
                              compact: true,
                              label: '入库',
                              value: '$inboundCount',
                              icon: Icons.north_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InventoryMetricCard(
                              compact: true,
                              label: '出库',
                              value: '$outboundCount',
                              icon: Icons.south_rounded,
                              color: AppColors.techBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final item in filtered) ...[
                        _TransactionCard(transaction: item),
                        const SizedBox(height: 9),
                      ],
                      InventorySummaryPanel(
                        title: '流水汇总',
                        icon: Icons.bar_chart_rounded,
                        metrics: [
                          ('本月变动', '${currentMonth.length}'),
                          ('入库', '$inboundCount'),
                          ('出库', '$outboundCount'),
                        ],
                        actionLabel: '查看',
                        onAction: () => context.push('/inventory/stock'),
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

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});
  final InventoryTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final value = transaction.quantityChange;
    final positive = value >= 0;
    final color = positive ? AppColors.primary : AppColors.danger;
    final label = switch (transaction.transactionType) {
      'receipt' => '入库',
      'issue' => '出库',
      'stocktake_gain' => '盘盈',
      'stocktake_loss' => '盘亏',
      'adjustment' => '调整',
      'return_in' => '退回',
      'transfer_in' => '调入',
      'transfer_out' => '调出',
      _ => transaction.transactionType,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    positive
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.materialNameSnapshot,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${transaction.modelSnapshot ?? '未填型号'} · ${transaction.unitSnapshot}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                InventoryStatusChip(label: label, color: color),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '库存 ${transaction.stockBefore} → ${transaction.stockAfter}',
                  ),
                ),
                Text(
                  '${positive ? '+' : ''}$value',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: color, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              '${_dateLabel(transaction.occurredAt)} · ${transaction.operatorNameSnapshot ?? '未填写经办人'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if ((transaction.remark ?? '').isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(transaction.remark!),
            ],
          ],
        ),
      ),
    );
  }
}

String _dateLabel(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
