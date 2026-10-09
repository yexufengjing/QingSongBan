import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../inventory/application/inventory_providers.dart';
import '../application/purchase_form_notifier.dart';
import '../application/purchase_providers.dart';
import '../domain/purchase_models.dart';
import '../purchase_routes.dart';
import 'purchase_item_prefill.dart';
import 'widgets/purchase_widgets.dart';

class PurchaseCreatePage extends ConsumerStatefulWidget {
  const PurchaseCreatePage({this.initialItem, this.requestId, super.key});

  final PurchaseItemPrefill? initialItem;
  final int? requestId;

  @override
  ConsumerState<PurchaseCreatePage> createState() => _PurchaseCreatePageState();
}

class _PurchaseCreatePageState extends ConsumerState<PurchaseCreatePage> {
  final _titleController = TextEditingController();
  final _remarkController = TextEditingController();
  final _reasonController = TextEditingController();
  final _loadedRequest = ValueNotifier<bool>(false);
  bool _checkingDuplicate = false;
  bool _editingSaving = false;
  bool _initialized = false;

  bool get _isEditing => widget.requestId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeForm());
  }

  void _initializeForm() {
    if (!mounted || _initialized) return;
    _initialized = true;
    if (_isEditing) {
      ref.listenManual(purchaseDetailProvider(widget.requestId!), (
        previous,
        next,
      ) {
        final detail = next.valueOrNull;
        if (detail == null || _loadedRequest.value) return;
        _loadedRequest.value = true;
        final form = ref.read(purchaseFormProvider.notifier);
        form.setTitle(detail.summary.title);
        form.setDemandReason(detail.demandReason ?? '');
        form.setRequestDate(detail.summary.requestDate);
        form.setRemark(detail.remark ?? '');
        for (final item in detail.items) {
          form.addItem(
            PurchaseItemDraft(
              inventoryMaterialId: item.inventoryMaterialId,
              itemName: item.itemName,
              specification: item.specification,
              unit: item.unit,
              currentStockSnapshot: item.currentStockSnapshot,
              requestQuantity: item.requestQuantity,
              remark: item.remark,
            ),
          );
        }
        _titleController.text = detail.summary.title;
        _reasonController.text = detail.demandReason ?? '';
        _remarkController.text = detail.remark ?? '';
      }, fireImmediately: true);
      return;
    }
    final initial = widget.initialItem;
    if (initial != null) {
      _titleController.text = '${initial.itemName}采购';
      ref.read(purchaseFormProvider.notifier).setTitle(_titleController.text);
      _addPrefill(initial, checkDuplicate: true);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _remarkController.dispose();
    _reasonController.dispose();
    _loadedRequest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchaseFormProvider);
    final form = ref.read(purchaseFormProvider.notifier);
    final detail = _isEditing
        ? ref.watch(purchaseDetailProvider(widget.requestId!))
        : null;
    return PurchasePageTheme(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? '编辑待申报采购' : '新建采购'),
          actions: [
            if (!_isEditing)
              TextButton(
                onPressed: state.isSaving || _editingSaving
                    ? null
                    : () => _save(create: true),
                child: const Text('保存草稿'),
              ),
          ],
        ),
        body: detail?.isLoading == true
            ? const PurchaseLoadingState()
            : detail?.hasError == true
            ? PurchaseErrorState(
                onRetry: () =>
                    ref.invalidate(purchaseDetailProvider(widget.requestId!)),
              )
            : detail?.hasValue == true && detail?.valueOrNull == null
            ? const PurchaseEmptyState(
                title: '采购记录不存在',
                message: '该采购记录可能已删除或暂时无法访问。',
              )
            : ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                children: [
                  PurchasePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PurchaseSectionHeading('基本信息'),
                        const SizedBox(height: 12),
                        PurchaseLabeledField(
                          label: '采购事项名称',
                          child: TextField(
                            key: const Key('purchase-title-field'),
                            controller: _titleController,
                            onChanged: form.setTitle,
                            decoration: const InputDecoration(
                              hintText: '例如：扫路车备件采购',
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '需求原因',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final chips = [
                              for (final reason in const [
                                '库存不足',
                                '临时需求',
                                '设备维修',
                                '其他',
                              ])
                                ChoiceChip(
                                  visualDensity: const VisualDensity(
                                    horizontal: -2,
                                    vertical: -2,
                                  ),
                                  labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  label: Text(reason),
                                  selected: _reasonController.text == reason,
                                  selectedColor: const Color(0xFF2563EB),
                                  labelStyle: TextStyle(
                                    color: _reasonController.text == reason
                                        ? Colors.white
                                        : const Color(0xFF425D7F),
                                    fontWeight: _reasonController.text == reason
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  ),
                                  side: BorderSide(
                                    color: _reasonController.text == reason
                                        ? Colors.white
                                        : const Color(0xFFE0EAF5),
                                  ),
                                  onSelected: (_) {
                                    _reasonController.text = reason;
                                    form.setDemandReason(reason);
                                    setState(() {});
                                  },
                                ),
                            ];
                            if (constraints.maxWidth < 330) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(children: chips),
                              );
                            }
                            return Row(
                              children: [
                                for (final (index, chip) in chips.indexed) ...[
                                  if (index > 0) const SizedBox(width: 5),
                                  Expanded(child: Center(child: chip)),
                                ],
                              ],
                            );
                          },
                        ),
                        PurchaseLabeledField(
                          label: '原因补充（选填）',
                          child: TextField(
                            key: const Key('purchase-reason-field'),
                            controller: _reasonController,
                            onChanged: form.setDemandReason,
                            decoration: const InputDecoration(
                              hintText: '可填写需求原因',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_month_outlined),
                          title: const Text('创建日期'),
                          subtitle: Text(purchaseDateLabel(state.requestDate)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final date = await pickPurchaseDate(
                              context,
                              initialDate: state.requestDate,
                            );
                            if (date != null) form.setRequestDate(date);
                          },
                        ),
                        PurchaseLabeledField(
                          label: '备注（选填）',
                          child: TextField(
                            key: const Key('purchase-remark-field'),
                            controller: _remarkController,
                            minLines: 2,
                            maxLines: 4,
                            maxLength: 200,
                            onChanged: form.setRemark,
                            decoration: const InputDecoration(hintText: '补充说明'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  PurchaseSectionHeading(
                    '采购物资（${state.items.length}）',
                    trailing: TextButton.icon(
                      onPressed: () => _showManualItemDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('添加物资'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (state.items.isEmpty)
                    const PurchasePanel(child: Text('请选择库存物资或手动新增物资。'))
                  else
                    for (
                      var index = 0;
                      index < state.items.length;
                      index++
                    ) ...[
                      _PurchaseDraftCard(
                        item: state.items[index],
                        index: index,
                        onChanged: (item) => form.updateItem(index, item),
                        onRemove: () => form.removeItem(index),
                      ),
                      const SizedBox(height: 10),
                    ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('purchase-select-inventory'),
                        onPressed: _selectInventoryItem,
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('选择库存物资'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _showManualItemDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('手动新增物资'),
                      ),
                    ],
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      key: const Key('purchase-form-error'),
                    ),
                  ],
                ],
              ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: state.isSaving || _editingSaving
                      ? null
                      : _isEditing
                      ? () => context.pop()
                      : () => _save(create: true),
                  child: Text(_isEditing ? '取消' : '保存待申报'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: const Key('purchase-save-button'),
                  onPressed: state.isSaving || _editingSaving
                      ? null
                      : () => _save(create: false),
                  child: Text(
                    state.isSaving || _editingSaving
                        ? '保存中…'
                        : _isEditing
                        ? '保存修改'
                        : '创建采购记录',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save({required bool create}) async {
    final state = ref.read(purchaseFormProvider);
    final form = ref.read(purchaseFormProvider.notifier);
    if (_isEditing) {
      final error = form.validate();
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      final detail = ref
          .read(purchaseDetailProvider(widget.requestId!))
          .valueOrNull;
      if (detail == null) return;
      setState(() => _editingSaving = true);
      try {
        await ref
            .read(purchaseRepositoryProvider)
            .updatePurchaseRequest(
              widget.requestId!,
              UpdatePurchaseRequestInput(
                title: state.title,
                items: state.items,
                requestDate: state.requestDate,
                appliedDate: detail.summary.appliedDate,
                oaRequestNo: detail.oaRequestNo,
                oaTitle: detail.oaTitle,
                oaUrl: detail.oaUrl,
                purchaseDepartment: detail.purchaseDepartment,
                purchaserName: detail.summary.purchaserName,
                assignedDate: detail.summary.assignedDate,
                arrivalNoticeDate: detail.summary.arrivalNoticeDate,
                receiveLocation: detail.summary.receiveLocation,
                demandReason: state.demandReason,
                remark: state.remark,
              ),
            );
        if (mounted) {
          context.pop();
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('保存失败：$error')));
        }
      } finally {
        if (mounted) setState(() => _editingSaving = false);
      }
      return;
    }
    final id = await form.save();
    if (id == null) {
      final message = ref.read(purchaseFormProvider).errorMessage;
      if (message != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    ref.invalidate(purchaseDashboardProvider);
    ref.invalidate(purchaseListProvider);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(create ? '已保存到待申报' : '采购记录已创建')));
      context.pop();
    }
  }

  Future<void> _addPrefill(
    PurchaseItemPrefill item, {
    bool checkDuplicate = false,
  }) async {
    final draft = PurchaseItemDraft(
      inventoryMaterialId: item.inventoryMaterialId,
      itemName: item.itemName,
      specification: item.specification,
      unit: item.unit,
      currentStockSnapshot: item.currentStock,
      requestQuantity: 1,
    );
    ref.read(purchaseFormProvider.notifier).addItem(draft);
    if (!checkDuplicate) return;
    await _checkDuplicate(item.inventoryMaterialId, item.itemName);
  }

  Future<void> _checkDuplicate(int materialId, String name) async {
    if (_checkingDuplicate) return;
    _checkingDuplicate = true;
    try {
      final duplicate = await ref
          .read(purchaseRepositoryProvider)
          .hasActiveRequest(materialId);
      if (!duplicate || !mounted) return;
      final existingId = await ref
          .read(purchaseRepositoryProvider)
          .findActiveRequestId(materialId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => PurchasePageTheme(
          child: AlertDialog(
            title: const Text('已有未完成采购'),
            content: Text('$name 当前已有未完成采购记录。'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  if (existingId != null) {
                    context.push(PurchaseRoutes.detail(existingId));
                  } else {
                    context.push(PurchaseRoutes.tracking);
                  }
                },
                child: const Text('查看已有记录'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('继续创建'),
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('重复采购检查失败，仍可继续创建：$error')));
      }
    } finally {
      _checkingDuplicate = false;
    }
  }

  Future<void> _selectInventoryItem() async {
    final result = await showModalBottomSheet<InventoryMaterial>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PurchasePageTheme(child: _InventoryPicker()),
    );
    if (result == null || !mounted) return;
    final exists = ref
        .read(purchaseFormProvider)
        .items
        .any((item) => item.inventoryMaterialId == result.id);
    if (exists) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('该物资已在本次采购中')));
      return;
    }
    await _addPrefill(
      PurchaseItemPrefill.fromInventoryMaterial(result),
      checkDuplicate: true,
    );
  }

  Future<void> _showManualItemDialog() async {
    final name = TextEditingController();
    final specification = TextEditingController();
    final unit = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final result = await showDialog<PurchaseItemDraft>(
      context: context,
      builder: (dialogContext) => PurchaseSheetResources(
        resources: [name, specification, unit, quantity],
        child: PurchasePageTheme(
          child: AlertDialog(
            title: const Text('手动新增物资'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PurchaseLabeledField(
                    label: '物资名称',
                    child: TextField(controller: name),
                  ),
                  PurchaseLabeledField(
                    label: '规格型号（选填）',
                    child: TextField(controller: specification),
                  ),
                  PurchaseLabeledField(
                    label: '单位',
                    child: TextField(controller: unit),
                  ),
                  PurchaseLabeledField(
                    label: '申报数量',
                    child: TextField(
                      controller: quantity,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    PurchaseItemDraft(
                      itemName: name.text.trim(),
                      specification: specification.text.trim().isEmpty
                          ? null
                          : specification.text.trim(),
                      unit: unit.text.trim(),
                      requestQuantity: double.tryParse(quantity.text) ?? 0,
                    ),
                  );
                },
                child: const Text('添加'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) ref.read(purchaseFormProvider.notifier).addItem(result);
  }
}

class _PurchaseDraftCard extends StatefulWidget {
  const _PurchaseDraftCard({
    required this.item,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  final PurchaseItemDraft item;
  final int index;
  final ValueChanged<PurchaseItemDraft> onChanged;
  final VoidCallback onRemove;

  @override
  State<_PurchaseDraftCard> createState() => _PurchaseDraftCardState();
}

class _PurchaseDraftCardState extends State<_PurchaseDraftCard> {
  bool _typingQuantity = false;
  late final TextEditingController _quantity = TextEditingController(
    text: purchaseQuantityLabel(widget.item.requestQuantity),
  );

  @override
  void didUpdateWidget(covariant _PurchaseDraftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_typingQuantity &&
        oldWidget.item.requestQuantity != widget.item.requestQuantity) {
      _quantity.text = purchaseQuantityLabel(widget.item.requestQuantity);
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PurchasePanel(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PurchaseMaterialIcon(size: 64),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.itemName,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: '移除物资',
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                '规格：${widget.item.specification?.isNotEmpty == true ? widget.item.specification : '未填写'}',
              ),
              Text('单位：${widget.item.unit.isEmpty ? '未填写' : widget.item.unit}'),
              if (widget.item.currentStockSnapshot != null)
                Text(
                  '当前库存：${purchaseQuantityLabel(widget.item.currentStockSnapshot!)}',
                ),
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 2,
                runSpacing: 4,
                children: [
                  const Text('申报数量'),
                  IconButton(
                    tooltip: '减少数量',
                    onPressed: () =>
                        _setQuantity(widget.item.requestQuantity - 1),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      key: Key('purchase-item-quantity-${widget.index}'),
                      controller: _quantity,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 8,
                        ),
                      ),
                      onChanged: (value) => _setQuantity(
                        double.tryParse(value) ?? 0,
                        updateController: false,
                      ),
                      onEditingComplete: _finishQuantityEdit,
                      onSubmitted: (_) => _finishQuantityEdit(),
                    ),
                  ),
                  IconButton(
                    tooltip: '增加数量',
                    onPressed: () =>
                        _setQuantity(widget.item.requestQuantity + 1),
                    icon: const Icon(
                      Icons.add_circle,
                      color: Color(0xFF00C16B),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 70),
                    child: Text(
                      widget.item.unit,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _setQuantity(double value, {bool updateController = true}) {
    _typingQuantity = !updateController;
    if (updateController) _quantity.text = purchaseQuantityLabel(value);
    widget.onChanged(
      PurchaseItemDraft(
        inventoryMaterialId: widget.item.inventoryMaterialId,
        itemName: widget.item.itemName,
        specification: widget.item.specification,
        unit: widget.item.unit,
        currentStockSnapshot: widget.item.currentStockSnapshot,
        requestQuantity: value,
        remark: widget.item.remark,
      ),
    );
  }

  void _finishQuantityEdit() {
    _typingQuantity = false;
    _quantity.text = purchaseQuantityLabel(widget.item.requestQuantity);
  }
}

class _InventoryPicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materials = ref.watch(inventoryMaterialsProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                '选择库存物资',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: materials.when(
                loading: () => const PurchaseLoadingState(),
                error: (error, stack) => const Center(child: Text('库存物资加载失败')),
                data: (items) {
                  final active = items
                      .where((item) => item.status == 'active')
                      .toList();
                  if (active.isEmpty) {
                    return const Center(child: Text('暂无可用的库存物资'));
                  }
                  return ListView.builder(
                    itemCount: active.length,
                    itemBuilder: (context, index) {
                      final item = active[index];
                      return ListTile(
                        title: Text(item.materialName),
                        subtitle: Text(
                          '${item.modelSpec ?? '无规格'} · 库存 ${purchaseQuantityLabel(item.currentStock)} ${item.unitName}',
                        ),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
