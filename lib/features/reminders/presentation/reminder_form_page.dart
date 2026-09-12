import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(title: const Text('新建自定义提醒')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            TextFormField(
              key: const Key('reminder-title-field'),
              controller: _titleController,
              decoration: const InputDecoration(labelText: '提醒标题'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入提醒标题' : null,
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('提醒日期'),
              subtitle: Text(
                _dueDate == null
                    ? '请选择日期'
                    : '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('提醒时间'),
              subtitle: Text(_time.format(context)),
              trailing: const Icon(Icons.schedule_outlined),
              onTap: _pickTime,
            ),
            DropdownButtonFormField<int>(
              key: const Key('reminder-lead-field'),
              initialValue: _leadDays,
              decoration: const InputDecoration(labelText: '提前提醒'),
              items: [
                for (final days in [0, 1, 3, 7])
                  DropdownMenuItem(
                    value: days,
                    child: Text(ReminderOptions.leadLabel(days)),
                  ),
              ],
              onChanged: (value) => setState(() => _leadDays = value ?? 0),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用提醒'),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            TextFormField(
              controller: _remarkController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '备注'),
            ),
            const SizedBox(height: 22),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请选择提醒日期')));
      return;
    }
    setState(() => _saving = true);
    final dueDate = DateTime(
      _dueDate!.year,
      _dueDate!.month,
      _dueDate!.day,
      _time.hour,
      _time.minute,
    );
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
      await ref.read(notificationServiceProvider).sync(reminder);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    }
  }
}
