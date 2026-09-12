import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../application/reminder_providers.dart';
import '../domain/reminder_options.dart';

class ReminderPage extends ConsumerWidget {
  const ReminderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('本地提醒')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('reminder-add-button'),
        onPressed: () => context.push('/settings/reminders/new'),
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('新建提醒'),
      ),
      body: reminders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('提醒加载失败：$error')),
        data: (items) {
          final settings = <String, Reminder>{
            for (final item in items)
              if (item.reminderType != 'custom') item.reminderType: item,
          };
          final customItems = items
              .where((item) => item.reminderType == 'custom')
              .toList();
          final systemItems = items
              .where(
                (item) =>
                    item.reminderType != 'custom' &&
                    !ReminderOptions.types.contains(item.reminderType),
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
            children: [
              Card(
                color: AppColors.lightBlue,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '提醒保存在本机。业务开关用于记录提醒偏好；自定义提醒可设置日期和提前天数，系统会通过 Android 通知栏提示。',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('业务提醒开关', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final type in ReminderOptions.types.where(
                (type) => type != 'custom',
              ))
                _SettingTile(
                  type: type,
                  reminder: settings[type],
                  onChanged: (enabled, leadDays) async {
                    try {
                      final reminder = await ref
                          .read(reminderRepositoryProvider)
                          .saveSetting(
                            reminderType: type,
                            title: ReminderOptions.typeLabel(type),
                            isEnabled: enabled,
                            leadDays: leadDays,
                          );
                      await ref
                          .read(notificationServiceProvider)
                          .sync(reminder);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('保存提醒设置失败：$error')),
                        );
                      }
                    }
                  },
                ),
              const SizedBox(height: 16),
              Text('自定义提醒', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (customItems.isEmpty)
                const _ReminderEmpty(message: '暂无自定义提醒，点击右下角新建。')
              else
                for (final reminder in customItems) ...[
                  _CustomReminderTile(reminder: reminder, ref: ref),
                  const SizedBox(height: 10),
                ],
              if (systemItems.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('待处理系统提醒', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final reminder in systemItems) ...[
                  _CustomReminderTile(reminder: reminder, ref: ref),
                  const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('reminder-test-button'),
                onPressed: () async {
                  try {
                    await ref
                        .read(notificationServiceProvider)
                        .showTestNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已发送测试通知，请查看模拟器通知栏')),
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('通知不可用：$error')));
                    }
                  }
                },
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('发送测试通知'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.type,
    required this.reminder,
    required this.onChanged,
  });

  final String type;
  final Reminder? reminder;
  final Future<void> Function(bool enabled, int leadDays) onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = reminder?.isEnabled ?? false;
    final leadDays = reminder?.leadDays ?? 0;
    return Card(
      child: ListTile(
        title: Text(ReminderOptions.typeLabel(type)),
        subtitle: Text(ReminderOptions.leadLabel(leadDays)),
        leading: Icon(
          enabled
              ? Icons.notifications_active_outlined
              : Icons.notifications_none,
          color: enabled ? AppColors.primary : AppColors.helper,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<int>(
              key: Key('reminder-lead-$type'),
              onSelected: (days) => onChanged(enabled, days),
              itemBuilder: (context) => [
                for (final days in [0, 1, 3, 7])
                  PopupMenuItem(
                    value: days,
                    child: Text(ReminderOptions.leadLabel(days)),
                  ),
              ],
            ),
            Switch(
              key: Key('reminder-switch-$type'),
              value: enabled,
              onChanged: (value) => onChanged(value, leadDays),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomReminderTile extends StatelessWidget {
  const _CustomReminderTile({required this.reminder, required this.ref});

  final Reminder reminder;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final due = reminder.dueDate;
    final dueText = due == null
        ? '未设置日期'
        : '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')} ${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}';
    return Card(
      child: ListTile(
        leading: Icon(
          reminder.isCompleted ? Icons.task_alt : Icons.alarm_outlined,
          color: reminder.isCompleted ? AppColors.primary : AppColors.techBlue,
        ),
        title: Text(reminder.title),
        subtitle: Text(
          '$dueText · ${ReminderOptions.leadLabel(reminder.leadDays)}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            if (action == 'complete') {
              await ref.read(reminderRepositoryProvider).complete(reminder.id);
              await ref.read(notificationServiceProvider).cancel(reminder.id);
            } else {
              await ref.read(reminderRepositoryProvider).delete(reminder.id);
              await ref.read(notificationServiceProvider).cancel(reminder.id);
            }
          },
          itemBuilder: (context) => [
            if (!reminder.isCompleted)
              const PopupMenuItem(value: 'complete', child: Text('标记完成')),
            const PopupMenuItem(value: 'delete', child: Text('删除提醒')),
          ],
        ),
      ),
    );
  }
}

class _ReminderEmpty extends StatelessWidget {
  const _ReminderEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.background,
      child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
    );
  }
}
