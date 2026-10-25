import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../reminders/application/reminder_providers.dart';
import '../../reminders/domain/reminder_options.dart';
import '../application/calendar_providers.dart';
import '../domain/calendar_models.dart';
import 'calendar_editor_page.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _selectedDate = _dateOnly(DateTime.now());
  late DateTime _displayedMonth = DateTime.now();
  bool _completedExpanded = false;
  final Set<int> _expandedEntries = <int>{};
  bool _busy = false;

  DateTime get _month => DateTime(_displayedMonth.year, _displayedMonth.month);

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(calendarMonthProvider(_month));
    return Scaffold(
      appBar: AppBar(
        title: const Text('日历与记录'),
        actions: [
          TextButton.icon(
            key: const Key('calendar-today'),
            onPressed: _goToday,
            icon: const Icon(Icons.today_outlined),
            label: const Text('今天'),
          ),
        ],
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _CalendarLoadError(
          onRetry: () => ref.invalidate(calendarMonthProvider(_month)),
        ),
        data: (value) => _buildContent(value),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('calendar-add'),
        onPressed: _busy ? null : _chooseCreateType,
        icon: const Icon(Icons.add),
        label: const Text('新增'),
      ),
    );
  }

  Widget _buildContent(CalendarSnapshot snapshot) {
    final todos = snapshot.todos.where((item) {
      final scheduledAt = item.scheduledAt;
      return scheduledAt != null &&
          _sameDay(scheduledAt, _selectedDate) &&
          (item.isPending || item.isCompleted);
    }).toList()..sort(_compareTodos);
    final entries = snapshot.entries.where((entry) {
      return _sameDay(_entryDate(entry), _selectedDate);
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final pending = todos.where((item) => item.isPending).toList();
    final completed = todos.where((item) => item.isCompleted).toList();

    return ListView(
      key: const Key('calendar-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      children: [
        _MonthToolbar(
          month: _displayedMonth,
          onPrevious: () => _changeMonth(-1),
          onNext: () => _changeMonth(1),
          onPickMonth: _pickMonth,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -80) _changeMonth(1);
            if (velocity > 80) _changeMonth(-1);
          },
          child: _MonthGrid(
            month: _displayedMonth,
            selectedDate: _selectedDate,
            todos: snapshot.todos,
            entries: snapshot.entries,
            onSelected: _selectDate,
          ),
        ),
        const SizedBox(height: 12),
        const _CalendarLegend(),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(
            '${_fullDate(_selectedDate)} · ${_weekDay(_selectedDate.weekday)} · 未完成 ${pending.length} 项',
            key: const Key('calendar-selected-date'),
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeading(title: '待办', count: pending.length),
        if (pending.isEmpty)
          const _InlineEmpty('这一天没有未完成事项')
        else
          for (final item in pending) ...[
            _TodoRow(
              key: ValueKey('todo-${item.id}-${item.occurrenceId}'),
              item: item,
              busy: _busy,
              onComplete: () => _toggleCompleted(item),
              onEdit: () => _editTodo(item),
              onDelete: () => _deleteTodo(item),
            ),
          ],
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 8),
          InkWell(
            key: const Key('calendar-completed-toggle'),
            borderRadius: BorderRadius.circular(8),
            onTap: () =>
                setState(() => _completedExpanded = !_completedExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _completedExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  const SizedBox(width: 8),
                  Text('已完成 ${completed.length} 项'),
                ],
              ),
            ),
          ),
          if (_completedExpanded)
            for (final item in completed)
              _TodoRow(
                key: ValueKey('todo-${item.id}-${item.occurrenceId}'),
                item: item,
                busy: _busy,
                onComplete: () => _toggleCompleted(item),
                onEdit: () => _editTodo(item),
                onDelete: () => _deleteTodo(item),
              ),
        ],
        const SizedBox(height: 24),
        _SectionHeading(title: '日记录', count: entries.length),
        if (entries.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('calendar-create-entry-empty'),
              onPressed: _busy ? null : () => _openEditor(entry: true),
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('写一条记录'),
            ),
          )
        else
          for (final entry in entries) ...[
            _EntryRow(
              key: ValueKey('entry-${entry.id}'),
              entry: entry,
              expanded: _expandedEntries.contains(entry.id),
              busy: _busy,
              onToggleExpanded: () => setState(() {
                if (!_expandedEntries.add(entry.id)) {
                  _expandedEntries.remove(entry.id);
                }
              }),
              onEdit: () => _openEditor(entry: true, existingEntry: entry),
              onDelete: () => _deleteEntry(entry),
            ),
          ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('calendar-unscheduled'),
          onPressed: () => context.push('/settings/reminders'),
          icon: const Icon(Icons.inbox_outlined),
          label: const Text('无日期事项 · 查看备忘提醒'),
        ),
      ],
    );
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = _dateOnly(date);
      _displayedMonth = DateTime(date.year, date.month);
      _completedExpanded = false;
    });
  }

  void _changeMonth(int delta) {
    final target = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + delta,
    );
    final day = _selectedDate.day
        .clamp(1, DateTime(target.year, target.month + 1, 0).day)
        .toInt();
    setState(() {
      _displayedMonth = target;
      _selectedDate = DateTime(target.year, target.month, day);
    });
  }

  void _goToday() => _selectDate(DateTime.now());

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      initialDatePickerMode: DatePickerMode.year,
      helpText: '选择年月',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) return;
    final target = DateTime(picked.year, picked.month);
    final day = _selectedDate.day
        .clamp(1, DateTime(target.year, target.month + 1, 0).day)
        .toInt();
    setState(() {
      _displayedMonth = target;
      _selectedDate = DateTime(target.year, target.month, day);
    });
  }

  Future<void> _chooseCreateType() async {
    final type = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: const Text('待办事项'),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('日记录'),
              onTap: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (type != null && mounted) _openEditor(entry: type);
  }

  Future<void> _openEditor({
    required bool entry,
    DailyEntry? existingEntry,
    ReminderItem? existingTodo,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CalendarEditorPage(
          isEntry: entry,
          initialDate: existingEntry != null
              ? _entryDate(existingEntry)
              : existingTodo?.scheduledAt ?? _selectedDate,
          initialContent:
              existingEntry?.content ?? existingTodo?.reminder.title ?? '',
          initialRemark: existingTodo?.reminder.remark ?? '',
          initialTime:
              existingTodo == null ||
                  existingTodo.isAllDay ||
                  existingTodo.scheduledAt == null
              ? null
              : TimeOfDay.fromDateTime(existingTodo.scheduledAt!),
          isAllDay: existingTodo?.isAllDay ?? true,
          onSave: (date, content, {time, isAllDay, remark}) async {
            setState(() => _busy = true);
            var notificationFailed = false;
            try {
              if (entry) {
                await ref
                    .read(calendarRepositoryProvider)
                    .saveEntry(
                      id: existingEntry?.id,
                      date: date,
                      content: content,
                    );
              } else {
                final saved = await ref
                    .read(calendarRepositoryProvider)
                    .saveTodo(
                      id: existingTodo?.id,
                      title: content,
                      date: date,
                      time: time == null
                          ? null
                          : DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            ),
                      isAllDay: isAllDay ?? true,
                      remark: remark,
                    );
                if (existingTodo != null) {
                  try {
                    final repository = ref.read(reminderRepositoryProvider);
                    await ref
                        .read(notificationServiceProvider)
                        .sync(
                          saved,
                          pendingOccurrences: await repository
                              .listPendingOccurrenceTimes(saved.id),
                        );
                  } catch (_) {
                    notificationFailed = true;
                  }
                }
              }
              if (mounted) {
                _selectDate(date);
                _refreshMonth();
                _message(
                  entry
                      ? '记录已保存'
                      : notificationFailed
                      ? '事项已保存，提醒更新失败'
                      : '事项已保存',
                );
              }
            } catch (error) {
              if (mounted) _message('保存失败：$error');
              rethrow;
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          },
        ),
      ),
    );
    if (mounted) _refreshMonth();
  }

  Future<void> _editTodo(ReminderItem item) async {
    if (item.isRepeating) {
      final editSeries = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('编辑重复事项'),
          content: const Text('将打开完整提醒设置，修改会影响整个重复系列。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('编辑整个系列'),
            ),
          ],
        ),
      );
      if (editSeries == true && mounted) {
        await context.push('/settings/reminders/${item.id}/edit');
        if (mounted) _refreshMonth();
      }
      return;
    }
    await _openEditor(entry: false, existingTodo: item);
  }

  Future<void> _toggleCompleted(ReminderItem item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(calendarRepositoryProvider)
          .setCompleted(item, !item.isCompleted);
      var notificationFailed = false;
      final saved = await ref
          .read(reminderRepositoryProvider)
          .findById(item.id);
      if (saved != null && saved.isEnabled) {
        try {
          final repository = ref.read(reminderRepositoryProvider);
          await ref
              .read(notificationServiceProvider)
              .sync(
                saved,
                pendingOccurrences: await repository.listPendingOccurrenceTimes(
                  saved.id,
                ),
              );
        } catch (_) {
          notificationFailed = true;
        }
      } else if (saved != null) {
        try {
          await ref.read(notificationServiceProvider).sync(saved);
        } catch (_) {
          notificationFailed = true;
        }
      }
      if (mounted) {
        _refreshMonth();
        _message(
          notificationFailed
              ? '状态已更新，提醒更新失败'
              : item.isCompleted
              ? '已恢复为待办'
              : '已完成本期事项',
        );
      }
    } catch (error) {
      if (mounted) _message('状态更新失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteTodo(ReminderItem item) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.isRepeating ? '处理重复事项' : '删除待办？'),
        content: Text(
          item.isRepeating
              ? '“${item.reminder.title}”是重复事项。可以只跳过本次，或删除整个重复系列。'
              : '确认删除“${item.reminder.title}”？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          if (item.isRepeating)
            TextButton(
              onPressed: () => Navigator.pop(context, 'skip'),
              child: const Text('只跳过本次'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: Text(item.isRepeating ? '删除整个系列' : '删除'),
          ),
        ],
      ),
    );
    if (action == null) return;
    setState(() => _busy = true);
    try {
      final repository = ref.read(calendarRepositoryProvider);
      var notificationFailed = false;
      if (action == 'skip') {
        await repository.skipOccurrence(item);
        final saved = await ref
            .read(reminderRepositoryProvider)
            .findById(item.id);
        if (saved != null) {
          try {
            final reminderRepository = ref.read(reminderRepositoryProvider);
            await ref
                .read(notificationServiceProvider)
                .sync(
                  saved,
                  pendingOccurrences: await reminderRepository
                      .listPendingOccurrenceTimes(saved.id),
                );
          } catch (_) {
            notificationFailed = true;
          }
        }
      } else if (item.isRepeating) {
        await ref.read(reminderRepositoryProvider).delete(item.id);
        try {
          await ref.read(notificationServiceProvider).cancel(item.id);
        } catch (_) {
          notificationFailed = true;
        }
      } else {
        await repository.deleteTodo(item);
        try {
          await ref.read(notificationServiceProvider).cancel(item.id);
        } catch (_) {
          notificationFailed = true;
        }
      }
      if (mounted) {
        _refreshMonth();
        _message(
          notificationFailed
              ? action == 'skip'
                    ? '已跳过本次，提醒更新失败'
                    : item.isRepeating
                    ? '系列已删除，提醒更新失败'
                    : '事项已删除，提醒更新失败'
              : action == 'skip'
              ? '已跳过本次'
              : '待办已删除',
        );
      }
    } catch (error) {
      if (mounted) _message('操作失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteEntry(DailyEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除日记录？'),
        content: Text('“${_excerpt(entry.content)}”将被删除。'),
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
      await ref.read(calendarRepositoryProvider).deleteEntry(entry.id);
      if (mounted) {
        _refreshMonth();
        _message('记录已删除');
      }
    } catch (error) {
      if (mounted) _message('删除失败：$error');
    }
  }

  void _refreshMonth() => ref.invalidate(calendarMonthProvider(_month));

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _MonthToolbar extends StatelessWidget {
  const _MonthToolbar({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onPickMonth,
  });
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickMonth;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: '上个月',
        onPressed: onPrevious,
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: TextButton(
          key: const Key('calendar-month-picker'),
          onPressed: onPickMonth,
          child: Text(
            '${month.year}年${month.month}月',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      IconButton(
        tooltip: '下个月',
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDate,
    required this.todos,
    required this.entries,
    required this.onSelected,
  });
  final DateTime month;
  final DateTime selectedDate;
  final List<ReminderItem> todos;
  final List<DailyEntry> entries;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final last = DateTime(month.year, month.month + 1, 0);
    final count = ((first.weekday - 1 + last.day) / 7).ceil() * 7;
    final today = _dateOnly(DateTime.now());
    return Column(
      children: [
        Row(
          children: [
            for (final day in ['一', '二', '三', '四', '五', '六', '日'])
              Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(color: AppColors.body, fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var week = 0; week < count ~/ 7; week++)
          Row(
            children: [
              for (var weekday = 0; weekday < 7; weekday++)
                Expanded(
                  child: _DateCell(
                    date: _gridDate(month, first.weekday, week, weekday),
                    inMonth:
                        _gridDate(month, first.weekday, week, weekday).month ==
                        month.month,
                    isToday: _sameDay(
                      _gridDate(month, first.weekday, week, weekday),
                      today,
                    ),
                    selected: _sameDay(
                      _gridDate(month, first.weekday, week, weekday),
                      selectedDate,
                    ),
                    todos: todos,
                    entries: entries,
                    onTap: onSelected,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.selected,
    required this.todos,
    required this.entries,
    required this.onTap,
  });
  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final bool selected;
  final List<ReminderItem> todos;
  final List<DailyEntry> entries;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(13) / 13;
    final cellHeight = 58 * textScale;
    final dayTodos = todos
        .where(
          (item) =>
              item.scheduledAt != null &&
              _sameDay(item.scheduledAt!, date) &&
              (item.isPending || item.isCompleted),
        )
        .toList();
    final pending = dayTodos.any((item) => item.isPending);
    final completed = dayTodos.isNotEmpty && !pending;
    final hasEntry = entries.any((entry) => _sameDay(_entryDate(entry), date));
    final semantic =
        '${_fullDate(date)}${isToday ? '，今天' : ''}${selected ? '，已选择' : ''}${dayTodos.isNotEmpty ? '，${dayTodos.where((item) => item.isPending).length}项未完成' : ''}${hasEntry ? '，有日记录' : ''}';
    return Semantics(
      button: true,
      selected: selected,
      label: semantic,
      onTap: () => onTap(date),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: ExcludeSemantics(
          child: InkWell(
            key: Key('calendar-date-${date.year}-${date.month}-${date.day}'),
            borderRadius: BorderRadius.circular(10),
            onTap: () => onTap(date),
            child: Container(
              height: cellHeight < 58 ? 58 : cellHeight,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isToday && !selected
                    ? Border.all(color: AppColors.primary, width: 1.5)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : inMonth
                          ? AppColors.ink
                          : AppColors.helper,
                      fontWeight: selected || isToday
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (pending)
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white
                                  : AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (completed)
                          Icon(
                            Icons.check,
                            size: 11,
                            color: selected ? Colors.white : AppColors.success,
                          ),
                        if (hasEntry)
                          Container(
                            width: 9,
                            height: 2,
                            margin: const EdgeInsets.only(left: 2),
                            decoration: BoxDecoration(
                              color: selected ? Colors.white : AppColors.body,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 8,
    children: const [
      _LegendItem(icon: Icons.circle, label: '未完成待办'),
      _LegendItem(icon: Icons.check, label: '全部完成'),
      _LegendItem(icon: Icons.remove, label: '有日记录'),
    ],
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppColors.body),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.count});
  final String title;
  final int count;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Text('$count', style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: AppColors.body),
    ),
  );
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({
    super.key,
    required this.item,
    required this.busy,
    required this.onComplete,
    required this.onEdit,
    required this.onDelete,
  });
  final ReminderItem item;
  final bool busy;
  final VoidCallback onComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final scheduled = item.scheduledAt;
    final overdue =
        item.isPending && scheduled != null && _isOverdue(item, DateTime.now());
    final detail = item.isAllDay
        ? '全天'
        : scheduled == null
        ? ''
        : '${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Checkbox(
              value: item.isCompleted,
              onChanged: busy ? null : (_) => onComplete(),
              semanticLabel: item.isCompleted
                  ? '恢复${item.reminder.title}为待办'
                  : '完成${item.reminder.title}',
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.reminder.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (detail.isNotEmpty || overdue) ...[
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (detail.isNotEmpty)
                            Text(
                              detail,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (overdue)
                            Text(
                              '逾期',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          if ((item.reminder.timezoneId ?? '').isNotEmpty)
                            Text(
                              '时区 ${item.reminder.timezoneId}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ],
                    if ((item.reminder.remark ?? '').trim().isNotEmpty)
                      Text(
                        item.reminder.remark!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '更多操作',
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('编辑')),
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    super.key,
    required this.entry,
    required this.expanded,
    required this.busy,
    required this.onToggleExpanded,
    required this.onEdit,
    required this.onDelete,
  });
  final DailyEntry entry;
  final bool expanded;
  final bool busy;
  final VoidCallback onToggleExpanded;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggleExpanded,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              entry.content,
              key: Key('calendar-entry-${entry.id}'),
              maxLines: expanded ? null : 3,
              overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
        Text(
          entry.updatedAt.isAfter(entry.createdAt)
              ? '更新于 ${_timeLabel(entry.updatedAt)}'
              : '记录于 ${_timeLabel(entry.createdAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: busy ? null : onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('编辑'),
            ),
            TextButton.icon(
              onPressed: busy ? null : onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('删除'),
            ),
          ],
        ),
        const Divider(height: 1),
      ],
    ),
  );
}

class _CalendarLoadError extends StatelessWidget {
  const _CalendarLoadError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
          const SizedBox(height: 12),
          const Text('日历加载失败'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('重新加载')),
        ],
      ),
    ),
  );
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
DateTime _gridDate(DateTime month, int firstWeekday, int week, int weekday) =>
    DateTime(month.year, month.month, 2 - firstWeekday + week * 7 + weekday);
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String _fullDate(DateTime value) =>
    '${value.year}年${value.month}月${value.day}日';
DateTime _entryDate(DailyEntry entry) {
  final parts = entry.recordDate.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

String _weekDay(int value) =>
    const ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'][value - 1];
String _excerpt(String value) {
  final normalized = value.replaceAll('\n', ' ').trim();
  return normalized.substring(0, normalized.length.clamp(0, 28).toInt());
}

String _timeLabel(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
bool _isOverdue(ReminderItem item, DateTime now) {
  final due = item.scheduledAt;
  if (due == null) return false;
  final deadline = item.isAllDay
      ? DateTime(due.year, due.month, due.day + 1)
      : due;
  return deadline.isBefore(now);
}

int _compareTodos(ReminderItem a, ReminderItem b) {
  if (a.isPending != b.isPending) return a.isPending ? -1 : 1;
  if (a.isAllDay != b.isAllDay) return a.isAllDay ? 1 : -1;
  return (a.scheduledAt ?? DateTime(9999)).compareTo(
    b.scheduledAt ?? DateTime(9999),
  );
}
