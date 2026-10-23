import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

typedef CalendarEditorSave = Future<void> Function(
  DateTime date,
  String content, {
  TimeOfDay? time,
  bool? isAllDay,
  String? remark,
});

class CalendarEditorPage extends StatefulWidget {
  const CalendarEditorPage({
    super.key,
    required this.isEntry,
    required this.initialDate,
    required this.initialContent,
    required this.initialRemark,
    required this.initialTime,
    required this.isAllDay,
    required this.onSave,
  });

  final bool isEntry;
  final DateTime initialDate;
  final String initialContent;
  final String initialRemark;
  final TimeOfDay? initialTime;
  final bool isAllDay;
  final CalendarEditorSave onSave;

  @override
  State<CalendarEditorPage> createState() => _CalendarEditorPageState();
}

class _CalendarEditorPageState extends State<CalendarEditorPage> {
  late final _contentController = TextEditingController(
    text: widget.initialContent,
  );
  late final _remarkController = TextEditingController(
    text: widget.initialRemark,
  );
  late DateTime _date = _dateOnly(widget.initialDate);
  late TimeOfDay? _time = widget.initialTime;
  late bool _isAllDay = widget.isAllDay;
  bool _saving = false;
  bool _allowPop = false;
  String? _contentError;
  String? _saveError;

  @override
  void dispose() {
    _contentController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _contentController.text != widget.initialContent ||
      _remarkController.text != widget.initialRemark ||
      !_sameDate(_date, widget.initialDate) ||
      _time != widget.initialTime ||
      _isAllDay != widget.isAllDay;

  Future<bool> _confirmClose() async {
    if (_saving || !_dirty) return !_saving;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('放弃未保存的更改？'),
            content: const Text('当前内容尚未保存。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('继续编辑'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('放弃更改'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _close() async {
    if (await _confirmClose() && mounted) {
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (date != null && mounted) setState(() => _date = _dateOnly(date));
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: '选择时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (time != null && mounted) setState(() => _time = time);
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() => _contentError = widget.isEntry ? '请输入记录内容' : '请输入待办标题');
      return;
    }
    if (!widget.isEntry && !_isAllDay && _time == null) {
      setState(() => _contentError = '请选择时间，或开启全天');
      return;
    }
    setState(() {
      _contentError = null;
      _saveError = null;
      _saving = true;
    });
    try {
      await widget.onSave(
        _date,
        content,
        time: _isAllDay ? null : _time,
        isAllDay: _isAllDay,
        remark: _remarkController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _saving = false;
          _allowPop = true;
        });
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = '保存失败，请检查内容后重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_dirty && !_saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '关闭',
          onPressed: _saving ? null : _close,
          icon: const Icon(Icons.close),
        ),
        title: Text(
          widget.isEntry
              ? (widget.initialContent.isEmpty ? '写日记录' : '编辑日记录')
              : (widget.initialContent.isEmpty ? '新建待办' : '编辑待办'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Text(
            widget.isEntry ? '记录内容' : '待办标题',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          TextField(
            key: Key(
              widget.isEntry ? 'calendar-entry-content' : 'calendar-todo-title',
            ),
            controller: _contentController,
            autofocus: true,
            minLines: widget.isEntry ? 5 : 1,
            maxLines: widget.isEntry ? 12 : 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_contentError != null) setState(() => _contentError = null);
            },
            decoration: InputDecoration(
              hintText: widget.isEntry ? '写下这一天想记住的内容' : '要做什么？',
              errorText: _contentError,
              alignLabelWithHint: widget.isEntry,
            ),
          ),
          if (_saveError != null) ...[
            const SizedBox(height: 8),
            Text(
              _saveError!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 20),
          Text('日期', style: Theme.of(context).textTheme.bodyLarge),
          ListTile(
            key: const Key('calendar-editor-date'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text('${_date.year}年${_date.month}月${_date.day}日'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickDate,
          ),
          if (!widget.isEntry) ...[
            SwitchListTile(
              key: const Key('calendar-editor-all-day'),
              contentPadding: EdgeInsets.zero,
              title: const Text('全天'),
              value: _isAllDay,
              onChanged: (value) => setState(() => _isAllDay = value),
            ),
            if (!_isAllDay)
              ListTile(
                key: const Key('calendar-editor-time'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: Text(_time == null ? '不指定时间' : _time!.format(context)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickTime,
                onLongPress: () => setState(() => _time = null),
              ),
            const Text(
              '日历新建事项只保存计划时间；需要系统提醒时，可在备忘提醒中设置。',
              style: TextStyle(color: AppColors.body, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text('备注（选填）', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            TextField(
              key: const Key('calendar-editor-remark'),
              controller: _remarkController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(hintText: '补充说明'),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          key: const Key('calendar-editor-save'),
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(_saving ? '保存中…' : '保存'),
        ),
      ),
    ),
  );
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
