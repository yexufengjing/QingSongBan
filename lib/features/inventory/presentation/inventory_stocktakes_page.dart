import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/inventory_providers.dart';
import 'widgets/inventory_export_button.dart';
import 'widgets/inventory_widgets.dart';

class InventoryStocktakesPage extends ConsumerStatefulWidget {
  const InventoryStocktakesPage({super.key});

  @override
  ConsumerState<InventoryStocktakesPage> createState() =>
      _InventoryStocktakesPageState();
}

class _InventoryStocktakesPageState
    extends ConsumerState<InventoryStocktakesPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _status = 'draft';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('库存盘点'),
      actions: [
        IconButton(
          key: const Key('inventory-stocktake-new'),
          tooltip: '新建盘点',
          onPressed: () => context.push('/inventory/stocktake/new'),
          icon: const Icon(Icons.add_circle_outline),
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
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'draft', label: Text('待盘点')),
                    ButtonSegment(value: 'confirmed', label: Text('已完成')),
                  ],
                  selected: {_status},
                  onSelectionChanged: (value) =>
                      setState(() => _status = value.first),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ref
              .watch(inventoryStocktakesProvider)
              .when(
                loading: () => const InventoryLoadingState(),
                error: (_, _) => InventoryErrorState(
                  onRetry: () => ref.invalidate(inventoryStocktakesProvider),
                ),
                data: (allItems) {
                  final monthItems = allItems
                      .where(
                        (item) =>
                            item.stocktakeDate.year == _month.year &&
                            item.stocktakeDate.month == _month.month,
                      )
                      .toList();
                  final items = monthItems
                      .where((item) => item.status == _status)
                      .toList();
                  final doneCount = monthItems
                      .where((item) => item.status == 'confirmed')
                      .length;
                  final pendingCount = monthItems.length - doneCount;
                  final monthLines = monthItems
                      .map(
                        (item) =>
                            ref.watch(inventoryStocktakeItemsProvider(item.id)),
                      )
                      .toList();
                  final diffLoading = monthLines.any(
                    (lines) => lines.isLoading,
                  );
                  final diffFailed = monthLines.any((lines) => lines.hasError);
                  final differenceCount = monthLines.fold<int>(
                    0,
                    (total, lines) =>
                        total +
                        (lines.valueOrNull
                                ?.where((line) => line.differenceQuantity != 0)
                                .length ??
                            0),
                  );
                  final differenceLabel = diffLoading
                      ? '…'
                      : diffFailed
                      ? '—'
                      : '$differenceCount';
                  if (items.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: InventoryMetricCard(
                                compact: true,
                                label: '待盘点',
                                value: '$pendingCount',
                                icon: Icons.fact_check_outlined,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InventoryMetricCard(
                                compact: true,
                                label: '已完成',
                                value: '$doneCount',
                                icon: Icons.check_circle_outline,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InventoryMetricCard(
                                compact: true,
                                label: '差异条数',
                                value: differenceLabel,
                                icon: Icons.schedule,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                        InventoryEmptyState(
                          title: allItems.isEmpty
                              ? '暂无盘点记录'
                              : '本月暂无${_status == 'draft' ? '待盘点' : '已完成'}任务',
                          message: allItems.isEmpty
                              ? '开始一次盘点，核对账面库存和实物数量。'
                              : '调整月份或状态筛选后再试。',
                          action: FilledButton.icon(
                            onPressed: () =>
                                context.push('/inventory/stocktake/new'),
                            icon: const Icon(Icons.add),
                            label: const Text('新建盘点'),
                          ),
                        ),
                      ],
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(inventoryStocktakesProvider),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: InventoryMetricCard(
                                compact: true,
                                label: '待盘点',
                                value: '$pendingCount',
                                icon: Icons.fact_check_outlined,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InventoryMetricCard(
                                compact: true,
                                label: '已完成',
                                value: '$doneCount',
                                icon: Icons.check_circle_outline,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InventoryMetricCard(
                                compact: true,
                                label: '差异条数',
                                value: differenceLabel,
                                icon: Icons.bar_chart_rounded,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final item in items) ...[
                          _StocktakeCard(stocktake: item),
                          const SizedBox(height: 10),
                        ],
                        InventorySummaryPanel(
                          title: '盘点汇总',
                          icon: Icons.bar_chart_rounded,
                          metrics: [
                            ('盘点总数', '${monthItems.length}'),
                            ('已完成', '$doneCount'),
                            ('差异条数', differenceLabel),
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

class _StocktakeCard extends ConsumerWidget {
  const _StocktakeCard({required this.stocktake});
  final InventoryStocktake stocktake;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = stocktake.status == 'confirmed';
    final lines = ref.watch(inventoryStocktakeItemsProvider(stocktake.id));
    return Card(
      child: InkWell(
        key: Key('inventory-stocktake-${stocktake.id}'),
        onTap: () => context.push('/inventory/stocktake/${stocktake.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: done
                        ? AppColors.lightGreen
                        : AppColors.lightOrange,
                    child: Icon(
                      done ? Icons.check_circle_outline : Icons.schedule,
                      color: done ? AppColors.primary : const Color(0xFFE98500),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dateLabel(stocktake.stocktakeDate),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${stocktake.operatorNameSnapshot ?? '未填写盘点人'} · ${stocktake.stocktakeNo}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  InventoryStatusChip(
                    label: done ? '已完成' : '进行中',
                    color: done ? AppColors.primary : const Color(0xFFE98500),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    tooltip: '更多操作',
                    onSelected: (value) {
                      if (value == 'detail') {
                        context.push('/inventory/stocktake/${stocktake.id}');
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'detail', child: Text('查看详情')),
                    ],
                    icon: const Icon(Icons.more_horiz, color: AppColors.helper),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F5F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 4, child: Text('物资名称')),
                    Expanded(
                      flex: 2,
                      child: Text('账面', textAlign: TextAlign.center),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('实盘', textAlign: TextAlign.center),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('差异', textAlign: TextAlign.center),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('状态', textAlign: TextAlign.center),
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
                  child: Text('盘点明细暂时无法读取'),
                ),
                data: (items) => Column(
                  children: [
                    for (final item in items) _StocktakeLine(item: item),
                    if (done)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '差异 ${items.where((item) => item.differenceQuantity != 0).length} 项',
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: AppColors.primary),
                        ),
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
}

class _StocktakeLine extends StatelessWidget {
  const _StocktakeLine({required this.item});
  final InventoryStocktakeItem item;

  @override
  Widget build(BuildContext context) {
    final difference = item.differenceQuantity;
    final hasDifference = difference != 0;
    final color = hasDifference ? AppColors.danger : AppColors.primary;
    final label = difference == 0
        ? '一致'
        : difference < 0
        ? '盘亏'
        : '盘盈';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
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
              _formatQuantity(item.bookQuantity),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatQuantity(item.actualQuantity),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${difference > 0 ? '+' : ''}${_formatQuantity(difference)}',
              textAlign: TextAlign.center,
              style: TextStyle(color: color),
            ),
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: InventoryStatusChip(label: label, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatQuantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

String _dateLabel(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
