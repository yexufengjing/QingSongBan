import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/inventory_providers.dart';
import 'widgets/inventory_export_button.dart';
import 'widgets/inventory_widgets.dart';

class InventoryIssuesPage extends ConsumerWidget {
  const InventoryIssuesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('领用出库'),
      actions: const [InventoryExportButton()],
    ),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('inventory-issue-add'),
      onPressed: () => context.push('/inventory/issues/new'),
      icon: const Icon(Icons.add),
      label: const Text('新增出库'),
    ),
    body: ref
        .watch(inventoryIssuesProvider)
        .when(
          loading: () => const InventoryLoadingState(),
          error: (_, _) => InventoryErrorState(
            onRetry: () => ref.invalidate(inventoryIssuesProvider),
          ),
          data: (issues) => issues.isEmpty
              ? InventoryEmptyState(
                  title: '暂无出库记录',
                  message: '员工领取或其他领用完成后会在此显示。',
                  action: FilledButton.icon(
                    onPressed: () => context.push('/inventory/issues/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('登记领用'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(inventoryIssuesProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
                    itemCount: issues.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _IssueCard(issue: issues[index]),
                  ),
                ),
        ),
  );
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue});
  final InventoryIssue issue;

  @override
  Widget build(BuildContext context) {
    final receiver =
        issue.employeeNameSnapshot ??
        issue.manualReceiverName ??
        issue.departmentNameSnapshot ??
        '公用';
    return Card(
      child: InkWell(
        key: Key('inventory-issue-${issue.id}'),
        onTap: () => context.push('/inventory/issues/${issue.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.north_east_rounded,
                    color: AppColors.techBlue,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      receiver,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    _dateLabel(issue.issueDate),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('单号：${issue.issueNo}'),
              Text(
                '用途：${issue.purpose ?? issue.issueType} · 经办人：${issue.operatorNameSnapshot ?? '未填写'}',
              ),
              if ((issue.remark ?? '').isNotEmpty) Text('备注：${issue.remark}'),
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.chevron_right, color: AppColors.helper),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _dateLabel(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
