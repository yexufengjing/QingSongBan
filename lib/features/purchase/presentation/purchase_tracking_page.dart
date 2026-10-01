import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/purchase_providers.dart';
import '../domain/purchase_models.dart';
import '../domain/purchase_status.dart';
import '../purchase_routes.dart';
import 'purchase_oa_navigation.dart';
import 'purchase_page_providers.dart';
import 'widgets/purchase_widgets.dart';

class PurchaseTrackingPage extends ConsumerStatefulWidget {
  const PurchaseTrackingPage({
    this.showAll = false,
    this.initialStatus,
    super.key,
  });
  final bool showAll;
  final PurchaseStatus? initialStatus;

  @override
  ConsumerState<PurchaseTrackingPage> createState() =>
      _PurchaseTrackingPageState();
}

class _PurchaseTrackingPageState extends ConsumerState<PurchaseTrackingPage> {
  final _searchController = TextEditingController();
  late PurchaseFilter _filter;
  PurchaseStatus? _selectedStatus;
  String? _purchaser;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus ?? PurchaseStatus.applied;
    _filter = PurchaseFilter(
      statuses: widget.showAll
          ? const {
              PurchaseStatus.pendingApply,
              PurchaseStatus.applied,
              PurchaseStatus.purchasing,
              PurchaseStatus.pendingReceive,
            }
          : {_selectedStatus ?? PurchaseStatus.applied},
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(purchaseRequestsByFilterProvider(_filter));
    final knownPurchasers =
        ref
            .watch(
              purchaseRequestsByFilterProvider(
                const PurchaseFilter(
                  statuses: {
                    PurchaseStatus.applied,
                    PurchaseStatus.purchasing,
                    PurchaseStatus.pendingApply,
                    PurchaseStatus.pendingReceive,
                  },
                ),
              ),
            )
            .valueOrNull
            ?.map((item) => item.purchaserName)
            .whereType<String>()
            .toSet()
            .toList() ??
        const <String>[];
    return Scaffold(
      appBar: AppBar(title: Text(widget.showAll ? '全部待处理' : '采购跟踪')),
      body: Column(
        children: [
          if (!widget.showAll)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SegmentedButton<PurchaseStatus>(
                segments: const [
                  ButtonSegment(
                    value: PurchaseStatus.applied,
                    label: Text('已申报'),
                  ),
                  ButtonSegment(
                    value: PurchaseStatus.purchasing,
                    label: Text('采购中'),
                  ),
                ],
                selected: {_selectedStatus ?? PurchaseStatus.applied},
                onSelectionChanged: (value) => setState(() {
                  _selectedStatus = value.single;
                  _filter = _filter.copyWith(statuses: {value.single});
                }),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  key: const Key('purchase-tracking-search'),
                  onChanged: (value) => setState(
                    () => _filter = _filter.copyWith(keyword: value),
                  ),
                  decoration: InputDecoration(
                    hintText: '搜索物资、OA编号、采购执行人',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: '清除搜索',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _filter = _filter.copyWith(keyword: ''));
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PopupMenuButton<String>(
                      tooltip: '日期筛选',
                      onSelected: (value) async {
                        final now = DateTime.now();
                        if (value == 'all') {
                          setState(() {
                            _filter = _filter.copyWith(clearDates: true);
                          });
                        } else if (value == '30') {
                          setState(() {
                            _filter = _filter.copyWith(
                              startDate: now.subtract(const Duration(days: 30)),
                              endDate: now,
                            );
                          });
                        } else {
                          final start = await pickPurchaseDate(
                            context,
                            initialDate: _filter.startDate,
                          );
                          if (start == null || !context.mounted) return;
                          final end = await pickPurchaseDate(
                            context,
                            initialDate: _filter.endDate ?? now,
                          );
                          if (end != null && context.mounted) {
                            if (end.isBefore(start)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('结束日期不能早于开始日期')),
                              );
                            } else {
                              setState(
                                () => _filter = _filter.copyWith(
                                  startDate: start,
                                  endDate: end,
                                ),
                              );
                            }
                          }
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'all', child: Text('全部日期')),
                        PopupMenuItem(value: '30', child: Text('最近30天')),
                        PopupMenuItem(value: 'custom', child: Text('自定义日期')),
                      ],
                      child: Chip(
                        avatar: const Icon(
                          Icons.calendar_month_outlined,
                          size: 18,
                        ),
                        label: Text(
                          _filter.startDate == null
                              ? '全部日期'
                              : '${purchaseShortDateLabel(_filter.startDate)}–${purchaseShortDateLabel(_filter.endDate)}',
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: '采购执行人',
                      onSelected: (value) => setState(() {
                        _purchaser = value == '__all__' ? null : value;
                        _filter = _filter.copyWith(
                          purchaserName: _purchaser,
                          clearPurchaser: _purchaser == null,
                        );
                      }),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: '__all__',
                          child: Text('所有执行人'),
                        ),
                        for (final person in knownPurchasers)
                          PopupMenuItem(value: person, child: Text(person)),
                      ],
                      child: Chip(
                        avatar: const Icon(Icons.person_outline, size: 18),
                        label: Text(_purchaser ?? '执行人'),
                      ),
                    ),
                    if (widget.showAll)
                      for (final status in const [
                        PurchaseStatus.pendingApply,
                        PurchaseStatus.applied,
                        PurchaseStatus.purchasing,
                        PurchaseStatus.pendingReceive,
                      ])
                        FilterChip(
                          label: Text(status.label),
                          selected: _filter.statuses.contains(status),
                          onSelected: (selected) => setState(() {
                            final next = {..._filter.statuses};
                            selected ? next.add(status) : next.remove(status);
                            if (next.isEmpty) {
                              next.addAll(const {
                                PurchaseStatus.pendingApply,
                                PurchaseStatus.applied,
                                PurchaseStatus.purchasing,
                                PurchaseStatus.pendingReceive,
                              });
                            }
                            _filter = _filter.copyWith(statuses: next);
                          }),
                        ),
                  ],
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
                      title: '暂无采购记录',
                      message: '符合当前筛选条件的采购记录会显示在这里。',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: items.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TrackingCard(request: items[index]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingCard extends ConsumerWidget {
  const _TrackingCard({required this.request});
  final PurchaseRequestSummary request;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PurchasePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => context.push(PurchaseRoutes.detail(request.id)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PurchaseMaterialIcon(size: 72),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PurchaseStatusChip(status: request.status),
                    const SizedBox(height: 5),
                    Text(
                      request.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    for (final item in request.items.take(2))
                      Text(
                        '${item.itemName} · ${item.specification ?? '无规格'} · ${purchaseQuantityLabel(item.requestQuantity)} ${item.unit}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      'OA申报日期：${purchaseShortDateLabel(request.appliedDate)}',
                    ),
                    if (request.purchaserName != null)
                      Text('执行人：${request.purchaserName}'),
                    if (request.assignedDate != null)
                      Text(
                        '分配日期：${purchaseShortDateLabel(request.assignedDate)}',
                      ),
                    if (request.status == PurchaseStatus.applied)
                      const Text(
                        '等待资材部分配采购执行人',
                        style: TextStyle(color: Color(0xFF1677FF)),
                      ),
                    if (request.status == PurchaseStatus.purchasing)
                      Text(
                        '已等待${_waitingDays(request)}天',
                        style: const TextStyle(color: Color(0xFF1677FF)),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        const Divider(height: 22),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.push(PurchaseRoutes.detail(request.id)),
              icon: const Icon(Icons.description_outlined),
              label: const Text('查看详情'),
            ),
            if (request.status == PurchaseStatus.applied)
              OutlinedButton.icon(
                onPressed: () => _openOa(context, ref),
                icon: const Icon(Icons.open_in_new),
                label: const Text('查看 OA 流程'),
              ),
            if (request.status == PurchaseStatus.applied)
              FilledButton.icon(
                key: Key('purchase-assign-${request.id}'),
                onPressed: () => _assign(context, ref),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('填写采购信息'),
              ),
            if (request.status == PurchaseStatus.purchasing)
              FilledButton.icon(
                key: Key('purchase-mark-receive-${request.id}'),
                onPressed: () => _markPendingReceive(context, ref),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('设为待领取'),
              ),
            if (request.status == PurchaseStatus.pendingReceive)
              FilledButton.icon(
                onPressed: () =>
                    context.push(PurchaseRoutes.stockIn(request.id)),
                icon: const Icon(Icons.move_to_inbox_outlined),
                label: const Text('入库'),
              ),
          ],
        ),
      ],
    ),
  );

  Future<void> _openOa(BuildContext context, WidgetRef ref) async {
    try {
      final detail = await ref.read(purchaseDetailProvider(request.id).future);
      if (!context.mounted) return;
      if (detail == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('采购详情暂时无法加载，请稍后重试。')));
        return;
      }
      await openPurchaseOaUrl(context, detail.oaUrl);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('采购详情暂时无法加载，请稍后重试。')));
      }
    }
  }

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    final department = TextEditingController();
    final purchaser = TextEditingController(text: request.purchaserName ?? '');
    var assigned = request.assignedDate ?? DateTime.now();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => PurchaseSheetResources(
        resources: [department, purchaser],
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
                      '填写采购执行信息',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: department,
                      decoration: const InputDecoration(labelText: '采购分部（选填）'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: purchaser,
                      decoration: const InputDecoration(labelText: '采购执行人（选填）'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('分配日期'),
                      subtitle: Text(purchaseDateLabel(assigned)),
                      onTap: () async {
                        final value = await pickPurchaseDate(
                          context,
                          initialDate: assigned,
                        );
                        if (value != null) {
                          setSheetState(() => assigned = value);
                        }
                      },
                    ),
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
    if (saved == true) {
      try {
        await ref
            .read(purchaseRepositoryProvider)
            .assignPurchaser(
              request.id,
              AssignPurchaserInput(
                purchaseDepartment: department.text.trim().isEmpty
                    ? null
                    : department.text.trim(),
                purchaserName: purchaser.text.trim().isEmpty
                    ? null
                    : purchaser.text.trim(),
                assignedDate: assigned,
              ),
            );
        ref.invalidate(purchaseDashboardProvider);
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('保存失败：$error')));
        }
      }
    }
  }

  Future<void> _markPendingReceive(BuildContext context, WidgetRef ref) async {
    var arrivalDate = DateTime.now();
    final location = TextEditingController(text: request.receiveLocation ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => PurchaseSheetResources(
        resources: [location],
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
                    subtitle: Text(purchaseDateLabel(arrivalDate)),
                    onTap: () async {
                      final value = await pickPurchaseDate(
                        context,
                        initialDate: arrivalDate,
                      );
                      if (value != null) {
                        setSheetState(() => arrivalDate = value);
                      }
                    },
                  ),
                  TextField(
                    controller: location,
                    decoration: const InputDecoration(labelText: '领取地点（选填）'),
                  ),
                  const SizedBox(height: 12),
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
    if (saved == true) {
      try {
        await ref
            .read(purchaseRepositoryProvider)
            .markPendingReceive(
              request.id,
              PendingReceiveInput(
                arrivalNoticeDate: arrivalDate,
                receiveLocation: location.text.trim().isEmpty
                    ? null
                    : location.text.trim(),
              ),
            );
        ref.invalidate(purchaseDashboardProvider);
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
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).difference(startDay).inDays;
}
