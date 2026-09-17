import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/database/app_database.dart';
import '../domain/reminder_schedule.dart';

class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  static const _occurrenceLimit = 12;
  static const _alertsPerOccurrence = 20;
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
    await cancel(reminder.id);
    if (!reminder.isEnabled || reminder.isCompleted || reminder.dueDate == null) {
      return;
    }

    final schedule = ReminderSchedule.decode(
      reminder.repeatRule,
      legacyLeadDays: reminder.leadDays,
    );
    final now = tz.TZDateTime.now(tz.local);
    final occurrences = schedule.upcoming(
      reminder.dueDate!,
      limit: _occurrenceLimit,
    );
    final alerts = schedule.alertMinutes.toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    for (var occurrenceIndex = 0;
        occurrenceIndex < occurrences.length;
        occurrenceIndex++) {
      final occurrence = occurrences[occurrenceIndex];
      final dueAt = tz.TZDateTime(
        tz.local,
        occurrence.year,
        occurrence.month,
        occurrence.day,
        occurrence.hour,
        occurrence.minute,
      );
      for (var alertIndex = 0;
          alertIndex < alerts.length && alertIndex < _alertsPerOccurrence;
          alertIndex++) {
        final scheduleAt = dueAt.subtract(Duration(minutes: alerts[alertIndex]));
        if (!scheduleAt.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          _notificationId(reminder.id, occurrenceIndex, alertIndex),
          reminder.title,
          reminder.remark?.trim().isNotEmpty == true
              ? reminder.remark!
              : _notificationBody(alerts[alertIndex], occurrenceIndex),
          scheduleAt,
          NotificationDetails(
            android: AndroidNotificationDetails(
              schedule.ringEnabled
                  ? 'qingsongban_reminders_ring'
                  : 'qingsongban_reminders_silent',
              schedule.ringEnabled ? '轻松办响铃提醒' : '轻松办静音提醒',
              channelDescription: '人员、考勤、车辆和工作计划提醒',
              importance: Importance.high,
              priority: Priority.high,
              playSound: schedule.ringEnabled,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: reminder.id.toString(),
        );
      }
    }
  }

  Future<void> cancel(int id) async {
    await initialize();
    await _plugin.cancel(id); // Cancel notifications created by older versions.
    await Future.wait([
      for (var occurrence = 0; occurrence < _occurrenceLimit; occurrence++)
        for (var alert = 0; alert < _alertsPerOccurrence; alert++)
          _plugin.cancel(_notificationId(id, occurrence, alert)),
    ]);
  }

  Future<void> showTestNotification() async {
    await requestPermission();
    await _plugin.show(
      2147483000,
      '轻松办提醒测试',
      '本地通知已开启',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'qingsongban_reminders_ring',
          '轻松办响铃提醒',
          channelDescription: '人员、考勤、车辆和工作计划提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  int _notificationId(int reminderId, int occurrence, int alert) =>
      (reminderId % 2000000) * 1000 + occurrence * _alertsPerOccurrence + alert;

  String _notificationBody(int minutes, int occurrenceIndex) {
    final prefix = occurrenceIndex == 0 ? '' : '重复事项 · ';
    return '$prefix${ReminderSchedule.alertMinuteLabel(minutes)}';
  }
}
