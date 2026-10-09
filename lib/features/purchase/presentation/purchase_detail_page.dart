import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/purchase_providers.dart';
import '../domain/purchase_models.dart';
import '../domain/purchase_status.dart';
import '../purchase_routes.dart';
import 'purchase_oa_navigation.dart';
import 'widgets/purchase_widgets.dart';

class PurchaseDetailPage extends ConsumerWidget {
  const PurchaseDetailPage({required this.requestId, super.key});
  final int requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(purchaseDetailProvider(requestId));
    return PurchasePageTheme(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('采购详情'),
          actions: [
            PopupMenuButton<String>(
              tooltip: '调整状态',
              icon: const Icon(Icons.more_horiz),
              onSelected: (item) => item == 'delete'
                  ? _softDelete(context, ref, value.valueOrNull)
                  : _changeStatus(
                      context,
                      ref,
                      value.valueOrNull,
                      PurchaseStatus.parse(item),
                    ),
              itemBuilder: (context) => [
                for (final status in PurchaseStatus.values)
                  PopupMenuItem(
                    value: status.storageValue,
                    child: Text('设为${status.label}'),
                  ),
                if (value.valueOrNull?.stockEntries.isEmpty == true)
                  const PopupMenuItem(value: 'delete', child: Text('删除采购记录')),
              ],
            ),
          ],
        ),
        body: value.when(
          loading: () => const PurchaseLoadingState(),
          error: (error, stack) => PurchaseErrorState(
            onRetry: () => ref.invalidate(purchaseDetailProvider(requestId)),
          ),
          data: (detail) => detail == null
              ? const PurchaseEmptyState(
                  title: '采购记录不存在',
                  message: '该记录可能已被删除。',
                )
              : _DetailBody(
                  detail: detail,
                  onEdit: () => _editMetadata(context, ref, detail),
                ),
        ),
        bottomNavigationBar: value.valueOrNull == null
            ? null
            : SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: _DetailActions(
                  detail: value.valueOrNull!,
                  onEdit: () => _editMetadata(context, ref, value.valueOrNull!),
                  onApplied: () =>
                      _confirmApplied(context, ref, value.valueOrNull!),
                  onAssign: () => _assign(context, ref, value.valueOrNull!),
                  onReceive: () =>
                      _markPendingReceive(context, ref, value.valueOrNull!),
                  onStockIn: () =>
                      context.push(PurchaseRoutes.stockIn(requestId)),
                ),
              ),
      ),
    );
  }

  Future<void> _confirmApplied(
    BuildContext context,
    WidgetRef ref,
    PurchaseRequestDetail detail,
  ) async {
    var appliedDate = DateTime.now();
    final oaNo = TextEditingController();
    final oaTitle = TextEditingController();
    final oaUrl = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => PurchaseSheetResources(
        resources: [oaNo, oaTitle, oaUrl],
        child: _DateTextSheet(
          title: '确认已完成 OA 申报',
          dateLabel: 'OA申报日期',
          initialDate: appliedDate,
          fields: [
            PurchaseLabeledField(
              label: 'OA流程编号（可选）',
              child: TextField(controller: oaNo),
            ),
            const SizedBox(height: 10),
            PurchaseLabeledField(
              label: 'OA流程标题（可选）',
              child: TextField(controller: oaTitle),
            ),
            const SizedBox(height: 10),
            PurchaseLabeledField(
              label: 'OA流程链接（可选）',
              child: TextField(controller: oaUrl),
            ),
          ],
          onDate: (value) => appliedDate = value,
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await ref
            .read(purchaseRepositoryProvider)
            .confirmApplied(
              detail.summary.id,
              ConfirmAppliedInput(
                appliedDate: appliedDate,
                oaRequestNo: _nullable(oaNo.text),
                oaTitle: _nullable(oaTitle.text),
                oaUrl: _nullable(oaUrl.text),
              ),
            );
        _refresh(ref, detail.summary.id);
      } catch (error) {
        if (context.mounted) _message(context, '更新失败：$error');
      }
    }
  }

  Future<void> _assign(
    BuildContext context,
    WidgetRef ref,
    PurchaseRequestDetail detail,
  ) async {
    final department = TextEditingController(
      text: detail.purchaseDepartment ?? '',
    );
    final purchaser = TextEditingController(
      text: detail.summary.purchaserName ?? '',
    );
    var date = detail.summary.assignedDate ?? DateTime.now();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => PurchaseSheetResources(
        resources: [department, purchaser],
        child: _DateTextSheet(
          title: '采购执行信息',
          dateLabel: '分配日期',
          initialDate: date,
          fields: [
            PurchaseLabeledField(
              label: '采购分部（选填）',
              child: TextField(controller: department),
            ),
            const SizedBox(height: 10),
            PurchaseLabeledField(
              label: '采购执行人（选填）',
              child: TextField(controller: purchaser),
            ),
          ],
          onDate: (value) => date = value,
        ),
      ),
    );
    if (result == true) {
      try {
        await ref
            .read(purchaseRepositoryProvider)
            .assignPurchaser(
              detail.summary.id,
              AssignPurchaserInput(
                purchaseDepartment: _nullable(department.text),
                purchaserName: _nullable(purchaser.text),
                assignedDate: date,
              ),
            );
        _refresh(ref, detail.summary.id);
      } catch (error) {
        if (context.mounted) _message(context, '保存失败：$error');
      }
    }
  }

  Future<void> _markPendingReceive(
    BuildContext context,
    WidgetRef ref,
    PurchaseRequestDetail detail,
  ) async {
    var date = DateTime.now();
    final location = TextEditingController(
      text: detail.summary.receiveLocation ?? '',
    );
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => PurchaseSheetResources(
        resources: [location],
        child: _DateTextSheet(
          title: '收到物资入厂通知',
          dateLabel: '通知日期',
          initialDate: date,
          fields: [
            PurchaseLabeledField(
              label: '领取地点（选填）',
              child: TextField(controller: location),
            ),
          ],
          onDate: (value) => date = value,
          actionLabel: '设为待领取',
        ),
      ),
    );
    if (result == true) {
      try {
        await ref
            .read(purchaseRepositoryProvider)
            .markPendingReceive(
              detail.summary.id,
              PendingReceiveInput(
                arrivalNoticeDate: date,
                receiveLocation: _nullable(location.text),
              ),
            );
        _refresh(ref, detail.summary.id);
      } catch (error) {
        if (context.mounted) _message(context, '更新失败：$error');
      }
    }
  }

  Future<void> _editMetadata(
    BuildContext context,
    WidgetRef ref,
    PurchaseRequestDetail detail,
  ) async {
    final title = TextEditingController(text: detail.summary.title);
    final reason = TextEditingController(text: detail.demandReason ?? '');
    final remark = TextEditingController(text: detail.remark ?? '');
    final oaNo = TextEditingController(text: detail.oaRequestNo ?? '');
    final oaTitle = TextEditingController(text: detail.oaTitle ?? '');
    final oaUrl = TextEditingController(text: detail.oaUrl ?? '');
    final department = TextEditingController(
      text: detail.purchaseDepartment ?? '',
    );
    final purchaser = TextEditingController(
      text: detail.summary.purchaserName ?? '',
    );
    final location = TextEditingController(
      text: detail.summary.receiveLocation ?? '',
    );
    var requestDate = detail.summary.requestDate;
    var appliedDate = detail.summary.appliedDate;
    var assignedDate = detail.summary.assignedDate;
    var arrivalDate = detail.summary.arrivalNoticeDate;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => PurchaseSheetResources(
        resources: [
          title,
          reason,
          remark,
          oaNo,
          oaTitle,
          oaUrl,
          department,
          purchaser,
          location,
        ],
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              8,
              18,
              18 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: StatefulBuilder(
              builder: (context, setSheetState) => ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      (MediaQuery.sizeOf(context).height -
                              MediaQuery.viewInsetsOf(context).bottom -
                              88)
                          .clamp(180.0, MediaQuery.sizeOf(context).height),
                ),
                child: Column(
                  children: [
                    Text(
                      '编辑采购信息',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(top: 8),
                        children: [
                          PurchaseLabeledField(
                            label: '采购事项名称',
                            child: TextField(controller: title),
                          ),
                          const SizedBox(height: 8),
                          PurchaseLabeledField(
                            label: '需求原因',
                            child: TextField(controller: reason),
                          ),
                          _MetadataDateRow(
                            label: '创建日期',
                            value: requestDate,
                            onTap: () async {
                              final v = await pickPurchaseDate(
                                context,
                                initialDate: requestDate,
                              );
                              if (v != null) {
                                setSheetState(() => requestDate = v);
                              }
                            },
                          ),
                          _MetadataDateRow(
                            label: 'OA申报日期',
                            value: appliedDate,
                            onTap: () async {
                              final v = await pickPurchaseDate(
                                context,
                                initialDate: appliedDate,
                              );
                              if (v != null) {
                                setSheetState(() => appliedDate = v);
                              }
                            },
                          ),
                          PurchaseLabeledField(
                            label: 'OA流程编号',
                            child: TextField(controller: oaNo),
                          ),
                          const SizedBox(height: 8),
                          PurchaseLabeledField(
                            label: 'OA流程标题',
                            child: TextField(controller: oaTitle),
                          ),
                          const SizedBox(height: 8),
                          PurchaseLabeledField(
                            label: 'OA流程链接',
                            child: TextField(controller: oaUrl),
                          ),
                          _MetadataDateRow(
                            label: '分配日期',
                            value: assignedDate,
                            onTap: () async {
                              final v = await pickPurchaseDate(
                                context,
                                initialDate: assignedDate,
                              );
                              if (v != null) {
                                setSheetState(() => assignedDate = v);
                              }
                            },
                          ),
                          PurchaseLabeledField(
                            label: '采购分部',
                            child: TextField(controller: department),
                          ),
                          const SizedBox(height: 8),
                          PurchaseLabeledField(
                            label: '采购执行人',
                            child: TextField(controller: purchaser),
                          ),
                          _MetadataDateRow(
                            label: '入厂通知日期',
                            value: arrivalDate,
                            onTap: () async {
                              final v = await pickPurchaseDate(
                                context,
                                initialDate: arrivalDate,
                              );
                              if (v != null) {
                                setSheetState(() => arrivalDate = v);
                              }
                            },
                          ),
                          PurchaseLabeledField(
                            label: '领取地点',
                            child: TextField(controller: location),
                          ),
                          const SizedBox(height: 8),
                          PurchaseLabeledField(
                            label: '备注',
                            child: TextField(
                              controller: remark,
                              minLines: 2,
                              maxLines: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('保存信息'),
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
    if (saved == true) {
      try {
        await ref
            .read(purchaseRepositoryProvider)
            .updatePurchaseMetadata(
              detail.summary.id,
              UpdatePurchaseMetadataInput(
                title: title.text.trim(),
                requestDate: requestDate,
                appliedDate: appliedDate,
                oaRequestNo: _nullable(oaNo.text),
                oaTitle: _nullable(oaTitle.text),
                oaUrl: _nullable(oaUrl.text),
                purchaseDepartment: _nullable(department.text),
                purchaserName: _nullable(purchaser.text),
                assignedDate: assignedDate,
                arrivalNoticeDate: arrivalDate,
                receiveLocation: _nullable(location.text),
                demandReason: _nullable(reason.text),
                remark: _nullable(remark.text),
              ),
            );
        _refresh(ref, detail.summary.id);
      } catch (error) {
        if (context.mounted) _message(context, '保存失败：$error');
      }
    }
  }

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    PurchaseRequestDetail? detail,
    PurchaseStatus target,
  ) async {
    if (detail == null || target == detail.summary.status) return;
    final current = detail.summary.status;
    final currentIndex = PurchaseStatus.normalFlow.indexOf(current);
    final targetIndex = PurchaseStatus.normalFlow.indexOf(target);
    final skipped =
        currentIndex < 0 || targetIndex < 0 || targetIndex != currentIndex + 1;
    final confirmed =
        !skipped ||
        await showDialog<bool>(
              context: context,
              builder: (context) => PurchasePageTheme(
                child: AlertDialog(
                  title: const Text('确认跳过采购状态'),
                  content: Text(
                    target == PurchaseStatus.stocked
                        ? '这只会将采购状态改为已入库，不会增加库存或创建库存流水。确定继续吗？'
                        : '当前操作将跳过部分采购状态，是否继续？',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('继续'),
                    ),
                  ],
                ),
              ),
            ) ==
            true;
    if (!confirmed) return;
    try {
      await ref
          .read(purchaseRepositoryProvider)
          .changeStatusManually(
            ManualPurchaseStatusInput(
              requestId: detail.summary.id,
              targetStatus: target,
              confirmed: true,
              remark: '手动调整状态',
            ),
          );
      _refresh(ref, detail.summary.id);
    } catch (error) {
      if (context.mounted) _message(context, '状态更新失败：$error');
    }
  }

  Future<void> _softDelete(
    BuildContext context,
    WidgetRef ref,
    PurchaseRequestDetail? detail,
  ) async {
    if (detail == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PurchasePageTheme(
        child: AlertDialog(
          title: const Text('删除采购记录'),
          content: const Text('确认将这条未入库采购记录移入回收状态？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认删除'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(purchaseRepositoryProvider).softDelete(detail.summary.id);
      if (context.mounted) context.pop();
      ref.invalidate(purchaseDashboardProvider);
      ref.invalidate(purchaseListProvider);
    } catch (error) {
      if (context.mounted) _message(context, '$error');
    }
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail, required this.onEdit});
  final PurchaseRequestDetail detail;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    children: [
      PurchasePanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PurchaseMaterialIcon(size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: PurchaseStatusChip(status: detail.summary.status),
                  ),
                  Text(
                    detail.summary.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  for (final item in detail.items) ...[
                    Text(
                      item.itemName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('型号：${item.specification ?? '无规格'}'),
                    Text(
                      '申报数量：${purchaseQuantityLabel(item.requestQuantity)} ${item.unit}',
                    ),
                  ],
                  if (detail.summary.appliedDate != null)
                    Text(
                      'OA申报日期：${purchaseShortDateLabel(detail.summary.appliedDate)}',
                    ),
                  if (detail.summary.status == PurchaseStatus.purchasing)
                    Text(
                      '当前已等待：${_waitingDays(detail.summary)}天',
                      style: const TextStyle(color: Color(0xFFFF8A1F)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      PurchasePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PurchaseSectionHeading('申报信息'),
            const SizedBox(height: 10),
            _InfoRow('需求原因', detail.demandReason),
            _InfoRow('创建日期', purchaseDateLabel(detail.summary.requestDate)),
            _InfoRow('OA申报日期', purchaseDateLabel(detail.summary.appliedDate)),
            _InfoRow('OA流程编号', detail.oaRequestNo),
            _InfoRow('OA流程标题', detail.oaTitle),
            if (detail.oaUrl != null && detail.oaUrl!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText('OA链接：${detail.oaUrl}'),
                  TextButton.icon(
                    onPressed: () => openPurchaseOaUrl(context, detail.oaUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('查看 OA 流程'),
                  ),
                ],
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      PurchasePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PurchaseSectionHeading(
              '采购执行信息',
              trailing: TextButton.icon(
                key: const Key('purchase-detail-edit-execution'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('编辑'),
              ),
            ),
            const SizedBox(height: 10),
            _InfoRow('采购分部', detail.purchaseDepartment),
            _InfoRow('采购执行人', detail.summary.purchaserName),
            _InfoRow('分配日期', purchaseDateLabel(detail.summary.assignedDate)),
            _InfoRow(
              '入厂通知日期',
              purchaseDateLabel(detail.summary.arrivalNoticeDate),
            ),
            _InfoRow('领取地点', detail.summary.receiveLocation),
            _InfoRow('备注', detail.remark),
          ],
        ),
      ),
      const SizedBox(height: 14),
      PurchasePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PurchaseSectionHeading('采购进度'),
            const SizedBox(height: 10),
            if (detail.statusLogs.isEmpty) const Text('暂无状态变更记录'),
            for (final (index, log) in detail.statusLogs.indexed)
              _TimelineRow(
                log: log,
                last: index == detail.statusLogs.length - 1,
                current:
                    index ==
                    detail.statusLogs.lastIndexWhere(
                      (entry) => entry.newStatus == detail.summary.status,
                    ),
              ),
            for (final status in _futureStatuses(detail))
              _FutureTimelineRow(status: status),
          ],
        ),
      ),
      const SizedBox(height: 14),
      PurchasePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PurchaseSectionHeading('物资明细'),
            const SizedBox(height: 10),
            for (final (index, item) in detail.items.indexed) ...[
              if (index > 0) const Divider(height: 22),
              Text(
                item.itemName,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text('规格：${item.specification ?? '未填写'} · 单位：${item.unit}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _QuantityInfo(
                      '申报数量',
                      item.requestQuantity,
                      item.unit,
                    ),
                  ),
                  Expanded(
                    child: _QuantityInfo(
                      '已入库',
                      item.receivedQuantity,
                      item.unit,
                      color: const Color(0xFF00A86B),
                    ),
                  ),
                  Expanded(
                    child: _QuantityInfo(
                      '剩余数量',
                      item.remainingQuantity,
                      item.unit,
                      color: const Color(0xFFFF8A1F),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _DetailActions extends StatelessWidget {
  const _DetailActions({
    required this.detail,
    required this.onEdit,
    required this.onApplied,
    required this.onAssign,
    required this.onReceive,
    required this.onStockIn,
  });
  final PurchaseRequestDetail detail;
  final VoidCallback onEdit;
  final VoidCallback onApplied;
  final VoidCallback onAssign;
  final VoidCallback onReceive;
  final VoidCallback onStockIn;

  @override
  Widget build(BuildContext context) {
    final action = switch (detail.summary.status) {
      PurchaseStatus.pendingApply => FilledButton(
        onPressed: onApplied,
        child: const Text('确认已申报'),
      ),
      PurchaseStatus.applied => FilledButton(
        onPressed: onAssign,
        child: const Text('填写采购信息'),
      ),
      PurchaseStatus.purchasing => FilledButton(
        onPressed: onReceive,
        child: const Text('设为待领取'),
      ),
      PurchaseStatus.pendingReceive => FilledButton(
        onPressed: onStockIn,
        child: const Text('采购入库'),
      ),
      _ => FilledButton.tonal(
        onPressed: onStockIn,
        child: const Text('历史补录入库'),
      ),
    };
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(onPressed: onEdit, child: const Text('编辑信息')),
        ),
        if (action is! SizedBox) ...[
          const SizedBox(width: 10),
          Expanded(child: action),
        ],
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.log,
    required this.last,
    required this.current,
  });
  final PurchaseStatusLogView log;
  final bool last;
  final bool current;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            children: [
              Icon(
                Icons.check_circle,
                size: 20,
                color: current
                    ? const Color(0xFF1677FF)
                    : const Color(0xFF00A86B),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 2, color: const Color(0xFFB9EAD1)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${purchaseShortDateLabel(log.changedAt)}  ${log.newStatus.label}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: current
                        ? const Color(0xFF1677FF)
                        : const Color(0xFF63758A),
                    fontWeight: current ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                if (log.remark?.isNotEmpty == true) Text(log.remark!),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

List<PurchaseStatus> _futureStatuses(PurchaseRequestDetail detail) {
  final currentIndex = PurchaseStatus.normalFlow.indexOf(detail.summary.status);
  if (currentIndex < 0) return const [];
  return PurchaseStatus.normalFlow.skip(currentIndex + 1).toList();
}

class _FutureTimelineRow extends StatelessWidget {
  const _FutureTimelineRow({required this.status});
  final PurchaseStatus status;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        const SizedBox(
          width: 28,
          child: Icon(
            Icons.radio_button_unchecked,
            size: 19,
            color: Color(0xFFB8C2CF),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${status.label} · 尚未发生',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 116,
          child: Text(
            '$label：',
            style: const TextStyle(color: Color(0xFF6A7D94)),
          ),
        ),
        Expanded(child: Text(value?.isNotEmpty == true ? value! : '未填写')),
      ],
    ),
  );
}

class _QuantityInfo extends StatelessWidget {
  const _QuantityInfo(this.label, this.value, this.unit, {this.color});
  final String label;
  final double value;
  final String unit;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Text(
        '${purchaseQuantityLabel(value)} $unit',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
      ),
    ],
  );
}

class _MetadataDateRow extends StatelessWidget {
  const _MetadataDateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(purchaseDateLabel(value)),
    trailing: const Icon(Icons.calendar_month_outlined),
    onTap: onTap,
  );
}

class _DateTextSheet extends StatefulWidget {
  const _DateTextSheet({
    required this.title,
    required this.dateLabel,
    required this.initialDate,
    required this.fields,
    required this.onDate,
    this.actionLabel = '确认',
  });
  final String title;
  final String dateLabel;
  final DateTime initialDate;
  final List<Widget> fields;
  final ValueChanged<DateTime> onDate;
  final String actionLabel;

  @override
  State<_DateTextSheet> createState() => _DateTextSheetState();
}

class _DateTextSheetState extends State<_DateTextSheet> {
  late DateTime _date = widget.initialDate;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.dateLabel),
              subtitle: Text(purchaseDateLabel(_date)),
              onTap: () async {
                final value = await pickPurchaseDate(
                  context,
                  initialDate: _date,
                );
                if (value != null) {
                  setState(() {
                    _date = value;
                    widget.onDate(value);
                  });
                }
              },
            ),
            ...widget.fields,
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(widget.actionLabel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();

int _waitingDays(PurchaseRequestSummary summary) {
  final start =
      summary.assignedDate ?? summary.appliedDate ?? summary.requestDate;
  if (start == null) return 0;
  final today = DateTime.now();
  return DateTime(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime(start.year, start.month, start.day)).inDays;
}

void _refresh(WidgetRef ref, int requestId) {
  ref.invalidate(purchaseDashboardProvider);
  ref.invalidate(purchaseListProvider);
  ref.invalidate(purchaseDetailProvider(requestId));
}

void _message(BuildContext context, String value) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
}
