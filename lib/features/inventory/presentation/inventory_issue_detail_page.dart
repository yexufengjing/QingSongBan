import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/inventory_providers.dart';
import 'widgets/inventory_widgets.dart';

class InventoryIssueDetailPage extends ConsumerStatefulWidget {
  const InventoryIssueDetailPage({required this.issueId, super.key});
  final int issueId;

  @override
  ConsumerState<InventoryIssueDetailPage> createState() =>
      _InventoryIssueDetailPageState();
}

class _InventoryIssueDetailPageState
    extends ConsumerState<InventoryIssueDetailPage> {
  late Future<InventoryIssue?> _issue;
  late Future<List<InventoryIssueItem>> _items;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final service = ref.read(inventoryServiceProvider);
    _issue = service.getIssue(widget.issueId);
    _items = service.getIssueItems(widget.issueId);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤销这笔出库？'),
        content: const Text('库存会按出库明细返还，并生成对应流水。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('撤销出库'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(inventoryServiceProvider).deleteIssue(widget.issueId);
      ref.invalidate(inventoryIssuesProvider);
      ref.invalidate(inventoryStockProvider);
      ref.invalidate(inventoryMaterialsProvider);
      ref.invalidate(inventoryOverviewProvider);
      ref.invalidate(inventoryWarningsProvider);
      ref.invalidate(inventoryTransactionsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('撤销失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('出库详情'),
      actions: [
        IconButton(
          tooltip: '撤销出库',
          onPressed: _deleting ? null : _delete,
          icon: _deleting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline),
        ),
      ],
    ),
    body: FutureBuilder<InventoryIssue?>(
      future: _issue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return InventoryErrorState(onRetry: () => setState(_load));
        }
        if (!snapshot.hasData) return const InventoryLoadingState();
        final issue = snapshot.data;
        if (issue == null) return const InventoryEmptyState(title: '出库单不存在');
        return FutureBuilder<List<InventoryIssueItem>>(
          future: _items,
          builder: (context, itemSnapshot) {
            if (itemSnapshot.hasError) {
              return InventoryErrorState(onRetry: () => setState(_load));
            }
            if (!itemSnapshot.hasData) return const InventoryLoadingState();
            final receiver =
                issue.employeeNameSnapshot ??
                issue.manualReceiverName ??
                issue.departmentNameSnapshot ??
                '公用';
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issue.issueNo,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        _IssueInfo(
                          label: '领取日期',
                          value: _dateLabel(issue.issueDate),
                        ),
                        _IssueInfo(label: '领取人', value: receiver),
                        _IssueInfo(
                          label: '所属单位',
                          value: issue.departmentNameSnapshot ?? '未填写',
                        ),
                        _IssueInfo(label: '用途', value: issue.purpose ?? '未填写'),
                        _IssueInfo(
                          label: '经办人',
                          value: issue.operatorNameSnapshot ?? '未填写',
                        ),
                        _IssueInfo(
                          label: '备注',
                          value: issue.remark ?? '无',
                          last: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                InventorySection(
                  title: '领用明细',
                  icon: Icons.list_alt_outlined,
                  child: itemSnapshot.data!.isEmpty
                      ? const InventoryEmptyState(title: '没有明细')
                      : Column(
                          children: [
                            for (final item in itemSnapshot.data!)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(item.materialNameSnapshot),
                                subtitle: Text(
                                  '${item.modelSnapshot ?? '未填型号'} · ${item.remark ?? '无备注'}',
                                ),
                                trailing: Text(
                                  '-${item.quantity} ${item.unitSnapshot}',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}

class _IssueInfo extends StatelessWidget {
  const _IssueInfo({
    required this.label,
    required this.value,
    this.last = false,
  });
  final String label;
  final String value;
  final bool last;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: last
        ? null
        : const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
    child: Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(child: Text(value, textAlign: TextAlign.right)),
      ],
    ),
  );
}

String _dateLabel(DateTime value) =>
    '${value.year}年${value.month}月${value.day}日';
