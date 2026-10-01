import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_models.dart';
import 'widgets/inventory_export_button.dart';
import 'widgets/inventory_widgets.dart';

class InventoryStockPage extends ConsumerStatefulWidget {
  const InventoryStockPage({super.key});

  @override
  ConsumerState<InventoryStockPage> createState() => _InventoryStockPageState();
}

class _InventoryStockPageState extends ConsumerState<InventoryStockPage> {
  final _search = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stock = ref.watch(inventoryStockProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('当前库存'),
        actions: [
          IconButton(
            tooltip: '库存预警',
            onPressed: () => context.push('/inventory/warnings'),
            icon: const Icon(Icons.warning_amber_rounded),
          ),
          IconButton(
            tooltip: '库存流水',
            onPressed: () => context.push('/inventory/transactions'),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          const InventoryExportButton(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '搜索物资、型号或位置',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: const Color(0xFFF0F5F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('全部')),
                      ButtonSegment(value: 'common', label: Text('常用')),
                      ButtonSegment(value: 'low', label: Text('库存不足')),
                      ButtonSegment(value: 'out', label: Text('缺货')),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (values) =>
                        setState(() => _filter = values.first),
                  ),
                ),
              ],
            ),
          ),
          stock.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (rows) {
              final normalCount = rows
                  .where((row) => row.status == InventoryStockStatus.normal)
                  .length;
              final lowCount = rows
                  .where((row) => row.status == InventoryStockStatus.low)
                  .length;
              final outCount = rows
                  .where((row) => row.status == InventoryStockStatus.outOfStock)
                  .length;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: InventoryMetricCard(
                        compact: true,
                        label: '物资种类',
                        value: '${rows.length}',
                        icon: Icons.inventory_2_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InventoryMetricCard(
                        compact: true,
                        label: '正常',
                        value: '$normalCount',
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InventoryMetricCard(
                        compact: true,
                        label: '库存不足',
                        value: '${lowCount + outCount}',
                        icon: Icons.warning_amber_rounded,
                        color: const Color(0xFFE98500),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: stock.when(
              loading: () => const InventoryLoadingState(),
              error: (_, _) => InventoryErrorState(
                onRetry: () => ref.invalidate(inventoryStockProvider),
              ),
              data: (rows) {
                final normalCount = rows
                    .where((row) => row.status == InventoryStockStatus.normal)
                    .length;
                final lowCount = rows
                    .where((row) => row.status == InventoryStockStatus.low)
                    .length;
                final outCount = rows
                    .where(
                      (row) => row.status == InventoryStockStatus.outOfStock,
                    )
                    .length;
                final keyword = _search.text.trim().toLowerCase();
                final filtered = rows.where((row) {
                  final m = row.material;
                  final matchesSearch =
                      keyword.isEmpty ||
                      m.materialName.toLowerCase().contains(keyword) ||
                      (m.modelSpec ?? '').toLowerCase().contains(keyword) ||
                      (m.storageLocation ?? '').toLowerCase().contains(keyword);
                  final matchesFilter = switch (_filter) {
                    'common' => m.isCommon,
                    'low' => row.status == InventoryStockStatus.low,
                    'out' => row.status == InventoryStockStatus.outOfStock,
                    _ => true,
                  };
                  return matchesSearch && matchesFilter;
                }).toList();
                if (filtered.isEmpty) {
                  return InventoryEmptyState(
                    title: rows.isEmpty ? '暂无库存记录' : '没有匹配的物资',
                    message: rows.isEmpty ? '先在物资信息中新增物资档案。' : '调整筛选条件后再试。',
                    action: rows.isEmpty
                        ? FilledButton.icon(
                            onPressed: () =>
                                context.push('/inventory/materials/new'),
                            icon: const Icon(Icons.add),
                            label: const Text('新增物资'),
                          )
                        : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(inventoryStockProvider),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      for (final row in filtered) ...[
                        _StockCard(row: row),
                        const SizedBox(height: 10),
                      ],
                      InventorySummaryPanel(
                        title: '库存状态摘要',
                        icon: Icons.bar_chart_rounded,
                        metrics: [
                          ('正常', '$normalCount'),
                          ('预警', '$lowCount'),
                          ('缺货', '$outCount'),
                        ],
                        actionLabel: '查看',
                        onAction: () => context.push('/inventory/warnings'),
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

class _StockCard extends StatelessWidget {
  const _StockCard({required this.row});

  final InventoryStockRow row;

  @override
  Widget build(BuildContext context) {
    final material = row.material;
    final color = switch (row.status) {
      InventoryStockStatus.normal => AppColors.primary,
      InventoryStockStatus.low => const Color(0xFFE98500),
      InventoryStockStatus.outOfStock => AppColors.danger,
    };
    final label = switch (row.status) {
      InventoryStockStatus.normal => '正常',
      InventoryStockStatus.low => '库存不足',
      InventoryStockStatus.outOfStock => '缺货',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 420;
            final summary = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.materialName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '规格：${material.modelSpec ?? '未填写'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '位置：${material.storageLocation ?? '未填写'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            );
            final balance = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('当前库存'),
                Text(
                  '${material.currentStock} ${material.unitName}',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w800),
                ),
                Text(
                  '最低库存：${material.minStock} ${material.unitName}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (narrow) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F5F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: summary),
                      const SizedBox(width: 12),
                      balance,
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      InventoryStatusChip(label: label, color: color),
                      const Spacer(),
                      OutlinedButton(
                        key: Key('inventory-adjust-${material.id}'),
                        onPressed: () => context.push(
                          '/inventory/adjust?materialId=${material.id}',
                        ),
                        child: const Text('调整库存'),
                      ),
                    ],
                  ),
                ] else
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F5F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: summary),
                      const VerticalDivider(width: 28),
                      balance,
                      const Spacer(),
                      Column(
                        children: [
                          InventoryStatusChip(label: label, color: color),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => context.push(
                              '/inventory/adjust?materialId=${material.id}',
                            ),
                            child: const Text('调整库存'),
                          ),
                        ],
                      ),
                    ],
                  ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        context.push('/inventory/materials/${material.id}'),
                    child: const Text('物资详情'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
