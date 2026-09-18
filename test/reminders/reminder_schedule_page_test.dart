import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/features/reminders/domain/reminder_schedule.dart';
import 'package:qingsongban/features/reminders/presentation/reminder_schedule_page.dart';

void main() {
  testWidgets('opens time, repeat, and multiple-alert configuration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReminderSchedulePage(
          initialDate: DateTime.now().add(const Duration(days: 2)),
          initialSchedule: const ReminderSchedule(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('自定义时间'), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsOneWidget);

    await tester.tap(find.byKey(const Key('reminder-schedule-time')));
    await tester.pumpAndSettle();
    expect(find.text('选择时间'), findsOneWidget);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();

    final repeatTile = find.byKey(const Key('reminder-schedule-repeat'));
    await tester.ensureVisible(repeatTile);
    await tester.tap(repeatTile);
    await tester.pumpAndSettle();
    expect(find.text('仅一次'), findsOneWidget);
    expect(find.text('每两周'), findsOneWidget);
    expect(find.byKey(const Key('reminder-repeat-custom')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final alertsTile = find.byKey(const Key('reminder-schedule-alerts'));
    await tester.ensureVisible(alertsTile);
    await tester.tap(alertsTile);
    await tester.pumpAndSettle();
    expect(find.text('可设置多个提醒'), findsOneWidget);
    expect(find.text('15 分钟前'), findsOneWidget);
    expect(find.byKey(const Key('reminder-alert-custom')), findsOneWidget);
  });
}
