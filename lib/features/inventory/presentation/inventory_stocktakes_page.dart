import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/inventory_providers.dart';
import 'widgets/inventory_export_button.dart';
import 'widgets/inventory_widgets.dart';

class InventoryStocktakesPage extends ConsumerWidget {
  const InventoryStocktakesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('库存盘点'),
      actions: const [InventoryExportButton()],
    ),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('inventory-stocktake-new'),
      onPressed: () => context.push('/inventory/stocktake/new'),
      icon: const Icon(Icons.add),
      label: const Text('新建盘点'),
    ),
    body: ref
        .watch(inventoryStocktakesProvider)
        .when(
          loading: () => const InventoryLoadingState(),
          error: (_, _) => InventoryErrorState(
            onRetry: () => ref.invalidate(inventoryStocktakesProvider),
          ),
          data: (items) => items.isEmpty
              ? InventoryEmptyState(
                  title: '暂无盘点记录',
                  message: '开始一次盘点，核对账面库存和实物数量。',
                  action: FilledButton.icon(
                    onPressed: () => context.push('/inventory/stocktake/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('新建盘点'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(inventoryStocktakesProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _StocktakeCard(stocktake: items[index]),
                  ),
                ),
        ),
  );
}

class _StocktakeCard extends StatelessWidget {
  const _StocktakeCard({required this.stocktake});
  final InventoryStocktake stocktake;

  @override
  Widget build(BuildContext context) {
    final done = stocktake.status == 'confirmed';
    return Card(
      child: InkWell(
        key: Key('inventory-stocktake-${stocktake.id}'),
        onTap: () => context.push('/inventory/stocktake/${stocktake.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
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
                      stocktake.stocktakeNo,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${_dateLabel(stocktake.stocktakeDate)} · ${stocktake.operatorNameSnapshot ?? '未填写盘点人'}',
                    ),
                  ],
                ),
              ),
              InventoryStatusChip(
                label: done ? '已完成' : '待盘点',
                color: done ? AppColors.primary : const Color(0xFFE98500),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.helper),
            ],
          ),
        ),
      ),
    );
  }
}

String _dateLabel(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
