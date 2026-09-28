import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../application/garden_tool_repair_providers.dart';
import '../domain/repair_formatters.dart';
import '../domain/repair_models.dart';
import '../domain/rmb_amount.dart';

class GardenToolRepairPage extends ConsumerStatefulWidget {
  const GardenToolRepairPage({this.initialYear, this.initialMonth, super.key});

  final int? initialYear;
  final int? initialMonth;

  @override
  ConsumerState<GardenToolRepairPage> createState() =>
      _GardenToolRepairPageState();
}

class _GardenToolRepairPageState extends ConsumerState<GardenToolRepairPage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final year = widget.initialYear ?? now.year;
    final requestedMonth = widget.initialMonth ?? now.month;
    _month = DateTime(
      year,
      requestedMonth >= 1 && requestedMonth <= 12 ? requestedMonth : now.month,
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(gardenToolRepairMonthProvider(_month));
    return Scaffold(
      appBar: AppBar(
        title: Text('${_month.month}月器械维修信息'),
        actions: [
          IconButton(
            tooltip: '维修单位',
            onPressed: () => context.push('/garden-tool-repairs/units'),
            icon: const Icon(Icons.business_outlined),
          ),
          IconButton(
            tooltip: '数据分析',
            onPressed: () => context.push(
              '/garden-tool-repairs/analysis?year=${_month.year}&month=${_month.month}',
            ),
            icon: const Icon(
              Icons.bar_chart_outlined,
              color: AppColors.techBlue,
            ),
          ),
          IconButton(
            tooltip: '价格比对',
            onPressed: () => context.push('/garden-tool-repairs/prices'),
            icon: const Icon(Icons.sell_outlined, color: AppColors.techBlue),
          ),
          IconButton(
            tooltip: '新增维修记录',
            onPressed: _addGroup,
            icon: const Icon(Icons.add_circle, color: AppColors.primary),
          ),
        ],
      ),
      body: SafeArea(
        child: groupsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _LoadError(message: error.toString()),
          data: (groups) => _buildLedger(groups),
        ),
      ),
    );
  }

  Widget _buildLedger(List<GardenToolRepairLedgerGroup> groups) {
    final summary = GardenToolRepairMonthSummary.fromGroups(groups);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _MonthSelector(
          month: _month,
          onPrevious: () => _changeMonth(-1),
          onNext: () => _changeMonth(1),
          onPick: _pickMonth,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: '本月合计',
                value: formatRepairMoney(summary.totalCents),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryCard(
                label: '记录组数',
                value: '${summary.groupCount}',
                color: AppColors.techBlue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryCard(
                label: '项目条数',
                value: '${summary.itemCount}',
                color: const Color(0xFFEF8B27),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          _EmptyLedger(onAdd: _addGroup)
        else
          for (final entry in groups) ...[
            _RepairGroupCard(
              entry: entry,
              onEdit: () => context.push(
                '/garden-tool-repairs/groups/${entry.group.id}/edit',
              ),
              onCopy: () => _copyGroup(entry.group.id),
              onDelete: () => _deleteGroup(entry.group.id),
              onAttachments: () => context.push(
                '/garden-tool-repairs/groups/${entry.group.id}/attachments',
              ),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 4),
        _MonthTotal(totalCents: summary.totalCents),
      ],
    );
  }

  void _changeMonth(int difference) {
    setState(() => _month = DateTime(_month.year, _month.month + difference));
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '选择维修月份',
    );
    if (picked != null && mounted) {
      setState(() => _month = DateTime(picked.year, picked.month));
    }
  }

  void _addGroup() {
    context.push(
      '/garden-tool-repairs/new?year=${_month.year}&month=${_month.month}',
    );
  }

  Future<void> _copyGroup(int id) async {
    try {
      final draft = await ref
          .read(gardenToolRepairRepositoryProvider)
          .copyDraft(id);
      if (mounted) {
        context.push(
          '/garden-tool-repairs/new?year=${_month.year}&month=${_month.month}',
          extra: draft,
        );
      }
    } catch (error) {
      if (mounted) _showMessage('复制失败：$error');
    }
  }

  Future<void> _deleteGroup(int id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除维修记录组？'),
        content: const Text('该组及其明细、附件将移入软删除记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    try {
      await ref.read(gardenToolRepairRepositoryProvider).softDeleteGroup(id);
    } catch (error) {
      if (mounted) _showMessage('删除失败：$error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => Card(
    child: Row(
      children: [
        IconButton(
          tooltip: '上个月',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: TextButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.calendar_month, color: AppColors.primary),
            label: Text('${month.year}年${month.month}月'),
          ),
        ),
        IconButton(
          tooltip: '下个月',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RepairGroupCard extends StatelessWidget {
  const _RepairGroupCard({
    required this.entry,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
    required this.onAttachments,
  });

  final GardenToolRepairLedgerGroup entry;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback onAttachments;

  @override
  Widget build(BuildContext context) {
    final group = entry.group;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.event_available,
                  color: AppColors.primary,
                  size: 19,
                ),
                const SizedBox(width: 7),
                Text('${group.repairDate.month}月${group.repairDate.day}日'),
                const SizedBox(width: 8),
                const _HeaderDivider(),
                const SizedBox(width: 8),
                const Icon(
                  Icons.apartment,
                  color: AppColors.techBlue,
                  size: 18,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    group.unitNameSnapshot,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const _HeaderDivider(),
                const SizedBox(width: 8),
                const Icon(
                  Icons.person_outline,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    group.repairerNameSnapshot,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<_GroupAction>(
                  tooltip: '更多操作',
                  onSelected: (action) {
                    switch (action) {
                      case _GroupAction.edit:
                        onEdit();
                      case _GroupAction.copy:
                        onCopy();
                      case _GroupAction.delete:
                        onDelete();
                      case _GroupAction.attachments:
                        onAttachments();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _GroupAction.edit,
                      child: Text('编辑本组'),
                    ),
                    PopupMenuItem(
                      value: _GroupAction.copy,
                      child: Text('复制本组'),
                    ),
                    PopupMenuItem(
                      value: _GroupAction.attachments,
                      child: Text('查看附件（${entry.attachmentCount}）'),
                    ),
                    PopupMenuItem(
                      value: _GroupAction.delete,
                      child: Text('删除本组'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                horizontalMargin: 8,
                columnSpacing: 14,
                headingRowHeight: 38,
                dataRowMinHeight: 42,
                dataRowMaxHeight: 48,
                columns: const [
                  DataColumn(label: Text('项目名称')),
                  DataColumn(label: Text('规格')),
                  DataColumn(label: Text('单位')),
                  DataColumn(label: Text('数量'), numeric: true),
                  DataColumn(label: Text('单价'), numeric: true),
                  DataColumn(label: Text('金额'), numeric: true),
                  DataColumn(label: Text('备注')),
                ],
                rows: [
                  for (final item in entry.items)
                    DataRow(
                      cells: [
                        DataCell(Text(item.projectName)),
                        DataCell(Text(item.specModel ?? '—')),
                        DataCell(Text(item.countUnit)),
                        DataCell(Text(formatRepairQuantity(item.quantity))),
                        DataCell(Text(formatRepairMoney(item.unitPriceCents))),
                        DataCell(
                          Text(
                            formatRepairMoney(item.amountCents),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        DataCell(Text(item.remark ?? '—')),
                      ],
                    ),
                ],
              ),
            ),
            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '小计：${formatRepairMoney(entry.subtotalCents)}',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _GroupAction { edit, copy, delete, attachments }

class _HeaderDivider extends StatelessWidget {
  const _HeaderDivider();

  @override
  Widget build(BuildContext context) =>
      Container(height: 18, width: 1, color: AppColors.divider);
}

class _MonthTotal extends StatelessWidget {
  const _MonthTotal({required this.totalCents});

  final int totalCents;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.lightGreen,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: AppColors.primary, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('合计金额', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 3),
                Text(
                  formatRepairMoney(totalCents),
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(color: AppColors.primary),
                ),
                Text(
                  '金额大写：${rmbUppercase(totalCents)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.summarize, color: AppColors.primary, size: 42),
        ],
      ),
    ),
  );
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 54,
            color: AppColors.helper,
          ),
          const SizedBox(height: 12),
          const Text('本月暂无维修记录'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('新增维修记录'),
          ),
        ],
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 44),
          const SizedBox(height: 10),
          const Text('维修台账加载失败'),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('返回'),
          ),
        ],
      ),
    ),
  );
}
