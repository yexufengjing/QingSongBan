import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/reminder_providers.dart';
import '../domain/reminder_options.dart';

class ReminderDetailPage extends ConsumerStatefulWidget {
  const ReminderDetailPage({
    required this.reminderId,
    this.occurrenceId,
    super.key,
  });
  final int reminderId;
  final int? occurrenceId;
  @override
  ConsumerState<ReminderDetailPage> createState() => _ReminderDetailPageState();
}

class _ReminderDetailPageState extends ConsumerState<ReminderDetailPage> {
  late Future<_ReminderDetailData?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ReminderDetailData?> _load() async {
    final repository = ref.read(reminderRepositoryProvider);
    final reminder = await repository.findById(widget.reminderId);
    if (reminder == null) return null;
    return _ReminderDetailData(
      reminder: reminder,
      occurrences: await repository.findOccurrences(widget.reminderId),
      rules: await repository.findAlertRules(widget.reminderId),
      links: await repository.findLinkDisplays(widget.reminderId),
    );
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReminderDetailData?>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('提醒详情'),
            actions: [
              if (data != null)
                PopupMenuButton<_DetailAction>(
                  onSelected: (action) => _handleAction(action, data),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _DetailAction.edit,
                      child: Text('编辑提醒'),
                    ),
                    const PopupMenuItem(
                      value: _DetailAction.copy,
                      child: Text('复制为新提醒'),
                    ),
                    PopupMenuItem(
                      value: _DetailAction.toggle,
                      child: Text(
                        data.reminder.isEnabled ? '停用整个事项' : '重新启用事项',
                      ),
                    ),
                    const PopupMenuItem(
                      value: _DetailAction.delete,
                      child: Text('删除提醒'),
                    ),
                  ],
                ),
            ],
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : data == null
              ? const Center(child: Text('提醒不存在或已被移除'))
              : _DetailBody(
                  data: data,
                  selectedOccurrenceId: widget.occurrenceId,
                  onChanged: _reload,
                  onComplete: _complete,
                  onSkip: _skip,
                ),
        );
      },
    );
  }

  Future<void> _handleAction(
    _DetailAction action,
    _ReminderDetailData data,
  ) async {
    final repository = ref.read(reminderRepositoryProvider);
    switch (action) {
      case _DetailAction.edit:
        if (mounted) {
          await context.push('/home/reminders/${widget.reminderId}/edit');
        }
        if (mounted) _reload();
      case _DetailAction.copy:
        if (mounted) {
          await context.push(
            '/home/reminders/new?copyFrom=${widget.reminderId}',
          );
        }
      case _DetailAction.toggle:
        await repository.setEnabled(
          widget.reminderId,
          !data.reminder.isEnabled,
        );
        await ref.read(reminderSchedulerProvider).rescheduleAll();
        if (mounted) _reload();
      case _DetailAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除提醒？'),
            content: const Text('删除后不再出现在待办中，历史记录会保留。'),
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
        await repository.delete(widget.reminderId);
        await ref.read(reminderSchedulerProvider).rescheduleAll();
        if (mounted) context.pop();
    }
  }

  Future<void> _complete(int occurrenceId, bool completed) async {
    await ref
        .read(reminderRepositoryProvider)
        .completeOccurrence(occurrenceId, completed: completed);
    await ref.read(reminderSchedulerProvider).rescheduleAll();
    if (mounted) _reload();
  }

  Future<void> _skip(int occurrenceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('跳过本期？'),
        content: const Text('本期不会再催办，重复事项的下一期仍会正常生成。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('跳过'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(reminderRepositoryProvider).skipOccurrence(occurrenceId);
    await ref.read(reminderSchedulerProvider).rescheduleAll();
    if (mounted) _reload();
  }
}

enum _DetailAction { edit, copy, toggle, delete }

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.data,
    required this.selectedOccurrenceId,
    required this.onChanged,
    required this.onComplete,
    required this.onSkip,
  });
  final _ReminderDetailData data;
  final int? selectedOccurrenceId;
  final VoidCallback onChanged;
  final Future<void> Function(int occurrenceId, bool completed) onComplete;
  final Future<void> Function(int occurrenceId) onSkip;

  @override
  Widget build(BuildContext context) {
    final selected =
        _firstOccurrence(data.occurrences, selectedOccurrenceId) ??
        _firstPending(data.occurrences) ??
        (data.occurrences.isEmpty ? null : data.occurrences.first);
    final due = selected?.scheduledAt ?? data.reminder.dueDate;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFFE8F7F0), Color(0xFFE8F1FF)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.reminder.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  _PriorityBadge(priority: data.reminder.priority),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${ReminderOptions.categoryLabel(data.reminder.category)} · ${ReminderOptions.repeatLabel(data.reminder.repeatRule)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (due != null) ...[
                const SizedBox(height: 8),
                Text(
                  '下一期：${_formatDateTime(due)}',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontSize: 16),
                ),
              ],
              if (!data.reminder.isEnabled) ...[
                const SizedBox(height: 10),
                const Text(
                  '整个事项已停用',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (selected != null && selected.status == 'pending')
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onComplete(selected.id, true),
                  icon: const Icon(Icons.check),
                  label: const Text('完成本期'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onSkip(selected.id),
                  icon: const Icon(Icons.skip_next_outlined),
                  label: const Text('跳过本期'),
                ),
              ),
            ],
          ),
        if (data.reminder.remark?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: 18),
          _DetailSection(
            title: '详细内容',
            child: Text(
              data.reminder.remark!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
        if (data.links.isNotEmpty) ...[
          const SizedBox(height: 18),
          _DetailSection(
            title: '关联对象',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final link in data.links)
                  Chip(
                    avatar: const Icon(Icons.person_outline, size: 16),
                    label: Text(
                      '${link.displayName}${link.status == null ? '' : ' · ${_employeeStatus(link.status!)}'}',
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        _DetailSection(
          title: '通知规则',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.rules.isEmpty) const Text('未设置通知规则'),
              for (final rule in data.rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        rule.isNagRule
                            ? Icons.notifications_active_outlined
                            : Icons.alarm_outlined,
                        size: 18,
                        color: AppColors.techBlue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rule.isNagRule
                              ? '到期后每 ${_intervalLabel(rule.repeatIntervalMinutes ?? 1440)}，最多 ${rule.maxRepeatCount ?? 3} 次'
                              : ReminderOptions.alertLabel(rule.offsetMinutes),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _DetailSection(
          title: '完成历史',
          child: data.occurrences.isEmpty
              ? const Text('暂无执行实例')
              : Column(
                  children: [
                    for (final occurrence in data.occurrences.take(20))
                      _OccurrenceTile(
                        occurrence: occurrence,
                        onUndo: occurrence.status == 'completed'
                            ? () => onComplete(occurrence.id, false)
                            : null,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ReminderDetailData {
  const _ReminderDetailData({
    required this.reminder,
    required this.occurrences,
    required this.rules,
    required this.links,
  });
  final Reminder reminder;
  final List<ReminderOccurrence> occurrences;
  final List<ReminderAlertRule> rules;
  final List<ReminderLinkDisplay> links;
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(17, 15, 17, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _OccurrenceTile extends StatelessWidget {
  const _OccurrenceTile({required this.occurrence, required this.onUndo});
  final ReminderOccurrence occurrence;
  final VoidCallback? onUndo;
  @override
  Widget build(BuildContext context) {
    final status = occurrence.status;
    final done = status == 'completed';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        done
            ? Icons.check_circle
            : status == 'skipped'
            ? Icons.skip_next_outlined
            : Icons.radio_button_unchecked,
        color: done ? AppColors.primary : AppColors.helper,
      ),
      title: Text(_formatDateTime(occurrence.scheduledAt)),
      subtitle: Text(
        done
            ? '已完成 · ${_formatDateTime(occurrence.completedAt)}'
            : status == 'skipped'
            ? '已跳过'
            : '待处理',
      ),
      trailing: onUndo == null
          ? null
          : TextButton(onPressed: onUndo, child: const Text('撤销')),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final String priority;
  @override
  Widget build(BuildContext context) {
    final color = priority == 'urgent'
        ? AppColors.danger
        : priority == 'important'
        ? const Color(0xFFE98500)
        : AppColors.techBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        ReminderOptions.priorityLabel(priority),
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _formatDateTime(DateTime? value) => value == null
    ? '—'
    : '${value.year}年${value.month}月${value.day}日 ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _intervalLabel(int minutes) =>
    minutes % 1440 == 0 ? '${minutes ~/ 1440} 天' : '${minutes ~/ 60} 小时';
String _employeeStatus(String value) => switch (value) {
  'active' => '在岗',
  'paused' => '暂停',
  'terminated' => '离职',
  _ => value,
};

ReminderOccurrence? _firstOccurrence(List<ReminderOccurrence> values, int? id) {
  if (id == null) return null;
  for (final value in values) {
    if (value.id == id) return value;
  }
  return null;
}

ReminderOccurrence? _firstPending(List<ReminderOccurrence> values) {
  for (final value in values) {
    if (value.status == 'pending') return value;
  }
  return null;
}
