import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../application/reminder_providers.dart';

class ReminderSettingsPage extends ConsumerStatefulWidget {
  const ReminderSettingsPage({super.key});

  @override
  ConsumerState<ReminderSettingsPage> createState() =>
      _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends ConsumerState<ReminderSettingsPage> {
  bool _requesting = false;
  Future<bool?>? _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _loadStatus();
  }

  Future<bool?> _loadStatus() async {
    try {
      return await ref
          .read(reminderSchedulerProvider)
          .notifications
          .areNotificationsEnabled();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('提醒设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: AppColors.lightOrange,
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: Color(0xFFE98500),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text('备忘提醒保存在本机。系统通知关闭时，事项仍会保留在 App 内，但不会弹出通知。'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('通知权限', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 5),
                  FutureBuilder<bool?>(
                    future: _statusFuture,
                    builder: (context, snapshot) {
                      final enabled = snapshot.data;
                      final label = enabled == true
                          ? '系统通知已开启'
                          : enabled == false
                          ? '系统通知已关闭'
                          : '暂时无法读取系统状态';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          enabled == true
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          color: enabled == true
                              ? AppColors.primary
                              : AppColors.helper,
                        ),
                        title: Text(label),
                        subtitle: const Text('Android 13 及以上需要允许通知权限。'),
                        trailing: FilledButton.tonal(
                          onPressed: _requesting ? null : _requestPermission,
                          child: Text(_requesting ? '处理中…' : '允许通知'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.lightGreen,
                    child: Icon(
                      Icons.checklist_rtl_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text('本地提醒'),
                  subtitle: const Text('查看今天、逾期和未来事项'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/home/reminders'),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  key: const Key('reminder-add-button'),
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.lightBlue,
                    child: Icon(
                      Icons.add_alert_outlined,
                      color: AppColors.techBlue,
                    ),
                  ),
                  title: const Text('新建提醒'),
                  subtitle: const Text('临时事项、工作计划或定期事项'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/home/reminders/new'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            key: const Key('reminder-test-button'),
            onPressed: _sendTest,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('发送测试通知'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermission() async {
    setState(() => _requesting = true);
    try {
      await ref
          .read(reminderSchedulerProvider)
          .notifications
          .requestPermission();
      if (mounted) setState(() => _statusFuture = _loadStatus());
    } catch (error) {
      if (mounted) _showMessage('通知权限请求失败：$error');
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _sendTest() async {
    try {
      await ref
          .read(reminderSchedulerProvider)
          .notifications
          .showTestNotification();
      if (mounted) _showMessage('已发送测试通知，请查看系统通知栏。');
    } catch (error) {
      if (mounted) _showMessage('通知不可用：$error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
