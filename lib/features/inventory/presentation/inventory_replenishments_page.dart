import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/inventory_providers.dart';
import '../domain/inventory_models.dart';
import 'widgets/inventory_export_button.dart';
import 'widgets/inventory_widgets.dart';

class InventoryReplenishmentsPage extends ConsumerWidget {
  const InventoryReplenishmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('待采购 / 待补充'),
      actions: [
        IconButton(
          tooltip: '新增待补充',
          onPressed: () => _showCreateDialog(context, ref),
          icon: const Icon(Icons.add),
        ),
        const InventoryExportButton(),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('inventory-replenishment-new'),
      onPressed: () => _showCreateDialog(context, ref),
      icon: const Icon(Icons.add),
      label: const Text('新增清单项'),
    ),
    body: ref
        .watch(inventoryReplenishmentsProvider)
        .when(
          loading: () => const InventoryLoadingState(),
          error: (_, _) => InventoryErrorState(
            onRetry: () => ref.invalidate(inventoryReplenishmentsProvider),
          ),
          data: (items) => items.isEmpty
              ? InventoryEmptyState(
                  title: '待补充清单为空',
                  message: '可以手动新建，或从库存预警中一键加入。',
                  action: FilledButton.icon(
                    onPressed: () => _showCreateDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('新增清单项'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(inventoryReplenishmentsProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _ReplenishmentCard(item: items[index]),
                  ),
                ),
        ),
  );

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<InventoryReplenishmentDraft>(
      context: context,
      builder: (context) => const _CreateReplenishmentDialog(),
    );
    if (draft == null || !context.mounted) return;
    try {
      await ref.read(inventoryServiceProvider).createReplenishment(draft);
      ref.invalidate(inventoryReplenishmentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已新增待补充事项')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    }
  }
}

class _ReplenishmentCard extends ConsumerStatefulWidget {
  const _ReplenishmentCard({required this.item});
  final InventoryReplenishmentItem item;

  @override
  ConsumerState<_ReplenishmentCard> createState() => _ReplenishmentCardState();
}

class _ReplenishmentCardState extends ConsumerState<_ReplenishmentCard> {
  bool _saving = false;

  Future<void> _setStatus(String status) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(inventoryServiceProvider)
          .updateReplenishmentStatus(widget.item.id, status);
      ref.invalidate(inventoryReplenishmentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('状态已更新：${_statusLabel(status)}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('更新失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final color = switch (item.status) {
      'received' => AppColors.primary,
      'ordered' => AppColors.techBlue,
      'submitted' => AppColors.techBlue,
      'cancelled' => AppColors.helper,
      _ => const Color(0xFFE98500),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.materialNameSnapshot,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                InventoryStatusChip(
                  label: _statusLabel(item.status),
                  color: color,
                ),
                PopupMenuButton<String>(
                  enabled: !_saving,
                  tooltip: '更新补充状态',
                  onSelected: _setStatus,
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'pending', child: Text('待处理')),
                    PopupMenuItem(value: 'submitted', child: Text('已申报')),
                    PopupMenuItem(value: 'ordered', child: Text('已采购 / 已领取')),
                    PopupMenuItem(value: 'received', child: Text('已入库 / 已领取')),
                    PopupMenuItem(value: 'cancelled', child: Text('取消')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text('型号：${item.modelSnapshot ?? '未填写'} · 单位：${item.unitSnapshot}'),
            const Divider(height: 20),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                _ReplenishmentDatum(
                  label: '当前库存',
                  value: '${item.currentStockSnapshot} ${item.unitSnapshot}',
                ),
                _ReplenishmentDatum(
                  label: '最低库存',
                  value: '${item.minStockSnapshot} ${item.unitSnapshot}',
                ),
                _ReplenishmentDatum(
                  label: '建议补充',
                  value: '${item.suggestedQuantity}',
                ),
                _ReplenishmentDatum(
                  label: '计划数量',
                  value: '${item.plannedQuantity ?? '未填写'}',
                ),
                _ReplenishmentDatum(
                  label: '补充方式',
                  value: _methodLabel(item.replenishMethod),
                ),
              ],
            ),
            if ((item.reason ?? '').isNotEmpty ||
                (item.remark ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '原因：${item.reason ?? item.remark}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 5),
            Text(
              '创建于 ${_dateLabel(item.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplenishmentDatum extends StatelessWidget {
  const _ReplenishmentDatum({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 105,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

class _CreateReplenishmentDialog extends StatefulWidget {
  const _CreateReplenishmentDialog();

  @override
  State<_CreateReplenishmentDialog> createState() =>
      _CreateReplenishmentDialogState();
}

class _CreateReplenishmentDialogState
    extends State<_CreateReplenishmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _unit = TextEditingController(text: '件');
  final _quantity = TextEditingController();
  final _reason = TextEditingController();
  String _method = 'central_store';

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('新增待补充事项'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: '物资名称'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入物资名称' : null,
            ),
            TextFormField(
              controller: _unit,
              decoration: const InputDecoration(labelText: '单位'),
            ),
            TextFormField(
              controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '计划补充数量'),
              validator: (value) {
                final number = double.tryParse(value ?? '');
                return number == null || number <= 0 ? '请输入大于 0 的数量' : null;
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: '补充方式'),
              items: const [
                DropdownMenuItem(value: 'central_store', child: Text('总库领取')),
                DropdownMenuItem(value: 'purchase', child: Text('外部采购')),
                DropdownMenuItem(value: 'other', child: Text('其他')),
              ],
              onChanged: (value) => setState(() => _method = value ?? _method),
            ),
            TextFormField(
              controller: _reason,
              decoration: const InputDecoration(labelText: '需求原因（可选）'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          final quantity = double.parse(_quantity.text.trim());
          Navigator.pop(
            context,
            InventoryReplenishmentDraft(
              materialName: _name.text.trim(),
              unitName: _unit.text.trim().isEmpty ? '件' : _unit.text.trim(),
              currentStock: 0,
              minStock: 0,
              suggestedQuantity: quantity,
              plannedQuantity: quantity,
              replenishMethod: _method,
              reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
            ),
          );
        },
        child: const Text('保存'),
      ),
    ],
  );
}

String _statusLabel(String status) => switch (status) {
  'submitted' => '已申报',
  'ordered' => '已采购 / 已领取',
  'received' => '已入库',
  'cancelled' => '已取消',
  _ => '待处理',
};

String _methodLabel(String method) => switch (method) {
  'purchase' => '外部采购',
  'other' => '其他',
  _ => '总库领取',
};

String _dateLabel(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
