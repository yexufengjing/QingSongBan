import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/purchase_providers.dart';
import '../domain/purchase_models.dart';
import '../domain/purchase_status.dart';
import '../purchase_routes.dart';
import 'purchase_reminder_navigation.dart';
import 'widgets/purchase_reminder_info.dart';
import 'widgets/purchase_widgets.dart';

class PurchaseHomePage extends ConsumerWidget {
  const PurchaseHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(purchaseDashboardProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('采购管理')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('purchase-home-create'),
        onPressed: () => context.push(PurchaseRoutes.create),
        icon: const Icon(Icons.add),
        label: const Text('新建采购'),
      ),
      body: dashboard.when(
        loading: () => const PurchaseLoadingState(),
        error: (error, stack) => PurchaseErrorState(
          onRetry: () => ref.invalidate(purchaseDashboardProvider),
        ),
        data: (data) => _DashboardContent(data: data),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data});
  final PurchaseDashboardData data;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    children: [
      PurchasePanel(
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final metrics = [
                  _MetricData(
                    '待申报',
                    data.pendingApplyCount,
                    Colors.orange,
                    PurchaseRoutes.pendingApply,
                  ),
                  _MetricData(
                    '已申报',
                    data.appliedCount,
                    const Color(0xFF1677FF),
                    PurchaseRoutes.tracking,
                  ),
                  _MetricData(
                    '采购中',
                    data.purchasingCount,
                    const Color(0xFF10B7A3),
                    '${PurchaseRoutes.tracking}?status=purchasing',
                  ),
                  _MetricData(
                    '待领取',
                    data.pendingReceiveCount,
                    Colors.deepOrange,
                    PurchaseRoutes.pendingReceive,
                  ),
                ];
                final twoColumns =
                    constraints.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(16) > 20;
                final columns = twoColumns ? 2 : 4;
                final spacing = 8.0;
                final width =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: 8,
                  children: [
                    for (final metric in metrics)
                      SizedBox(
                        width: width,
                        child: PurchaseMetricTile(
                          label: metric.label,
                          value: '${metric.value}',
                          color: metric.color,
                          icon: twoColumns ? Icons.description_outlined : null,
                          onTap: () => context.push(metric.route),
                        ),
                      ),
                  ],
                );
              },
            ),
            const Divider(height: 24),
            InkWell(
              key: const Key('purchase-this-month-history'),
              onTap: () => context.push('/purchase/history?preset=month'),
              child: Row(
                children: [
                  const Icon(
                    Icons.home_work_outlined,
                    color: Color(0xFF00C16B),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('本月已入库')),
                  Text(
                    '${data.stockedThisMonthCount} 项',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF00C16B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      PurchaseSectionHeading(
        '需要处理',
        trailing: TextButton(
          onPressed: () => context.push('${PurchaseRoutes.tracking}?all=1'),
          child: const Text('查看全部'),
        ),
      ),
      const SizedBox(height: 10),
      if (data.actionRequired.isEmpty)
        const PurchasePanel(child: Text('暂无需要处理的采购记录。'))
      else
        for (final request in data.actionRequired.take(8)) ...[
          _ActionCard(request: request),
          const SizedBox(height: 10),
        ],
      const SizedBox(height: 10),
      const PurchaseSectionHeading('常用功能'),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _QuickAction(
            label: '新建采购',
            icon: Icons.add_circle_outline,
            route: PurchaseRoutes.create,
          ),
          _QuickAction(
            label: '待申报',
            icon: Icons.assignment_outlined,
            route: PurchaseRoutes.pendingApply,
          ),
          _QuickAction(
            label: '采购跟踪',
            icon: Icons.shopping_cart_outlined,
            route: PurchaseRoutes.tracking,
          ),
          _QuickAction(
            label: '采购历史',
            icon: Icons.history,
            route: PurchaseRoutes.history,
          ),
        ],
      ),
    ],
  );
}

class _MetricData {
  const _MetricData(this.label, this.value, this.color, this.route);
  final String label;
  final int value;
  final Color color;
  final String route;
}

class _ActionCard extends ConsumerWidget {
  const _ActionCard({required this.request});
  final PurchaseRequestSummary request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminderId = ref
        .watch(purchaseReminderIdProvider(request.id))
        .valueOrNull;
    final hasReminderRecord = request.hasReminder || reminderId != null;
    return PurchasePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: Key('purchase-action-${request.id}'),
            onTap: () => context.push(PurchaseRoutes.detail(request.id)),
            borderRadius: BorderRadius.circular(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PurchaseMaterialIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PurchaseStatusChip(status: request.status),
                      const SizedBox(height: 6),
                      Text(
                        request.itemNames.join('、').isEmpty
                            ? request.title
                            : request.itemNames.join('、'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      for (final item in request.items.take(3))
                        Text(
                          '${item.itemName} ${purchaseQuantityLabel(item.requestQuantity)} ${item.unit}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (request.status == PurchaseStatus.pendingReceive) ...[
                        Text(
                          '入厂通知：${purchaseShortDateLabel(request.arrivalNoticeDate)}',
                        ),
                        Text(
                          '领取地点：${request.receiveLocation?.isNotEmpty == true ? request.receiveLocation : '未填写'}',
                        ),
                      ],
                      if (request.purchaserName != null)
                        Text('执行人：${request.purchaserName}'),
                      if (request.status == PurchaseStatus.purchasing ||
                          request.status == PurchaseStatus.applied)
                        Text(
                          'OA申报：${purchaseShortDateLabel(request.appliedDate)}',
                        ),
                      if (request.status == PurchaseStatus.purchasing) ...[
                        Text(
                          '分配日期：${purchaseShortDateLabel(request.assignedDate)}',
                        ),
                        Text(
                          '已等待${_waitingDays(request)}天',
                          style: const TextStyle(color: Color(0xFF1677FF)),
                        ),
                      ],
                      if (request.status == PurchaseStatus.pendingReceive)
                        PurchaseReminderInfo(requestId: request.id),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF70839A)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: _actions(context, ref, hasReminderRecord),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    WidgetRef ref,
    bool hasReminderRecord,
  ) => switch (request.status) {
    PurchaseStatus.pendingReceive => [
      OutlinedButton.icon(
        key: Key('purchase-home-reminder-${request.id}'),
        onPressed: () => openPurchaseReminder(
          context,
          ref,
          requestId: request.id,
          content: request.items
              .map(
                (item) =>
                    '${item.itemName} ${purchaseQuantityLabel(item.remainingQuantity)}${item.unit}',
              )
              .join('、'),
        ),
        icon: Icon(
          hasReminderRecord
              ? Icons.edit_calendar_outlined
              : Icons.notifications_active_outlined,
        ),
        label: Text(hasReminderRecord ? '修改提醒' : '设置提醒'),
      ),
      FilledButton.icon(
        onPressed: () => context.push(PurchaseRoutes.stockIn(request.id)),
        icon: const Icon(Icons.move_to_inbox_outlined),
        label: const Text('入库'),
      ),
    ],
    PurchaseStatus.purchasing => [
      OutlinedButton(
        onPressed: () => context.push(PurchaseRoutes.detail(request.id)),
        child: const Text('查看详情'),
      ),
      FilledButton.icon(
        onPressed: () => _markPendingReceive(context, ref),
        icon: const Icon(Icons.inventory_2_outlined),
        label: const Text('设为待领取'),
      ),
    ],
    PurchaseStatus.pendingApply => [
      OutlinedButton(
        onPressed: () =>
            context.push('${PurchaseRoutes.create}?editId=${request.id}'),
        child: const Text('编辑'),
      ),
      FilledButton(
        onPressed: () => context.push(PurchaseRoutes.pendingApply),
        child: const Text('确认已申报'),
      ),
    ],
    PurchaseStatus.applied => [
      OutlinedButton(
        onPressed: () => context.push(PurchaseRoutes.detail(request.id)),
        child: const Text('查看详情'),
      ),
      FilledButton.icon(
        onPressed: () => context.push(PurchaseRoutes.tracking),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('填写采购信息'),
      ),
    ],
    _ => [
      OutlinedButton(
        onPressed: () => context.push(PurchaseRoutes.detail(request.id)),
        child: const Text('查看详情'),
      ),
    ],
  };

  Future<void> _markPendingReceive(BuildContext context, WidgetRef ref) async {
    final date = ValueNotifier<DateTime>(DateTime.now());
    final location = TextEditingController(text: request.receiveLocation ?? '');
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => PurchaseSheetResources(
        resources: [date, location],
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: StatefulBuilder(
              builder: (context, setSheetState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '收到物资入厂通知',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('通知日期'),
                    subtitle: Text(purchaseDateLabel(date.value)),
                    onTap: () async {
                      final result = await pickPurchaseDate(
                        context,
                        initialDate: date.value,
                      );
                      if (result != null) {
                        setSheetState(() => date.value = result);
                      }
                    },
                  ),
                  TextField(
                    controller: location,
                    decoration: const InputDecoration(labelText: '领取地点（选填）'),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('设为待领取'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(purchaseRepositoryProvider)
            .markPendingReceive(
              request.id,
              PendingReceiveInput(
                arrivalNoticeDate: date.value,
                receiveLocation: location.text.trim().isEmpty
                    ? null
                    : location.text.trim(),
              ),
            );
        ref.invalidate(purchaseDashboardProvider);
        ref.invalidate(purchaseListProvider);
        ref.invalidate(purchaseDetailProvider(request.id));
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('更新失败：$error')));
        }
      }
    }
  }
}

int _waitingDays(PurchaseRequestSummary request) {
  final start =
      request.assignedDate ?? request.appliedDate ?? request.requestDate;
  if (start == null) return 0;
  final startDay = DateTime(start.year, start.month, start.day);
  final today = DateTime.now();
  return DateTime(
    today.year,
    today.month,
    today.day,
  ).difference(startDay).inDays;
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.route,
  });
  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 42) / 2,
    child: OutlinedButton.icon(
      onPressed: () => context.push(route),
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        alignment: Alignment.centerLeft,
      ),
    ),
  );
}
