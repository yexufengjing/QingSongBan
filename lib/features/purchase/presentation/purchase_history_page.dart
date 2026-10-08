import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/purchase_models.dart';
import '../domain/purchase_status.dart';
import '../purchase_routes.dart';
import 'purchase_page_providers.dart';
import 'widgets/purchase_widgets.dart';

class PurchaseHistoryPage extends ConsumerStatefulWidget {
  const PurchaseHistoryPage({this.initialPreset, super.key});
  final String? initialPreset;

  @override
  ConsumerState<PurchaseHistoryPage> createState() =>
      _PurchaseHistoryPageState();
}

class _PurchaseHistoryPageState extends ConsumerState<PurchaseHistoryPage> {
  final _search = TextEditingController();
  PurchaseHistoryFilter _filter = const PurchaseHistoryFilter();
  String? _purchaser;
  String _periodLabel = '本月';

  @override
  void initState() {
    super.initState();
    _applyPreset(widget.initialPreset ?? 'month');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case 'month':
        _periodLabel = '本月';
        start = DateTime(now.year, now.month);
      case '3m':
        _periodLabel = '近3个月';
        start = DateTime(now.year, now.month - 2, 1);
      case 'year':
        _periodLabel = '本年度';
        start = DateTime(now.year);
      case 'all':
        _periodLabel = '全部日期';
        start = null;
        end = null;
    }
    _filter = _nextFilter(
      startDate: start,
      endDate: end,
      clearDates: preset == 'all',
    );
  }

  PurchaseHistoryFilter _nextFilter({
    String? keyword,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDates = false,
    String? purchaserName,
    bool clearPurchaser = false,
    PurchaseHistoryMode? mode,
    Set<PurchaseStatus>? historyStatus,
  }) => PurchaseHistoryFilter(
    keyword: keyword ?? _filter.keyword,
    startDate: clearDates ? null : startDate ?? _filter.startDate,
    endDate: clearDates ? null : endDate ?? _filter.endDate,
    purchaserName: clearPurchaser
        ? null
        : purchaserName ?? _filter.purchaserName,
    inventoryMaterialId: _filter.inventoryMaterialId,
    historyStatus: historyStatus ?? _filter.historyStatus,
    mode: mode ?? _filter.mode,
  );

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(purchaseHistoryByFilterProvider(_filter));
    final allPeople = ref.watch(
      purchaseHistoryByFilterProvider(const PurchaseHistoryFilter()),
    );
    final purchasers =
        allPeople.valueOrNull
            ?.map((row) => row.purchaserName)
            .whereType<String>()
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList() ??
        const <String>[];
    final annualRows = allPeople.valueOrNull ?? const <PurchaseHistoryRow>[];
    final year = DateTime.now().year;
    final appliedCount = annualRows
        .where((row) => row.appliedDate?.year == year)
        .map((row) => row.requestId)
        .toSet()
        .length;
    final completedCount = annualRows
        .where(
          (row) => row.completedAt?.year == year && row.receivedQuantity > 0,
        )
        .map((row) => row.requestId)
        .toSet()
        .length;
    return PurchasePageTheme(
      child: Scaffold(
        appBar: AppBar(title: const Text('采购历史')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  TextField(
                    key: const Key('purchase-history-search'),
                    controller: _search,
                    onChanged: (value) =>
                        setState(() => _filter = _nextFilter(keyword: value)),
                    decoration: InputDecoration(
                      hintText: '搜索物资名称 / 型号 / OA编号',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _filter.keyword.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _search.clear();
                                setState(
                                  () => _filter = _nextFilter(keyword: ''),
                                );
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<PurchaseHistoryMode>(
                    expandedInsets: EdgeInsets.zero,
                    segments: const [
                      ButtonSegment(
                        value: PurchaseHistoryMode.byRequest,
                        label: Text('按记录'),
                      ),
                      ButtonSegment(
                        value: PurchaseHistoryMode.byMaterial,
                        label: Text('按物资'),
                      ),
                    ],
                    selected: {_filter.mode},
                    onSelectionChanged: (value) => setState(
                      () => _filter = _nextFilter(mode: value.single),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (index, preset) in const [
                          ('month', '本月'),
                          ('3m', '近3个月'),
                          ('year', '本年度'),
                          ('custom', '自定义'),
                        ].indexed) ...[
                          if (index > 0) const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(preset.$2),
                            selected: preset.$2 == _periodLabel,
                            selectedColor: const Color(0xFF2563EB),
                            labelStyle: TextStyle(
                              color: preset.$2 == _periodLabel
                                  ? Colors.white
                                  : const Color(0xFF425D7F),
                            ),
                            onSelected: (_) {
                              if (preset.$1 == 'custom') {
                                _selectDateRange();
                              } else {
                                setState(() => _applyPreset(preset.$1));
                              }
                            },
                          ),
                        ],
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          tooltip: '更多日期范围',
                          onSelected: (value) =>
                              setState(() => _applyPreset(value)),
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'all', child: Text('全部日期')),
                          ],
                          child: const Chip(
                            avatar: Icon(Icons.tune, size: 18),
                            label: Text('筛选'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      PopupMenuButton<String>(
                        onSelected: (value) => setState(() {
                          _purchaser = value == '__all__' ? null : value;
                          _filter = _nextFilter(
                            purchaserName: _purchaser,
                            clearPurchaser: _purchaser == null,
                          );
                        }),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: '__all__',
                            child: Text('所有执行人'),
                          ),
                          for (final person in purchasers)
                            PopupMenuItem(value: person, child: Text(person)),
                        ],
                        child: Chip(
                          avatar: const Icon(Icons.person_outline, size: 18),
                          label: Text(_purchaser ?? '执行人'),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) => setState(() {
                          final status = value == '__all__'
                              ? <PurchaseStatus>{}
                              : {PurchaseStatus.parse(value)};
                          _filter = _nextFilter(historyStatus: status);
                        }),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: '__all__',
                            child: Text('全部状态'),
                          ),
                          for (final status in PurchaseStatus.values)
                            PopupMenuItem(
                              value: status.storageValue,
                              child: Text(status.label),
                            ),
                        ],
                        child: const Chip(
                          avatar: Icon(Icons.filter_alt_outlined, size: 18),
                          label: Text('状态筛选'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (allPeople.valueOrNull != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: PurchasePanel(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: PurchaseMetricTile(
                          label: '本年度申报',
                          value: '$appliedCount 次',
                          color: const Color(0xFF1677FF),
                          icon: Icons.description_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PurchaseMetricTile(
                          label: '完成入库',
                          value: '$completedCount 次',
                          color: const Color(0xFF00A85D),
                          icon: Icons.inventory_2_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: history.when(
                loading: () => const PurchaseLoadingState(),
                error: (error, stack) => PurchaseErrorState(
                  onRetry: () =>
                      ref.invalidate(purchaseHistoryByFilterProvider(_filter)),
                ),
                data: (rows) => rows.isEmpty
                    ? const PurchaseEmptyState(
                        title: '暂无采购历史',
                        message: '完成采购入库后，将自动形成历史记录。',
                      )
                    : _filter.mode == PurchaseHistoryMode.byRequest
                    ? _buildRequestHistory(rows)
                    : _buildMaterialHistory(rows),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestHistory(List<PurchaseHistoryRow> rows) {
    final grouped = <int, List<PurchaseHistoryRow>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.requestId, () => []).add(row);
    }
    final records = grouped.values.toList()
      ..sort((a, b) => _historyDate(b.first).compareTo(_historyDate(a.first)));
    final byMonth = <String, List<List<PurchaseHistoryRow>>>{};
    for (final record in records) {
      final date = _historyDate(record.first);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => []).add(record);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        for (final entry in byMonth.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              entry.key,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final record in entry.value) ...[
            _RequestHistoryCard(rows: record),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  DateTime _historyDate(PurchaseHistoryRow row) =>
      row.appliedDate ?? row.requestDate ?? DateTime(1);

  Widget _buildMaterialHistory(List<PurchaseHistoryRow> rows) {
    final grouped = <String, List<PurchaseHistoryRow>>{};
    for (final row in rows) {
      final key = row.inventoryMaterialId == null
          ? 'manual:${row.itemName}:${row.specification ?? ''}'
          : 'inventory:${row.inventoryMaterialId}';
      grouped.putIfAbsent(key, () => []).add(row);
    }
    final materials = grouped.values.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: materials.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _MaterialHistoryCard(rows: materials[index]),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final start = await pickPurchaseDate(
      context,
      initialDate: _filter.startDate,
    );
    if (start == null || !mounted) return;
    final end = await pickPurchaseDate(
      context,
      initialDate: _filter.endDate ?? DateTime.now(),
    );
    if (end == null || !mounted) return;
    if (end.isBefore(start)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('结束日期不能早于开始日期')));
      return;
    }
    setState(() {
      _periodLabel =
          '${purchaseShortDateLabel(start)}–${purchaseShortDateLabel(end)}';
      _filter = _nextFilter(startDate: start, endDate: end);
    });
  }
}

class _RequestHistoryCard extends StatelessWidget {
  const _RequestHistoryCard({required this.rows});
  final List<PurchaseHistoryRow> rows;

  @override
  Widget build(BuildContext context) {
    final first = rows.first;
    return PurchasePanel(
      child: InkWell(
        key: Key('purchase-history-request-${first.requestId}'),
        onTap: () => context.push(PurchaseRoutes.detail(first.requestId)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const PurchaseMaterialIcon(size: 62),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PurchaseStatusChip(status: first.status),
                      const SizedBox(height: 4),
                      Text(
                        rows.map((row) => row.itemName).join('、'),
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('申报日期：${purchaseDateLabel(first.appliedDate)}'),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            const Divider(height: 20),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${row.itemName}：申报 ${purchaseQuantityLabel(row.requestQuantity)} ${row.unit}',
                    ),
                    Text(
                      '实际入库 ${purchaseQuantityLabel(row.receivedQuantity)} ${row.unit}',
                    ),
                    Text('入库日期：${purchaseDateLabel(row.lastStockInDate)}'),
                  ],
                ),
              ),
            if (first.purchaserName != null) Text('执行人：${first.purchaserName}'),
            Text(
              '采购周期：${first.cycleDays == null ? '无足够记录' : '${first.cycleDays} 天'}',
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialHistoryCard extends StatelessWidget {
  const _MaterialHistoryCard({required this.rows});
  final List<PurchaseHistoryRow> rows;

  @override
  Widget build(BuildContext context) {
    final first = rows.first;
    final cycles = rows.map((row) => row.cycleDays).whereType<int>().toList();
    return PurchasePanel(
      child: InkWell(
        key: first.inventoryMaterialId == null
            ? null
            : Key('purchase-item-history-${first.inventoryMaterialId}'),
        onTap: first.inventoryMaterialId == null
            ? null
            : () => context.push(
                PurchaseRoutes.itemHistory(first.inventoryMaterialId!),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const PurchaseMaterialIcon(size: 58),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        first.itemName,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('${first.specification ?? '无规格'} · ${first.unit}'),
                    ],
                  ),
                ),
                if (first.inventoryMaterialId != null)
                  const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(
                  '当前库存：${first.currentStock == null ? '—' : purchaseQuantityLabel(first.currentStock!)} ${first.unit}',
                ),
                Text(
                  '历史采购：${rows.map((row) => row.requestId).toSet().length} 次',
                ),
                Text(
                  '最近申报：${purchaseShortDateLabel(_latestAppliedDate(rows))}',
                ),
                Text('最近周期：${cycles.isEmpty ? '—' : '${cycles.first}天'}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

DateTime? _latestAppliedDate(List<PurchaseHistoryRow> rows) {
  final dates = rows
      .map((row) => row.appliedDate)
      .whereType<DateTime>()
      .toList();
  if (dates.isEmpty) return null;
  dates.sort((a, b) => b.compareTo(a));
  return dates.first;
}
