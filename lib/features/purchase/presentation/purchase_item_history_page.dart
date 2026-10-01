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
    return Scaffold(
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
            ? const PurchaseEmptyState(title: '暂无物资历史', message: '该库存物资尚无采购历史。')
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
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
                ],
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
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CycleCard(
                label: '最近3次采购周期',
                value: cycles.isEmpty
                    ? '无足够历史记录'
                    : cycles.map((e) => '$e天').join(' / '),
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
            ],
          ),
        ),
        const SizedBox(height: 14),
        const PurchaseSectionHeading('历史采购记录'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final period in const ['全部', '近半年', '本年度'])
              ChoiceChip(
                label: Text(period),
                selected: _period == period,
                onSelected: (_) => setState(() => _period = period),
              ),
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
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F7FC),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF1677FF), size: 19),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ],
    ),
  );
}

class _CycleCard extends StatelessWidget {
  const _CycleCard({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 76)
        .clamp(120.0, 180.0)
        .toDouble(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, softWrap: true),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: const Color(0xFF1677FF)),
          softWrap: true,
        ),
      ],
    ),
  );
}

class _ItemHistoryRow extends StatelessWidget {
  const _ItemHistoryRow({required this.row});
  final PurchaseHistoryRow row;
  @override
  Widget build(BuildContext context) => PurchasePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PurchaseStatusChip(status: row.status),
            const SizedBox(width: 8),
            Expanded(child: Text('申报日期：${purchaseDateLabel(row.appliedDate)}')),
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
            Text('完成入库：${purchaseDateLabel(row.lastStockInDate)}'),
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
