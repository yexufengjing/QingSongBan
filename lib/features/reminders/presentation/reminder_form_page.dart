import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../application/reminder_providers.dart';
import '../domain/reminder_options.dart';
import '../domain/reminder_schedule.dart';
import 'reminder_schedule_page.dart';

class ReminderFormPage extends ConsumerStatefulWidget {
  const ReminderFormPage({super.key});

  @override
  ConsumerState<ReminderFormPage> createState() => _ReminderFormPageState();
}

class _ReminderFormPageState extends ConsumerState<ReminderFormPage> {
  final _titleController = TextEditingController();
  final _remarkController = TextEditingController();
  late DateTime _dueDate = _defaultDueDate();
  ReminderSchedule _schedule = const ReminderSchedule();
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: _saving ? null : () => context.pop(),
          child: const Text('取消'),
        ),
        leadingWidth: 72,
        title: const Text('新建待办'),
        centerTitle: true,
        actions: [
          TextButton(
            key: const Key('reminder-save-button'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '完成'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.lightOrange,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('reminder-title-field'),
                  controller: _titleController,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 6,
                  style: Theme.of(context).textTheme.headlineMedium,
                  decoration: const InputDecoration(
                    hintText: '请输入要做的事情',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      key: const Key('reminder-custom-time'),
                      avatar: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(_scheduleChipLabel()),
                      onPressed: _editSchedule,
                    ),
                    const Chip(
                      avatar: Icon(Icons.flag_outlined, size: 18),
                      label: Text('普通'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('时间与提醒'),
                  subtitle: Text(
                    '${_fullDateLabel(_dueDate)} · ${_schedule.repeatLabel(_dueDate)} · ${_schedule.alertLabel}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _editSchedule,
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _remarkController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '补充说明（选填）',
                      hintText: '地点、联系人、车辆或需要准备的材料',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '点击时间卡片，可设置滚轮日期和时间、重复频率、多个提前提醒及响铃。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
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
      });
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入要做的事情')),
      );
      return;
    }
    if (!_dueDate.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('提醒时间必须晚于当前时间')),
      );
      return;
    }
    if (_schedule.alertMinutes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个提醒时间')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final reminder = await ref.read(reminderRepositoryProvider).save(
        draft: ReminderDraft(
          title: title,
          reminderType: 'custom',
          dueDate: _dueDate,
          leadDays: 0,
          repeatRule: _schedule.encode(),
          isEnabled: true,
          remark: _remarkController.text,
        ),
      );
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.requestPermission();
      await notificationService.sync(reminder);
      if (mounted) context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    }
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

DateTime _defaultDueDate() {
  final value = DateTime.now().add(const Duration(hours: 1));
  return DateTime(value.year, value.month, value.day, value.hour, 0);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _fullDateLabel(DateTime value) =>
    '${value.year}年${value.month}月${value.day}日 '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
