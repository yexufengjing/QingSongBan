import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../application/garden_tool_repair_providers.dart';
import '../domain/repair_formatters.dart';
import '../domain/repair_models.dart';
import '../domain/rmb_amount.dart';
import 'garden_tool_repair_design.dart';

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
    return Theme(
      data: gardenToolRepairTheme(context),
      child: Scaffold(
        appBar: AppBar(title: Text('${_month.month}月器械维修信息')),
        body: SafeArea(
          child: groupsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _LoadError(message: error.toString()),
            data: (groups) => _buildLedger(groups),
          ),
        ),
      ),
    );
  }

  Widget _buildLedger(List<GardenToolRepairLedgerGroup> groups) {
    final summary = GardenToolRepairMonthSummary.fromGroups(groups);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _MonthSelector(month: _month, onPick: _pickMonth),
            ),
            _RepairHeaderAction(
              icon: Icons.add,
              label: '新增',
              color: AppColors.primary,
              onPressed: _addGroup,
            ),
            _RepairHeaderAction(
              icon: Icons.bar_chart,
              label: '分析',
              color: AppColors.primary,
              onPressed: () => context.push(
                '/garden-tool-repairs/analysis?year=${_month.year}&month=${_month.month}',
              ),
            ),
            _RepairHeaderAction(
              icon: Icons.show_chart,
              label: '比价',
              color: AppColors.primary,
              onPressed: () => context.push('/garden-tool-repairs/prices'),
            ),
            PopupMenuButton<String>(
              tooltip: '更多功能',
              child: Container(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 56),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.more_horiz, color: AppColors.body),
                    SizedBox(height: 4),
                    Text(
                      '更多',
                      style: TextStyle(color: AppColors.body, fontSize: 14),
                    ),
                  ],
                ),
              ),
              onSelected: (value) {
                if (value == 'units') {
                  context.push('/garden-tool-repairs/units');
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'units', child: Text('维修单位管理')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: '本月合计',
                    value: formatRepairMoney(summary.totalCents),
                    color: AppColors.primary,
                    icon: Icons.account_balance_wallet,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryCard(
                    label: '记录组数',
                    value: '${summary.groupCount}',
                    color: AppColors.success,
                    icon: Icons.receipt_long,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryCard(
                    label: '项目条数',
                    value: '${summary.itemCount}',
                    color: const Color(0xFFEF8B27),
                    icon: Icons.format_list_bulleted,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
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
            const SizedBox(height: 16),
          ],
        const SizedBox(height: 4),
        _MonthTotal(totalCents: summary.totalCents),
      ],
    );
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
  const _MonthSelector({required this.month, required this.onPick});

  final DateTime month;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Center(
      child: TextButton.icon(
        onPressed: onPick,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.lightBlue,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: const Icon(Icons.calendar_month, size: 18),
        label: Text('${month.year}年${month.month}月'),
      ),
    ),
  );
}

class _RepairHeaderAction extends StatelessWidget {
  const _RepairHeaderAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    child: Material(
      color: label == '新增' ? AppColors.primary : AppColors.lightBlue,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: label == '新增' ? Colors.white : color, size: 21),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: label == '新增' ? Colors.white : color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 88),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: AppColors.body, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ],
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
        padding: const EdgeInsets.all(16),
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
                const Icon(Icons.apartment, color: AppColors.primary, size: 18),
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
                headingRowColor: const WidgetStatePropertyAll(
                  AppColors.background,
                ),
                headingTextStyle: const TextStyle(
                  color: AppColors.body,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                dataTextStyle: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 14,
                ),
                horizontalMargin: 14,
                columnSpacing: 24,
                headingRowHeight: 44,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 68,
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
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '小计：${formatRepairMoney(entry.subtotalCents)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
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
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '合计金额',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  formatRepairMoney(totalCents),
                  style: const TextStyle(
                    fontSize: 24,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 56, child: VerticalDivider(width: 24)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('金额大写', style: TextStyle(color: AppColors.body)),
                const SizedBox(height: 8),
                Text(
                  rmbUppercase(totalCents),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
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
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
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
          const SizedBox(height: 16),
          const Text('维修台账加载失败'),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('返回'),
          ),
        ],
      ),
    ),
  );
}
