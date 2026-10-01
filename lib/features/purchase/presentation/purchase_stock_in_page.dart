import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../inventory/application/inventory_providers.dart';
import '../application/purchase_providers.dart';
import '../domain/purchase_models.dart';
import '../domain/purchase_status.dart';
import 'widgets/purchase_widgets.dart';

class PurchaseStockInPage extends ConsumerStatefulWidget {
  const PurchaseStockInPage({required this.requestId, super.key});
  final int requestId;

  @override
  ConsumerState<PurchaseStockInPage> createState() =>
      _PurchaseStockInPageState();
}

class _PurchaseStockInPageState extends ConsumerState<PurchaseStockInPage> {
  final _remark = TextEditingController();
  final Map<int, TextEditingController> _quantities = {};
  final Map<int, TextEditingController> _locations = {};
  final Map<int, TextEditingController> _codes = {};
  final Map<int, int?> _materialIds = {};
  final Map<int, String> _materialModes = {};
  final Set<int> _includedLines = {};
  final Set<int> _lineInitialized = {};
  final Set<int> _locationTouched = {};
  final Set<int> _locationDefaults = {};
  DateTime _stockInDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _remark.dispose();
    for (final controller in [
      ..._quantities.values,
      ..._locations.values,
      ..._codes.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(purchaseDetailProvider(widget.requestId));
    final materials =
        ref.watch(inventoryMaterialsProvider).valueOrNull ??
        const <InventoryMaterial>[];
    final activeMaterials = materials
        .where((item) => item.status == 'active')
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('采购入库')),
      body: detailAsync.when(
        loading: () => const PurchaseLoadingState(),
        error: (error, stack) => PurchaseErrorState(
          onRetry: () =>
              ref.invalidate(purchaseDetailProvider(widget.requestId)),
        ),
        data: (detail) => detail == null
            ? const PurchaseEmptyState(title: '采购记录不存在', message: '该记录可能已删除。')
            : _buildBody(context, detail, materials, activeMaterials),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => context.pop(),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const Key('purchase-confirm-stock-in'),
                onPressed: _saving ? null : () => _save(),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? '处理中…' : '确认入库'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PurchaseRequestDetail detail,
    List<InventoryMaterial> materials,
    List<InventoryMaterial> activeMaterials,
  ) {
    for (final item in detail.items) {
      _quantities.putIfAbsent(
        item.id,
        () => TextEditingController(
          text: purchaseQuantityLabel(item.remainingQuantity),
        ),
      );
      _locations.putIfAbsent(item.id, () => TextEditingController());
      _codes.putIfAbsent(item.id, () => TextEditingController());
      _materialIds.putIfAbsent(item.id, () => item.inventoryMaterialId);
      if (_lineInitialized.add(item.id) && item.remainingQuantity > 0) {
        _includedLines.add(item.id);
      }
      final linked = materials
          .where((material) => material.id == item.inventoryMaterialId)
          .firstOrNull;
      _materialModes.putIfAbsent(
        item.id,
        () => linked == null
            ? 'unresolved'
            : linked.status == 'active'
            ? 'select'
            : 'unresolved',
      );
      if (_materialModes[item.id] == 'unresolved' &&
          linked?.status == 'active') {
        _materialModes[item.id] = 'select';
        _materialIds[item.id] = linked!.id;
      }
      final selectedMaterial = materials
          .where((material) => material.id == _materialIds[item.id])
          .firstOrNull;
      if (!_locationTouched.contains(item.id) &&
          selectedMaterial?.storageLocation?.isNotEmpty == true &&
          !_locationDefaults.contains(item.id)) {
        _locations[item.id]!.text = selectedMaterial!.storageLocation!;
        _locationDefaults.add(item.id);
      }
    }
    final nonPending = detail.summary.status != PurchaseStatus.pendingReceive;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        PurchasePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.summary.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final item in detail.items)
                Text('${item.itemName} · ${item.specification ?? '无规格'}'),
              const Divider(height: 20),
              Wrap(
                spacing: 18,
                runSpacing: 10,
                children: [
                  for (final item in detail.items)
                    _StockQuantity(
                      label: '申报 ${item.itemName}',
                      value: item.requestQuantity,
                      unit: item.unit,
                    ),
                  for (final item in detail.items)
                    _StockQuantity(
                      label: '已入库',
                      value: item.receivedQuantity,
                      unit: item.unit,
                    ),
                  for (final item in detail.items)
                    _StockQuantity(
                      label: '剩余待入库',
                      value: item.remainingQuantity,
                      unit: item.unit,
                    ),
                ],
              ),
              if (nonPending) ...[
                const SizedBox(height: 10),
                const Text(
                  '当前状态不是待领取。历史补录会增加库存并生成库存流水，继续前需确认。',
                  style: TextStyle(color: Color(0xFF1677FF)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const PurchaseSectionHeading('本次入库'),
        const SizedBox(height: 8),
        for (final item in detail.items) ...[
          PurchasePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('型号：${item.specification ?? '未填写'} · 单位：${item.unit}'),
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _includedLines.contains(item.id),
                  title: const Text('本次入库'),
                  subtitle: item.remainingQuantity <= 0
                      ? const Text('剩余待入库数量为 0；勾选后可记录超量入库。')
                      : null,
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      _includedLines.add(item.id);
                    } else {
                      _includedLines.remove(item.id);
                    }
                  }),
                ),
                TextField(
                  key: Key('purchase-stock-quantity-${item.id}'),
                  controller: _quantities[item.id],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '本次入库数量',
                    suffixText: item.unit,
                  ),
                  enabled: _includedLines.contains(item.id),
                ),
                const SizedBox(height: 10),
                _materialSelection(context, item, materials, activeMaterials),
                const SizedBox(height: 8),
                TextField(
                  controller: _locations[item.id],
                  decoration: const InputDecoration(labelText: '存放位置（选填）'),
                  onChanged: (_) => _locationTouched.add(item.id),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_month_outlined),
          title: const Text('入库日期'),
          subtitle: Text(purchaseDateLabel(_stockInDate)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final date = await pickPurchaseDate(
              context,
              initialDate: _stockInDate,
            );
            if (date != null) setState(() => _stockInDate = date);
          },
        ),
        TextField(
          controller: _remark,
          minLines: 2,
          maxLines: 4,
          maxLength: 200,
          decoration: const InputDecoration(labelText: '备注（选填）'),
        ),
        PurchasePanel(
          child: const Text(
            '确认后将增加库存，并生成关联采购的入库流水。部分入库时，剩余数量会继续保留在待领取状态。',
            style: TextStyle(color: Color(0xFF168458)),
          ),
        ),
      ],
    );
  }

  Widget _materialSelection(
    BuildContext context,
    PurchaseRequestItemView item,
    List<InventoryMaterial> materials,
    List<InventoryMaterial> activeMaterials,
  ) {
    final mode = _materialModes[item.id] ?? 'unresolved';
    final linked = materials
        .where((material) => material.id == item.inventoryMaterialId)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (linked == null || linked.status != 'active')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2E4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              linked == null
                  ? '该采购物资尚未关联库存物资，请选择入库方式。'
                  : '原关联库存物资已停用，请恢复、改选或新建。',
              style: const TextStyle(color: Color(0xFFC76A00)),
            ),
          ),
        if (linked == null || linked.status != 'active') ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (linked != null)
                ChoiceChip(
                  label: const Text('恢复原物资'),
                  selected: mode == 'restore',
                  onSelected: (_) =>
                      setState(() => _materialModes[item.id] = 'restore'),
                ),
              ChoiceChip(
                label: const Text('选择其他物资'),
                selected: mode == 'select',
                onSelected: (_) =>
                    setState(() => _materialModes[item.id] = 'select'),
              ),
              ChoiceChip(
                label: const Text('新建库存物资'),
                selected: mode == 'new',
                onSelected: (_) =>
                    setState(() => _materialModes[item.id] = 'new'),
              ),
            ],
          ),
        ],
        if (mode == 'restore')
          Text('将恢复原物资：${linked?.materialName ?? item.itemName}'),
        if (mode == 'select') ...[
          const SizedBox(height: 6),
          DropdownButtonFormField<int?>(
            key: ValueKey(
              'purchase-material-select-${item.id}-${_materialIds[item.id]}',
            ),
            initialValue:
                _materialIds[item.id] != null &&
                    activeMaterials.any((m) => m.id == _materialIds[item.id])
                ? _materialIds[item.id]
                : null,
            decoration: const InputDecoration(labelText: '选择库存物资'),
            items: [
              for (final material in activeMaterials)
                DropdownMenuItem(
                  value: material.id,
                  child: Text(
                    '${material.materialName} · ${material.modelSpec ?? '无规格'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            isExpanded: true,
            onChanged: (value) => setState(() {
              _materialIds[item.id] = value;
              final material = activeMaterials
                  .where((entry) => entry.id == value)
                  .firstOrNull;
              if (!_locationTouched.contains(item.id)) {
                _locations[item.id]!.text = material?.storageLocation ?? '';
                _locationDefaults.remove(item.id);
              }
            }),
          ),
        ],
        if (mode == 'new') ...[
          const SizedBox(height: 6),
          TextField(
            controller: _codes[item.id],
            decoration: const InputDecoration(labelText: '新库存物资编号（选填，自动生成）'),
          ),
        ],
        if (mode == 'select' && activeMaterials.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('当前没有启用的库存物资，可恢复原物资或新建。'),
          ),
      ],
    );
  }

  Future<void> _save() async {
    final detail = ref
        .read(purchaseDetailProvider(widget.requestId))
        .valueOrNull;
    if (detail == null) return;
    final lines = <PurchaseStockInLineInput>[];
    final excessItems = <int, String>{};
    for (final item in detail.items) {
      if (!_includedLines.contains(item.id)) continue;
      final quantity = double.tryParse(_quantities[item.id]?.text ?? '') ?? 0;
      if (!quantity.isFinite || quantity <= 0) {
        _showMessage('请输入${item.itemName}的入库数量，且必须大于 0。');
        return;
      }
      final mode = _materialModes[item.id] ?? 'unresolved';
      final selected = _materialIds[item.id];
      final linked = item.inventoryMaterialId;
      if (mode == 'unresolved' || (mode == 'select' && selected == null)) {
        _showMessage('请为${item.itemName}选择、恢复或新建库存物资。');
        return;
      }
      if (quantity > item.remainingQuantity) {
        excessItems[item.id] =
            '${item.itemName}：超出${purchaseQuantityLabel(quantity - item.remainingQuantity)} ${item.unit}';
      }
      lines.add(
        PurchaseStockInLineInput(
          requestItemId: item.id,
          quantity: quantity,
          confirmExcess: false,
          inventoryMaterialId: mode == 'select' ? selected : null,
          restoreLinkedMaterial: mode == 'restore' && linked != null,
          createInventoryMaterial: mode == 'new',
          newMaterialCode: _codes[item.id]?.text,
          storageLocation: _locations[item.id]?.text,
        ),
      );
    }
    if (lines.isEmpty) {
      _showMessage('请至少勾选一项本次入库物资。');
      return;
    }
    if (excessItems.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认超量入库'),
          content: Text(
            '本次入库数量超过剩余待入库数量：\n${excessItems.values.join('\n')}\n\n请确认仍要入库。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('仍然入库'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      for (var i = 0; i < lines.length; i++) {
        if (excessItems.containsKey(lines[i].requestItemId)) {
          final line = lines[i];
          lines[i] = PurchaseStockInLineInput(
            requestItemId: line.requestItemId,
            quantity: line.quantity,
            confirmExcess: true,
            inventoryMaterialId: line.inventoryMaterialId,
            restoreLinkedMaterial: line.restoreLinkedMaterial,
            createInventoryMaterial: line.createInventoryMaterial,
            newMaterialCode: line.newMaterialCode,
            storageLocation: line.storageLocation,
          );
        }
      }
    }
    final nonPending = detail.summary.status != PurchaseStatus.pendingReceive;
    if (nonPending) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认历史补录入库'),
          content: const Text('当前采购状态不是待领取。继续后将更新库存并创建入库流水。确定继续吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认补录'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    final reviewed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认入库'),
        content: SingleChildScrollView(
          child: Text(
            '${lines.map((line) {
              final item = detail.items.firstWhere((value) => value.id == line.requestItemId);
              return '${item.itemName} ${purchaseQuantityLabel(line.quantity)} ${item.unit}，存放位置：${_locations[item.id]?.text.trim().isNotEmpty == true ? _locations[item.id]!.text.trim() : '未填写'}';
            }).join('\n')}\n\n确认后将更新库存并生成采购入库流水。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认入库'),
          ),
        ],
      ),
    );
    if (!mounted || reviewed != true) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(purchaseRepositoryProvider)
          .stockIn(
            StockInInput(
              requestId: widget.requestId,
              stockInDate: _stockInDate,
              lines: lines,
              confirmedNonPending: nonPending,
              remark: _remark.text,
            ),
          );
      ref.invalidate(purchaseDetailProvider(widget.requestId));
      ref.invalidate(purchaseDashboardProvider);
      ref.invalidate(inventoryStockProvider);
      ref.invalidate(inventoryMaterialsProvider);
      ref.invalidate(inventoryReceiptsProvider);
      ref.invalidate(inventoryTransactionsProvider);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) _showMessage('入库失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StockQuantity extends StatelessWidget {
  const _StockQuantity({
    required this.label,
    required this.value,
    required this.unit,
  });
  final String label;
  final double value;
  final String unit;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Text(
        '${purchaseQuantityLabel(value)} $unit',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    ],
  );
}
