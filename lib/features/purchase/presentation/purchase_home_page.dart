import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/design_widgets.dart';
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
    return PurchasePageTheme(
      child: Scaffold(
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
      DesignSection(
        child: DesignGrid(
          children: [
            for (final metric in [
              _MetricData(
                '待申报',
                data.pendingApplyCount,
                AppColors.warning,
                Icons.description_outlined,
                PurchaseRoutes.pendingApply,
              ),
              _MetricData(
                '已申报',
                data.appliedCount,
                AppColors.techBlue,
                Icons.task_alt_outlined,
                PurchaseRoutes.tracking,
              ),
              _MetricData(
                '采购中',
                data.purchasingCount,
                AppColors.success,
                Icons.shopping_cart_outlined,
                '${PurchaseRoutes.tracking}?status=purchasing',
              ),
              _MetricData(
                '待领取',
                data.pendingReceiveCount,
                AppColors.purple,
                Icons.inventory_2_outlined,
                PurchaseRoutes.pendingReceive,
              ),
            ])
              PurchaseMetricTile(
                label: metric.label,
                value: '${metric.value}',
                color: metric.color,
                icon: metric.icon,
                onTap: () => context.push(metric.route),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      PurchasePanel(
        child: InkWell(
          key: const Key('purchase-this-month-history'),
          onTap: () => context.push('/purchase/history?preset=month'),
          child: Row(
            children: [
              const DesignIcon(Icons.receipt_long_outlined),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '本月已入库',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${data.stockedThisMonthCount} 项',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      DesignSection(
        title: '需要处理',
        trailing: TextButton(
          onPressed: () => context.push('${PurchaseRoutes.tracking}?all=1'),
          child: const Text('查看全部'),
        ),
        child: data.actionRequired.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        color: AppColors.helper,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '暂无需要处理的采购记录。',
                        style: TextStyle(color: AppColors.body, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  for (final request in data.actionRequired.take(3)) ...[
                    _ActionCard(request: request),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
      const SizedBox(height: 12),
      DesignSection(
        title: '常用功能',
        child: DesignGrid(
          children: [
            for (final action in const [
              _QuickActionData(
                '新建采购',
                Icons.note_add_outlined,
                AppColors.techBlue,
                PurchaseRoutes.create,
              ),
              _QuickActionData(
                '待申报',
                Icons.description_outlined,
                AppColors.warning,
                PurchaseRoutes.pendingApply,
              ),
              _QuickActionData(
                '采购跟踪',
                Icons.shopping_cart_outlined,
                AppColors.success,
                PurchaseRoutes.tracking,
              ),
              _QuickActionData(
                '采购历史',
                Icons.inventory_2_outlined,
                AppColors.purple,
                PurchaseRoutes.history,
              ),
            ])
              _QuickAction(
                label: action.label,
                icon: action.icon,
                color: action.color,
                route: action.route,
              ),
          ],
        ),
      ),
    ],
  );
}

class _MetricData {
  const _MetricData(this.label, this.value, this.color, this.icon, this.route);
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final String route;
}

class _QuickActionData {
  const _QuickActionData(this.label, this.icon, this.color, this.route);
  final String label;
  final IconData icon;
  final Color color;
  final String route;
}

class _ActionCard extends ConsumerWidget {
  const _ActionCard({required this.request});
  final PurchaseRequestSummary request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(purchaseDetailProvider(request.id)).valueOrNull;
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
            borderRadius: BorderRadius.circular(12),
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
                      if (request.items.isEmpty)
                        Text(
                          request.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      for (final (index, item)
                          in request.items.take(3).indexed) ...[
                        Text(
                          item.itemName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: index == 0
                              ? Theme.of(context).textTheme.titleLarge
                              : Theme.of(context).textTheme.titleMedium,
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          children: [
                            if (item.specification?.isNotEmpty == true)
                              Text('规格：${item.specification}'),
                            Text(
                              '申报 ${purchaseQuantityLabel(item.requestQuantity)} ${item.unit}',
                            ),
                            if (request.status ==
                                PurchaseStatus.pendingReceive) ...[
                              Text(
                                '已入库 ${purchaseQuantityLabel(item.receivedQuantity)} ${item.unit}',
                                style: const TextStyle(
                                  color: Color(0xFF00A86B),
                                ),
                              ),
                              Text(
                                '剩余 ${purchaseQuantityLabel(item.remainingQuantity)} ${item.unit}',
                                style: const TextStyle(
                                  color: Color(0xFFFF8A1F),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (request.status == PurchaseStatus.pendingReceive) ...[
                        Text(
                          '收到通知：${purchaseShortDateLabel(request.arrivalNoticeDate)}',
                        ),
                        Text(
                          '领取地点：${request.receiveLocation?.isNotEmpty == true ? request.receiveLocation : '未填写'}',
                        ),
                        if (request.items.any(
                          (item) => item.receivedQuantity > 0,
                        ))
                          _ReceiveProgress(items: request.items),
                      ],
                      if (request.status == PurchaseStatus.pendingApply &&
                          detail?.demandReason?.isNotEmpty == true)
                        Text('需求原因：${detail!.demandReason}'),
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
          const Divider(height: 20),
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
        label: Text(
          request.items.any((item) => item.receivedQuantity > 0)
              ? '继续入库'
              : '入库',
        ),
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
      backgroundColor: Colors.white,
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
              builder: (context, setSheetState) => SingleChildScrollView(
                child: Column(
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
                    PurchaseLabeledField(
                      label: '领取地点（选填）',
                      child: TextField(controller: location),
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
    required this.color,
    required this.route,
  });
  final String label;
  final IconData icon;
  final Color color;
  final String route;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            DesignIcon(icon, color: color),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.ink, fontSize: 14),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReceiveProgress extends StatelessWidget {
  const _ReceiveProgress({required this.items});
  final List<PurchaseRequestItemView> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items.where(
            (entry) => entry.receivedQuantity > 0,
          )) ...[
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: item.requestQuantity <= 0
                        ? 0
                        : (item.receivedQuantity / item.requestQuantity).clamp(
                            0.0,
                            1.0,
                          ),
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${item.requestQuantity <= 0 ? 0 : (item.receivedQuantity / item.requestQuantity * 100).round()}%',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${items.length > 1 ? '${item.itemName}：' : ''}部分入库，仍有${purchaseQuantityLabel(item.remainingQuantity)}${item.unit}待领取',
              style: const TextStyle(color: Color(0xFF00A86B)),
            ),
          ],
        ],
      ),
    );
  }
}
