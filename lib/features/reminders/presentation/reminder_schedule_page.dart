import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../domain/reminder_schedule.dart';
import 'reminder_alerts_page.dart';
import 'reminder_repeat_page.dart';

class ReminderScheduleResult {
  const ReminderScheduleResult({required this.dueDate, required this.schedule});

  final DateTime dueDate;
  final ReminderSchedule schedule;
}

class ReminderSchedulePage extends StatefulWidget {
  const ReminderSchedulePage({
    super.key,
    required this.initialDate,
    required this.initialSchedule,
  });

  final DateTime initialDate;
  final ReminderSchedule initialSchedule;

  @override
  State<ReminderSchedulePage> createState() => _ReminderSchedulePageState();
}

class _ReminderSchedulePageState extends State<ReminderSchedulePage> {
  late DateTime _date = widget.initialDate;
  late ReminderSchedule _schedule = widget.initialSchedule;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        leadingWidth: 72,
        title: const Text('自定义时间'),
        centerTitle: true,
        actions: [
          TextButton(
            key: const Key('reminder-schedule-done'),
            onPressed: () => Navigator.pop(
              context,
              ReminderScheduleResult(dueDate: _date, schedule: _schedule),
            ),
            child: const Text('完成'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('开始'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      _dateLabel(_date),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const Divider(),
                SizedBox(
                  height: 320,
                  child: Stack(
                    children: [
                      CalendarDatePicker(
                        key: ValueKey('${_date.year}-${_date.month}'),
                        initialDate: _date,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                        onDateChanged: (value) => setState(() => _date = DateTime(
                          value.year,
                          value.month,
                          value.day,
                          _date.hour,
                          _date.minute,
                        )),
                      ),
                      Positioned(
                        top: 3,
                        left: 88,
                        right: 88,
                        child: GestureDetector(
                          key: const Key('reminder-year-month-wheel'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _pickDateWheel,
                          child: Container(
                            height: 42,
                            alignment: Alignment.center,
                            color: Theme.of(context).colorScheme.surface,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_date.year}年${_date.month}月',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_drop_down, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                _OptionTile(
                  tileKey: const Key('reminder-schedule-time'),
                  title: '时间',
                  value: _timeLabel(_date),
                  onTap: _pickTime,
                ),
                const Divider(),
                _OptionTile(
                  tileKey: const Key('reminder-schedule-repeat'),
                  title: '重复',
                  value: _schedule.repeatLabel(_date),
                  onTap: _pickRepeat,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                _OptionTile(
                  tileKey: const Key('reminder-schedule-alerts'),
                  title: '提醒',
                  value: _schedule.alertLabel,
                  onTap: _pickAlerts,
                ),
                const Divider(),
                SwitchListTile(
                  key: const Key('reminder-ring-switch'),
                  title: const Text('响铃提醒'),
                  subtitle: const Text('关闭后仍显示通知，但不播放提示音'),
                  value: _schedule.ringEnabled,
                  onChanged: (value) => setState(
                    () => _schedule = _schedule.copyWith(ringEnabled: value),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateWheel() async {
    var year = _date.year;
    var month = _date.month;
    var day = _date.day;
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final maxDay = DateTime(year, month + 1, 0).day;
          if (day > maxDay) day = maxDay;
          return SafeArea(
            child: SizedBox(
              height: 340,
              child: Column(
                children: [
                  _PickerHeader(
                    title: '选择日期',
                    onCancel: () => Navigator.pop(context),
                    onConfirm: () => Navigator.pop(context, DateTime(year, month, day)),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoPicker(
                            itemExtent: 48,
                            scrollController: FixedExtentScrollController(initialItem: year - DateTime.now().year),
                            onSelectedItemChanged: (index) => setSheetState(() => year = DateTime.now().year + index),
                            children: [for (var value = DateTime.now().year; value <= DateTime.now().year + 10; value++) Center(child: Text('$value年'))],
                          ),
                        ),
                        Expanded(
                          child: CupertinoPicker(
                            itemExtent: 48,
                            scrollController: FixedExtentScrollController(initialItem: month - 1),
                            onSelectedItemChanged: (index) => setSheetState(() => month = index + 1),
                            children: [for (var value = 1; value <= 12; value++) Center(child: Text('$value月'))],
                          ),
                        ),
                        Expanded(
                          child: CupertinoPicker(
                            key: ValueKey('$year-$month-$maxDay'),
                            itemExtent: 48,
                            scrollController: FixedExtentScrollController(initialItem: day - 1),
                            onSelectedItemChanged: (index) => setSheetState(() => day = index + 1),
                            children: [for (var value = 1; value <= maxDay; value++) Center(child: Text('$value日'))],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (result != null && mounted) {
      setState(() => _date = DateTime(result.year, result.month, result.day, _date.hour, _date.minute));
    }
  }

  Future<void> _pickTime() async {
    var hour = _date.hour;
    var minute = _date.minute;
    final result = await showModalBottomSheet<TimeOfDay>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 340,
          child: Column(
            children: [
              _PickerHeader(
                title: '选择时间',
                onCancel: () => Navigator.pop(context),
                onConfirm: () => Navigator.pop(context, TimeOfDay(hour: hour, minute: minute)),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 48,
                        scrollController: FixedExtentScrollController(initialItem: hour),
                        onSelectedItemChanged: (index) => hour = index,
                        children: [for (var value = 0; value < 24; value++) Center(child: Text(value.toString().padLeft(2, '0')))],
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 48,
                        scrollController: FixedExtentScrollController(initialItem: minute),
                        onSelectedItemChanged: (index) => minute = index,
                        children: [for (var value = 0; value < 60; value++) Center(child: Text(value.toString().padLeft(2, '0')))],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _date = DateTime(_date.year, _date.month, _date.day, result.hour, result.minute));
    }
  }

  Future<void> _pickRepeat() async {
    final result = await Navigator.push<ReminderSchedule>(
      context,
      MaterialPageRoute(
        builder: (_) => ReminderRepeatPage(initial: _schedule, startDate: _date),
      ),
    );
    if (result != null && mounted) setState(() => _schedule = result);
  }

  Future<void> _pickAlerts() async {
    final result = await Navigator.push<List<int>>(
      context,
      MaterialPageRoute(
        builder: (_) => ReminderAlertsPage(initialMinutes: _schedule.alertMinutes),
      ),
    );
    if (result != null && mounted) {
      setState(() => _schedule = _schedule.copyWith(alertMinutes: result));
    }
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.tileKey,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final Key tileKey;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: tileKey,
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(value, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _PickerHeader extends StatelessWidget {
  const _PickerHeader({
    required this.title,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton(onPressed: onCancel, child: const Text('取消')),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(onPressed: onConfirm, child: const Text('确定')),
      ],
    );
  }
}

String _dateLabel(DateTime value) => '${value.year}年${value.month}月${value.day}日';

String _timeLabel(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
