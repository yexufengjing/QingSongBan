import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/inventory_providers.dart';
import '../domain/inventory_models.dart';
import 'widgets/inventory_widgets.dart';

class InventoryStocktakeFormPage extends ConsumerStatefulWidget {
  const InventoryStocktakeFormPage({super.key});

  @override
  ConsumerState<InventoryStocktakeFormPage> createState() =>
      _InventoryStocktakeFormPageState();
}

class _InventoryStocktakeFormPageState
    extends ConsumerState<InventoryStocktakeFormPage> {
  final _operator = TextEditingController();
  final _remark = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _operator.dispose();
    _remark.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _create(List<InventoryStockRow> rows) async {
    if (rows.isEmpty) return;
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(inventoryServiceProvider)
          .createStocktakeDraft(
            InventoryStocktakeDraft(
              stocktakeDate: _date,
              operatorName: _operator.text.trim().isEmpty
                  ? null
                  : _operator.text.trim(),
              remark: _remark.text.trim().isEmpty ? null : _remark.text.trim(),
              items: [
                for (final row in rows)
                  InventoryStocktakeLineDraft(
                    materialId: row.material.id,
                    actualQuantity: row.material.currentStock,
                  ),
              ],
            ),
          );
      ref.invalidate(inventoryStocktakesProvider);
      if (mounted) context.go('/inventory/stocktake/$id');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('创建失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = ref.watch(inventoryStockProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('新建库存盘点')),
      bottomNavigationBar: stock.valueOrNull?.isNotEmpty == true
          ? InventoryFormFooter(
              label: '创建盘点任务',
              icon: Icons.add_task,
              saving: _saving,
              buttonKey: const Key('inventory-stocktake-create'),
              onSave: () => _create(stock.valueOrNull!),
            )
          : null,
      body: stock.when(
        loading: () => const InventoryLoadingState(),
        error: (_, _) => InventoryErrorState(
          onRetry: () => ref.invalidate(inventoryStockProvider),
        ),
        data: (rows) => rows.isEmpty
            ? const InventoryEmptyState(title: '没有可盘点的物资', message: '先新增物资档案。')
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.calendar_month_outlined),
                            title: const Text('盘点日期'),
                            subtitle: Text(_dateLabel(_date)),
                            trailing: const Icon(Icons.edit_calendar_outlined),
                            onTap: _pickDate,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _operator,
                            decoration: const InputDecoration(
                              labelText: '盘点人（可选）',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _remark,
                            decoration: const InputDecoration(
                              labelText: '备注（可选）',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  InventorySection(
                    title: '盘点范围 · ${rows.length} 种物资',
                    icon: Icons.fact_check_outlined,
                    child: Column(
                      children: [
                        for (final row in rows)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(row.material.materialName),
                            subtitle: Text(
                              '${row.material.modelSpec ?? '未填型号'} · ${row.material.unitName}',
                            ),
                            trailing: Text('账面 ${row.material.currentStock}'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const SizedBox(height: 8),
                  Text(
                    '创建后可逐项录入实盘数量，确认时由库存服务统一登记盘盈或盘亏。',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}

String _dateLabel(DateTime value) =>
    '${value.year}年${value.month}月${value.day}日';
