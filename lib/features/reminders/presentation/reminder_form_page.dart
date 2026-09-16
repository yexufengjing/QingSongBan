import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../application/reminder_providers.dart';
import '../domain/reminder_options.dart';

class ReminderFormPage extends ConsumerStatefulWidget {
  const ReminderFormPage({super.key});

  @override
  ConsumerState<ReminderFormPage> createState() => _ReminderFormPageState();
}

class _ReminderFormPageState extends ConsumerState<ReminderFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _remarkController = TextEditingController();
  DateTime? _dueDate;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  int _leadDays = 0;
  bool _enabled = true;
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
      appBar: AppBar(title: const Text('新建提醒')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            Card(
              color: AppColors.lightBlue,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: AppColors.techBlue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '先写要做什么，再选择提醒时间。保存后会在通知栏提醒你。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text('要做什么', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('reminder-title-field'),
              controller: _titleController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '事项标题',
                hintText: '例如：提交月度报表',
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入事项标题' : null,
            ),
            const SizedBox(height: 22),
            Text('什么时候提醒', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  key: const Key('reminder-date-today'),
                  label: const Text('今天'),
                  onPressed: () => _setQuickDate(0),
                ),
                ActionChip(
                  key: const Key('reminder-date-tomorrow'),
                  label: const Text('明天'),
                  onPressed: () => _setQuickDate(1),
                ),
                ActionChip(
                  key: const Key('reminder-date-next-week'),
                  label: const Text('一周后'),
                  onPressed: () => _setQuickDate(7),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    key: const Key('reminder-date-field'),
                    title: const Text('日期'),
                    subtitle: Text(
                      _dueDate == null ? '请选择提醒日期' : _formatDate(_dueDate!),
                    ),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: _pickDate,
                  ),
                  const Divider(),
                  ListTile(
                    key: const Key('reminder-time-field'),
                    title: const Text('时间'),
                    subtitle: Text(_time.format(context)),
                    trailing: const Icon(Icons.schedule_outlined),
                    onTap: _pickTime,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              key: const Key('reminder-lead-field'),
              initialValue: _leadDays,
              decoration: const InputDecoration(
                labelText: '提前提醒',
                helperText: '如果提前时间已经过去，将在事项到期时提醒。',
              ),
              items: [
                for (final days in [0, 1, 3, 7])
                  DropdownMenuItem(
                    value: days,
                    child: Text(ReminderOptions.leadLabel(days)),
                  ),
              ],
              onChanged: (value) => setState(() => _leadDays = value ?? 0),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('通知栏提醒'),
              subtitle: const Text('关闭后事项仍会保存，但手机不会弹出通知。'),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            const SizedBox(height: 14),
            Text('补充说明（选填）', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            TextFormField(
              controller: _remarkController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '记录地点、联系人或需要准备的材料',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('reminder-save-button'),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? '保存中…' : '保存提醒'),
            ),
          ],
        ),
      ),
    );
  }

  void _setQuickDate(int daysFromToday) {
    final date = DateTime.now().add(Duration(days: daysFromToday));
    setState(() => _dueDate = DateTime(date.year, date.month, date.day));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _dueDate ?? DateTime.now(),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dueDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择提醒日期')));
      return;
    }
    final dueDate = DateTime(
      _dueDate!.year,
      _dueDate!.month,
      _dueDate!.day,
      _time.hour,
      _time.minute,
    );
    if (!dueDate.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('提醒时间必须晚于当前时间')));
      return;
    }
    setState(() => _saving = true);
    try {
      final reminder = await ref
          .read(reminderRepositoryProvider)
          .save(
            draft: ReminderDraft(
              title: _titleController.text,
              reminderType: 'custom',
              dueDate: dueDate,
              leadDays: _leadDays,
              isEnabled: _enabled,
              remark: _remarkController.text,
            ),
          );
      final notificationService = ref.read(notificationServiceProvider);
      if (_enabled) await notificationService.requestPermission();
      await notificationService.sync(reminder);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    }
  }
}

String _formatDate(DateTime date) {
  return '${date.year}年${date.month}月${date.day}日';
}
