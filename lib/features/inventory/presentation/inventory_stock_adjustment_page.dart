import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/inventory_providers.dart';
import 'widgets/inventory_widgets.dart';

class InventoryStockAdjustmentPage extends ConsumerStatefulWidget {
  const InventoryStockAdjustmentPage({required this.materialId, super.key});
  final int materialId;

  @override
  ConsumerState<InventoryStockAdjustmentPage> createState() =>
      _InventoryStockAdjustmentPageState();
}

class _InventoryStockAdjustmentPageState
    extends ConsumerState<InventoryStockAdjustmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _remark = TextEditingController();
  late final Future<InventoryMaterial?> _material;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _material = ref
        .read(inventoryServiceProvider)
        .getMaterial(widget.materialId);
  }

  @override
  void dispose() {
    _quantity.dispose();
    _remark.dispose();
    super.dispose();
  }

  Future<void> _save(InventoryMaterial material) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(inventoryServiceProvider)
          .adjustStock(
            material.id,
            double.parse(_quantity.text.trim()),
            remark: _remark.text.trim().isEmpty ? null : _remark.text.trim(),
          );
      ref.invalidate(inventoryStockProvider);
      ref.invalidate(inventoryMaterialsProvider);
      ref.invalidate(inventoryTransactionsProvider);
      ref.invalidate(inventoryOverviewProvider);
      ref.invalidate(inventoryWarningsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('库存已调整，流水已记录')));
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('调整失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('调整库存')),
    body: FutureBuilder<InventoryMaterial?>(
      future: _material,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return InventoryErrorState(onRetry: () => setState(() {}));
        }
        if (!snapshot.hasData) return const InventoryLoadingState();
        final material = snapshot.data;
        if (material == null) {
          return const InventoryEmptyState(
            title: '物资不存在',
            message: '该物资档案可能已被移除。',
          );
        }
        if (_quantity.text.isEmpty) _quantity.text = '${material.currentStock}';
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.inventory_2_outlined),
                ),
                title: Text(material.materialName),
                subtitle: Text(
                  '${material.modelSpec ?? '未填写型号'} · ${material.unitName}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('调整前'),
                    Text(
                      '${material.currentStock} ${material.unitName}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '新库存数量',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const Key('inventory-adjust-quantity'),
                        controller: _quantity,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: '调整后数量（${material.unitName}）',
                        ),
                        validator: (value) {
                          final quantity = double.tryParse(value ?? '');
                          return quantity == null || quantity < 0
                              ? '请输入大于或等于 0 的数量'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _remark,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '调整原因（可选）',
                          hintText: '例如：实物盘点后修正',
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _saving ? null : () => _save(material),
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? '正在保存…' : '保存调整'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
