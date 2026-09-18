import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/features/reminders/domain/reminder_schedule.dart';

void main() {
  test('encodes and decodes multiple alerts and custom weekly repeat', () {
    final value = ReminderSchedule(
      repeatUnit: ReminderRepeatUnit.week,
      interval: 2,
      weekdays: const {1, 5},
      repeatEnd: ReminderRepeatEnd.count,
      endCount: 8,
      alertMinutes: const [0, 15, 1440],
      ringEnabled: false,
    );

    final decoded = ReminderSchedule.decode(value.encode());

    expect(decoded.repeatUnit, ReminderRepeatUnit.week);
    expect(decoded.interval, 2);
    expect(decoded.weekdays, {1, 5});
    expect(decoded.repeatEnd, ReminderRepeatEnd.count);
    expect(decoded.endCount, 8);
    expect(decoded.alertMinutes, [0, 15, 1440]);
    expect(decoded.ringEnabled, isFalse);
  });

  test('generates selected weekdays and respects repeat count', () {
    final value = ReminderSchedule(
      repeatUnit: ReminderRepeatUnit.week,
      weekdays: const {1, 3},
      repeatEnd: ReminderRepeatEnd.count,
      endCount: 4,
    );

    final occurrences = value.upcoming(DateTime(2026, 9, 14, 9));

    expect(occurrences, [
      DateTime(2026, 9, 14, 9),
      DateTime(2026, 9, 16, 9),
      DateTime(2026, 9, 21, 9),
      DateTime(2026, 9, 23, 9),
    ]);
  });

  test('supports multiple selected dates in monthly repeat', () {
    final value = ReminderSchedule(
      repeatUnit: ReminderRepeatUnit.month,
      monthDays: const {1, 15},
    );

    final occurrences = value.upcoming(DateTime(2026, 9, 1, 8), limit: 4);

    expect(occurrences, [
      DateTime(2026, 9, 1, 8),
      DateTime(2026, 9, 15, 8),
      DateTime(2026, 10, 1, 8),
      DateTime(2026, 10, 15, 8),
    ]);
  });

  test('keeps legacy monthly settings readable', () {
    final decoded = ReminderSchedule.decode('monthly', legacyLeadDays: 3);

    expect(decoded.repeatUnit, ReminderRepeatUnit.month);
    expect(decoded.alertMinutes, [4320]);
  });

  test('preserves an explicit no-reminder schedule and disables ringing', () {
    final decoded = ReminderSchedule.decode(
      const ReminderSchedule(alertMinutes: <int>[], ringEnabled: true).encode(),
    );

    expect(decoded.alertMinutes, isEmpty);
    expect(decoded.ringEnabled, isFalse);
  });
}
