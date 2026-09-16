import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/features/reminders/domain/recurrence_service.dart';

void main() {
  const service = RecurrenceService();
  final createdAt = DateTime(2026, 1, 1);

  Reminder reminder(String rule, DateTime due) => Reminder(
    id: 1,
    title: '测试事项',
    reminderType: 'custom',
    priority: 'normal',
    category: 'general',
    dueDate: due,
    leadDays: 0,
    repeatRule: rule,
    repeatMode: 'fixedSchedule',
    isEnabled: true,
    isCompleted: false,
    createdAt: createdAt,
    updatedAt: createdAt,
    isDeleted: false,
  );

  test('generates weekly, quarterly and yearly occurrences through rrule', () {
    final weekly = service.generateOccurrences(
      reminder('RRULE:FREQ=WEEKLY;BYDAY=MO,TH', DateTime(2026, 9, 14, 10)),
      from: DateTime(2026, 9, 14),
      window: const Duration(days: 14),
      limit: 10,
    );
    expect(weekly.map((value) => value.day), [14, 17, 21, 24]);
    expect(weekly.toSet(), hasLength(4));

    final quarterly = service.generateOccurrences(
      reminder(
        'RRULE:FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=15',
        DateTime(2026, 1, 15, 9),
      ),
      from: DateTime(2026, 1, 1),
      window: const Duration(days: 400),
      limit: 10,
    );
    expect(quarterly.map((value) => value.month), [1, 4, 7, 10, 1]);

    final yearly = service.generateOccurrences(
      reminder(
        'RRULE:FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29',
        DateTime(2024, 2, 29, 9),
      ),
      from: DateTime(2024, 1, 1),
      window: const Duration(days: 1530),
      limit: 10,
    );
    expect(yearly.map((value) => value.year), [2024, 2028]);
  });

  test('respects count and until boundaries', () {
    final counted = service.generateOccurrences(
      reminder('RRULE:FREQ=DAILY;COUNT=3', DateTime(2026, 9, 1, 9)),
      from: DateTime(2026, 9, 1),
      window: const Duration(days: 20),
    );
    expect(counted, hasLength(3));

    final until = service.generateOccurrences(
      reminder(
        'RRULE:FREQ=DAILY;UNTIL=20260903T090000Z',
        DateTime(2026, 9, 1, 9),
      ),
      from: DateTime(2026, 9, 1),
      window: const Duration(days: 20),
    );
    expect(until, hasLength(3));
  });
}
