import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/inventory_providers.dart';
import 'widgets/inventory_widgets.dart';

class InventoryReceiptDetailPage extends ConsumerStatefulWidget {
  const InventoryReceiptDetailPage({required this.receiptId, super.key});
  final int receiptId;

  @override
  ConsumerState<InventoryReceiptDetailPage> createState() =>
      _InventoryReceiptDetailPageState();
}

class _InventoryReceiptDetailPageState
    extends ConsumerState<InventoryReceiptDetailPage> {
  late Future<InventoryReceipt?> _receipt;
  late Future<List<InventoryReceiptItem>> _items;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final service = ref.read(inventoryServiceProvider);
    _receipt = service.getReceipt(widget.receiptId);
    _items = service.getReceiptItems(widget.receiptId);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤销这笔入库？'),
        content: const Text('库存将按入库明细反向调整，并生成对应流水。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('撤销入库'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(inventoryServiceProvider).deleteReceipt(widget.receiptId);
      ref.invalidate(inventoryReceiptsProvider);
      ref.invalidate(inventoryStockProvider);
      ref.invalidate(inventoryMaterialsProvider);
      ref.invalidate(inventoryOverviewProvider);
      ref.invalidate(inventoryWarningsProvider);
      ref.invalidate(inventoryTransactionsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('撤销失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('入库详情'),
      actions: [
        IconButton(
          tooltip: _deleting ? '正在撤销' : '撤销入库',
          onPressed: _deleting ? null : _delete,
          icon: _deleting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline),
        ),
      ],
    ),
    body: FutureBuilder<InventoryReceipt?>(
      future: _receipt,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return InventoryErrorState(onRetry: () => setState(_load));
        }
        if (!snapshot.hasData) return const InventoryLoadingState();
        final receipt = snapshot.data;
        if (receipt == null) return const InventoryEmptyState(title: '入库单不存在');
        return FutureBuilder<List<InventoryReceiptItem>>(
          future: _items,
          builder: (context, itemSnapshot) {
            if (itemSnapshot.hasError) {
              return InventoryErrorState(onRetry: () => setState(_load));
            }
            if (!itemSnapshot.hasData) return const InventoryLoadingState();
            final items = itemSnapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receipt.receiptNo,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        _InfoLine(
                          label: '入库日期',
                          value: _dateLabel(receipt.receiptDate),
                        ),
                        _InfoLine(
                          label: '入库类型',
                          value: _receiptType(receipt.receiptType),
                        ),
                        _InfoLine(
                          label: '来源',
                          value: receipt.sourceName ?? '未填写',
                        ),
                        _InfoLine(
                          label: '经办人',
                          value: receipt.operatorNameSnapshot ?? '未填写',
                        ),
                        _InfoLine(
                          label: '备注',
                          value: receipt.remark ?? '无',
                          last: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                InventorySection(
                  title: '入库明细',
                  icon: Icons.list_alt_outlined,
                  child: items.isEmpty
                      ? const InventoryEmptyState(title: '没有明细')
                      : Column(
                          children: [
                            for (final item in items)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(item.materialNameSnapshot),
                                subtitle: Text(
                                  '${item.modelSnapshot ?? '未填型号'} · ${item.remark ?? '无备注'}',
                                ),
                                trailing: Text(
                                  '+${item.quantity} ${item.unitSnapshot}',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.last = false,
  });
  final String label;
  final String value;
  final bool last;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: last
        ? null
        : const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
    child: Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(child: Text(value, textAlign: TextAlign.right)),
      ],
    ),
  );
}

String _receiptType(String value) => switch (value) {
  'central_store' => '总库领取',
  'purchase' => '采购入库',
  'return_in' => '退回入库',
  'transfer_in' => '调拨入库',
  'stocktake_gain' => '盘盈入库',
  _ => '其他入库',
};

String _dateLabel(DateTime value) =>
    '${value.year}年${value.month}月${value.day}日';
