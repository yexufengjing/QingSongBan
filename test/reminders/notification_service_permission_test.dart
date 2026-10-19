import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/features/reminders/application/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  bool? permissionResult;
  var showCalls = 0;

  setUp(() {
    permissionResult = false;
    showCalls = 0;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    messenger.setMockMethodCallHandler(notificationChannel, (call) async {
      switch (call.method) {
        case 'initialize':
          return true;
        case 'requestNotificationsPermission':
          return permissionResult;
        case 'show':
          showCalls++;
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(notificationChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'does not show the test notification when permission is denied',
    () async {
      final service = NotificationService();

      await expectLater(
        service.showTestNotification(),
        throwsA(isA<NotificationPermissionDeniedException>()),
      );

      expect(showCalls, 0);
    },
  );

  test(
    'shows the test notification when permission result is unavailable',
    () async {
      permissionResult = null;
      final service = NotificationService();

      await service.showTestNotification();

      expect(showCalls, 1);
    },
  );
}
