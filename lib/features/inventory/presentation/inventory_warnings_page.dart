import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_models.dart';
import 'widgets/inventory_widgets.dart';

class InventoryWarningsPage extends ConsumerWidget {
  const InventoryWarningsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warnings = ref.watch(inventoryWarningsProvider);
    final replenishments = ref.watch(inventoryReplenishmentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('库存预警与待补充')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('inventory-replenishment-add'),
        onPressed: () => context.push('/inventory/replenishment'),
        icon: const Icon(Icons.shopping_cart_outlined),
        label: const Text('待补充清单'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(inventoryWarningsProvider);
          ref.invalidate(inventoryReplenishmentsProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 90),
          children: [
            InventorySection(
              title: '库存预警',
              icon: Icons.notifications_active_outlined,
              child: warnings.when(
                loading: () => const InventoryLoadingState(),
                error: (_, _) => InventoryErrorState(
                  onRetry: () => ref.invalidate(inventoryWarningsProvider),
                ),
                data: (rows) => rows.isEmpty
                    ? const InventoryEmptyState(
                        title: '没有库存预警',
                        message: '所有启用预警的物资库存都高于最低库存。',
                      )
                    : Column(
                        children: [
                          for (final row in rows) _WarningCard(row: row),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            InventorySection(
              title: '待补充摘要',
              icon: Icons.shopping_cart_outlined,
              trailing: TextButton(
                onPressed: () => context.push('/inventory/replenishment'),
                child: const Text('全部清单'),
              ),
              child: replenishments.when(
                loading: () => const InventoryLoadingState(),
                error: (_, _) => InventoryErrorState(
                  onRetry: () =>
                      ref.invalidate(inventoryReplenishmentsProvider),
                ),
                data: (items) {
                  final pending = items
                      .where((item) => item.status == 'pending')
                      .length;
                  return items.isEmpty
                      ? const InventoryEmptyState(
                          title: '清单还是空的',
                          message: '可以从库存预警中一键加入待补充。',
                        )
                      : Row(
                          children: [
                            Expanded(child: Text('共 ${items.length} 项待补充记录')),
                            InventoryStatusChip(
                              label: '$pending 项待处理',
                              color: const Color(0xFFE98500),
                            ),
                          ],
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningCard extends ConsumerStatefulWidget {
  const _WarningCard({required this.row});
  final InventoryStockRow row;

  @override
  ConsumerState<_WarningCard> createState() => _WarningCardState();
}

class _WarningCardState extends ConsumerState<_WarningCard> {
  bool _adding = false;

  Future<void> _add() async {
    setState(() => _adding = true);
    try {
      await ref
          .read(inventoryServiceProvider)
          .addWarningToReplenishment(widget.row.material.id);
      ref.invalidate(inventoryReplenishmentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已加入待补充清单')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('加入失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final material = row.material;
    final out = row.status == InventoryStockStatus.outOfStock;
    final color = out ? AppColors.danger : const Color(0xFFE98500);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  out
                      ? Icons.inventory_2_outlined
                      : Icons.warning_amber_rounded,
                  color: color,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    material.materialName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                InventoryStatusChip(label: out ? '缺货' : '库存不足', color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${material.modelSpec ?? '未填型号'} · ${material.storageLocation ?? '未填位置'}',
            ),
            const SizedBox(height: 5),
            Text(
              '当前库存 ${material.currentStock} ${material.unitName}　最低库存 ${material.minStock}',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/inventory/materials/${material.id}'),
                    icon: const Icon(Icons.info_outline),
                    label: const Text('物资详情'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _adding ? null : _add,
                    icon: _adding
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_shopping_cart_outlined),
                    label: const Text('加入待补充'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
