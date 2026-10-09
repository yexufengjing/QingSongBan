import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';

import '../../../core/database/app_database.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_models.dart';
import 'widgets/inventory_widgets.dart';

class InventoryReceiptFormPage extends ConsumerStatefulWidget {
  const InventoryReceiptFormPage({super.key});

  @override
  ConsumerState<InventoryReceiptFormPage> createState() =>
      _InventoryReceiptFormPageState();
}

class _InventoryReceiptFormPageState
    extends ConsumerState<InventoryReceiptFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _source = TextEditingController();
  final _operator = TextEditingController();
  final _remark = TextEditingController();
  final List<_ReceiptLineState> _lines = [_ReceiptLineState()];
  DateTime _date = DateTime.now();
  String _type = 'central_store';
  bool _saving = false;

  @override
  void dispose() {
    _source.dispose();
    _operator.dispose();
    _remark.dispose();
    for (final line in _lines) {
      line.dispose();
    }
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

  Future<void> _save(List<InventoryMaterial> materials) async {
    if (!_formKey.currentState!.validate()) return;
    final lines = <InventoryReceiptLineDraft>[];
    for (final line in _lines) {
      final id = line.materialId;
      final quantity = double.tryParse(line.quantity.text.trim());
      if (id == null || quantity == null || quantity <= 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('请选择物资并填写大于 0 的数量')));
        return;
      }
      lines.add(
        InventoryReceiptLineDraft(
          materialId: id,
          quantity: quantity,
          remark: line.remark.text.trim().isEmpty
              ? null
              : line.remark.text.trim(),
        ),
      );
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(inventoryServiceProvider)
          .createReceipt(
            InventoryReceiptDraft(
              receiptDate: _date,
              receiptType: _type,
              sourceName: _source.text.trim().isEmpty
                  ? null
                  : _source.text.trim(),
              operatorName: _operator.text.trim().isEmpty
                  ? null
                  : _operator.text.trim(),
              remark: _remark.text.trim().isEmpty ? null : _remark.text.trim(),
              items: lines,
            ),
          );
      _invalidateLists();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('入库已保存，库存和流水已更新')));
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('入库失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _invalidateLists() {
    ref.invalidate(inventoryOverviewProvider);
    ref.invalidate(inventoryStockProvider);
    ref.invalidate(inventoryMaterialsProvider);
    ref.invalidate(inventoryWarningsProvider);
    ref.invalidate(inventoryReceiptsProvider);
    ref.invalidate(inventoryTransactionsProvider);
    ref.invalidate(inventoryReplenishmentsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final materials = ref.watch(inventoryMaterialsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('新增入库')),
      bottomNavigationBar: materials.valueOrNull?.isNotEmpty == true
          ? InventoryFormFooter(
              label: '保存入库单',
              icon: Icons.save_outlined,
              saving: _saving,
              buttonKey: const Key('inventory-receipt-submit'),
              onSave: () => _save(materials.valueOrNull!),
            )
          : null,
      body: materials.when(
        loading: () => const InventoryLoadingState(),
        error: (_, _) => InventoryErrorState(
          onRetry: () => ref.invalidate(inventoryMaterialsProvider),
        ),
        data: (items) => items.isEmpty
            ? InventoryEmptyState(
                title: '先新增物资档案',
                message: '入库单需要关联已有物资。',
                action: FilledButton.icon(
                  onPressed: () => context.push('/inventory/materials/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('新增物资'),
                ),
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.calendar_month_outlined,
                              ),
                              title: const Text('入库日期'),
                              subtitle: Text(_dateLabel(_date)),
                              trailing: const Icon(
                                Icons.edit_calendar_outlined,
                              ),
                              onTap: _pickDate,
                            ),
                            DropdownButtonFormField<String>(
                              initialValue: _type,
                              decoration: const InputDecoration(
                                labelText: '入库类型',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'central_store',
                                  child: Text('总库领取'),
                                ),
                                DropdownMenuItem(
                                  value: 'purchase',
                                  child: Text('采购入库'),
                                ),
                                DropdownMenuItem(
                                  value: 'return_in',
                                  child: Text('退回入库'),
                                ),
                                DropdownMenuItem(
                                  value: 'transfer_in',
                                  child: Text('调拨入库'),
                                ),
                                DropdownMenuItem(
                                  value: 'stocktake_gain',
                                  child: Text('盘盈入库'),
                                ),
                                DropdownMenuItem(
                                  value: 'other',
                                  child: Text('其他入库'),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _type = value ?? _type),
                            ),
                            TextFormField(
                              controller: _source,
                              decoration: const InputDecoration(
                                labelText: '来源',
                              ),
                            ),
                            TextFormField(
                              controller: _operator,
                              decoration: const InputDecoration(
                                labelText: '经办人',
                              ),
                            ),
                            TextFormField(
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
                      title: '入库明细',
                      icon: Icons.list_alt_outlined,
                      trailing: IconButton(
                        tooltip: '添加明细',
                        onPressed: () =>
                            setState(() => _lines.add(_ReceiptLineState())),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      child: Column(
                        children: [
                          for (var index = 0; index < _lines.length; index++)
                            _ReceiptLineEditor(
                              key: ValueKey(_lines[index]),
                              state: _lines[index],
                              materials: items,
                              onRemove: _lines.length == 1
                                  ? null
                                  : () {
                                      setState(() {
                                        _lines.removeAt(index).dispose();
                                      });
                                    },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ReceiptLineState {
  int? materialId;
  final quantity = TextEditingController();
  final remark = TextEditingController();
  void dispose() {
    quantity.dispose();
    remark.dispose();
  }
}

class _ReceiptLineEditor extends StatefulWidget {
  const _ReceiptLineEditor({
    required this.state,
    required this.materials,
    this.onRemove,
    super.key,
  });
  final _ReceiptLineState state;
  final List<InventoryMaterial> materials;
  final VoidCallback? onRemove;

  @override
  State<_ReceiptLineEditor> createState() => _ReceiptLineEditorState();
}

class _ReceiptLineEditorState extends State<_ReceiptLineEditor> {
  @override
  Widget build(BuildContext context) {
    final material = widget.materials
        .where((item) => item.id == widget.state.materialId)
        .firstOrNull;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InventoryMaterialPickerField(
                    key: Key('receipt-material-${widget.key}'),
                    materials: widget.materials,
                    selectedId: widget.state.materialId,
                    onChanged: (value) =>
                        setState(() => widget.state.materialId = value),
                  ),
                ),
                if (widget.onRemove != null)
                  IconButton(
                    tooltip: '移除明细',
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '规格',
                fillColor: AppColors.lightBlue,
              ),
              child: Text(material?.modelSpec ?? '选择物资后显示规格'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.state.quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                suffixText: material?.unitName,
                labelText: '入库数量',
                hintText: '大于 0',
              ),
              validator: (value) {
                final quantity = double.tryParse(value ?? '');
                return quantity == null || quantity <= 0 ? '请输入大于 0 的数量' : null;
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.state.remark,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '明细备注（可选）'),
            ),
          ],
        ),
      ),
    );
  }
}

String _dateLabel(DateTime value) =>
    '${value.year}年${value.month.toString().padLeft(2, '0')}月${value.day.toString().padLeft(2, '0')}日';
