import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/calendar/presentation/calendar_page.dart';
import 'package:qingsongban/features/reminders/application/notification_service.dart';
import 'package:qingsongban/features/reminders/application/reminder_providers.dart';

class _QuietNotificationService extends NotificationService {
  @override
  Future<void> sync(
    Reminder reminder, {
    Iterable<DateTime>? pendingOccurrences,
  }) async {}

  @override
  Future<void> cancel(int id) async {}
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.idle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creates, completes, edits, and deletes calendar items', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    final database = AppDatabase.forTesting();
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await database.close();
    });

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            notificationServiceProvider.overrideWithValue(
              _QuietNotificationService(),
            ),
          ],
          child: const MaterialApp(home: CalendarPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('calendar-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('待办事项'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('calendar-editor-save')));
      await tester.pumpAndSettle();
      expect(find.text('请输入待办标题'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('calendar-todo-title')),
        '整理工具',
      );
      await tester.enterText(
        find.byKey(const Key('calendar-editor-remark')),
        '带上手套',
      );
      await tester.tap(find.byKey(const Key('calendar-editor-save')));
      await tester.pumpAndSettle();
      expect(find.text('整理工具'), findsOneWidget);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('已完成 1 项'), findsOneWidget);
      await tester.tap(find.byKey(const Key('calendar-completed-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('整理工具'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('calendar-editor-remark')))
            .controller
            ?.text,
        '带上手套',
      );
      await tester.enterText(
        find.byKey(const Key('calendar-todo-title')),
        '整理维修工具',
      );
      await tester.tap(find.byKey(const Key('calendar-editor-save')));
      await tester.pumpAndSettle();
      expect(find.text('整理维修工具'), findsOneWidget);
      await tester.tap(find.byTooltip('更多操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      expect(find.text('整理维修工具'), findsNothing);

      await tester.tap(find.byKey(const Key('calendar-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('日记录').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('calendar-entry-content')),
        '完成了工具盘点',
      );
      await tester.tap(find.byKey(const Key('calendar-editor-save')));
      await tester.pumpAndSettle();
      expect(find.text('完成了工具盘点'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await _unmount(tester);
    }
  });

  testWidgets('supports month selection on a narrow viewport with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1400);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    final database = AppDatabase.forTesting();
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await database.close();
    });

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: CalendarPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('calendar-month-picker')), findsOneWidget);
      await tester.tap(find.byTooltip('下个月'));
      await tester.pumpAndSettle();
      final nextMonth = DateTime(DateTime.now().year, DateTime.now().month + 1);
      expect(
        find.text('${nextMonth.year}年${nextMonth.month}月'),
        findsOneWidget,
      );
      final date = DateTime(nextMonth.year, nextMonth.month, 1);
      await tester.tap(
        find.byKey(Key('calendar-date-${date.year}-${date.month}-${date.day}')),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('calendar-selected-date')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final weekday = const [
        '星期一',
        '星期二',
        '星期三',
        '星期四',
        '星期五',
        '星期六',
        '星期日',
      ][date.weekday - 1];
      expect(
        find.text(
          '${date.year}年${date.month}月${date.day}日 · $weekday · 未完成 0 项',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await _unmount(tester);
    }
  });
}
