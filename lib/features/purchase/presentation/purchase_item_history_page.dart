import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/purchase_providers.dart';
import '../domain/purchase_models.dart';
import '../purchase_routes.dart';
import 'purchase_item_prefill.dart';
import 'widgets/purchase_widgets.dart';

class PurchaseItemHistoryPage extends ConsumerStatefulWidget {
  const PurchaseItemHistoryPage({required this.inventoryMaterialId, super.key});
  final int inventoryMaterialId;

  @override
  ConsumerState<PurchaseItemHistoryPage> createState() =>
      _PurchaseItemHistoryPageState();
}

class _PurchaseItemHistoryPageState
    extends ConsumerState<PurchaseItemHistoryPage> {
  String _period = '全部';

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(
      purchaseItemHistoryProvider(widget.inventoryMaterialId),
    );
    return PurchasePageTheme(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('物资采购历史'),
          actions: [
            IconButton(
              tooltip: '查看库存详情',
              onPressed: () => context.push(
                '/inventory/materials/${widget.inventoryMaterialId}',
              ),
              icon: const Icon(Icons.more_horiz),
            ),
          ],
        ),
        body: historyAsync.when(
          loading: () => const PurchaseLoadingState(),
          error: (error, stack) => PurchaseErrorState(
            onRetry: () => ref.invalidate(
              purchaseItemHistoryProvider(widget.inventoryMaterialId),
            ),
          ),
          data: (history) => history == null
              ? const PurchaseEmptyState(
                  title: '暂无物资历史',
                  message: '该库存物资尚无采购历史。',
                )
              : _buildHistory(context, history),
        ),
        bottomNavigationBar: historyAsync.valueOrNull == null
            ? null
            : SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(
                          '/inventory/materials/${widget.inventoryMaterialId}',
                        ),
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('查看库存详情'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('purchase-repeat-request'),
                        onPressed: () => context.push(
                          PurchaseRoutes.create,
                          extra: PurchaseItemPrefill.fromItemHistory(
                            historyAsync.valueOrNull!,
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('再次申报采购'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHistory(BuildContext context, PurchaseItemHistory item) {
    final rows = _filteredRows(item.rows);
    final cycles = item.recentCycleDays.take(3).toList();
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        PurchasePanel(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PurchaseMaterialIcon(size: 88),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.itemName,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '规格型号：${item.specification ?? '未填写'} · 单位：${item.unit}',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '当前库存：${item.currentStock == null ? '—' : purchaseQuantityLabel(item.currentStock!)} ${item.unit}',
                        ),
                        Text('历史采购次数：${item.purchaseCount} 次'),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final metrics = [
                    _DateMetric(
                      label: '最近申报',
                      value: purchaseDateLabel(item.mostRecentRequestDate),
                      icon: Icons.calendar_month_outlined,
                    ),
                    _DateMetric(
                      label: '最近入库',
                      value: purchaseDateLabel(item.mostRecentStockInDate),
                      icon: Icons.move_to_inbox_outlined,
                    ),
                    _DateMetric(
                      label: '最近周期',
                      value: _recentCycleLabel(cycles),
                      icon: Icons.schedule,
                    ),
                  ];
                  if (constraints.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(14) > 18) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final metric in metrics) ...[
                          metric,
                          if (metric != metrics.last) const SizedBox(height: 8),
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      for (final (index, metric) in metrics.indexed) ...[
                        if (index > 0) const SizedBox(width: 8),
                        Expanded(child: metric),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PurchaseSectionHeading(
          '采购周期概览',
          trailing: Text(
            '基于真实完成入库记录',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 8),
        PurchasePanel(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _CycleCard(
                  label: '最近3次采购周期',
                  value: cycles.isEmpty
                      ? '无足够历史记录'
                      : cycles.map((e) => '$e天').join(' / '),
                  fitSingleLineValue: true,
                ),
                _CycleCard(
                  label: '平均采购周期',
                  value: item.averageCycleDays == null
                      ? '无足够历史记录'
                      : '${item.averageCycleDays!.round()}天',
                ),
                _CycleCard(
                  label: '最近一次采购执行人',
                  value: _latestPurchaser(item.rows),
                ),
              ];
              if (constraints.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(14) > 18) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final card in cards) ...[
                      card,
                      if (card != cards.last) const SizedBox(height: 10),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (index, card) in cards.indexed) ...[
                    if (index > 0) const SizedBox(width: 10),
                    Expanded(child: card),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        const PurchaseSectionHeading('历史采购记录'),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final (index, period) in const [
              '全部',
              '近半年',
              '本年度',
            ].indexed) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(
                child: _HistoryPeriodSegment(
                  label: period,
                  selected: _period == period,
                  onTap: () => setState(() => _period = period),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const PurchasePanel(child: Text('当前时间范围内没有采购记录。'))
        else
          for (final row in rows) ...[
            _ItemHistoryRow(row: row),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  List<PurchaseHistoryRow> _filteredRows(List<PurchaseHistoryRow> rows) {
    final now = DateTime.now();
    final start = switch (_period) {
      '近半年' => DateTime(now.year, now.month - 5, 1),
      '本年度' => DateTime(now.year),
      _ => null,
    };
    return rows.where((row) {
      if (start == null) return true;
      final date = row.appliedDate ?? row.requestDate;
      return date != null && !date.isBefore(start);
    }).toList();
  }
}

class _DateMetric extends StatelessWidget {
  const _DateMetric({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F7FC),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF1677FF), size: 19),
        const SizedBox(height: 4),
        Text(label, maxLines: 2, softWrap: true),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: Theme.of(context).textTheme.titleSmall),
        ),
      ],
    ),
  );
}

class _CycleCard extends StatelessWidget {
  const _CycleCard({
    required this.label,
    required this.value,
    this.fitSingleLineValue = false,
  });
  final String label;
  final String value;
  final bool fitSingleLineValue;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, softWrap: true),
      const SizedBox(height: 4),
      if (fitSingleLineValue)
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: const Color(0xFF1677FF)),
          ),
        )
      else
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: const Color(0xFF1677FF)),
          softWrap: true,
        ),
    ],
  );
}

class _HistoryPeriodSegment extends StatelessWidget {
  const _HistoryPeriodSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFF00A86B) : const Color(0xFFF0F5FB),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF425D7F),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ItemHistoryRow extends ConsumerWidget {
  const _ItemHistoryRow({required this.row});
  final PurchaseHistoryRow row;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(purchaseDetailProvider(row.requestId)).valueOrNull;
    return PurchasePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PurchaseStatusChip(status: row.status),
              const SizedBox(width: 8),
              Expanded(
                child: Text('申报日期：${purchaseDateLabel(row.appliedDate)}'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              Text(
                '申报数量：${purchaseQuantityLabel(row.requestQuantity)} ${row.unit}',
              ),
              Text(
                '实际入库：${purchaseQuantityLabel(row.receivedQuantity)} ${row.unit}',
              ),
              Text('执行人：${row.purchaserName ?? '未填写'}'),
              Text(
                '${row.completedAt != null ? '完成入库' : '最近入库'}：${purchaseDateLabel(row.completedAt ?? row.lastStockInDate)}',
              ),
              if (detail?.purchaseDepartment?.isNotEmpty == true)
                Text('资材分部：${detail!.purchaseDepartment}'),
              if (detail?.oaRequestNo?.isNotEmpty == true)
                Text('OA流程编号：${detail!.oaRequestNo}'),
              Text(
                '采购周期：${row.cycleDays == null ? '无足够记录' : '${row.cycleDays}天'}',
              ),
            ],
          ),
          if (row.requestId > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    context.push(PurchaseRoutes.detail(row.requestId)),
                child: const Text('查看采购详情'),
              ),
            ),
        ],
      ),
    );
  }
}

String _recentCycleLabel(List<int> cycles) =>
    cycles.isEmpty ? '无足够历史记录' : '${cycles.first}天';

String _latestPurchaser(List<PurchaseHistoryRow> rows) {
  final ordered = [...rows]
    ..sort(
      (a, b) => (b.appliedDate ?? b.requestDate ?? DateTime(1)).compareTo(
        a.appliedDate ?? a.requestDate ?? DateTime(1),
      ),
    );
  for (final row in ordered) {
    if (row.purchaserName?.isNotEmpty == true) return row.purchaserName!;
  }
  return '未填写';
}
