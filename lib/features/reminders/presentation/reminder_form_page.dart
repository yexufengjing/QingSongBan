import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../personnel/application/personnel_providers.dart';
import '../application/reminder_providers.dart';
import '../domain/reminder_options.dart';

class ReminderFormPage extends ConsumerStatefulWidget {
  const ReminderFormPage({
    this.reminderId,
    this.copyFromId,
    this.initialEmployeeId,
    super.key,
  });

  final int? reminderId;
  final int? copyFromId;
  final int? initialEmployeeId;

  @override
  ConsumerState<ReminderFormPage> createState() => _ReminderFormPageState();
}

class _ReminderFormPageState extends ConsumerState<ReminderFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _remarkController = TextEditingController();
  final _customRuleController = TextEditingController();
  final _customAlertController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  String _reminderType = 'custom';
  String _category = 'general';
  String _priority = 'normal';
  String _repeat = 'none';
  final Set<int> _weekdays = {DateTime.monday};
  final Set<int> _alerts = {0};
  DateTime? _repeatEndsAt;
  int? _repeatCount;
  bool _nagEnabled = false;
  int _nagIntervalHours = 24;
  int _nagMaxCount = 7;
  bool _enabled = true;
  bool _advancedExpanded = false;
  bool _customAlertInputVisible = false;
  String? _customAlertError;
  bool _loading = false;
  bool _saving = false;
  final Set<int> _selectedEmployeeIds = {};

  bool get _isEditing => widget.reminderId != null;
  String get _pageTitle => _isEditing ? '编辑提醒' : '新建提醒';

  @override
  void initState() {
    super.initState();
    if (widget.initialEmployeeId != null) {
      _selectedEmployeeIds.add(widget.initialEmployeeId!);
    }
    if (widget.reminderId != null || widget.copyFromId != null) {
      _loading = true;
      Future<void>.microtask(_loadExisting);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _remarkController.dispose();
    _customRuleController.dispose();
    _customAlertController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_pageTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final employees =
        ref.watch(allPersonnelProvider).valueOrNull ?? const <Employee>[];
    return Scaffold(
      appBar: AppBar(title: Text(_pageTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _FormSection(
              title: '先记下要做什么',
              subtitle: '标题和时间是唯一必填项，其他设置可以稍后补充。',
              child: Column(
                children: [
                  TextFormField(
                    key: const Key('reminder-title-field'),
                    controller: _titleController,
                    autofocus: !_isEditing,
                    decoration: const InputDecoration(
                      labelText: '提醒标题',
                      hintText: '例如：检查材料、领取福利',
                      prefixIcon: Icon(Icons.title_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '请输入提醒标题'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _DateTimeTile(
                    date: _dueDate,
                    time: _time,
                    onDate: _pickDate,
                    onTime: _pickTime,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: '事项类型',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    items: [
                      for (final category in ReminderOptions.categories)
                        DropdownMenuItem(
                          value: category,
                          child: Text(ReminderOptions.categoryLabel(category)),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _category = value ?? 'general'),
                  ),
                  const SizedBox(height: 12),
                  _AlertSelector(
                    alerts: _alerts,
                    onChanged: _toggleAlert,
                    onCustom: _showCustomAlertInput,
                    onCustomSubmit: _submitCustomAlert,
                    onCustomCancel: _cancelCustomAlert,
                    onCustomRemoved: _removeCustomAlert,
                    customInputVisible: _customAlertInputVisible,
                    customController: _customAlertController,
                    customError: _customAlertError,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _TemplateStrip(onSelected: _applyTemplate),
            const SizedBox(height: 4),
            ExpansionTile(
              initiallyExpanded: _advancedExpanded,
              onExpansionChanged: (expanded) =>
                  setState(() => _advancedExpanded = expanded),
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('高级设置'),
              subtitle: const Text('重复、优先级、催办和关联人员'),
              leading: const Icon(Icons.tune_outlined),
              children: [
                _FormSection(
                  title: '重复方式',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _repeat,
                        decoration: const InputDecoration(labelText: '重复周期'),
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('不重复')),
                          DropdownMenuItem(value: 'daily', child: Text('每天')),
                          DropdownMenuItem(value: 'weekly', child: Text('每周')),
                          DropdownMenuItem(value: 'monthly', child: Text('每月')),
                          DropdownMenuItem(
                            value: 'quarterly',
                            child: Text('每季度'),
                          ),
                          DropdownMenuItem(value: 'yearly', child: Text('每年')),
                          DropdownMenuItem(
                            value: 'custom',
                            child: Text('自定义 RRULE'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _repeat = value ?? 'none'),
                      ),
                      if (_repeat == 'weekly') ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '选择星期',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          children: [
                            for (
                              var day = DateTime.monday;
                              day <= DateTime.sunday;
                              day++
                            )
                              FilterChip(
                                label: Text(_weekdayLabel(day)),
                                selected: _weekdays.contains(day),
                                onSelected: (selected) => setState(() {
                                  if (selected) {
                                    _weekdays.add(day);
                                  } else if (_weekdays.length > 1) {
                                    _weekdays.remove(day);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ],
                      if (_repeat == 'custom') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customRuleController,
                          decoration: const InputDecoration(
                            labelText: 'RRULE',
                            hintText: '例如：FREQ=WEEKLY;BYDAY=MO,TH',
                          ),
                        ),
                      ],
                      if (_repeat != 'none') ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickRepeatEnd,
                                icon: const Icon(Icons.event_outlined),
                                label: Text(
                                  _repeatEndsAt == null
                                      ? '永不结束'
                                      : '截至 ${_repeatEndsAt!.month}月${_repeatEndsAt!.day}日',
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickRepeatCount,
                                icon: const Icon(Icons.numbers_outlined),
                                label: Text(
                                  _repeatCount == null
                                      ? '不限次数'
                                      : '共 $_repeatCount 次',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _FormSection(
                  title: '重要程度',
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'normal',
                        label: Text('普通'),
                        icon: Icon(Icons.circle_outlined),
                      ),
                      ButtonSegment(
                        value: 'important',
                        label: Text('重要'),
                        icon: Icon(Icons.bookmark_border),
                      ),
                      ButtonSegment(
                        value: 'urgent',
                        label: Text('紧急'),
                        icon: Icon(Icons.priority_high_outlined),
                      ),
                    ],
                    selected: {_priority},
                    onSelectionChanged: (value) =>
                        setState(() => _priority = value.first),
                  ),
                ),
                const SizedBox(height: 12),
                _FormSection(
                  title: '未完成催办',
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('到期后继续提醒'),
                        subtitle: const Text('完成或跳过本期后，剩余催办会自动取消。'),
                        value: _nagEnabled,
                        onChanged: (value) =>
                            setState(() => _nagEnabled = value),
                      ),
                      if (_nagEnabled)
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: _nagIntervalHours,
                                decoration: const InputDecoration(
                                  labelText: '间隔',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 1,
                                    child: Text('每 1 小时'),
                                  ),
                                  DropdownMenuItem(
                                    value: 4,
                                    child: Text('每 4 小时'),
                                  ),
                                  DropdownMenuItem(
                                    value: 24,
                                    child: Text('每天'),
                                  ),
                                ],
                                onChanged: (value) => setState(
                                  () => _nagIntervalHours = value ?? 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: _nagMaxCount,
                                decoration: const InputDecoration(
                                  labelText: '最多次数',
                                ),
                                items: [
                                  for (final count in [1, 3, 5, 7, 10])
                                    DropdownMenuItem(
                                      value: count,
                                      child: Text('$count 次'),
                                    ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _nagMaxCount = value ?? 7),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _EmployeeSelector(
                  employees: employees,
                  selectedIds: _selectedEmployeeIds,
                  onTap: () => _pickEmployees(employees),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _remarkController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '详细内容',
                    hintText: '补充地点、材料或处理说明',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('启用系统通知'),
              subtitle: const Text('关闭后仍可在备忘提醒中查看事项。'),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('reminder-save-button'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? '保存中…' : '保存提醒'),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除提醒'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadExisting() async {
    final id = widget.reminderId ?? widget.copyFromId;
    if (id == null) return;
    final repository = ref.read(reminderRepositoryProvider);
    final reminder = await repository.findById(id);
    if (reminder == null || !mounted) return;
    final rules = await repository.findAlertRules(id);
    final links = await repository.findLinkDisplays(id);
    final due = reminder.dueDate;
    _titleController.text = reminder.title;
    _remarkController.text = reminder.remark ?? '';
    _reminderType = reminder.reminderType;
    _category = reminder.category;
    _priority = reminder.priority;
    _enabled = reminder.isEnabled;
    if (due != null) {
      _dueDate = due;
      _time = TimeOfDay(hour: due.hour, minute: due.minute);
    }
    _alerts
      ..clear()
      ..addAll(
        rules
            .where((rule) => !rule.isNagRule)
            .map((rule) => rule.offsetMinutes),
      );
    if (_alerts.isEmpty) _alerts.add(-reminder.leadDays * 1440);
    _nagEnabled = rules.any((rule) => rule.isNagRule);
    final nagRules = rules.where((rule) => rule.isNagRule).toList();
    final nag = nagRules.isEmpty ? null : nagRules.first;
    if (nag != null) {
      _nagIntervalHours = ((nag.repeatIntervalMinutes ?? 1440) / 60).round();
      _nagMaxCount = nag.maxRepeatCount ?? 7;
    }
    final rule = reminder.repeatRule;
    if (rule == null || rule.isEmpty) {
      _repeat = 'none';
    } else if (rule.contains('FREQ=DAILY')) {
      _repeat = 'daily';
    } else if (rule.contains('FREQ=WEEKLY')) {
      _repeat = 'weekly';
      _weekdays
        ..clear()
        ..addAll(_parseWeekdays(rule));
    } else if (rule.contains('INTERVAL=3')) {
      _repeat = 'quarterly';
    } else if (rule.contains('FREQ=MONTHLY')) {
      _repeat = 'monthly';
    } else if (rule.contains('FREQ=YEARLY')) {
      _repeat = 'yearly';
    } else {
      _repeat = 'custom';
      _customRuleController.text = rule.replaceFirst('RRULE:', '');
    }
    _selectedEmployeeIds.addAll(
      links
          .where((link) => link.entityType == 'employee')
          .map((link) => link.entityId),
    );
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_repeat == 'custom' && _customRuleController.text.trim().isEmpty) {
      _showMessage('请输入自定义 RRULE');
      return;
    }
    setState(() => _saving = true);
    final due = DateTime(
      _dueDate.year,
      _dueDate.month,
      _dueDate.day,
      _time.hour,
      _time.minute,
    );
    final employees =
        ref.read(allPersonnelProvider).valueOrNull ?? const <Employee>[];
    final links = [
      for (final employee in employees.where(
        (item) => _selectedEmployeeIds.contains(item.id),
      ))
        ReminderLinkDraft(
          entityType: 'employee',
          entityId: employee.id,
          displayNameSnapshot: employee.name,
        ),
    ];
    final repeatEnds = _repeatEndsAt == null
        ? null
        : DateTime(
            _repeatEndsAt!.year,
            _repeatEndsAt!.month,
            _repeatEndsAt!.day,
            23,
            59,
          );
    final rule = ReminderOptions.buildRule(
      start: due,
      repeat: _repeat,
      weekdays: _weekdays,
      customRule: _customRuleController.text,
      until: repeatEnds,
      count: _repeatCount,
    );
    final firstLead = _alerts
        .where((value) => value < 0)
        .fold<int?>(
          null,
          (value, item) => value == null || item < value ? item : value,
        );
    try {
      final reminder = await ref
          .read(reminderRepositoryProvider)
          .save(
            id: widget.reminderId,
            draft: ReminderDraft(
              title: _titleController.text,
              reminderType: _reminderType,
              leadDays: firstLead == null ? 0 : (-firstLead ~/ 1440),
              isEnabled: _enabled,
              dueDate: due,
              repeatRule: rule,
              priority: _priority,
              category: _category,
              remark: _remarkController.text,
              alertOffsetsMinutes: _alerts.toList(),
              nagRepeatIntervalMinutes: _nagEnabled
                  ? _nagIntervalHours * 60
                  : null,
              nagMaxRepeatCount: _nagEnabled ? _nagMaxCount : null,
              links: links,
            ),
          );
      await ref.read(reminderSchedulerProvider).reschedule(reminder.id);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage('保存失败：$error');
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除提醒？'),
        content: const Text('删除后不再出现在待办中，已完成历史会保留在本机数据库。'),
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
    if (confirmed != true || widget.reminderId == null) return;
    await ref.read(reminderRepositoryProvider).delete(widget.reminderId!);
    await ref.read(reminderSchedulerProvider).rescheduleAll();
    if (mounted) context.pop();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _dueDate,
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickRepeatEnd() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: _dueDate,
      lastDate: _dueDate.add(const Duration(days: 3650)),
      initialDate: _repeatEndsAt ?? _dueDate.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _repeatEndsAt = picked);
  }

  Future<void> _pickRepeatCount() async {
    final value = await showDialog<int>(
      context: context,
      builder: (context) => _NumberInputDialog(
        title: '重复次数',
        hintText: '留空表示不限次数',
        initialValue: _repeatCount?.toString(),
        confirmLabel: '确定',
      ),
    );
    if (value != null && mounted) setState(() => _repeatCount = value);
  }

  Future<void> _pickEmployees(List<Employee> employees) async {
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (context) => _EmployeePickerDialog(
        employees: employees,
        selectedIds: _selectedEmployeeIds,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedEmployeeIds
          ..clear()
          ..addAll(result);
      });
    }
  }

  void _toggleAlert(int minutes, bool selected) {
    setState(() {
      if (selected) {
        _alerts.add(minutes);
      } else if (_alerts.length > 1) {
        _alerts.remove(minutes);
      }
    });
  }

  void _showCustomAlertInput() {
    setState(() {
      _customAlertInputVisible = true;
      _customAlertError = null;
      _customAlertController.clear();
    });
  }

  void _cancelCustomAlert() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _customAlertInputVisible = false;
      _customAlertError = null;
      _customAlertController.clear();
    });
  }

  void _submitCustomAlert() {
    final value = _customAlertController.text.trim();
    final days = int.tryParse(value);
    if (days == null || days < 0 || days > 365) {
      setState(
        () =>
            _customAlertError = value.isEmpty ? '请输入提前天数' : '请输入 0–365 之间的整数天数',
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _alerts.add(-days * 1440);
      _customAlertInputVisible = false;
      _customAlertError = null;
      _customAlertController.clear();
    });
  }

  void _removeCustomAlert(int minutes) {
    setState(() => _alerts.remove(minutes));
  }

  void _applyTemplate(ReminderTemplate template) {
    setState(() {
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = template.title;
      }
      _category = template.category;
      _reminderType = template.type;
      if (template.repeat != 'none') _repeat = template.repeat;
      if (template.title == '每月福利领取') {
        _alerts
          ..clear()
          ..addAll({-4320, -1440, 0});
      }
      _advancedExpanded = true;
    });
  }

  Set<int> _parseWeekdays(String rule) {
    const map = {
      'MO': DateTime.monday,
      'TU': DateTime.tuesday,
      'WE': DateTime.wednesday,
      'TH': DateTime.thursday,
      'FR': DateTime.friday,
      'SA': DateTime.saturday,
      'SU': DateTime.sunday,
    };
    final match = RegExp(r'BYDAY=([^;]+)').firstMatch(rule);
    final result = {
      for (final day in match?.group(1)?.split(',') ?? const <String>[])
        if (map[day] != null) map[day]!,
    };
    return result.isEmpty ? {DateTime.monday} : result;
  }

  String _weekdayLabel(int day) =>
      const {
        DateTime.monday: '一',
        DateTime.tuesday: '二',
        DateTime.wednesday: '三',
        DateTime.thursday: '四',
        DateTime.friday: '五',
        DateTime.saturday: '六',
        DateTime.sunday: '日',
      }[day] ??
      '';

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.date,
    required this.time,
    required this.onDate,
    required this.onTime,
  });
  final DateTime date;
  final TimeOfDay time;
  final VoidCallback onDate;
  final VoidCallback onTime;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text('${date.year}/${date.month}/${date.day}'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onTime,
            icon: const Icon(Icons.schedule_outlined),
            label: Text(time.format(context)),
          ),
        ),
      ],
    );
  }
}

class _AlertSelector extends StatelessWidget {
  const _AlertSelector({
    required this.alerts,
    required this.onChanged,
    required this.onCustom,
    required this.onCustomSubmit,
    required this.onCustomCancel,
    required this.onCustomRemoved,
    required this.customInputVisible,
    required this.customController,
    required this.customError,
  });
  final Set<int> alerts;
  final void Function(int minutes, bool selected) onChanged;
  final VoidCallback onCustom;
  final VoidCallback onCustomSubmit;
  final VoidCallback onCustomCancel;
  final ValueChanged<int> onCustomRemoved;
  final bool customInputVisible;
  final TextEditingController customController;
  final String? customError;

  static const _presetMinutes = {0, -1440, -4320, -10080};

  @override
  Widget build(BuildContext context) {
    final customAlerts =
        alerts.where((minutes) => !_presetMinutes.contains(minutes)).toList()
          ..sort((a, b) => a.compareTo(b));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('提前提醒（可多选）', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 6,
          children: [
            for (final minutes in [0, -1440, -4320, -10080])
              FilterChip(
                label: Text(ReminderOptions.alertLabel(minutes)),
                selected: alerts.contains(minutes),
                onSelected: (value) => onChanged(minutes, value),
              ),
            ActionChip(
              avatar: Icon(
                customInputVisible ? Icons.close : Icons.add,
                size: 17,
              ),
              label: Text(customInputVisible ? '收起自定义' : '自定义'),
              onPressed: customInputVisible ? onCustomCancel : onCustom,
            ),
          ],
        ),
        if (customAlerts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              for (final minutes in customAlerts)
                InputChip(
                  avatar: const Icon(Icons.edit_calendar_outlined, size: 16),
                  label: Text(ReminderOptions.alertLabel(minutes)),
                  onDeleted: () => onCustomRemoved(minutes),
                ),
            ],
          ),
        ],
        if (customInputVisible) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.techBlue.withValues(alpha: 0.24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '填写自定义提前时间',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: customController,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => onCustomSubmit(),
                        decoration: InputDecoration(
                          labelText: '提前天数',
                          hintText: '例如 2',
                          suffixText: '天',
                          errorText: customError,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: onCustomSubmit,
                      child: const Text('添加'),
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      tooltip: '取消自定义提醒',
                      onPressed: onCustomCancel,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '输入 0 表示到期时提醒，最多可提前 365 天。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TemplateStrip extends StatelessWidget {
  const _TemplateStrip({required this.onSelected});
  final ValueChanged<ReminderTemplate> onSelected;
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.lightBlue,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '快捷模板',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final template in ReminderOptions.templates)
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ActionChip(
                        label: Text(template.title),
                        onPressed: () => onSelected(template),
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

class _NumberInputDialog extends StatefulWidget {
  const _NumberInputDialog({
    required this.title,
    required this.hintText,
    required this.confirmLabel,
    this.initialValue,
  });

  final String title;
  final String hintText;
  final String confirmLabel;
  final String? initialValue;

  @override
  State<_NumberInputDialog> createState() => _NumberInputDialogState();
}

class _NumberInputDialogState extends State<_NumberInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final value = int.tryParse(text);
    if (value == null || value < 1 || value > 9999) {
      setState(() => _error = '请输入 1–9999 之间的整数');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(hintText: widget.hintText, errorText: _error),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
    ],
  );
}

class _EmployeeSelector extends StatelessWidget {
  const _EmployeeSelector({
    required this.employees,
    required this.selectedIds,
    required this.onTap,
  });
  final List<Employee> employees;
  final Set<int> selectedIds;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final selected = employees
        .where((item) => selectedIds.contains(item.id))
        .toList();
    return Card(
      color: AppColors.background,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        leading: const CircleAvatar(
          backgroundColor: AppColors.lightGreen,
          child: Icon(Icons.people_outline, color: AppColors.primary),
        ),
        title: const Text('关联人员'),
        subtitle: Text(
          selected.isEmpty
              ? '可选择一个或多个人员'
              : selected.map((item) => item.name).join('、'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _EmployeePickerDialog extends StatefulWidget {
  const _EmployeePickerDialog({
    required this.employees,
    required this.selectedIds,
  });
  final List<Employee> employees;
  final Set<int> selectedIds;
  @override
  State<_EmployeePickerDialog> createState() => _EmployeePickerDialogState();
}

class _EmployeePickerDialogState extends State<_EmployeePickerDialog> {
  late final Set<int> _selected = {...widget.selectedIds};
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employees = widget.employees
        .where(
          (employee) =>
              _search.isEmpty ||
              employee.name.contains(_search) ||
              employee.employeeNo.contains(_search),
        )
        .toList();
    return AlertDialog(
      title: const Text('选择关联人员'),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索姓名或编号',
              ),
              onChanged: (value) => setState(() => _search = value.trim()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: employees.isEmpty
                  ? const Center(child: Text('没有匹配的人员'))
                  : ListView.builder(
                      itemCount: employees.length,
                      itemBuilder: (context, index) {
                        final employee = employees[index];
                        return CheckboxListTile(
                          value: _selected.contains(employee.id),
                          onChanged: (value) => setState(() {
                            if (value == true) {
                              _selected.add(employee.id);
                            } else {
                              _selected.remove(employee.id);
                            }
                          }),
                          title: Text(employee.name),
                          subtitle: Text(
                            '${employee.employeeNo} · ${_employeeStatusLabel(employee.status)}',
                          ),
                          secondary: Icon(
                            employee.status == EmployeeStatus.active
                                ? Icons.person_outline
                                : Icons.person_off_outlined,
                            color: employee.status == EmployeeStatus.active
                                ? AppColors.primary
                                : AppColors.helper,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text('确定（${_selected.length}）'),
        ),
      ],
    );
  }
}

String _employeeStatusLabel(EmployeeStatus status) => switch (status) {
  EmployeeStatus.active => '在岗',
  EmployeeStatus.paused => '暂停',
  EmployeeStatus.terminated => '离职',
};
