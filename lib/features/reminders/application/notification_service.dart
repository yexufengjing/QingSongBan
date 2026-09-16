import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// The only class in the reminders feature that talks to the notification
/// plugin. Scheduling policy lives in ReminderScheduler.
class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  String _timezoneId = 'UTC';

  String get timezoneId => _timezoneId;

  Future<void> initialize({
    void Function(NotificationResponse response)? onResponse,
  }) async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      _timezoneId = zone.identifier;
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Tests, unsupported desktop targets, and devices with an incomplete
      // timezone database can still use the package's current location.
      _timezoneId = tz.local.name;
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: onResponse,
    );
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

  Future<bool?> areNotificationsEnabled() async {
    await initialize();
    return _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.areNotificationsEnabled();
  }

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime at,
    required String payload,
  }) async {
    await initialize();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      at,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<List<PendingNotificationRequest>> pendingRequests() async {
    await initialize();
    return _plugin.pendingNotificationRequests();
  }

  Future<NotificationResponse?> launchResponse() async {
    await initialize();
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      return details?.didNotificationLaunchApp == true
          ? details?.notificationResponse
          : null;
    } catch (_) {
      // Some desktop implementations do not expose launch details.
      return null;
    }
  }

  Future<void> cancel(int id) async {
    await initialize();
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  Future<void> showTestNotification() async {
    await requestPermission();
    await _plugin.show(2147483000, '轻松办提醒测试', '本地通知已开启', _details);
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'qingsongban_reminders',
      '轻松办提醒',
      channelDescription: '人员、考勤和业务计划提醒',
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction('complete', '完成'),
        AndroidNotificationAction('snooze', '稍后提醒'),
      ],
    ),
  );
}
