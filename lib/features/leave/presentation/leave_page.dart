import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../application/leave_providers.dart';
import '../domain/leave_options.dart';

class LeavePage extends ConsumerWidget {
  const LeavePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(leaveMonthProvider);
    final records = ref.watch(leaveRecordsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('请假记录'),
        actions: [
          IconButton(
            onPressed: () => context.push('/attendance/leave/new'),
            icon: const Icon(Icons.add),
            tooltip: '新增请假',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _LeaveMonthSelector(
              month: month,
              onChanged: (value) =>
                  ref.read(leaveMonthProvider.notifier).state = value,
            ),
          ),
          Expanded(
            child: records.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _LeaveError(
                message: error.toString(),
                onRetry: () => ref.invalidate(leaveRecordsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return _LeaveEmpty(
                    month: month,
                    onCreate: () => context.push('/attendance/leave/new'),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  children: [
                    _LeaveSummary(count: items.length),
                    const SizedBox(height: 14),
                    for (final item in items) ...[
                      _LeaveCard(
                        item: item,
                        onEdit: () => context.push(
                          '/attendance/leave/${item.leave.id}/edit',
                        ),
                        onDelete: () => _delete(context, ref, item),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    LeaveRecordView item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除请假记录？'),
        content: const Text('删除后对应考勤中仍为“请假”的半天会恢复为“未登记”；已经手动修改的考勤状态会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(leaveRepositoryProvider).delete(item.leave.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('请假记录已删除')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('删除失败：$error')));
      }
    }
  }
}

class _LeaveMonthSelector extends StatelessWidget {
  const _LeaveMonthSelector({required this.month, required this.onChanged});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            IconButton(
              key: const Key('leave-previous-month'),
              onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left),
              tooltip: '上个月',
            ),
            Expanded(
              child: Center(
                child: Text(
                  leaveMonthLabel(month),
                  key: const Key('leave-month-label'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            TextButton(
              key: const Key('leave-current-month'),
              onPressed: () {
                final now = DateTime.now();
                onChanged(DateTime(now.year, now.month));
              },
              child: const Text('本月'),
            ),
            IconButton(
              key: const Key('leave-next-month'),
              onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right),
              tooltip: '下个月',
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveSummary extends StatelessWidget {
  const _LeaveSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.lightBlue,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            const Icon(
              Icons.event_available_outlined,
              color: AppColors.techBlue,
            ),
            const SizedBox(width: 10),
            Text('本月请假记录', style: Theme.of(context).textTheme.bodyLarge),
            const Spacer(),
            Text(
              '$count 条',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: AppColors.techBlue),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final LeaveRecordView item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final leave = item.leave;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.lightBlue,
                shape: BoxShape.circle,
              ),
              child: Text(
                item.employee.name.characters.first,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: AppColors.techBlue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.employee.name,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _LeaveTypeTag(type: leave.leaveType),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${item.employee.employeeNo} · ${LeaveOptions.dateRangeLabel(leave)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '共 ${_formatHalfDays(LeaveOptions.halfDays(leave))} 天${leave.remark == null ? '' : ' · ${leave.remark}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            PopupMenuButton<_LeaveAction>(
              key: Key('leave-actions-${leave.id}'),
              onSelected: (action) {
                switch (action) {
                  case _LeaveAction.edit:
                    onEdit();
                  case _LeaveAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: _LeaveAction.edit, child: Text('编辑')),
                PopupMenuItem(value: _LeaveAction.delete, child: Text('删除')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatHalfDays(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }
}

class _LeaveTypeTag extends StatelessWidget {
  const _LeaveTypeTag({required this.type});

  final LeaveType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.lightOrange,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        LeaveOptions.typeLabel(type),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: const Color(0xFFE98500),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LeaveEmpty extends StatelessWidget {
  const _LeaveEmpty({required this.month, required this.onCreate});

  final DateTime month;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_busy_outlined,
              size: 44,
              color: AppColors.helper,
            ),
            const SizedBox(height: 14),
            Text(
              '${AppDateUtils.yearMonth(month)} 暂无请假记录',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '请假记录会同步到对应日期的上午、下午考勤状态。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('新增请假'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveError extends StatelessWidget {
  const _LeaveError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 42),
            const SizedBox(height: 12),
            Text('请假记录暂时不可用', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('重新加载')),
          ],
        ),
      ),
    );
  }
}

enum _LeaveAction { edit, delete }
