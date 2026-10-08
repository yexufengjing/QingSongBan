import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/inventory_providers.dart';
import 'widgets/inventory_export_button.dart';
import 'widgets/inventory_widgets.dart';

class InventoryIssuesPage extends ConsumerStatefulWidget {
  const InventoryIssuesPage({super.key});

  @override
  ConsumerState<InventoryIssuesPage> createState() =>
      _InventoryIssuesPageState();
}

class _InventoryIssuesPageState extends ConsumerState<InventoryIssuesPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _type = 'all';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final issues = ref.watch(inventoryIssuesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('领用记录'),
        centerTitle: false,
        actions: [const InventoryExportButton()],
      ),
      bottomNavigationBar: InventoryFormFooter(
        label: '新增领取登记',
        icon: Icons.add,
        buttonKey: const Key('inventory-issue-add-fixed'),
        onSave: () => context.push('/inventory/issues/new'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final controls = _IssueMonthControls(
                  month: _month,
                  onMonthChanged: (value) => setState(() => _month = value),
                );
                final search = _IssueSearchField(
                  controller: _searchController,
                  onChanged: () => setState(() {}),
                );
                if (constraints.maxWidth < 340) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [controls, const SizedBox(height: 8), search],
                  );
                }
                return Row(
                  children: [
                    controls,
                    const SizedBox(width: 8),
                    Expanded(child: search),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: DropdownButtonFormField<String>(
              key: const Key('inventory-issue-type-filter'),
              initialValue: _type,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('全部类型')),
                DropdownMenuItem(value: 'employee_claim', child: Text('员工领取')),
                DropdownMenuItem(
                  value: 'department_use',
                  child: Text('部门/公用领取'),
                ),
                DropdownMenuItem(value: 'transfer_out', child: Text('调拨出库')),
                DropdownMenuItem(value: 'other', child: Text('其他出库')),
              ],
              onChanged: (value) => setState(() => _type = value ?? 'all'),
            ),
          ),
          Expanded(
            child: issues.when(
              loading: () => const InventoryLoadingState(),
              error: (_, _) => InventoryErrorState(
                onRetry: () => ref.invalidate(inventoryIssuesProvider),
              ),
              data: (allIssues) {
                final monthIssues = allIssues.where((issue) {
                  final sameMonth =
                      issue.issueDate.year == _month.year &&
                      issue.issueDate.month == _month.month;
                  return sameMonth;
                }).toList();
                final itemResultsByIssueId =
                    <int, AsyncValue<List<InventoryIssueItem>>>{};
                for (final issue in monthIssues) {
                  itemResultsByIssueId[issue.id] = ref.watch(
                    inventoryIssueItemsProvider(issue.id),
                  );
                }
                final query = _searchController.text.trim().toLowerCase();
                var materialSearchLoading = false;
                final materialSearchErrors = <int>[];
                final filtered = monthIssues.where((issue) {
                  if (_type != 'all' && issue.issueType != _type) return false;
                  if (query.isEmpty) return true;
                  final receiverMatches = _receiverName(issue)
                      .toLowerCase()
                      .contains(query);
                  final lines = itemResultsByIssueId[issue.id]!;
                  if (!receiverMatches && lines.hasError) {
                    materialSearchErrors.add(issue.id);
                  } else if (!receiverMatches && !lines.hasValue) {
                    materialSearchLoading = true;
                  }
                  final materialMatches =
                      lines.valueOrNull?.any(
                        (item) => item.materialNameSnapshot
                            .toLowerCase()
                            .contains(query),
                      ) ??
                      false;
                  return receiverMatches || materialMatches;
                }).toList()..sort((a, b) => b.issueDate.compareTo(a.issueDate));
                final receiverCount = filtered.where(_hasReceiver).length;
                final itemResults = filtered
                    .map((issue) => itemResultsByIssueId[issue.id]!)
                    .toList(growable: false);
                final detailCount = _detailCountLabel(itemResults);
                final quantityByUnit = _quantityByUnitLabel(itemResults);
                final dateGroups = <DateTime, List<InventoryIssue>>{};
                for (final issue in filtered) {
                  final day = DateTime(
                    issue.issueDate.year,
                    issue.issueDate.month,
                    issue.issueDate.day,
                  );
                  dateGroups.putIfAbsent(day, () => []).add(issue);
                }
                if (filtered.isEmpty && materialSearchErrors.isNotEmpty) {
                  return InventoryErrorState(
                    onRetry: () {
                      for (final id in materialSearchErrors) {
                        ref.invalidate(inventoryIssueItemsProvider(id));
                      }
                    },
                  );
                }
                if (filtered.isEmpty && materialSearchLoading) {
                  return const InventoryLoadingState();
                }
                if (filtered.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _IssueMetricsPanel(
                        quantity: '0',
                        receivers: '0',
                        entries: '0',
                      ),
                      InventoryEmptyState(
                        title: query.isNotEmpty
                            ? '没有匹配记录'
                            : allIssues.isEmpty
                            ? '暂无领用记录'
                            : '本月暂无领用记录',
                        message: query.isNotEmpty
                            ? '换个领取人或物资名称试试。'
                            : allIssues.isEmpty
                            ? '员工领取或其他领用完成后会在此显示。'
                            : '调整月份或类型筛选后再试。',
                        action: FilledButton.icon(
                          onPressed: query.isNotEmpty
                              ? () {
                                  _searchController.clear();
                                  setState(() {});
                                }
                              : () => context.push('/inventory/issues/new'),
                          icon: Icon(
                            query.isNotEmpty ? Icons.close : Icons.add,
                          ),
                          label: Text(query.isNotEmpty ? '清除搜索' : '登记领用'),
                        ),
                      ),
                    ],
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(inventoryIssuesProvider),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                    children: [
                      _IssueMetricsPanel(
                        quantity: quantityByUnit,
                        receivers: '$receiverCount',
                        entries: detailCount,
                      ),
                      const SizedBox(height: 12),
                      for (final day
                          in dateGroups.keys.toList()
                            ..sort((a, b) => b.compareTo(a))) ...[
                        _IssueDateGroup(day: day, issues: dateGroups[day]!),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueMonthControls extends StatelessWidget {
  const _IssueMonthControls({
    required this.month,
    required this.onMonthChanged,
  });

  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;

  Future<void> _pickMonth(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: month,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: '选择统计月份',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (selected != null) {
      onMonthChanged(DateTime(selected.year, selected.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final canGoForward = month.isBefore(currentMonth);
    final canGoBack = month.isAfter(DateTime(2000, 1));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MonthArrowButton(
          tooltip: '上个月',
          icon: Icons.chevron_left,
          onPressed: canGoBack
              ? () => onMonthChanged(DateTime(month.year, month.month - 1))
              : null,
        ),
        const SizedBox(width: 4),
        Material(
          color: AppColors.lightBlue,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            key: const Key('inventory-issue-month'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => _pickMonth(context),
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    '${month.year}年${month.month}月',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        _MonthArrowButton(
          tooltip: '下个月',
          icon: Icons.chevron_right,
          onPressed: canGoForward
              ? () => onMonthChanged(DateTime(month.year, month.month + 1))
              : null,
        ),
      ],
    );
  }
}

class _MonthArrowButton extends StatelessWidget {
  const _MonthArrowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: AppColors.lightBlue,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 44,
          child: Icon(
            icon,
            color: onPressed == null ? AppColors.body : AppColors.primary,
          ),
        ),
      ),
    ),
  );
}

class _IssueSearchField extends StatelessWidget {
  const _IssueSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    key: const Key('inventory-issue-search'),
    controller: controller,
    onChanged: (_) => onChanged(),
    decoration: InputDecoration(
      hintText: '搜索领取人或物资',
      prefixIcon: const Icon(Icons.search),
      suffixIcon: controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: '清除搜索',
              onPressed: () {
                controller.clear();
                onChanged();
              },
              icon: const Icon(Icons.close),
            ),
      isDense: true,
    ),
  );
}

String _detailCountLabel<T>(List<AsyncValue<List<T>>> itemResults) {
  if (itemResults.any((result) => result.hasError)) return '—';
  if (itemResults.any((result) => !result.hasValue)) return '…';
  return '${itemResults.fold<int>(0, (total, result) => total + result.requireValue.length)}';
}

String _quantityByUnitLabel(
  List<AsyncValue<List<InventoryIssueItem>>> itemResults,
) {
  if (itemResults.any((result) => result.hasError)) return '—';
  if (itemResults.any((result) => !result.hasValue)) return '…';
  final totals = <String, double>{};
  for (final result in itemResults) {
    for (final item in result.requireValue) {
      totals.update(
        item.unitSnapshot,
        (quantity) => quantity + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }
  }
  if (totals.isEmpty) return '0';
  return totals.entries
      .map((entry) => '${_formatQuantity(entry.value)}${entry.key}')
      .join('\n');
}

String _formatQuantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

bool _hasReceiver(InventoryIssue issue) => switch (issue.receiverType) {
  'employee' => (issue.employeeNameSnapshot ?? '').trim().isNotEmpty,
  'manual' => (issue.manualReceiverName ?? '').trim().isNotEmpty,
  'department' => (issue.departmentNameSnapshot ?? '').trim().isNotEmpty,
  'public' => true,
  _ => false,
};

class _IssueDateGroup extends StatelessWidget {
  const _IssueDateGroup({required this.day, required this.issues});

  final DateTime day;
  final List<InventoryIssue> issues;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Container(
      key: Key('inventory-issue-day-${day.year}-${day.month}-${day.day}'),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              '${day.month.toString().padLeft(2, '0')}月${day.day.toString().padLeft(2, '0')}日  周${weekdays[day.weekday - 1]}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (var index = 0; index < issues.length; index++) ...[
            _IssueSummaryRow(issue: issues[index]),
            if (index < issues.length - 1)
              const Divider(height: 1, indent: 42, endIndent: 8),
          ],
        ],
      ),
    );
  }
}

class _IssueMetricsPanel extends StatelessWidget {
  const _IssueMetricsPanel({
    required this.quantity,
    required this.receivers,
    required this.entries,
  });

  final String quantity;
  final String receivers;
  final String entries;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.divider),
    ),
    child: Row(
      children: [
        _IssueMetric(
          label: '领用数量',
          value: quantity,
          icon: Icons.front_hand_outlined,
        ),
        const _MetricDivider(),
        _IssueMetric(
          label: '领取人次',
          value: receivers,
          icon: Icons.people_alt_outlined,
        ),
        const _MetricDivider(),
        _IssueMetric(
          label: '记录条目',
          value: entries,
          icon: Icons.receipt_long_outlined,
        ),
      ],
    ),
  );
}

class _IssueMetric extends StatelessWidget {
  const _IssueMetric({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 54,
    margin: const EdgeInsets.symmetric(horizontal: 5),
    color: AppColors.divider,
  );
}

class _IssueSummaryRow extends ConsumerWidget {
  const _IssueSummaryRow({required this.issue});
  final InventoryIssue issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(inventoryIssueItemsProvider(issue.id));
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: Key('inventory-issue-${issue.id}'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push('/inventory/issues/${issue.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.front_hand_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _receiverName(issue),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_timeLabel(issue.issueDate)} · ${_issueType(issue.issueType)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 5),
                    lines.when(
                      loading: () => const Text('正在读取物资…'),
                      error: (_, _) => const Text('物资明细暂时无法读取'),
                      data: (items) => Text(
                        items.isEmpty
                            ? '暂无物资明细'
                            : '${items.first.materialNameSnapshot}${items.first.modelSnapshot == null ? '' : ' · ${items.first.modelSnapshot}'} · ${_quantity(items.first.quantity)}${items.first.unitSnapshot}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  lines.when(
                    loading: () => const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, _) => const Text('—'),
                    data: (items) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '共${items.length}项',
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.helper),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _receiverName(InventoryIssue issue) =>
    issue.employeeNameSnapshot ??
    issue.manualReceiverName ??
    issue.departmentNameSnapshot ??
    '公用';
String _issueType(String value) => switch (value) {
  'employee_claim' => '员工领用',
  'department_use' => '部门领用',
  'transfer_out' => '调拨出库',
  'stocktake_loss' => '盘亏出库',
  _ => '其他出库',
};
String _timeLabel(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _quantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
