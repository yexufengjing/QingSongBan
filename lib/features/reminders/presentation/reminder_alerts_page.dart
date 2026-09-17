import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../domain/reminder_schedule.dart';

class ReminderAlertsPage extends StatefulWidget {
  const ReminderAlertsPage({super.key, required this.initialMinutes});

  final List<int> initialMinutes;

  @override
  State<ReminderAlertsPage> createState() => _ReminderAlertsPageState();
}

class _ReminderAlertsPageState extends State<ReminderAlertsPage> {
  static const _presets = <int>[0, 5, 15, 30, 60, 120, 1440, 2880, 10080];
  late final Set<int> _selected = widget.initialMinutes.toSet();

  @override
  Widget build(BuildContext context) {
    final custom =
        _selected.where((value) => !_presets.contains(value)).toList()..sort();
    return Scaffold(
      appBar: AppBar(
        title: const Text('提醒'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected.toList()..sort()),
            child: const Text('完成'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          children: [
            Text(
              '可设置多个提醒',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  for (final minutes in _presets)
                    CheckboxListTile(
                      key: Key('reminder-alert-$minutes'),
                      title: Text(ReminderSchedule.alertMinuteLabel(minutes)),
                      value: _selected.contains(minutes),
                      controlAffinity: ListTileControlAffinity.trailing,
                      onChanged: (_) => _toggle(minutes),
                    ),
                ],
              ),
            ),
            if (custom.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    for (final minutes in custom)
                      CheckboxListTile(
                        title: Text(ReminderSchedule.alertMinuteLabel(minutes)),
                        value: true,
                        controlAffinity: ListTileControlAffinity.trailing,
                        onChanged: (_) => _toggle(minutes),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                key: const Key('reminder-alert-custom'),
                title: const Text('添加自定义'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _addCustom,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(int minutes) {
    setState(() {
      _selected.contains(minutes)
          ? _selected.remove(minutes)
          : _selected.add(minutes);
    });
  }

  Future<void> _addCustom() async {
    var amount = 1;
    var unitIndex = 0;
    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: 330,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      const Expanded(
                        child: Text(
                          '自定义提前时间',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          const multipliers = [1, 60, 1440, 10080];
                          Navigator.pop(
                            context,
                            amount * multipliers[unitIndex],
                          );
                        },
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          itemExtent: 48,
                          scrollController: FixedExtentScrollController(
                            initialItem: amount - 1,
                          ),
                          onSelectedItemChanged: (index) =>
                              setSheetState(() => amount = index + 1),
                          children: [
                            for (var value = 1; value <= 60; value++)
                              Center(child: Text('$value')),
                          ],
                        ),
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          itemExtent: 48,
                          onSelectedItemChanged: (index) =>
                              setSheetState(() => unitIndex = index),
                          children: const [
                            Center(child: Text('分钟')),
                            Center(child: Text('小时')),
                            Center(child: Text('天')),
                            Center(child: Text('周')),
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
    if (result != null && mounted) setState(() => _selected.add(result));
  }
}
