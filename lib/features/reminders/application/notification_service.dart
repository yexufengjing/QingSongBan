import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/database/app_database.dart';

class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    } catch (_) {
      // Keep the package default location if a platform timezone is unavailable.
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> requestPermission() async {
    await initialize();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> sync(Reminder reminder) async {
    await initialize();
    await _plugin.cancel(reminder.id);
    if (!reminder.isEnabled ||
        reminder.isCompleted ||
        reminder.dueDate == null) {
      return;
    }
    final due = reminder.dueDate!;
    final dueAt = tz.TZDateTime(
      tz.local,
      due.year,
      due.month,
      due.day,
      due.hour,
      due.minute,
    );
    final preferredScheduleAt = dueAt.subtract(
      Duration(days: reminder.leadDays),
    );
    final now = tz.TZDateTime.now(tz.local);
    final scheduleAt = preferredScheduleAt.isAfter(now)
        ? preferredScheduleAt
        : dueAt;
    if (!scheduleAt.isAfter(now)) return;
    await _plugin.zonedSchedule(
      reminder.id,
      reminder.title,
      reminder.remark ?? '轻松办提醒',
      scheduleAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'qingsongban_reminders',
          '轻松办提醒',
          channelDescription: '人员、考勤和保险业务提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: reminder.id.toString(),
    );
  }

  Future<void> cancel(int id) async {
    await initialize();
    await _plugin.cancel(id);
  }

  Future<void> showTestNotification() async {
    await requestPermission();
    await _plugin.show(
      2147483000,
      '轻松办提醒测试',
      '本地通知已开启',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'qingsongban_reminders',
          '轻松办提醒',
          channelDescription: '人员、考勤和保险业务提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
