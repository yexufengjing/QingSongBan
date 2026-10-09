import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../inventory/application/inventory_providers.dart';
import '../application/purchase_providers.dart';
import '../domain/purchase_models.dart';
import '../domain/purchase_status.dart';
import '../purchase_routes.dart';
import 'purchase_page_providers.dart';
import 'widgets/purchase_widgets.dart';

class PurchasePendingApplyPage extends ConsumerStatefulWidget {
  const PurchasePendingApplyPage({super.key});

  @override
  ConsumerState<PurchasePendingApplyPage> createState() =>
      _PurchasePendingApplyPageState();
}

class _PurchasePendingApplyPageState
    extends ConsumerState<PurchasePendingApplyPage> {
  final _searchController = TextEditingController();
  PurchaseFilter _filter = const PurchaseFilter(
    statuses: {PurchaseStatus.pendingApply},
  );

  @override
  void initState() => super.initState();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(purchaseRequestsByFilterProvider(_filter));
    return PurchasePageTheme(
      child: Scaffold(
        appBar: AppBar(title: const Text('待申报')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  TextField(
                    key: const Key('purchase-pending-search'),
                    controller: _searchController,
                    onChanged: (value) => setState(
                      () => _filter = _filter.copyWith(keyword: value),
                    ),
                    decoration: InputDecoration(
                      hintText: '搜索物资名称 / 型号 / OA编号',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _filter.keyword.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(
                                  () => _filter = _filter.copyWith(keyword: ''),
                                );
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final reason in const [
                          null,
                          '库存不足',
                          '临时需求',
                          '设备维修',
                          '其他',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(reason ?? '全部'),
                              selected: _filter.demandReason == reason,
                              selectedColor: const Color(0xFF2563EB),
                              labelStyle: TextStyle(
                                color: _filter.demandReason == reason
                                    ? Colors.white
                                    : const Color(0xFF425D7F),
                                fontWeight: FontWeight.w600,
                              ),
                              side: BorderSide(
                                color: _filter.demandReason == reason
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFE0EAF5),
                              ),
                              onSelected: (_) => setState(
                                () => _filter = _filter.copyWith(
                                  demandReason: reason,
                                  clearDemandReason: reason == null,
                                ),
                              ),
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
                    ? PurchaseEmptyState(
                        title: '暂无待申报采购',
                        message: '库存不足或有新的物资需求时，可新建采购记录。',
                        action: FilledButton.icon(
                          onPressed: () => context.push(PurchaseRoutes.create),
                          icon: const Icon(Icons.add),
                          label: const Text('新建采购'),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        itemCount: items.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PendingApplyCard(request: items[index]),
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

class _PendingApplyCard extends ConsumerWidget {
  const _PendingApplyCard({required this.request});
  final PurchaseRequestSummary request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(purchaseDetailProvider(request.id)).valueOrNull;
    final materials =
        ref.watch(inventoryMaterialsProvider).valueOrNull ?? const [];
    final materialById = {for (final item in materials) item.id: item};
    return PurchasePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => context.push(PurchaseRoutes.detail(request.id)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PurchaseMaterialIcon(size: 76),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PurchaseStatusChip(
                        status: PurchaseStatus.pendingApply,
                      ),
                      const SizedBox(height: 5),
                      if (request.items.isEmpty)
                        Text(
                          request.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      for (final item in request.items.take(3)) ...[
                        Text(
                          item.itemName,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '型号：${item.specification?.isNotEmpty == true ? item.specification : '未填写'}',
                        ),
                        Text(
                          '数量：${purchaseQuantityLabel(item.requestQuantity)} ${item.unit}',
                        ),
                      ],
                      if (request.items.isEmpty)
                        Text(
                          request.itemNames.join('、'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      for (final item in request.items.take(3))
                        Text(
                          '${item.inventoryMaterialId != null && materialById[item.inventoryMaterialId]?.currentStock != null ? '当前库存' : '建单时库存'}：${purchaseQuantityLabel((item.inventoryMaterialId == null ? null : materialById[item.inventoryMaterialId]?.currentStock) ?? item.currentStockSnapshot ?? 0)} ${item.unit}',
                        ),
                      if (detail?.demandReason?.isNotEmpty == true)
                        Text('需求原因：${detail!.demandReason}'),
                      Text(
                        '创建日期：${purchaseShortDateLabel(request.requestDate)}',
                      ),
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
                key: Key('purchase-edit-${request.id}'),
                onPressed: () => context.push(
                  '${PurchaseRoutes.create}?editId=${request.id}',
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('编辑'),
              ),
              FilledButton.icon(
                key: Key('purchase-confirm-applied-${request.id}'),
                onPressed: () => _confirmApplied(context, ref),
                icon: const Icon(Icons.check),
                label: const Text('确认已申报'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmApplied(BuildContext context, WidgetRef ref) async {
    final date = ValueNotifier<DateTime>(DateTime.now());
    final oaNo = TextEditingController();
    final oaTitle = TextEditingController();
    final oaUrl = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => PurchaseSheetResources(
        resources: [date, oaNo, oaTitle, oaUrl],
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '确认已完成 OA 申报',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month_outlined),
                      title: const Text('OA申报日期'),
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
                      child: TextField(
                        controller: oaUrl,
                        keyboardType: TextInputType.url,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('确认'),
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
    if (confirmed == true) {
      try {
        await ref
            .read(purchaseRepositoryProvider)
            .confirmApplied(
              request.id,
              ConfirmAppliedInput(
                appliedDate: date.value,
                oaRequestNo: oaNo.text.trim().isEmpty ? null : oaNo.text.trim(),
                oaTitle: oaTitle.text.trim().isEmpty
                    ? null
                    : oaTitle.text.trim(),
                oaUrl: oaUrl.text.trim().isEmpty ? null : oaUrl.text.trim(),
              ),
            );
        ref.invalidate(purchaseDashboardProvider);
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
