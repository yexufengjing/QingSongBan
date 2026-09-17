import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../personnel/application/personnel_providers.dart';
import '../../personnel/domain/personnel_options.dart';
import '../application/reminder_providers.dart';
import '../domain/reminder_options.dart';
import '../domain/reminder_schedule.dart';
import 'reminder_schedule_page.dart';

class ReminderFormPage extends ConsumerStatefulWidget {
  const ReminderFormPage({super.key, this.reminderId});

  final int? reminderId;

  @override
  ConsumerState<ReminderFormPage> createState() => _ReminderFormPageState();
}

class _ReminderFormPageState extends ConsumerState<ReminderFormPage> {
  final _titleController = TextEditingController();
  final _remarkController = TextEditingController();
  late DateTime _dueDate = _defaultDueDate();
  ReminderSchedule _schedule = const ReminderSchedule();
  String _priority = 'normal';
  String _category = 'general';
  bool _isEnabled = true;
  bool _advancedExpanded = false;
  bool _loading = false;
  bool _saving = false;
  final Set<int> _employeeIds = <int>{};

  bool get _isEditing => widget.reminderId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loading = true;
      Future<void>.microtask(_loadReminder);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _loadReminder() async {
    final item = await ref
        .read(reminderRepositoryProvider)
        .findItemById(widget.reminderId!);
    if (!mounted) return;
    if (item == null) {
      context.pop();
      return;
    }
    final reminder = item.reminder;
    setState(() {
      _titleController.text = reminder.title;
      _remarkController.text = reminder.remark ?? '';
      _dueDate = reminder.dueDate ?? _defaultDueDate();
      _schedule = ReminderSchedule.decode(
        reminder.repeatRule,
        legacyLeadDays: reminder.leadDays,
      );
      _priority = reminder.priority;
      _category = reminder.category;
      _isEnabled = reminder.isEnabled;
      _employeeIds.addAll(
        item.links
            .where((link) => link.entityType == 'employee')
            .map((link) => link.entityId),
      );
      _advancedExpanded =
          _priority != 'normal' ||
          _category == 'custom' ||
          _employeeIds.isNotEmpty ||
          _remarkController.text.isNotEmpty;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final employees =
        ref.watch(allPersonnelProvider).valueOrNull ?? const <Employee>[];
    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: _saving ? null : () => context.pop(),
          child: const Text('取消'),
        ),
        leadingWidth: 72,
        title: Text(_isEditing ? '编辑提醒' : '新建提醒'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
              children: [
                _buildMainInput(context),
                const SizedBox(height: 18),
                Text('事项类型', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in ReminderCategories.values)
                      ChoiceChip(
                        label: Text(ReminderCategories.label(category)),
                        selected: _category == category,
                        onSelected: (_) => _selectCategory(category),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Card(
                  child: ListTile(
                    key: const Key('reminder-custom-time'),
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('时间与提醒'),
                    subtitle: Text(
                      '${_fullDateLabel(_dueDate)} · ${_schedule.repeatLabel(_dueDate)} · ${_schedule.alertLabel}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _editSchedule,
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: ExpansionTile(
                    initiallyExpanded: _advancedExpanded,
                    leading: const Icon(Icons.tune_outlined),
                    title: const Text('更多设置'),
                    subtitle: Text(_advancedSummary()),
                    onExpansionChanged: (value) => _advancedExpanded = value,
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    children: [
                      const Divider(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '重要程度',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: [
                          for (final priority in ReminderPriorities.values)
                            ButtonSegment(
                              value: priority,
                              label: Text(ReminderPriorities.label(priority)),
                              icon: Icon(_priorityIcon(priority)),
                            ),
                        ],
                        selected: {_priority},
                        onSelectionChanged: (value) =>
                            setState(() => _priority = value.single),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _remarkController,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: '详细内容（选填）',
                          hintText: '地点、联系人或需要准备的材料',
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.group_outlined),
                        title: const Text('关联人员'),
                        subtitle: Text(
                          _employeeIds.isEmpty
                              ? '未关联'
                              : '已选择 ${_employeeIds.length} 人',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pickEmployees(employees),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('启用系统通知'),
                        subtitle: const Text('关闭后事项仍会保留在应用内'),
                        value: _isEnabled,
                        onChanged: (value) =>
                            setState(() => _isEnabled = value),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: FilledButton.icon(
          key: const Key('reminder-save-button'),
          onPressed: _saving || _loading ? null : () => _save(employees),
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(_saving ? '保存中…' : '保存提醒'),
        ),
      ),
    );
  }

  Widget _buildMainInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.lightOrange,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFDDB8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('reminder-title-field'),
            controller: _titleController,
            autofocus: !_isEditing,
            minLines: 2,
            maxLines: 5,
            textInputAction: TextInputAction.done,
            style: Theme.of(context).textTheme.headlineMedium,
            decoration: const InputDecoration(
              hintText: '要提醒什么？',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(_scheduleChipLabel()),
              ),
              Chip(
                avatar: Icon(_priorityIcon(_priority), size: 18),
                label: Text(ReminderPriorities.label(_priority)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _selectCategory(String category) {
    setState(() {
      _category = category;
      if (category == 'periodic' && !_schedule.repeats) {
        _schedule = _schedule.copyWith(
          repeatUnit: ReminderRepeatUnit.month,
          monthDays: {_dueDate.day},
        );
      }
    });
  }

  Future<void> _editSchedule() async {
    final result = await Navigator.push<ReminderScheduleResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ReminderSchedulePage(
          initialDate: _dueDate,
          initialSchedule: _schedule,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _dueDate = result.dueDate;
        _schedule = result.schedule;
        if (_schedule.repeats && _category == 'general') {
          _category = 'periodic';
        }
      });
    }
  }

  Future<void> _pickEmployees(List<Employee> employees) async {
    final selected = {..._employeeIds};
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      const Expanded(
                        child: Text(
                          '关联人员',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, selected),
                        child: const Text('完成'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: employees.isEmpty
                      ? const Center(child: Text('暂无可关联人员'))
                      : ListView.builder(
                          itemCount: employees.length,
                          itemBuilder: (context, index) {
                            final employee = employees[index];
                            return CheckboxListTile(
                              value: selected.contains(employee.id),
                              title: Text(employee.name),
                              subtitle: Text(
                                '${employee.employeeNo} · ${PersonnelOptions.statusLabel(employee.status)}',
                              ),
                              onChanged: (_) => setSheetState(() {
                                selected.contains(employee.id)
                                    ? selected.remove(employee.id)
                                    : selected.add(employee.id);
                              }),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _employeeIds
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _save(List<Employee> employees) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('请先输入要做的事情');
      return;
    }
    if (!_isEditing && !_dueDate.isAfter(DateTime.now())) {
      _showMessage('提醒时间必须晚于当前时间');
      return;
    }
    if (_isEnabled && _schedule.alertMinutes.isEmpty) {
      _showMessage('请至少选择一个提醒时间，或关闭系统通知');
      return;
    }
    setState(() => _saving = true);
    try {
      final notificationService = ref.read(notificationServiceProvider);
      final timezoneId = await notificationService.currentTimezoneId();
      final reminder = await ref
          .read(reminderRepositoryProvider)
          .save(
            id: widget.reminderId,
            draft: ReminderDraft(
              title: title,
              reminderType: 'custom',
              dueDate: _dueDate,
              leadDays: 0,
              repeatRule: _schedule.encode(),
              isEnabled: _isEnabled,
              remark: _remarkController.text,
              priority: _priority,
              category: _category,
              timezoneId: timezoneId,
              links: [
                for (final employee in employees)
                  if (_employeeIds.contains(employee.id))
                    ReminderLinkDraft(
                      entityType: 'employee',
                      entityId: employee.id,
                      displayName: employee.name,
                    ),
              ],
            ),
          );
      if (_isEnabled) {
        await notificationService.requestPermission();
        await notificationService.sync(
          reminder,
          pendingOccurrences: await ref
              .read(reminderRepositoryProvider)
              .listPendingOccurrenceTimes(reminder.id),
        );
      } else {
        await notificationService.cancel(reminder.id);
      }
      if (mounted) context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('保存失败：$error');
    }
  }

  String _advancedSummary() {
    final parts = <String>[
      ReminderPriorities.label(_priority),
      if (_employeeIds.isNotEmpty) '关联 ${_employeeIds.length} 人',
      _isEnabled ? '通知已开启' : '仅应用内显示',
    ];
    return parts.join(' · ');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _scheduleChipLabel() {
    final now = DateTime.now();
    final date = _sameDay(_dueDate, now)
        ? '今天'
        : _sameDay(_dueDate, now.add(const Duration(days: 1)))
        ? '明天'
        : '${_dueDate.month}月${_dueDate.day}日';
    return '$date ${_dueDate.hour.toString().padLeft(2, '0')}:${_dueDate.minute.toString().padLeft(2, '0')}';
  }
}

IconData _priorityIcon(String priority) => switch (priority) {
  'urgent' => Icons.priority_high_rounded,
  'important' => Icons.flag_outlined,
  _ => Icons.remove_rounded,
};

DateTime _defaultDueDate() {
  final value = DateTime.now().add(const Duration(hours: 1));
  return DateTime(value.year, value.month, value.day, value.hour, 0);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _fullDateLabel(DateTime value) =>
    '${value.year}年${value.month}月${value.day}日 '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
