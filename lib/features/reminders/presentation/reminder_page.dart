import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/reminder_providers.dart';
import '../domain/reminder_options.dart';
import '../domain/reminder_schedule.dart';

enum _ReminderView { pending, planned, completed }

enum _TimeFilter { all, today, overdue, week }

class ReminderPage extends ConsumerStatefulWidget {
  const ReminderPage({super.key});

  @override
  ConsumerState<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends ConsumerState<ReminderPage> {
  final _searchController = TextEditingController();
  _ReminderView _view = _ReminderView.pending;
  _TimeFilter _timeFilter = _TimeFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reminders = ref.watch(reminderItemsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('备忘提醒'),
        actions: [
          IconButton(
            tooltip: '新建提醒',
            onPressed: () => context.push('/settings/reminders/new'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('reminder-add-button'),
        onPressed: () => context.push('/settings/reminders/new'),
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('新建'),
      ),
      body: reminders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadError(
          message: '提醒加载失败：$error',
          onRetry: () => ref.invalidate(reminderItemsProvider),
        ),
        data: _buildContent,
      ),
    );
  }

  Widget _buildContent(List<ReminderItem> items) {
    final settings = <String, Reminder>{};
    final workItems = <ReminderItem>[];
    for (final item in items) {
      if (item.reminder.reminderType != 'custom' &&
          ReminderOptions.types.contains(item.reminder.reminderType)) {
        settings[item.reminder.reminderType] = item.reminder;
      } else {
        workItems.add(item);
      }
    }
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final weekEnd = todayEnd.add(const Duration(days: 7));
    final pending = workItems.where((item) => item.isPending).toList();
    final todayCount = pending
        .where(
          (item) =>
              item.scheduledAt != null && _sameDay(item.scheduledAt!, now),
        )
        .length;
    final overdueCount = pending
        .where((item) => item.scheduledAt?.isBefore(now) == true)
        .length;
    final weekCount = pending
        .where(
          (item) =>
              item.scheduledAt?.isAfter(todayEnd) == true &&
              !item.scheduledAt!.isAfter(weekEnd),
        )
        .length;

    final query = _searchController.text.trim().toLowerCase();
    var visible = workItems.where((item) {
      final matchesView = switch (_view) {
        _ReminderView.completed => item.isCompleted,
        _ReminderView.pending =>
          item.isPending &&
              (item.scheduledAt == null ||
                  !item.scheduledAt!.isAfter(todayEnd)),
        _ReminderView.planned =>
          item.isPending &&
              item.scheduledAt != null &&
              item.scheduledAt!.isAfter(todayEnd),
      };
      final matchesSearch =
          query.isEmpty ||
          item.reminder.title.toLowerCase().contains(query) ||
          (item.reminder.remark ?? '').toLowerCase().contains(query) ||
          item.links.any(
            (link) => link.displayNameSnapshot.toLowerCase().contains(query),
          );
      final matchesTime = switch (_timeFilter) {
        _TimeFilter.all => true,
        _TimeFilter.today =>
          item.scheduledAt != null && _sameDay(item.scheduledAt!, now),
        _TimeFilter.overdue => item.scheduledAt?.isBefore(now) == true,
        _TimeFilter.week =>
          item.scheduledAt?.isAfter(todayEnd) == true &&
              !item.scheduledAt!.isAfter(weekEnd),
      };
      return matchesView && matchesSearch && matchesTime;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '搜索事项、说明或关联人员',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: '清空搜索',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        _OverviewPanel(
          todayCount: todayCount,
          overdueCount: overdueCount,
          weekCount: weekCount,
          selected: _timeFilter,
          onSelected: (value) => setState(() => _timeFilter = value),
        ),
        const SizedBox(height: 14),
        SegmentedButton<_ReminderView>(
          key: const Key('reminder-filter-pending'),
          segments: const [
            ButtonSegment(
              value: _ReminderView.pending,
              label: Text('待办'),
              icon: Icon(Icons.check_box_outline_blank),
            ),
            ButtonSegment(
              value: _ReminderView.planned,
              label: Text('计划'),
              icon: Icon(Icons.event_outlined),
            ),
            ButtonSegment(
              value: _ReminderView.completed,
              label: Text('已完成'),
              icon: Icon(Icons.task_alt),
            ),
          ],
          selected: {_view},
          onSelectionChanged: (value) => setState(() {
            _view = value.single;
            _timeFilter = _TimeFilter.all;
          }),
        ),
        const SizedBox(height: 18),
        if (visible.isEmpty)
          _ReminderEmpty(
            searching: query.isNotEmpty,
            onCreate: () => context.push('/settings/reminders/new'),
          )
        else
          ..._buildSections(visible, now),
        const SizedBox(height: 12),
        _BusinessPreferences(settings: settings, ref: ref),
        const SizedBox(height: 12),
        _NotificationCheck(ref: ref),
      ],
    );
  }

  List<Widget> _buildSections(List<ReminderItem> items, DateTime now) {
    if (_view == _ReminderView.completed) {
      return [_ReminderSection(title: '完成记录', items: items, ref: ref)];
    }
    if (_view == _ReminderView.planned) {
      return [_ReminderSection(title: '后续计划', items: items, ref: ref)];
    }
    final overdue = items
        .where((item) => item.scheduledAt?.isBefore(now) == true)
        .toList();
    final today = items
        .where(
          (item) =>
              item.scheduledAt != null &&
              !item.scheduledAt!.isBefore(now) &&
              _sameDay(item.scheduledAt!, now),
        )
        .toList();
    final unscheduled = items
        .where((item) => item.scheduledAt == null)
        .toList();
    return [
      if (overdue.isNotEmpty)
        _ReminderSection(title: '已逾期', items: overdue, ref: ref, warning: true),
      if (today.isNotEmpty)
        _ReminderSection(title: '今天', items: today, ref: ref),
      if (unscheduled.isNotEmpty)
        _ReminderSection(title: '未设置时间', items: unscheduled, ref: ref),
    ];
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({
    required this.todayCount,
    required this.overdueCount,
    required this.weekCount,
    required this.selected,
    required this.onSelected,
  });

  final int todayCount;
  final int overdueCount;
  final int weekCount;
  final _TimeFilter selected;
  final ValueChanged<_TimeFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.lightBlue,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('把事情记下来，到点提醒', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '按执行时间查看，完成后仍保留记录。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MetricButton(
                    label: '今天',
                    value: todayCount,
                    selected: selected == _TimeFilter.today,
                    onTap: () => onSelected(
                      selected == _TimeFilter.today
                          ? _TimeFilter.all
                          : _TimeFilter.today,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricButton(
                    label: '逾期',
                    value: overdueCount,
                    warning: overdueCount > 0,
                    selected: selected == _TimeFilter.overdue,
                    onTap: () => onSelected(
                      selected == _TimeFilter.overdue
                          ? _TimeFilter.all
                          : _TimeFilter.overdue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricButton(
                    label: '7 天内',
                    value: weekCount,
                    selected: selected == _TimeFilter.week,
                    onTap: () => onSelected(
                      selected == _TimeFilter.week
                          ? _TimeFilter.all
                          : _TimeFilter.week,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricButton extends StatelessWidget {
  const _MetricButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    this.warning = false,
  });

  final String label;
  final int value;
  final bool selected;
  final bool warning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppColors.danger : AppColors.techBlue;
    return Material(
      color: selected ? color : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Text(
                '$value',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: selected ? Colors.white : color),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: selected ? Colors.white : AppColors.body),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderSection extends StatelessWidget {
  const _ReminderSection({
    required this.title,
    required this.items,
    required this.ref,
    this.warning = false,
  });

  final String title;
  final List<ReminderItem> items;
  final WidgetRef ref;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                warning ? Icons.warning_amber_rounded : Icons.schedule_outlined,
                color: warning ? AppColors.danger : AppColors.body,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 6),
              Text(
                '${items.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 9),
          for (var index = 0; index < items.length; index++) ...[
            _ReminderTile(item: items[index], ref: ref),
            if (index != items.length - 1) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.item, required this.ref});

  final ReminderItem item;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final reminder = item.reminder;
    final schedule = ReminderSchedule.decode(
      reminder.repeatRule,
      legacyLeadDays: reminder.leadDays,
    );
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/settings/reminders/${reminder.id}/edit'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                key: Key(
                  'reminder-complete-${item.occurrence?.id ?? reminder.id}',
                ),
                tooltip: item.isCompleted ? '恢复为待办' : '标记完成',
                onPressed: () => _toggleCompleted(context),
                icon: Icon(
                  item.isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: item.isCompleted
                      ? AppColors.primary
                      : _priorityColor(reminder.priority),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              reminder.title,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    decoration: item.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: item.isCompleted
                                        ? AppColors.helper
                                        : AppColors.ink,
                                  ),
                            ),
                          ),
                          if (reminder.priority != 'normal')
                            _StatusBadge(
                              label: ReminderPriorities.label(
                                reminder.priority,
                              ),
                              color: _priorityColor(reminder.priority),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          _formatDueDate(item.scheduledAt),
                          if (schedule.repeats)
                            schedule.repeatLabel(
                              reminder.dueDate ?? item.scheduledAt!,
                            ),
                          if (!reminder.isEnabled) '已停用',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (item.links.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final link in item.links.take(3))
                              _StatusBadge(
                                label: link.displayNameSnapshot,
                                color: AppColors.techBlue,
                                icon: Icons.person_outline,
                              ),
                            if (item.links.length > 3)
                              _StatusBadge(
                                label: '+${item.links.length - 3}',
                                color: AppColors.body,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (action) => _handleAction(context, action),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('编辑提醒')),
                  if (item.isPending && schedule.repeats)
                    const PopupMenuItem(value: 'skip', child: Text('跳过本期')),
                  PopupMenuItem(
                    value: 'enabled',
                    child: Text(reminder.isEnabled ? '停用整个提醒' : '重新启用'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('删除提醒')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleCompleted(BuildContext context) async {
    final completed = !item.isCompleted;
    final repository = ref.read(reminderRepositoryProvider);
    await repository.complete(
      item.reminder.id,
      completed: completed,
      occurrenceId: item.occurrence?.id,
    );
    final reminder = await repository.findById(item.reminder.id);
    if (reminder != null) {
      await ref
          .read(notificationServiceProvider)
          .sync(
            reminder,
            pendingOccurrences: await repository.listPendingOccurrenceTimes(
              reminder.id,
            ),
          );
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(completed ? '已完成本期提醒' : '已恢复为待办'),
        action: completed
            ? SnackBarAction(
                label: '撤销',
                onPressed: () async {
                  await repository.complete(
                    item.reminder.id,
                    completed: false,
                    occurrenceId: item.occurrence?.id,
                  );
                  final restored = await repository.findById(item.reminder.id);
                  if (restored != null) {
                    await ref
                        .read(notificationServiceProvider)
                        .sync(
                          restored,
                          pendingOccurrences: await repository
                              .listPendingOccurrenceTimes(restored.id),
                        );
                  }
                },
              )
            : null,
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final repository = ref.read(reminderRepositoryProvider);
    if (action == 'edit') {
      context.push('/settings/reminders/${item.reminder.id}/edit');
      return;
    }
    if (action == 'skip') {
      await repository.skip(
        item.reminder.id,
        occurrenceId: item.occurrence?.id,
      );
      final reminder = await repository.findById(item.reminder.id);
      if (reminder != null) {
        await ref
            .read(notificationServiceProvider)
            .sync(
              reminder,
              pendingOccurrences: await repository.listPendingOccurrenceTimes(
                reminder.id,
              ),
            );
      }
      return;
    }
    if (action == 'enabled') {
      final enabled = !item.reminder.isEnabled;
      await repository.setEnabled(item.reminder.id, enabled);
      if (enabled) {
        final reminder = await repository.findById(item.reminder.id);
        if (reminder != null) {
          await ref
              .read(notificationServiceProvider)
              .sync(
                reminder,
                pendingOccurrences: await repository.listPendingOccurrenceTimes(
                  reminder.id,
                ),
              );
        }
      } else {
        await ref.read(notificationServiceProvider).cancel(item.reminder.id);
      }
      return;
    }
    if (action == 'delete') {
      await _delete(context);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除提醒？'),
        content: Text('“${item.reminder.title}”的未来通知会一并取消，完成记录不再显示。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除提醒'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(reminderRepositoryProvider).delete(item.reminder.id);
    await ref.read(notificationServiceProvider).cancel(item.reminder.id);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
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
        leading: const Icon(Icons.tune_outlined),
        title: const Text('业务提醒偏好'),
        subtitle: const Text('考勤、工资和保险等业务的默认提醒'),
        children: [
          const Divider(),
          for (final type in ReminderOptions.types.where(
            (type) => type != 'custom',
          ))
            SwitchListTile(
              title: Text(ReminderOptions.typeLabel(type)),
              subtitle: Text(
                ReminderOptions.leadLabel(settings[type]?.leadDays ?? 0),
              ),
              value: settings[type]?.isEnabled ?? false,
              onChanged: (enabled) async {
                final reminder = await ref
                    .read(reminderRepositoryProvider)
                    .saveSetting(
                      reminderType: type,
                      title: ReminderOptions.typeLabel(type),
                      isEnabled: enabled,
                      leadDays: settings[type]?.leadDays ?? 0,
                    );
                await ref.read(notificationServiceProvider).sync(reminder);
              },
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
    return OutlinedButton.icon(
      key: const Key('reminder-test-button'),
      onPressed: () async {
        try {
          await ref.read(notificationServiceProvider).showTestNotification();
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('已发送测试通知')));
          }
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('测试通知失败：$error')));
          }
        }
      },
      icon: const Icon(Icons.notifications_active_outlined),
      label: const Text('发送测试通知'),
    );
  }
}

class _ReminderEmpty extends StatelessWidget {
  const _ReminderEmpty({required this.searching, required this.onCreate});
  final bool searching;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Column(
        children: [
          Icon(
            searching ? Icons.search_off_outlined : Icons.task_alt,
            size: 48,
            color: AppColors.helper,
          ),
          const SizedBox(height: 12),
          Text(
            searching ? '没有找到相关提醒' : '当前没有待办事项',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            searching ? '换个关键词试试。' : '创建一个提醒，时间和完成记录都会保留。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (!searching) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('新建第一个提醒'),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('重新加载')),
          ],
        ),
      ),
    );
  }
}

Color _priorityColor(String priority) => switch (priority) {
  'urgent' => AppColors.danger,
  'important' => const Color(0xFFB35C00),
  _ => AppColors.techBlue,
};

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatDueDate(DateTime? value) {
  if (value == null) return '未设置时间';
  final now = DateTime.now();
  final date = _sameDay(value, now)
      ? '今天'
      : _sameDay(value, now.add(const Duration(days: 1)))
      ? '明天'
      : '${value.month}月${value.day}日';
  return '$date ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
