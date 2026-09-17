import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/reminder_providers.dart';
import '../domain/reminder_options.dart';
import '../domain/reminder_schedule.dart';

enum _ReminderFilter { pending, completed }

class ReminderPage extends ConsumerStatefulWidget {
  const ReminderPage({super.key});

  @override
  ConsumerState<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends ConsumerState<ReminderPage> {
  _ReminderFilter _filter = _ReminderFilter.pending;

  @override
  Widget build(BuildContext context) {
    final reminders = ref.watch(remindersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('备忘提醒')),
      body: reminders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('提醒加载失败：$error')),
        data: (items) {
          final settings = <String, Reminder>{
            for (final item in items)
              if (item.reminderType != 'custom' &&
                  ReminderOptions.types.contains(item.reminderType))
                item.reminderType: item,
          };
          final workItems = items
              .where(
                (item) =>
                    item.reminderType == 'custom' ||
                    !ReminderOptions.types.contains(item.reminderType),
              )
              .toList();
          final pendingItems = workItems
              .where((item) => !item.isCompleted)
              .toList();
          final completedItems = workItems
              .where((item) => item.isCompleted)
              .toList();
          final now = DateTime.now();
          final overdueItems = pendingItems
              .where(
                (item) =>
                    item.dueDate != null && item.dueDate!.isBefore(now),
              )
              .toList();
          final todayItems = pendingItems
              .where(
                (item) =>
                    item.dueDate != null &&
                    !item.dueDate!.isBefore(now) &&
                    _isSameDay(item.dueDate!, now),
              )
              .toList();
          final upcomingItems = pendingItems
              .where(
                (item) =>
                    item.dueDate != null &&
                    item.dueDate!.isAfter(now) &&
                    !_isSameDay(item.dueDate!, now),
              )
              .toList();
          final unscheduledItems = pendingItems
              .where((item) => item.dueDate == null)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              _OverviewCard(
                pendingCount: pendingItems.length,
                todayCount: todayItems.length,
                overdueCount: overdueItems.length,
                onCreate: () => context.push('/settings/reminders/new'),
              ),
              const SizedBox(height: 18),
              _FilterBar(
                selected: _filter,
                pendingCount: pendingItems.length,
                completedCount: completedItems.length,
                onSelected: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 18),
              if (_filter == _ReminderFilter.pending) ...[
                if (pendingItems.isEmpty)
                  const _ReminderEmpty(
                    icon: Icons.task_alt,
                    title: '当前没有待办事项',
                    message: '临时任务、工作计划和到期事项都可以记在这里。',
                  )
                else ...[
                  if (overdueItems.isNotEmpty)
                    _ReminderSection(
                      title: '已逾期',
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.danger,
                      items: overdueItems,
                      ref: ref,
                    ),
                  if (todayItems.isNotEmpty)
                    _ReminderSection(
                      title: '今天',
                      icon: Icons.today_outlined,
                      color: AppColors.primary,
                      items: todayItems,
                      ref: ref,
                    ),
                  if (upcomingItems.isNotEmpty)
                    _ReminderSection(
                      title: '接下来',
                      icon: Icons.event_outlined,
                      color: AppColors.techBlue,
                      items: upcomingItems,
                      ref: ref,
                    ),
                  if (unscheduledItems.isNotEmpty)
                    _ReminderSection(
                      title: '未设置时间',
                      icon: Icons.schedule_outlined,
                      color: AppColors.helper,
                      items: unscheduledItems,
                      ref: ref,
                    ),
                ],
              ] else ...[
                if (completedItems.isEmpty)
                  const _ReminderEmpty(
                    icon: Icons.history_toggle_off_outlined,
                    title: '还没有完成记录',
                    message: '完成的事项会保留在这里，方便以后回看。',
                  )
                else
                  _ReminderSection(
                    title: '已完成',
                    icon: Icons.check_circle_outline,
                    color: AppColors.primary,
                    items: completedItems,
                    ref: ref,
                  ),
              ],
              const SizedBox(height: 22),
              _BusinessPreferences(settings: settings, ref: ref),
              const SizedBox(height: 12),
              _NotificationCheck(ref: ref),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.pendingCount,
    required this.todayCount,
    required this.overdueCount,
    required this.onCreate,
  });

  final int pendingCount;
  final int todayCount;
  final int overdueCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.lightBlue,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.techBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '把事情记下来，到点提醒',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '适合临时事项、工作计划和需要提前准备的任务。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CountBadge(label: '待办', value: pendingCount),
                _CountBadge(label: '今天', value: todayCount),
                _CountBadge(
                  label: '逾期',
                  value: overdueCount,
                  isWarning: overdueCount > 0,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('reminder-add-button'),
              onPressed: onCreate,
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('新建提醒'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  final String label;
  final int value;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: isWarning ? AppColors.lightDanger : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isWarning ? AppColors.danger : AppColors.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.pendingCount,
    required this.completedCount,
    required this.onSelected,
  });

  final _ReminderFilter selected;
  final int pendingCount;
  final int completedCount;
  final ValueChanged<_ReminderFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            key: const Key('reminder-filter-pending'),
            label: Text('待办 $pendingCount'),
            selected: selected == _ReminderFilter.pending,
            onSelected: (_) => onSelected(_ReminderFilter.pending),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ChoiceChip(
            key: const Key('reminder-filter-completed'),
            label: Text('已完成 $completedCount'),
            selected: selected == _ReminderFilter.completed,
            onSelected: (_) => onSelected(_ReminderFilter.completed),
          ),
        ),
      ],
    );
  }
}

class _ReminderSection extends StatelessWidget {
  const _ReminderSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.ref,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Reminder> items;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 7),
              Text('${items.length}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 9),
          for (var index = 0; index < items.length; index++) ...[
            _ReminderTile(reminder: items[index], ref: ref),
            if (index != items.length - 1) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.reminder, required this.ref});

  final Reminder reminder;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final dueText = _formatDueDate(reminder.dueDate);
    final schedule = ReminderSchedule.decode(
      reminder.repeatRule,
      legacyLeadDays: reminder.leadDays,
    );
    final detailParts = <String>[
      dueText,
      if (reminder.dueDate != null) schedule.repeatLabel(reminder.dueDate!),
      schedule.alertLabel,
      if (!schedule.ringEnabled) '静音',
      if (!reminder.isEnabled) '通知已关闭',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 5, 4, 5),
        child: Row(
          children: [
            IconButton(
              key: Key('reminder-complete-${reminder.id}'),
              tooltip: reminder.isCompleted ? '恢复为待办' : '标记完成',
              onPressed: () => _toggleCompleted(context),
              icon: Icon(
                reminder.isCompleted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: reminder.isCompleted
                    ? AppColors.primary
                    : AppColors.techBlue,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        decoration: reminder.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: reminder.isCompleted
                            ? AppColors.helper
                            : AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detailParts.join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if ((reminder.remark ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        reminder.remark!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'toggle') {
                  await _toggleCompleted(context);
                } else if (action == 'delete') {
                  await _delete(context);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(reminder.isCompleted ? '恢复为待办' : '标记完成'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('删除提醒')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleCompleted(BuildContext context) async {
    final completed = !reminder.isCompleted;
    try {
      await ref
          .read(reminderRepositoryProvider)
          .complete(reminder.id, completed: completed);
      if (completed) {
        await ref.read(notificationServiceProvider).cancel(reminder.id);
      } else {
        final refreshed = await ref
            .read(reminderRepositoryProvider)
            .findById(reminder.id);
        if (refreshed != null) {
          await ref.read(notificationServiceProvider).sync(refreshed);
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(completed ? '已标记完成' : '已恢复为待办')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$error')),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除提醒？'),
        content: Text('“${reminder.title}”删除后不会再通知。'),
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
    if (confirmed != true) return;
    try {
      await ref.read(reminderRepositoryProvider).delete(reminder.id);
      await ref.read(notificationServiceProvider).cancel(reminder.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：$error')),
        );
      }
    }
  }
}

class _BusinessPreferences extends StatelessWidget {
  const _BusinessPreferences({required this.settings, required this.ref});

  final Map<String, Reminder> settings;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        key: const Key('reminder-business-preferences'),
        leading: const Icon(Icons.tune_outlined, color: AppColors.body),
        title: const Text('业务提醒偏好'),
        subtitle: const Text('考勤、月度名单、工资等业务的默认提醒设置'),
        children: [
          const Divider(),
          for (final type in ReminderOptions.types.where(
            (type) => type != 'custom',
          ))
            _SettingTile(
              type: type,
              reminder: settings[type],
              onChanged: (enabled, leadDays) async {
                try {
                  final reminder = await ref
                      .read(reminderRepositoryProvider)
                      .saveSetting(
                        reminderType: type,
                        title: ReminderOptions.typeLabel(type),
                        isEnabled: enabled,
                        leadDays: leadDays,
                      );
                  await ref.read(notificationServiceProvider).sync(reminder);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('保存提醒偏好失败：$error')),
                    );
                  }
                }
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.type,
    required this.reminder,
    required this.onChanged,
  });

  final String type;
  final Reminder? reminder;
  final Future<void> Function(bool enabled, int leadDays) onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = reminder?.isEnabled ?? false;
    final leadDays = reminder?.leadDays ?? 0;
    return ListTile(
      title: Text(ReminderOptions.typeLabel(type)),
      subtitle: Text(ReminderOptions.leadLabel(leadDays)),
      leading: Icon(
        enabled
            ? Icons.notifications_active_outlined
            : Icons.notifications_none,
        color: enabled ? AppColors.primary : AppColors.helper,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<int>(
            key: Key('reminder-lead-$type'),
            tooltip: '设置提前时间',
            onSelected: (days) => onChanged(enabled, days),
            itemBuilder: (context) => [
              for (final days in [0, 1, 3, 7])
                PopupMenuItem(
                  value: days,
                  child: Text(ReminderOptions.leadLabel(days)),
                ),
            ],
          ),
          Switch(
            key: Key('reminder-switch-$type'),
            value: enabled,
            onChanged: (value) => onChanged(value, leadDays),
          ),
        ],
      ),
    );
  }
}

class _NotificationCheck extends StatelessWidget {
  const _NotificationCheck({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.techBlue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('检查通知', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 3),
                  Text(
                    '没有收到提醒时，可先发送一条测试通知。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            TextButton(
              key: const Key('reminder-test-button'),
              onPressed: () async {
                try {
                  await ref
                      .read(notificationServiceProvider)
                      .showTestNotification();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已发送测试通知，请查看通知栏')),
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('通知不可用：$error')),
                    );
                  }
                }
              },
              child: const Text('发送测试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderEmpty extends StatelessWidget {
  const _ReminderEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        child: Column(
          children: [
            Icon(icon, color: AppColors.helper, size: 36),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatDueDate(DateTime? due) {
  if (due == null) return '未设置时间';
  final now = DateTime.now();
  final time =
      '${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}';
  if (_isSameDay(due, now)) return '今天 $time';
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  if (_isSameDay(due, tomorrow)) return '明天 $time';
  return '${due.month}月${due.day}日 $time';
}
