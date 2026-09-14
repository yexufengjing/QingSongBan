import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../application/item_distribution_providers.dart';
import '../domain/item_distribution_models.dart';

class ItemDistributionPage extends ConsumerStatefulWidget {
  const ItemDistributionPage({super.key});

  @override
  ConsumerState<ItemDistributionPage> createState() => _ItemDistributionPageState();
}

class _ItemDistributionPageState extends ConsumerState<ItemDistributionPage> {
  late DateTime _month;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month - 1, 1);
  }

  String get _monthKey => '${_month.year.toString().padLeft(4, '0')}-${_month.month.toString().padLeft(2, '0')}';

  void _refresh() {
    ref.invalidate(distributionGroupsProvider(_monthKey));
    ref.invalidate(distributionSummaryProvider(_monthKey));
    ref.invalidate(temporaryWelfareCandidatesProvider(_monthKey));
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(distributionGroupsProvider(_monthKey));
    final summaryAsync = ref.watch(distributionSummaryProvider(_monthKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('物品领取'),
        actions: [
          IconButton(
            tooltip: '发放设置',
            onPressed: _showSettings,
            icon: const Icon(Icons.tune_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            _monthHeader(),
            const SizedBox(height: 12),
            summaryAsync.when(
              loading: () => const SizedBox(height: 92, child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
              data: _summaryCards,
            ),
            const SizedBox(height: 14),
            _actionPanel(),
            const SizedBox(height: 14),
            _filterBar(),
            const SizedBox(height: 8),
            groupsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('领取记录加载失败：$error'),
                ),
              ),
              data: (groups) {
                final visible = groups.where(_matchesFilter).toList();
                if (visible.isEmpty) return _emptyState(groups.isEmpty);
                return Column(
                  children: [
                    for (final group in visible) ...[
                      _recipientCard(group),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showManualDistribution,
        icon: const Icon(Icons.add),
        label: const Text('办公/工具领用'),
      ),
    );
  }

  Widget _monthHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1, 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickMonth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Text('福利归属月份', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 2),
                      Text('${_month.year}年${_month.month}月', style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1, 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCards(DistributionSummary summary) {
    final values = [
      ('应领', summary.recipientCount, AppColors.techBlue),
      ('已领', summary.receivedCount, AppColors.primary),
      ('待领', summary.pendingCount, const Color(0xFFE98500)),
      ('未领', summary.notReceivedCount, AppColors.danger),
    ];
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text('${values[i].$2}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: values[i].$3, fontWeight: FontWeight.w800)),
                    Text(values[i].$1, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _actionPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本月福利', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('正式工自动带入；临时工按本月实际发放名单勾选。系统按规则自动生成洗衣膏、手套和毛巾。'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _generateWelfare,
                    icon: const Icon(Icons.playlist_add_check_circle_outlined),
                    label: const Text('生成/补充福利清单'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _addFormalTowel,
                  child: const Text('正式工加毛巾'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterBar() {
    final filters = [('all', '全部'), ('pending', '待领'), ('received', '已领'), ('notReceived', '未领')];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in filters) ...[
            ChoiceChip(
              label: Text(item.$2),
              selected: _filter == item.$1,
              onSelected: (_) => setState(() => _filter = item.$1),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  bool _matchesFilter(DistributionRecipientGroup group) {
    return switch (_filter) {
      'pending' => group.hasPending,
      'received' => group.allReceived,
      'notReceived' => group.hasNotReceived,
      _ => true,
    };
  }

  Widget _recipientCard(DistributionRecipientGroup group) {
    final statusColor = group.allReceived
        ? AppColors.primary
        : group.hasNotReceived
            ? AppColors.danger
            : const Color(0xFFE98500);
    final statusText = group.allReceived ? '已领取' : group.hasNotReceived ? '未领取' : '待领取';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Icon(group.recipientType == 'employee' ? Icons.person_outline : Icons.inventory_2_outlined, color: statusColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.recipientName, style: Theme.of(context).textTheme.titleMedium),
                      if (group.employmentType != null) Text(group.employmentType!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: group.entries.map((entry) {
                final q = entry.quantity == entry.quantity.roundToDouble() ? entry.quantity.toInt().toString() : entry.quantity.toString();
                return Chip(label: Text('${entry.itemName} $q${entry.unit}'));
              }).toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: group.allReceived ? null : () => _setStatus(group, DistributionStatus.received),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('签收'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _setStatus(group, DistributionStatus.notReceived),
                  child: const Text('未领取'),
                ),
                if (!group.hasPending) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '恢复待领取',
                    onPressed: () => _setStatus(group, DistributionStatus.pending),
                    icon: const Icon(Icons.undo),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(bool noRecords) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(Icons.inventory_2_outlined, size: 46, color: AppColors.body),
            const SizedBox(height: 10),
            Text(noRecords ? '本月还没有领取清单' : '当前筛选下没有记录'),
            if (noRecords) ...[
              const SizedBox(height: 6),
              const Text('点击“生成/补充福利清单”即可开始。'),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _generateWelfare() async {
    final candidates = await ref.read(temporaryWelfareCandidatesProvider(_monthKey).future);
    if (!mounted) return;
    final selected = <int>{for (final c in candidates.where((c) => c.isCurrentlyActive)) c.id};
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('选择临时工发放名单', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text('默认勾选当前在岗人员；已离职但在 $_monthKey 仍符合归属条件的人员会保留在名单中，可手动勾选。'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton(onPressed: () => setSheetState(() { selected..clear()..addAll(candidates.map((e) => e.id)); }), child: const Text('全选')),
                        TextButton(onPressed: () => setSheetState(selected.clear), child: const Text('清空')),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          final candidate = candidates[index];
                          return CheckboxListTile(
                            value: selected.contains(candidate.id),
                            onChanged: (value) => setSheetState(() {
                              if (value == true) { selected.add(candidate.id); } else { selected.remove(candidate.id); }
                            }),
                            title: Text(candidate.name),
                            subtitle: Text('${candidate.employeeNo}${candidate.isCurrentlyActive ? '' : ' · 当前非在岗'}'),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, Set<int>.from(selected)),
                        child: Text('生成福利清单（临时工 ${selected.length} 人）'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (result == null) return;
    await ref.read(itemDistributionRepositoryProvider).ensureWelfareBatch(month: _monthKey, temporaryEmployeeIds: result);
    _refresh();
  }

  Future<void> _addFormalTowel() async {
    await ref.read(itemDistributionRepositoryProvider).addFormalTowelForMonth(_monthKey);
    _refresh();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已为本月正式工补充毛巾')));
  }

  Future<void> _setStatus(DistributionRecipientGroup group, DistributionStatus status) async {
    await ref.read(itemDistributionRepositoryProvider).setRecipientStatus(_monthKey, group.recipientKey, status);
    _refresh();
  }

  Future<void> _showSettings() async {
    final repo = ref.read(itemDistributionRepositoryProvider);
    final sweeper = TextEditingController(text: '${await repo.getSweeperCount()}');
    final public = TextEditingController(text: '${await repo.getPublicCount()}');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('福利发放设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: sweeper, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '扫路车数量', helperText: '默认 6 辆，可随时修改')),
            const SizedBox(height: 12),
            TextField(controller: public, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '公用福利份数', helperText: '按实际公用份数填写')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              await repo.setSweeperCount(int.tryParse(sweeper.text) ?? 6);
              await repo.setPublicCount(int.tryParse(public.text) ?? 1);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _showManualDistribution() async {
    var category = DistributionCategory.office;
    final recipient = TextEditingController();
    final item = TextEditingController();
    final qty = TextEditingController(text: '1');
    final unit = TextEditingController(text: '件');
    final note = TextEditingController();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('新增办公/工具领用'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<DistributionCategory>(
                  segments: const [
                    ButtonSegment(value: DistributionCategory.office, label: Text('办公用品'), icon: Icon(Icons.print_outlined)),
                    ButtonSegment(value: DistributionCategory.tool, label: Text('工具'), icon: Icon(Icons.build_outlined)),
                  ],
                  selected: {category},
                  onSelectionChanged: (value) => setDialogState(() => category = value.first),
                ),
                const SizedBox(height: 12),
                TextField(controller: recipient, decoration: const InputDecoration(labelText: '领取人/领取对象')),
                const SizedBox(height: 10),
                TextField(controller: item, decoration: const InputDecoration(labelText: '物品名称')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '数量'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: '单位'))),
                ]),
                const SizedBox(height: 10),
                TextField(controller: note, decoration: const InputDecoration(labelText: '备注（可选）')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                if (recipient.text.trim().isEmpty || item.text.trim().isEmpty) return;
                final draft = ManualDistributionDraft(
                  category: category,
                  month: _monthKey,
                  recipientName: recipient.text.trim(),
                  recipientType: 'custom',
                  recipientKey: 'custom:${recipient.text.trim()}',
                  itemName: item.text.trim(),
                  quantity: double.tryParse(qty.text) ?? 1,
                  unit: unit.text.trim().isEmpty ? '件' : unit.text.trim(),
                  note: note.text.trim().isEmpty ? null : note.text.trim(),
                );
                final repo = ref.read(itemDistributionRepositoryProvider);
                final duplicates = await repo.duplicateCount(draft);
                if (!context.mounted) return;
                if (duplicates > 0) {
                  final proceed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('重复领取提醒'),
                      content: Text('${draft.recipientName} 本月已有“${draft.itemName}”领取记录。是否仍要继续登记？'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('返回检查')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('仍然登记')),
                      ],
                    ),
                  );
                  if (proceed != true) return;
                }
                await repo.addManualDistribution(draft);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                _refresh();
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMonth() async {
    final year = await showDialog<int>(
      context: context,
      builder: (context) {
        var selectedYear = _month.year;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('选择年份'),
            content: DropdownButtonFormField<int>(
              initialValue: selectedYear,
              items: [for (var y = DateTime.now().year - 5; y <= DateTime.now().year + 2; y++) DropdownMenuItem(value: y, child: Text('$y年'))],
              onChanged: (value) => setState(() => selectedYear = value ?? selectedYear),
            ),
            actions: [FilledButton(onPressed: () => Navigator.pop(context, selectedYear), child: const Text('下一步'))],
          ),
        );
      },
    );
    if (year == null || !mounted) return;
    final month = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择月份'),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (var m = 1; m <= 12; m++) ActionChip(label: Text('$m月'), onPressed: () => Navigator.pop(context, m))],
            ),
          ),
        ],
      ),
    );
    if (month != null) setState(() => _month = DateTime(year, month, 1));
  }
}
