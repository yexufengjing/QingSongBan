import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/inventory_providers.dart';
import 'widgets/inventory_export_button.dart';
import 'widgets/inventory_widgets.dart';

class InventoryReceiptsPage extends ConsumerWidget {
  const InventoryReceiptsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('入库管理'),
      actions: const [InventoryExportButton()],
    ),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('inventory-receipt-add'),
      onPressed: () => context.push('/inventory/receipts/new'),
      icon: const Icon(Icons.add),
      label: const Text('新增入库'),
    ),
    body: ref
        .watch(inventoryReceiptsProvider)
        .when(
          loading: () => const InventoryLoadingState(),
          error: (_, _) => InventoryErrorState(
            onRetry: () => ref.invalidate(inventoryReceiptsProvider),
          ),
          data: (receipts) => receipts.isEmpty
              ? InventoryEmptyState(
                  title: '暂无入库记录',
                  message: '从总库领取或采购后，登记第一笔入库。',
                  action: FilledButton.icon(
                    onPressed: () => context.push('/inventory/receipts/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('新增入库'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(inventoryReceiptsProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
                    itemCount: receipts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _ReceiptCard(receipt: receipts[index]),
                  ),
                ),
        ),
  );
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.receipt});
  final InventoryReceipt receipt;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      key: Key('inventory-receipt-${receipt.id}'),
      onTap: () => context.push('/inventory/receipts/${receipt.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.south_west_rounded, color: AppColors.primary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _receiptType(receipt.receiptType),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  _dateLabel(receipt.receiptDate),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('单号：${receipt.receiptNo}'),
            Text(
              '来源：${receipt.sourceName ?? '未填写'} · 经办人：${receipt.operatorNameSnapshot ?? '未填写'}',
            ),
            if ((receipt.remark ?? '').isNotEmpty) Text('备注：${receipt.remark}'),
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(Icons.chevron_right, color: AppColors.helper),
            ),
          ],
        ),
      ),
    ),
  );
}

String _receiptType(String value) => switch (value) {
  'central_store' => '总库领取入库',
  'purchase' => '采购入库',
  'return_in' => '退回入库',
  'transfer_in' => '调拨入库',
  'stocktake_gain' => '盘盈入库',
  _ => '其他入库',
};

String _dateLabel(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
