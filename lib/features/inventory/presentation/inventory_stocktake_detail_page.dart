import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/inventory_providers.dart';
import 'widgets/inventory_widgets.dart';

class InventoryStocktakeDetailPage extends ConsumerStatefulWidget {
  const InventoryStocktakeDetailPage({required this.stocktakeId, super.key});
  final int stocktakeId;

  @override
  ConsumerState<InventoryStocktakeDetailPage> createState() =>
      _InventoryStocktakeDetailPageState();
}

class _InventoryStocktakeDetailPageState
    extends ConsumerState<InventoryStocktakeDetailPage> {
  late Future<InventoryStocktake?> _stocktake;
  late Future<List<InventoryStocktakeItem>> _items;
  final Map<int, TextEditingController> _actualFields = {};
  bool _saving = false;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final service = ref.read(inventoryServiceProvider);
    _stocktake = service.getStocktake(widget.stocktakeId);
    _items = service.getStocktakeItems(widget.stocktakeId);
  }

  @override
  void dispose() {
    for (final field in _actualFields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _confirm(List<InventoryStocktakeItem> items) async {
    final quantities = <int, double>{};
    for (final item in items) {
      final quantity = double.tryParse(
        _actualFields[item.id]?.text.trim() ?? '${item.actualQuantity}',
      );
      if (quantity == null || quantity < 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('请为每项填写大于或等于 0 的实盘数量')));
        return;
      }
      quantities[item.id] = quantity;
    }
    final confirmed = await showInventoryConfirmation(
      context: context,
      title: '确认盘点？',
      message: '确认后将按实盘数量更新库存，并为盘盈盘亏生成库存流水。',
      cancelLabel: '继续核对',
      confirmLabel: '确认盘点',
      icon: Icons.info_outline,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _confirming = true);
    try {
      final service = ref.read(inventoryServiceProvider);
      for (final item in items) {
        await service.updateStocktakeItem(item.id, quantities[item.id]!);
      }
      await service.confirmStocktake(widget.stocktakeId);
      ref.invalidate(inventoryStocktakesProvider);
      ref.invalidate(inventoryStocktakeItemsProvider(widget.stocktakeId));
      ref.invalidate(inventoryStockProvider);
      ref.invalidate(inventoryMaterialsProvider);
      ref.invalidate(inventoryWarningsProvider);
      ref.invalidate(inventoryOverviewProvider);
      ref.invalidate(inventoryTransactionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('盘点已确认，库存已更新')));
        setState(_load);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('确认失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _saveCounts(List<InventoryStocktakeItem> items) async {
    final quantities = <int, double>{};
    for (final item in items) {
      final quantity = double.tryParse(
        _actualFields[item.id]?.text.trim() ?? '${item.actualQuantity}',
      );
      if (quantity == null || quantity < 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('请为每项填写大于或等于 0 的实盘数量')));
        return;
      }
      quantities[item.id] = quantity;
    }
    setState(() => _saving = true);
    try {
      final service = ref.read(inventoryServiceProvider);
      for (final item in items) {
        await service.updateStocktakeItem(item.id, quantities[item.id]!);
      }
      if (mounted) {
        setState(_load);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('实盘数量已保存，差异已更新')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('盘点详情')),
    body: FutureBuilder<InventoryStocktake?>(
      future: _stocktake,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return InventoryErrorState(onRetry: () => setState(_load));
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const InventoryLoadingState();
        }
        final stocktake = snapshot.data;
        if (stocktake == null) {
          return const InventoryEmptyState(title: '盘点记录不存在');
        }
        return FutureBuilder<List<InventoryStocktakeItem>>(
          future: _items,
          builder: (context, itemSnapshot) {
            if (itemSnapshot.hasError) {
              return InventoryErrorState(onRetry: () => setState(_load));
            }
            if (!itemSnapshot.hasData) return const InventoryLoadingState();
            final items = itemSnapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Card(
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      stocktake.stocktakeNo,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      '${_dateLabel(stocktake.stocktakeDate)} · ${stocktake.operatorNameSnapshot ?? '未填写盘点人'}',
                    ),
                    trailing: InventoryStatusChip(
                      label: stocktake.status == 'confirmed' ? '已完成' : '待盘点',
                      color: stocktake.status == 'confirmed'
                          ? AppColors.primary
                          : const Color(0xFFE98500),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InventorySection(
                  title: '盘点明细',
                  icon: Icons.fact_check_outlined,
                  child: items.isEmpty
                      ? const InventoryEmptyState(title: '没有盘点明细')
                      : Column(
                          children: [
                            for (final item in items)
                              _StocktakeItemEditor(
                                item: item,
                                controller: _actualFields.putIfAbsent(
                                  item.id,
                                  () => TextEditingController(
                                    text: '${item.actualQuantity}',
                                  ),
                                ),
                                editable: stocktake.status != 'confirmed',
                              ),
                          ],
                        ),
                ),
                if (stocktake.status != 'confirmed' && items.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _saving || _confirming
                        ? null
                        : () => _saveCounts(items),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? '正在保存…' : '保存实盘数并查看差异'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('inventory-stocktake-confirm'),
                    onPressed: _saving || _confirming
                        ? null
                        : () => _confirm(items),
                    icon: _confirming
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_confirming ? '正在确认…' : '保存实盘数量并确认'),
                  ),
                ],
              ],
            );
          },
        );
      },
    ),
  );
}

class _StocktakeItemEditor extends StatelessWidget {
  const _StocktakeItemEditor({
    required this.item,
    required this.controller,
    required this.editable,
  });
  final InventoryStocktakeItem item;
  final TextEditingController controller;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final difference = item.differenceQuantity;
    final differenceColor = difference == 0
        ? AppColors.primary
        : AppColors.danger;
    final compact =
        MediaQuery.sizeOf(context).width <= 320 ||
        MediaQuery.textScalerOf(context).scale(14) > 17;
    final materialInfo = Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.lightBlue,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.category_outlined,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.materialNameSnapshot,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                '${item.modelSnapshot ?? '未填型号'} · ${item.unitSnapshot}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
    final quantityField = SizedBox(
      width: compact ? double.infinity : 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('实盘数量', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          TextField(
            key: Key('inventory-stocktake-actual-${item.id}'),
            controller: controller,
            enabled: editable,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              isDense: true,
              filled: !editable,
              fillColor: editable ? null : const Color(0xFFF1F5F9),
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
      child: Column(
        children: [
          if (compact) ...[
            SizedBox(width: double.infinity, child: materialInfo),
            const SizedBox(height: 12),
            quantityField,
          ] else
            Row(
              children: [
                Expanded(child: materialInfo),
                const SizedBox(width: 10),
                quantityField,
              ],
            ),
          const SizedBox(height: 9),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF6FAFE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text('账面数量：${item.bookQuantity}'),
                Text(
                  '差异：${difference > 0 ? '+' : ''}$difference',
                  style: TextStyle(
                    color: differenceColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                InventoryStatusChip(
                  label: difference == 0
                      ? '一致'
                      : difference > 0
                      ? '盘盈'
                      : '盘亏',
                  color: difference == 0 ? AppColors.primary : AppColors.danger,
                ),
              ],
            ),
          ),
          const Divider(height: 22),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime value) =>
    '${value.year}年${value.month}月${value.day}日';
