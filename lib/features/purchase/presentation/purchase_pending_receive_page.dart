import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/purchase_providers.dart';
import '../domain/purchase_models.dart';
import '../domain/purchase_status.dart';
import '../purchase_routes.dart';
import 'purchase_page_providers.dart';
import 'purchase_reminder_navigation.dart';
import 'widgets/purchase_reminder_info.dart';
import 'widgets/purchase_widgets.dart';

class PurchasePendingReceivePage extends ConsumerStatefulWidget {
  const PurchasePendingReceivePage({super.key});

  @override
  ConsumerState<PurchasePendingReceivePage> createState() =>
      _PurchasePendingReceivePageState();
}

class _PurchasePendingReceivePageState
    extends ConsumerState<PurchasePendingReceivePage> {
  final _search = TextEditingController();
  PurchaseFilter _filter = const PurchaseFilter(
    statuses: {PurchaseStatus.pendingReceive},
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(purchaseRequestsByFilterProvider(_filter));
    return PurchasePageTheme(
      child: Scaffold(
        appBar: AppBar(title: const Text('待领取')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  TextField(
                    key: const Key('purchase-receive-search'),
                    controller: _search,
                    onChanged: (value) => setState(
                      () => _filter = _filter.copyWith(keyword: value),
                    ),
                    decoration: const InputDecoration(
                      hintText: '搜索物资名称 / 型号 / OA编号',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  requests.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stack) => const SizedBox.shrink(),
                    data: (items) => Row(
                      children: [
                        Expanded(
                          child: PurchaseMetricTile(
                            label: '待领取',
                            value: '${items.length} 项',
                            color: const Color(0xFFFF8A1F),
                            icon: Icons.inventory_2_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PurchaseMetricTile(
                            label: '已设置提醒',
                            value:
                                '${items.where((item) => item.hasReminder).length} 项',
                            color: const Color(0xFF00A85D),
                            icon: Icons.notifications_active_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: requests.when(
                loading: () => const PurchaseLoadingState(),
                error: (error, stack) => PurchaseErrorState(
                  onRetry: () =>
                      ref.invalidate(purchaseRequestsByFilterProvider(_filter)),
                ),
                data: (items) => items.isEmpty
                    ? const PurchaseEmptyState(
                        title: '暂无待领取物资',
                        message: '收到入厂通知后，可将采购记录设为待领取。',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: items.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ReceiveCard(request: items[index]),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiveCard extends ConsumerWidget {
  const _ReceiveCard({required this.request});
  final PurchaseRequestSummary request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminderId = ref
        .watch(purchaseReminderIdProvider(request.id))
        .valueOrNull;
    final hasReminderRecord = request.hasReminder || reminderId != null;
    final reminderContent = [
      request.items
          .map(
            (item) =>
                '${item.itemName} ${purchaseQuantityLabel(item.remainingQuantity)} $item.unit',
          )
          .join('、'),
      '领取地点：${request.receiveLocation ?? '未填写'}',
    ].join('，');
    return PurchasePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => context.push(PurchaseRoutes.detail(request.id)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PurchaseMaterialIcon(size: 82),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PurchaseStatusChip(
                        status: PurchaseStatus.pendingReceive,
                      ),
                      const SizedBox(height: 5),
                      if (request.items.isEmpty)
                        Text(
                          request.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      const SizedBox(height: 5),
                      for (final item in request.items)
                        _ItemReceiveInfo(item: item),
                      const SizedBox(height: 6),
                      Text(
                        '收到通知：${purchaseShortDateLabel(request.arrivalNoticeDate)}',
                      ),
                      Text(
                        '领取地点：${request.receiveLocation?.isNotEmpty == true ? request.receiveLocation : '未填写'}',
                      ),
                      const SizedBox(height: 4),
                      PurchaseReminderInfo(requestId: request.id),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const Divider(height: 24),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: Key('purchase-reminder-${request.id}'),
                onPressed: () => openPurchaseReminder(
                  context,
                  ref,
                  requestId: request.id,
                  content: reminderContent,
                ),
                icon: Icon(
                  hasReminderRecord
                      ? Icons.edit_calendar_outlined
                      : Icons.notifications_active_outlined,
                ),
                label: Text(hasReminderRecord ? '修改提醒' : '设置提醒'),
              ),
              FilledButton.icon(
                key: Key('purchase-stock-in-${request.id}'),
                onPressed: () =>
                    context.push(PurchaseRoutes.stockIn(request.id)),
                icon: const Icon(Icons.move_to_inbox_outlined),
                label: Text(
                  request.items.any((item) => item.receivedQuantity > 0)
                      ? '继续入库'
                      : '入库',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemReceiveInfo extends StatelessWidget {
  const _ItemReceiveInfo({required this.item});
  final PurchaseRequestItemView item;

  @override
  Widget build(BuildContext context) {
    final ratio = item.requestQuantity <= 0
        ? 0.0
        : (item.receivedQuantity / item.requestQuantity).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.itemName, style: Theme.of(context).textTheme.titleMedium),
          Text('型号：${item.specification ?? '无规格'}'),
          Text(
            '申报数量：${purchaseQuantityLabel(item.requestQuantity)} ${item.unit}',
          ),
          Text(
            '已入库：${purchaseQuantityLabel(item.receivedQuantity)} ${item.unit}',
            style: const TextStyle(color: Color(0xFF00A86B)),
          ),
          Text(
            '剩余数量：${purchaseQuantityLabel(item.remainingQuantity)} ${item.unit}',
            style: const TextStyle(color: Color(0xFFFF8A1F)),
          ),
          if (item.receivedQuantity > 0) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: ratio, minHeight: 7),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${(ratio * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '部分入库，仍有${purchaseQuantityLabel(item.remainingQuantity)}${item.unit}待领取',
              style: const TextStyle(color: Color(0xFF00A86B)),
            ),
          ],
        ],
      ),
    );
  }
}
