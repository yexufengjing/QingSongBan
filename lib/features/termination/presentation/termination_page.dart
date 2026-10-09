import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../application/termination_providers.dart';
import '../../reminders/application/reminder_providers.dart';
import '../domain/termination_options.dart';

class TerminationPage extends ConsumerWidget {
  const TerminationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(terminationRecordsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('离职管理'),
        actions: [
          IconButton(
            onPressed: () => context.push('/attendance/termination/new'),
            icon: const Icon(Icons.add),
            tooltip: '登记离职',
          ),
        ],
      ),
      floatingActionButton:
          records.maybeWhen(
            data: (items) => items.isNotEmpty,
            orElse: () => false,
          )
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/attendance/termination/new'),
              icon: const Icon(Icons.add),
              label: const Text('登记离职'),
            )
          : null,
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _TerminationError(
          message: error.toString(),
          onRetry: () => ref.invalidate(terminationRecordsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _TerminationEmpty(
              onCreate: () => context.push('/attendance/termination/new'),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 104),
            children: [
              Card(
                color: AppColors.lightOrange,
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFFE98500)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('离职日之后禁止登记正常考勤；撤销离职只恢复人员状态，不会覆盖已有历史考勤。'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              for (final item in items) ...[
                _TerminationCard(
                  item: item,
                  onEdit: () => context.push(
                    '/attendance/termination/${item.termination.id}/edit',
                  ),
                  onRevoke: () => _revoke(context, ref, item),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    TerminationRecordView item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤销离职？', textAlign: TextAlign.center),
        content: Text(
          '撤销 ${item.employee.name} 的离职记录后，人员状态将恢复为“在岗”，已有考勤数据不会被修改。',
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('确认撤销'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final reminder = await ref
          .read(reminderRepositoryProvider)
          .findBySource('termination', item.termination.id);
      await ref.read(terminationRepositoryProvider).revoke(item.termination.id);
      if (reminder != null) {
        await ref.read(notificationServiceProvider).cancel(reminder.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('离职已撤销，历史考勤保持不变')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('撤销失败：$error')));
      }
    }
  }
}

class _TerminationCard extends StatelessWidget {
  const _TerminationCard({
    required this.item,
    required this.onEdit,
    required this.onRevoke,
  });

  final TerminationRecordView item;
  final VoidCallback onEdit;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final record = item.termination;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.lightBlue,
                  child: Icon(
                    Icons.person_outline,
                    color: AppColors.techBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.employee.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.employee.employeeNo,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  color: AppColors.techBlue,
                  tooltip: '编辑',
                ),
                PopupMenuButton<_TerminationAction>(
                  key: Key('termination-actions-${record.id}'),
                  onSelected: (action) {
                    switch (action) {
                      case _TerminationAction.edit:
                        onEdit();
                      case _TerminationAction.revoke:
                        onRevoke();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _TerminationAction.edit,
                      child: Text('编辑'),
                    ),
                    PopupMenuItem(
                      value: _TerminationAction.revoke,
                      child: Text('撤销离职'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _TerminationTag(type: record.terminationType),
            const Divider(height: 24),
            for (final row in <(String, String)>[
              ('正式离职日期', terminationDateLabel(record)),
              ('离职原因', TerminationOptions.typeLabel(record.terminationType)),
              (
                '社保停保状态',
                record.isInsuranceStopped
                    ? '已停保${record.stopInsuranceMonth == null ? '' : ' ${record.stopInsuranceMonth}'}'
                    : '待停保',
              ),
              ('工具归还情况', record.toolsReturned ? '已归还' : '待归还'),
              ('物资交接情况', record.materialsTransferred ? '已交接' : '待交接'),
              ('未结事项', record.hasUnsettledItems ? '存在未结事项' : '无未结事项'),
              ('说明', record.remark ?? '未填写'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        row.$1,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.$2,
                        style: Theme.of(context).textTheme.bodyLarge,
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
}

class _TerminationTag extends StatelessWidget {
  const _TerminationTag({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.lightOrange,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        TerminationOptions.typeLabel(type),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: const Color(0xFFE98500),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TerminationEmpty extends StatelessWidget {
  const _TerminationEmpty({required this.onCreate});

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
              Icons.person_off_outlined,
              size: 44,
              color: AppColors.helper,
            ),
            const SizedBox(height: 14),
            Text('暂无离职记录', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '登记离职后，系统会保留历史数据并停止离职日之后的正常考勤。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('登记离职'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TerminationError extends StatelessWidget {
  const _TerminationError({required this.message, required this.onRetry});

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
            Text('离职记录暂时不可用', style: Theme.of(context).textTheme.titleLarge),
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

enum _TerminationAction { edit, revoke }
