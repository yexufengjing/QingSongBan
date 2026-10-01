import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/inventory_providers.dart';
import 'widgets/inventory_export_button.dart';
import 'widgets/inventory_widgets.dart';

class InventoryReceiptsPage extends ConsumerStatefulWidget {
  const InventoryReceiptsPage({super.key});

  @override
  ConsumerState<InventoryReceiptsPage> createState() =>
      _InventoryReceiptsPageState();
}

class _InventoryReceiptsPageState extends ConsumerState<InventoryReceiptsPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _type = 'all';

  @override
  Widget build(BuildContext context) {
    final receipts = ref.watch(inventoryReceiptsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('${_month.month}月入库管理'),
        actions: [
          IconButton(
            key: const Key('inventory-receipt-add'),
            tooltip: '新增入库',
            onPressed: () => context.push('/inventory/receipts/new'),
            icon: const Icon(Icons.add_circle_outline),
          ),
          PopupMenuButton<String>(
            tooltip: '入库来源',
            icon: const Icon(Icons.upload_outlined),
            onSelected: (value) => setState(() => _type = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'all', child: Text('全部来源')),
              PopupMenuItem(value: 'central_store', child: Text('总库领取')),
              PopupMenuItem(value: 'purchase', child: Text('外部采购')),
              PopupMenuItem(value: 'return_in', child: Text('退回入库')),
              PopupMenuItem(value: 'transfer_in', child: Text('调拨入库')),
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
                    _type == 'all' ? '全部来源' : _receiptType(_type),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: receipts.when(
              loading: () => const InventoryLoadingState(),
              error: (_, _) => InventoryErrorState(
                onRetry: () => ref.invalidate(inventoryReceiptsProvider),
              ),
              data: (allReceipts) {
                final filtered = allReceipts.where((receipt) {
                  final sameMonth =
                      receipt.receiptDate.year == _month.year &&
                      receipt.receiptDate.month == _month.month;
                  return sameMonth &&
                      (_type == 'all' || receipt.receiptType == _type);
                }).toList();
                final sourceCount = filtered
                    .map(
                      (item) =>
                          item.sourceName ?? _receiptType(item.receiptType),
                    )
                    .toSet()
                    .length;
                final itemResults = filtered
                    .map(
                      (receipt) =>
                          ref.watch(inventoryReceiptItemsProvider(receipt.id)),
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
                              key: const Key('inventory-receipt-quantity'),
                              compact: true,
                              label: '本月入库',
                              value: '0',
                              valueMaxLines: 3,
                              icon: Icons.inventory_2_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InventoryMetricCard(
                              compact: true,
                              key: const Key('inventory-receipt-group-count'),
                              label: '记录组数',
                              value: '0',
                              icon: Icons.upload_outlined,
                              color: AppColors.techBlue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InventoryMetricCard(
                              compact: true,
                              key: const Key('inventory-receipt-detail-count'),
                              label: '条目条数',
                              value: '0',
                              icon: Icons.list_alt_rounded,
                              color: const Color(0xFFE98500),
                            ),
                          ),
                        ],
                      ),
                      InventoryEmptyState(
                        title: allReceipts.isEmpty ? '暂无入库记录' : '本月暂无入库记录',
                        message: allReceipts.isEmpty
                            ? '从总库领取或采购后，登记第一笔入库。'
                            : '调整月份或来源筛选后再试。',
                        action: FilledButton.icon(
                          onPressed: () =>
                              context.push('/inventory/receipts/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('新增入库'),
                        ),
                      ),
                    ],
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(inventoryReceiptsProvider),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InventoryMetricCard(
                              key: const Key('inventory-receipt-quantity'),
                              compact: true,
                              label: '本月入库',
                              value: quantityByUnit,
                              valueMaxLines: 3,
                              icon: Icons.inventory_2_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InventoryMetricCard(
                              key: const Key('inventory-receipt-group-count'),
                              compact: true,
                              label: '记录组数',
                              value: '${filtered.length}',
                              icon: Icons.upload_outlined,
                              color: AppColors.techBlue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InventoryMetricCard(
                              compact: true,
                              key: const Key('inventory-receipt-detail-count'),
                              label: '条目条数',
                              value: detailCount,
                              icon: Icons.list_alt_rounded,
                              color: const Color(0xFFE98500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final receipt in filtered) ...[
                        _ReceiptCard(receipt: receipt),
                        const SizedBox(height: 10),
                      ],
                      InventorySummaryPanel(
                        title: '本月入库汇总',
                        icon: Icons.bar_chart_rounded,
                        metrics: [
                          ('记录组数', '${filtered.length}'),
                          ('条目条数', detailCount),
                          ('来源数', '$sourceCount'),
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
  List<AsyncValue<List<InventoryReceiptItem>>> itemResults,
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

class _ReceiptCard extends ConsumerWidget {
  const _ReceiptCard({required this.receipt});
  final InventoryReceipt receipt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(inventoryReceiptItemsProvider(receipt.id));
    return Card(
      child: InkWell(
        key: Key('inventory-receipt-${receipt.id}'),
        onTap: () => context.push('/inventory/receipts/${receipt.id}'),
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
                    _dateLabel(receipt.receiptDate),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.warehouse_outlined,
                    color: AppColors.primary,
                    size: 19,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      receipt.sourceName ?? _receiptType(receipt.receiptType),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    receipt.operatorNameSnapshot ?? '未填写',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                    tooltip: '更多操作',
                    onSelected: (value) {
                      if (value == 'detail') {
                        context.push('/inventory/receipts/${receipt.id}');
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
                    '单号：${receipt.receiptNo}',
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
                    Expanded(flex: 2, child: Text('规格')),
                    Expanded(flex: 1, child: Text('单位')),
                    Expanded(
                      flex: 2,
                      child: Text('数量', textAlign: TextAlign.center),
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
                                item.remark ?? '—',
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

String _receiptType(String value) => switch (value) {
  'central_store' => '总库领取入库',
  'purchase' => '采购入库',
  'return_in' => '退回入库',
  'transfer_in' => '调拨入库',
  'stocktake_gain' => '盘盈入库',
  _ => '其他入库',
};

String _dateLabel(DateTime value) => '${value.month}月${value.day}日';
String _quantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
