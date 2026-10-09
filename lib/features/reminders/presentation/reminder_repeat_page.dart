import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../domain/reminder_schedule.dart';

class ReminderRepeatPage extends StatelessWidget {
  const ReminderRepeatPage({
    super.key,
    required this.initial,
    required this.startDate,
  });

  final ReminderSchedule initial;
  final DateTime startDate;

  @override
  Widget build(BuildContext context) {
    final options = <({String label, ReminderSchedule value})>[
      (label: '仅一次', value: initial.copyWith(clearRepeatUnit: true)),
      (label: '每天', value: _preset(ReminderRepeatUnit.day)),
      (label: '每周', value: _preset(ReminderRepeatUnit.week)),
      (
        label: '每两周',
        value: _preset(ReminderRepeatUnit.week).copyWith(interval: 2),
      ),
      (label: '每月', value: _preset(ReminderRepeatUnit.month)),
      (label: '每年', value: _preset(ReminderRepeatUnit.year)),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('重复')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            child: Column(
              children: [
                for (final option in options)
                  RadioListTile<String>(
                    title: Text(option.label),
                    value: option.label,
                    groupValue: _presetLabel(initial),
                    onChanged: (_) => Navigator.pop(context, option.value),
                  ),
                ListTile(
                  key: const Key('reminder-repeat-custom'),
                  title: const Text('自定义'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_presetLabel(initial) == null)
                        const Icon(Icons.radio_button_checked),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () async {
                    final result = await Navigator.push<ReminderSchedule>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomRepeatPage(
                          initial: initial.repeats
                              ? initial
                              : initial.copyWith(
                                  repeatUnit: ReminderRepeatUnit.week,
                                  weekdays: {startDate.weekday},
                                ),
                          startDate: startDate,
                        ),
                      ),
                    );
                    if (result != null && context.mounted) {
                      Navigator.pop(context, result);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ReminderSchedule _preset(ReminderRepeatUnit unit) => initial.copyWith(
    repeatUnit: unit,
    interval: 1,
    weekdays: unit == ReminderRepeatUnit.week ? {startDate.weekday} : {},
    monthDays: unit == ReminderRepeatUnit.month ? {startDate.day} : {},
    repeatEnd: ReminderRepeatEnd.never,
    clearEndDate: true,
    clearEndCount: true,
  );

  String? _presetLabel(ReminderSchedule value) {
    if (!value.repeats) return '仅一次';
    if (value.repeatEnd != ReminderRepeatEnd.never) return null;
    if (value.repeatUnit == ReminderRepeatUnit.day && value.interval == 1) {
      return '每天';
    }
    if (value.repeatUnit == ReminderRepeatUnit.week &&
        value.weekdays.difference({startDate.weekday}).isEmpty &&
        value.interval == 1) {
      return '每周';
    }
    if (value.repeatUnit == ReminderRepeatUnit.week &&
        value.weekdays.difference({startDate.weekday}).isEmpty &&
        value.interval == 2) {
      return '每两周';
    }
    if (value.repeatUnit == ReminderRepeatUnit.month &&
        value.monthDays.difference({startDate.day}).isEmpty &&
        value.interval == 1) {
      return '每月';
    }
    if (value.repeatUnit == ReminderRepeatUnit.year && value.interval == 1) {
      return '每年';
    }
    return null;
  }
}

class CustomRepeatPage extends StatefulWidget {
  const CustomRepeatPage({
    super.key,
    required this.initial,
    required this.startDate,
  });

  final ReminderSchedule initial;
  final DateTime startDate;

  @override
  State<CustomRepeatPage> createState() => _CustomRepeatPageState();
}

class _CustomRepeatPageState extends State<CustomRepeatPage> {
  late ReminderSchedule _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final compactWeekdayGrid =
        MediaQuery.sizeOf(context).width <= 320 &&
        MediaQuery.textScalerOf(context).scale(14) > 14;
    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        leadingWidth: 72,
        title: const Text('自定义重复'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _value),
            child: const Text('完成'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '重复频率',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      _SelectionRow(
                        key: const Key('reminder-repeat-frequency'),
                        value: _frequencyLabel(),
                        onTap: _pickFrequency,
                      ),
                      if (_value.repeatUnit == ReminderRepeatUnit.week) ...[
                        const SizedBox(height: 8),
                        Text(
                          _weekdaySummary(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                if (_value.repeatUnit == ReminderRepeatUnit.week) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('选择提醒星期'),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: compactWeekdayGrid ? 3 : 4,
                          mainAxisExtent: 56,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (var day = 1; day <= 7; day++)
                              _WeekdayButton(
                                label: '周${'一二三四五六日'[day - 1]}',
                                selected: _value.weekdays.contains(day),
                                onTap: () => _toggleWeekday(day),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (_value.repeatUnit == ReminderRepeatUnit.month) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('选择提醒日期（可多选）'),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 7,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (var day = 1; day <= 31; day++)
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _toggleMonthDay(day),
                                child: Container(
                                  margin: const EdgeInsets.all(3),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _value.monthDays.contains(day)
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                  child: Text(
                                    '$day',
                                    style: TextStyle(
                                      color: _value.monthDays.contains(day)
                                          ? Colors.white
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('结束重复', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  _SelectionRow(
                    key: const Key('reminder-repeat-end'),
                    value: _endLabel(),
                    onTap: _pickEnd,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFrequency() async {
    var interval = _value.interval;
    var unit = _value.repeatUnit ?? ReminderRepeatUnit.week;
    final result =
        await showModalBottomSheet<({int interval, ReminderRepeatUnit unit})>(
          context: context,
          showDragHandle: true,
          builder: (context) => StatefulBuilder(
            builder: (context, setSheetState) => SafeArea(
              child: SizedBox(
                height: 330,
                child: Column(
                  children: [
                    _SheetHeader(
                      title: '重复频率',
                      onCancel: () => Navigator.pop(context),
                      onConfirm: () => Navigator.pop(context, (
                        interval: interval,
                        unit: unit,
                      )),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoPicker(
                              itemExtent: 48,
                              scrollController: FixedExtentScrollController(
                                initialItem: interval - 1,
                              ),
                              onSelectedItemChanged: (index) =>
                                  setSheetState(() => interval = index + 1),
                              children: [
                                for (var value = 1; value <= 20; value++)
                                  Center(child: Text('$value')),
                              ],
                            ),
                          ),
                          Expanded(
                            child: CupertinoPicker(
                              itemExtent: 48,
                              scrollController: FixedExtentScrollController(
                                initialItem: unit.index,
                              ),
                              onSelectedItemChanged: (index) => setSheetState(
                                () => unit = ReminderRepeatUnit.values[index],
                              ),
                              children: const [
                                Center(child: Text('天')),
                                Center(child: Text('周')),
                                Center(child: Text('月')),
                                Center(child: Text('年')),
                              ],
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
        );
    if (result == null || !mounted) return;
    setState(() {
      _value = _value.copyWith(
        interval: result.interval,
        repeatUnit: result.unit,
        weekdays: result.unit == ReminderRepeatUnit.week
            ? (_value.weekdays.isEmpty
                  ? {widget.startDate.weekday}
                  : _value.weekdays)
            : {},
        monthDays: result.unit == ReminderRepeatUnit.month
            ? (_value.monthDays.isEmpty
                  ? {widget.startDate.day}
                  : _value.monthDays)
            : {},
      );
    });
  }

  Future<void> _pickEnd() async {
    final result = await showModalBottomSheet<ReminderRepeatEnd>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '结束重复',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            for (final end in ReminderRepeatEnd.values)
              RadioListTile<ReminderRepeatEnd>(
                title: Text(switch (end) {
                  ReminderRepeatEnd.never => '永不结束',
                  ReminderRepeatEnd.date => '按日期',
                  ReminderRepeatEnd.count => '按次数',
                }),
                value: end,
                groupValue: _value.repeatEnd,
                onChanged: (value) => Navigator.pop(context, value),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (result == ReminderRepeatEnd.date) {
      final date = await showDatePicker(
        context: context,
        initialDate:
            _value.endDate ?? widget.startDate.add(const Duration(days: 30)),
        firstDate: widget.startDate,
        lastDate: widget.startDate.add(const Duration(days: 3650)),
      );
      if (date != null && mounted) {
        setState(
          () => _value = _value.copyWith(
            repeatEnd: result,
            endDate: date,
            clearEndCount: true,
          ),
        );
      }
      return;
    }
    if (result == ReminderRepeatEnd.count) {
      final count = await _pickCount();
      if (count != null && mounted) {
        setState(
          () => _value = _value.copyWith(
            repeatEnd: result,
            endCount: count,
            clearEndDate: true,
          ),
        );
      }
      return;
    }
    setState(
      () => _value = _value.copyWith(
        repeatEnd: result,
        clearEndDate: true,
        clearEndCount: true,
      ),
    );
  }

  Future<int?> _pickCount() {
    var count = _value.endCount ?? 10;
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 300,
          child: Column(
            children: [
              _SheetHeader(
                title: '重复次数',
                onCancel: () => Navigator.pop(context),
                onConfirm: () => Navigator.pop(context, count),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 48,
                  scrollController: FixedExtentScrollController(
                    initialItem: count - 1,
                  ),
                  onSelectedItemChanged: (index) => count = index + 1,
                  children: [
                    for (var value = 1; value <= 100; value++)
                      Center(child: Text('$value 次')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleWeekday(int day) {
    final values = {..._value.weekdays};
    values.contains(day) ? values.remove(day) : values.add(day);
    if (values.isNotEmpty) {
      setState(() => _value = _value.copyWith(weekdays: values));
    }
  }

  String _frequencyLabel() {
    final unit = switch (_value.repeatUnit) {
      ReminderRepeatUnit.day => '天',
      ReminderRepeatUnit.week => '周',
      ReminderRepeatUnit.month => '月',
      ReminderRepeatUnit.year => '年',
      null => '周',
    };
    return '每${_value.interval}$unit';
  }

  String _weekdaySummary() {
    final days = _value.weekdays.toList()..sort();
    if (days.isEmpty) return '每周';
    return '每周${days.map((day) => '周${'一二三四五六日'[day - 1]}').join('、')}';
  }

  void _toggleMonthDay(int day) {
    final values = {..._value.monthDays};
    values.contains(day) ? values.remove(day) : values.add(day);
    if (values.isNotEmpty) {
      setState(() => _value = _value.copyWith(monthDays: values));
    }
  }

  String _endLabel() => switch (_value.repeatEnd) {
    ReminderRepeatEnd.never => '永不结束',
    ReminderRepeatEnd.date =>
      _value.endDate == null
          ? '按日期'
          : '${_value.endDate!.year}年${_value.endDate!.month}月${_value.endDate!.day}日',
    ReminderRepeatEnd.count => '重复 ${_value.endCount ?? 1} 次',
  };
}

class _SelectionRow extends StatelessWidget {
  const _SelectionRow({super.key, required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(child: Text(value)),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekdayButton extends StatelessWidget {
  const _WeekdayButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? color : Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: selected ? color : Theme.of(context).colorScheme.outline,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  const Icon(Icons.check, color: Colors.white, size: 18),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
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
