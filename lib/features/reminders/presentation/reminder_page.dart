import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../application/reminder_providers.dart';
import '../domain/reminder_options.dart';

class ReminderPage extends ConsumerStatefulWidget {
  const ReminderPage({super.key});

  @override
  ConsumerState<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends ConsumerState<ReminderPage> {
  String _view = 'todo';
  String _search = '';
  String? _priority;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(
      reminderItemsProvider((search: _search, view: _view)),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('备忘提醒'),
        actions: [
          IconButton(
            tooltip: '搜索提醒',
            onPressed: _showSearch,
            icon: const Icon(Icons.search_outlined),
          ),
          IconButton(
            tooltip: '筛选提醒',
            onPressed: _showFilter,
            icon: Badge(
              isLabelVisible: _priority != null,
              child: const Icon(Icons.tune_outlined),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('reminder-add-button'),
        onPressed: () => context.push('/home/reminders/new'),
        icon: const Icon(Icons.add),
        label: const Text('新建提醒'),
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('提醒加载失败：$error')),
        data: (data) {
          final visible = _priority == null
              ? data
              : data
                    .where((item) => item.reminder.priority == _priority)
                    .toList(growable: false);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(
              reminderItemsProvider((search: _search, view: _view)),
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
              children: [
                _ReminderIntro(
                  search: _search,
                  priority: _priority,
                  onClear: () => setState(() {
                    _search = '';
                    _priority = null;
                  }),
                ),
                const SizedBox(height: 14),
                _ReminderStats(items: data),
                const SizedBox(height: 18),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'todo',
                      label: Text('待办'),
                      icon: Icon(Icons.inbox_outlined),
                    ),
                    ButtonSegment(
                      value: 'plan',
                      label: Text('计划'),
                      icon: Icon(Icons.event_note_outlined),
                    ),
                    ButtonSegment(
                      value: 'completed',
                      label: Text('已完成'),
                      icon: Icon(Icons.task_alt_outlined),
                    ),
                  ],
                  selected: {_view},
                  onSelectionChanged: (value) =>
                      setState(() => _view = value.first),
                ),
                const SizedBox(height: 20),
                if (visible.isEmpty)
                  _ReminderEmpty(
                    completed: _view == 'completed',
                    onCreate: () => context.push('/home/reminders/new'),
                  )
                else
                  ..._buildGroups(context, visible),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildGroups(
    BuildContext context,
    List<ReminderListItem> items,
  ) {
    final groups = <String, List<ReminderListItem>>{};
    for (final item in items) {
      groups.putIfAbsent(_groupLabel(item), () => []).add(item);
    }
    return [
      for (final entry in groups.entries) ...[
        Text(
          entry.key,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 9),
        for (final item in entry.value) ...[
          _ReminderCard(item: item, onComplete: () => _complete(item)),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
      ],
    ];
  }

  String _groupLabel(ReminderListItem item) {
    if (item.isCompleted || item.isSkipped) return '已处理';
    if (item.isOverdue) return '逾期';
    if (item.isToday) return '今天';
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final date = item.scheduledAt;
    if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return '明天';
    }
    return '未来';
  }

  Future<void> _complete(ReminderListItem item) async {
    await ref
        .read(reminderRepositoryProvider)
        .completeOccurrence(item.occurrence.id);
    await ref.read(reminderSchedulerProvider).rescheduleAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已完成“${item.reminder.title}”'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () async {
            await ref
                .read(reminderRepositoryProvider)
                .completeOccurrence(item.occurrence.id, completed: false);
            await ref.read(reminderSchedulerProvider).rescheduleAll();
          },
        ),
      ),
    );
  }

  Future<void> _showSearch() async {
    final controller = TextEditingController(text: _search);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索提醒'),
        content: TextField(
          autofocus: true,
          controller: controller,
          decoration: const InputDecoration(
            hintText: '标题或备注',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('清除'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('搜索'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && mounted) setState(() => _search = result);
  }

  Future<void> _showFilter() async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Wrap(
            runSpacing: 8,
            children: [
              Text('按重要程度', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              for (final priority in ReminderOptions.priorities)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _priorityIcon(priority),
                    color: _priorityColor(priority),
                  ),
                  title: Text(ReminderOptions.priorityLabel(priority)),
                  trailing: _priority == priority
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(priority),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.clear_all_outlined),
                title: const Text('显示全部'),
                onTap: () => Navigator.of(context).pop(''),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _priority = result.isEmpty ? null : result);
    }
  }
}

class _ReminderIntro extends StatelessWidget {
  const _ReminderIntro({
    required this.search,
    required this.priority,
    required this.onClear,
  });

  final String search;
  final String? priority;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasFilter = search.isNotEmpty || priority != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFFE9F8F0), Color(0xFFE9F1FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.checklist_rtl_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本地提醒', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  hasFilter
                      ? '${search.isNotEmpty ? '搜索“$search”' : ''}${priority == null ? '' : ' · ${ReminderOptions.priorityLabel(priority!)}'}'
                      : '今天、逾期和未来计划一眼可见',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (hasFilter)
            IconButton(
              onPressed: onClear,
              tooltip: '清除筛选',
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}

class _ReminderStats extends StatelessWidget {
  const _ReminderStats({required this.items});

  final List<ReminderListItem> items;

  @override
  Widget build(BuildContext context) {
    final today = items.where((item) => item.isToday).length;
    final overdue = items.where((item) => item.isOverdue).length;
    final future = items.where((item) {
      final date = item.scheduledAt;
      final now = DateTime.now();
      return date.isAfter(now) &&
          date.isBefore(now.add(const Duration(days: 7)));
    }).length;
    return Row(
      children: [
        _StatCard(
          label: '今天',
          value: today,
          color: AppColors.primary,
          icon: Icons.today_outlined,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: '逾期',
          value: overdue,
          color: AppColors.danger,
          icon: Icons.warning_amber_outlined,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: '未来 7 天',
          value: future,
          color: AppColors.techBlue,
          icon: Icons.date_range_outlined,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(height: 7),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w800),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.item, required this.onComplete});

  final ReminderListItem item;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final due = item.scheduledAt;
    final dueText =
        '${due.month}月${due.day}日 ${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}';
    final color = item.isOverdue
        ? AppColors.danger
        : _priorityColor(item.reminder.priority);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(
          '/home/reminders/${item.reminder.id}?occurrenceId=${item.occurrence.id}',
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 13, 14, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: '完成 ${item.reminder.title}',
                child: IconButton(
                  onPressed: item.isPending ? onComplete : null,
                  icon: Icon(
                    item.isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: item.isCompleted ? AppColors.primary : color,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.reminder.title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 16,
                                  decoration: item.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                          ),
                        ),
                        _PriorityBadge(priority: item.reminder.priority),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${item.isOverdue ? '逾期 · ' : ''}$dueText · ${ReminderOptions.repeatLabel(item.reminder.repeatRule)}',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: color, fontWeight: FontWeight.w600),
                    ),
                    if (item.links.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: [
                          for (final link in item.links.take(3))
                            Chip(
                              label: Text(link.displayName),
                              avatar: const Icon(
                                Icons.person_outline,
                                size: 15,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.helper),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: _priorityColor(priority).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      ReminderOptions.priorityLabel(priority),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: _priorityColor(priority),
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _ReminderEmpty extends StatelessWidget {
  const _ReminderEmpty({required this.completed, required this.onCreate});

  final bool completed;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          Icon(
            completed ? Icons.task_alt_outlined : Icons.wb_sunny_outlined,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            completed ? '还没有已完成的事项' : '今天没有待处理事项',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            completed ? '完成的提醒会在这里留下记录。' : '现在记录一件要做的事，之后就不会忘。',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (!completed) ...[
            const SizedBox(height: 17),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('新建第一个提醒'),
            ),
          ],
        ],
      ),
    ),
  );
}

Color _priorityColor(String priority) => switch (priority) {
  'urgent' => AppColors.danger,
  'important' => const Color(0xFFE98500),
  _ => AppColors.techBlue,
};

IconData _priorityIcon(String priority) => switch (priority) {
  'urgent' => Icons.priority_high_outlined,
  'important' => Icons.bookmark_border_outlined,
  _ => Icons.circle_outlined,
};
