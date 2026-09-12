import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../application/overtime_providers.dart';
import '../domain/overtime_options.dart';

class OvertimePage extends ConsumerWidget {
  const OvertimePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(overtimeMonthProvider);
    final records = ref.watch(overtimeRecordsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('加班记录'),
        actions: [
          IconButton(
            onPressed: () => context.push('/attendance/overtime/new'),
            icon: const Icon(Icons.add),
            tooltip: '新增加班',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _OvertimeMonthSelector(
              month: month,
              onChanged: (value) =>
                  ref.read(overtimeMonthProvider.notifier).state = value,
            ),
          ),
          Expanded(
            child: records.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _OvertimeError(
                message: error.toString(),
                onRetry: () => ref.invalidate(overtimeRecordsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return _OvertimeEmpty(
                    month: month,
                    onCreate: () => context.push('/attendance/overtime/new'),
                  );
                }
                final totalMinutes = items.fold<int>(
                  0,
                  (total, item) => total + item.overtime.durationMinutes,
                );
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  children: [
                    _OvertimeSummary(
                      count: items.length,
                      totalMinutes: totalMinutes,
                    ),
                    const SizedBox(height: 14),
                    for (final item in items) ...[
                      _OvertimeCard(
                        item: item,
                        onEdit: () => context.push(
                          '/attendance/overtime/${item.overtime.id}/edit',
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
    OvertimeRecordView item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除加班记录？'),
        content: Text(
          '${item.employee.name} 的 ${OvertimeOptions.timeRangeLabel(item.overtime)} 将被移除。',
        ),
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
      await ref.read(overtimeRepositoryProvider).delete(item.overtime.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('加班记录已删除')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('删除失败：$error')));
      }
    }
  }
}

class _OvertimeMonthSelector extends StatelessWidget {
  const _OvertimeMonthSelector({required this.month, required this.onChanged});

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
              key: const Key('overtime-previous-month'),
              onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left),
              tooltip: '上个月',
            ),
            Expanded(
              child: Center(
                child: Text(
                  overtimeMonthLabel(month),
                  key: const Key('overtime-month-label'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            TextButton(
              key: const Key('overtime-current-month'),
              onPressed: () {
                final now = DateTime.now();
                onChanged(DateTime(now.year, now.month));
              },
              child: const Text('本月'),
            ),
            IconButton(
              key: const Key('overtime-next-month'),
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

class _OvertimeSummary extends StatelessWidget {
  const _OvertimeSummary({required this.count, required this.totalMinutes});

  final int count;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.lightGreen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            const Icon(Icons.schedule_outlined, color: AppColors.primary),
            const SizedBox(width: 10),
            Text('$count 段加班', style: Theme.of(context).textTheme.bodyLarge),
            const Spacer(),
            Text(
              OvertimeOptions.formatDuration(totalMinutes),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _OvertimeCard extends StatelessWidget {
  const _OvertimeCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final OvertimeRecordView item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final record = item.overtime;
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
                color: AppColors.lightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.schedule_outlined,
                color: AppColors.primary,
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
                      _OvertimeTypeTag(type: record.overtimeType),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${item.employee.employeeNo} · ${OvertimeOptions.timeRangeLabel(record)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${OvertimeOptions.formatDuration(record.durationMinutes)}${record.workContent == null ? '' : ' · ${record.workContent}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            PopupMenuButton<_OvertimeAction>(
              key: Key('overtime-actions-${record.id}'),
              onSelected: (action) {
                switch (action) {
                  case _OvertimeAction.edit:
                    onEdit();
                  case _OvertimeAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: _OvertimeAction.edit, child: Text('编辑')),
                PopupMenuItem(value: _OvertimeAction.delete, child: Text('删除')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OvertimeTypeTag extends StatelessWidget {
  const _OvertimeTypeTag({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        OvertimeOptions.typeLabel(type),
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: AppColors.techBlue, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _OvertimeEmpty extends StatelessWidget {
  const _OvertimeEmpty({required this.month, required this.onCreate});

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
              Icons.schedule_outlined,
              size: 44,
              color: AppColors.helper,
            ),
            const SizedBox(height: 14),
            Text(
              '${AppDateUtils.yearMonth(month)} 暂无加班记录',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '加班与基础出勤独立保存，不会改变出勤天数。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('新增加班'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OvertimeError extends StatelessWidget {
  const _OvertimeError({required this.message, required this.onRetry});

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
            Text('加班记录暂时不可用', style: Theme.of(context).textTheme.titleLarge),
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

enum _OvertimeAction { edit, delete }
