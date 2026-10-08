import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../purchase/presentation/purchase_item_prefill.dart';
import '../../purchase/purchase_routes.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_models.dart';
import 'widgets/inventory_widgets.dart';

class InventoryMaterialDetailPage extends ConsumerStatefulWidget {
  const InventoryMaterialDetailPage({required this.materialId, super.key});
  final int materialId;

  @override
  ConsumerState<InventoryMaterialDetailPage> createState() =>
      _InventoryMaterialDetailPageState();
}

class _InventoryMaterialDetailPageState
    extends ConsumerState<InventoryMaterialDetailPage> {
  late Future<InventoryMaterial?> _material;
  late Future<List<InventoryTransaction>> _transactions;
  bool _addingReplenishment = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final service = ref.read(inventoryServiceProvider);
    _material = service.getMaterial(widget.materialId);
    _transactions = service.getTransactions(materialId: widget.materialId);
  }

  Future<void> _addToReplenishment(InventoryMaterial material) async {
    setState(() => _addingReplenishment = true);
    try {
      await ref
          .read(inventoryServiceProvider)
          .addWarningToReplenishment(material.id);
      ref.invalidate(inventoryReplenishmentsProvider);
      ref.invalidate(inventoryOverviewProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已加入待采购 / 待补充清单')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('加入失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _addingReplenishment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(inventoryCategoriesProvider).valueOrNull ??
        const <InventoryCategory>[];
    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('物资详情'),
        actions: [
          IconButton(
            tooltip: '编辑物资',
            onPressed: () =>
                context.push('/inventory/materials/${widget.materialId}/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: FutureBuilder<InventoryMaterial?>(
        future: _material,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return InventoryErrorState(onRetry: () => setState(_load));
          }
          if (!snapshot.hasData) return const InventoryLoadingState();
          final material = snapshot.data;
          if (material == null) {
            return const InventoryEmptyState(title: '物资不存在');
          }
          final row = InventoryStockRow(material: material);
          final status = switch (row.status) {
            InventoryStockStatus.normal => ('正常', AppColors.success),
            InventoryStockStatus.low => ('库存不足', const Color(0xFFE98500)),
            InventoryStockStatus.outOfStock => ('缺货', AppColors.danger),
          };
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            child: Icon(Icons.inventory_2_outlined),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  material.materialName,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(
                                  '${material.materialCode} · ${material.modelSpec ?? '未填写型号'}',
                                ),
                              ],
                            ),
                          ),
                          InventoryStatusChip(
                            label: material.status == 'active'
                                ? status.$1
                                : '停用',
                            color: material.status == 'active'
                                ? status.$2
                                : AppColors.helper,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '当前库存',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              '${material.currentStock} ${material.unitName}',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 20,
                        runSpacing: 16,
                        children: [
                          _DetailValue(
                            label: '物资分类',
                            value:
                                categoryNames[material.categoryId] ??
                                (material.categoryId == null ? '未分类' : '分类加载中'),
                          ),
                          _DetailValue(
                            label: '规格型号',
                            value: material.modelSpec ?? '未填写',
                          ),
                          _DetailValue(label: '单位', value: material.unitName),
                          _DetailValue(
                            label: '最低库存',
                            value: '${material.minStock}',
                          ),
                          _DetailValue(
                            label: '存放位置',
                            value: material.storageLocation ?? '未填写',
                          ),
                          _DetailValue(
                            label: '默认来源',
                            value: material.defaultSource ?? '未填写',
                          ),
                          _DetailValue(
                            label: '库存预警',
                            value: material.warningEnabled ? '已启用' : '已关闭',
                          ),
                          _DetailValue(
                            label: '物资状态',
                            value: material.status == 'active' ? '启用' : '停用',
                          ),
                        ],
                      ),
                      if ((material.remark ?? '').isNotEmpty) ...[
                        const Divider(height: 24),
                        Text('备注：${material.remark}'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push('/inventory/receipts/new'),
                      icon: const Icon(Icons.move_to_inbox_outlined),
                      label: const Text('快速入库'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/inventory/issues/new'),
                      icon: const Icon(Icons.outbox_outlined),
                      label: const Text('快速出库'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('inventory-material-create-purchase'),
                onPressed: () => context.push(
                  PurchaseRoutes.create,
                  extra: PurchaseItemPrefill.fromInventoryMaterial(material),
                ),
                icon: const Icon(Icons.add_shopping_cart_outlined),
                label: const Text('申报采购'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('inventory-material-add-replenishment'),
                onPressed: _addingReplenishment
                    ? null
                    : () => _addToReplenishment(material),
                icon: _addingReplenishment
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_shopping_cart_outlined),
                label: Text(_addingReplenishment ? '正在加入…' : '加入待采购 / 待补充'),
              ),
              const SizedBox(height: 18),
              InventorySection(
                title: '最近库存流水',
                icon: Icons.history_rounded,
                trailing: TextButton(
                  onPressed: () => context.push('/inventory/transactions'),
                  child: const Text('全部流水'),
                ),
                child: FutureBuilder<List<InventoryTransaction>>(
                  future: _transactions,
                  builder: (context, records) {
                    if (records.hasError) {
                      return InventoryErrorState(
                        onRetry: () => setState(_load),
                      );
                    }
                    if (!records.hasData) return const InventoryLoadingState();
                    final allTransactions = records.data!;
                    final now = DateTime.now();
                    final monthlyTransactions = allTransactions.where(
                      (transaction) =>
                          transaction.occurredAt.year == now.year &&
                          transaction.occurredAt.month == now.month,
                    );
                    final monthlyInbound = monthlyTransactions
                        .where(
                          (transaction) =>
                              _isInbound(transaction.transactionType),
                        )
                        .fold<double>(
                          0,
                          (total, transaction) =>
                              total + transaction.quantityChange,
                        );
                    final monthlyOutbound = monthlyTransactions
                        .where(
                          (transaction) =>
                              _isOutbound(transaction.transactionType),
                        )
                        .fold<double>(
                          0,
                          (total, transaction) =>
                              total + transaction.quantityChange.abs(),
                        );
                    final latestInbound = allTransactions
                        .where(
                          (transaction) =>
                              _isInbound(transaction.transactionType),
                        )
                        .toList();
                    final latestOutbound = allTransactions
                        .where(
                          (transaction) =>
                              _isOutbound(transaction.transactionType),
                        )
                        .toList();
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _DetailValue(
                                label: '本月入库数量',
                                value: '$monthlyInbound ${material.unitName}',
                              ),
                            ),
                            Expanded(
                              child: _DetailValue(
                                label: '本月出库数量',
                                value: '$monthlyOutbound ${material.unitName}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _DetailValue(
                          label: '最近一次入库',
                          value: latestInbound.isEmpty
                              ? '暂无记录'
                              : _dateLabel(latestInbound.first.occurredAt),
                        ),
                        const SizedBox(height: 8),
                        _DetailValue(
                          label: '最近一次出库',
                          value: latestOutbound.isEmpty
                              ? '暂无记录'
                              : _dateLabel(latestOutbound.first.occurredAt),
                        ),
                        const Divider(height: 24),
                        if (records.data!.isEmpty)
                          const InventoryEmptyState(
                            title: '暂无流水',
                            message: '物资库存发生变化后会显示在这里。',
                          )
                        else
                          for (final transaction in records.data!.take(5))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _transactionLabel(transaction.transactionType),
                              ),
                              subtitle: Text(
                                _dateLabel(transaction.occurredAt),
                              ),
                              trailing: Text(
                                '${transaction.quantityChange > 0 ? '+' : ''}${transaction.quantityChange} ${transaction.unitSnapshot}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: transaction.quantityChange >= 0
                                          ? AppColors.primary
                                          : AppColors.danger,
                                    ),
                              ),
                            ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailValue extends StatelessWidget {
  const _DetailValue({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.only(bottom: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.body, fontSize: 14),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.ink, fontSize: 16),
          ),
        ),
      ],
    ),
  );
}

String _transactionLabel(String value) => switch (value) {
  'receipt' => '入库',
  'issue' => '员工领用',
  'stocktake_gain' => '盘盈',
  'stocktake_loss' => '盘亏',
  'adjustment' => '手动调整',
  _ => value,
};

bool _isInbound(String type) => const {
  'receipt',
  'return_in',
  'transfer_in',
  'stocktake_gain',
}.contains(type);

bool _isOutbound(String type) =>
    const {'issue', 'transfer_out', 'stocktake_loss'}.contains(type);

String _dateLabel(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
