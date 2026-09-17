import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/features/reminders/data/reminder_repository.dart';
import 'package:qingsongban/features/reminders/domain/reminder_options.dart';
import 'package:qingsongban/features/reminders/domain/reminder_schedule.dart';

void main() {
  late AppDatabase database;
  late ReminderRepository repository;

  setUp(() {
    database = AppDatabase.forTesting();
    repository = ReminderRepository(database);
  });

  tearDown(() => database.close());

  test('saves business reminder settings without duplicates', () async {
    final first = await repository.saveSetting(
      reminderType: 'monthlySummary',
      title: '月度汇总提醒',
      isEnabled: true,
      leadDays: 3,
    );
    final second = await repository.saveSetting(
      reminderType: 'monthlySummary',
      title: '月度汇总提醒',
      isEnabled: false,
      leadDays: 7,
    );

    expect(second.id, first.id);
    expect((await repository.findByType('monthlySummary'))?.isEnabled, isFalse);
    expect((await database.select(database.reminders).get()), hasLength(1));
  });

  test('saves, completes, and soft deletes a custom reminder', () async {
    final reminder = await repository.save(
      draft: ReminderDraft(
        title: '检查材料',
        reminderType: 'custom',
        dueDate: DateTime(2026, 10, 1, 9),
        leadDays: 1,
        isEnabled: true,
      ),
    );
    expect(reminder.dueDate, DateTime(2026, 10, 1, 9));
    await repository.complete(reminder.id);
    expect((await repository.findById(reminder.id))?.isCompleted, isTrue);
    await repository.delete(reminder.id);
    expect(await repository.findById(reminder.id), isNull);
  });

  test(
    'creates occurrences, alert rules, and employee links atomically',
    () async {
      final schedule = ReminderSchedule(
        repeatUnit: ReminderRepeatUnit.month,
        repeatEnd: ReminderRepeatEnd.count,
        endCount: 3,
        alertMinutes: const [0, 1440, 4320],
      );
      final reminder = await repository.save(
        draft: ReminderDraft(
          title: '每月福利领取',
          reminderType: 'custom',
          dueDate: DateTime(2026, 10, 5, 9),
          leadDays: 0,
          repeatRule: schedule.encode(),
          isEnabled: true,
          category: 'periodic',
          priority: 'important',
          timezoneId: 'Asia/Shanghai',
          links: const [
            ReminderLinkDraft(
              entityType: 'employee',
              entityId: 7,
              displayName: '赵六',
            ),
            ReminderLinkDraft(
              entityType: 'employee',
              entityId: 8,
              displayName: '钱七',
            ),
          ],
        ),
      );

      final occurrences = await database
          .select(database.reminderOccurrences)
          .get();
      final alertRules = await database
          .select(database.reminderAlertRules)
          .get();
      final links = await database.select(database.reminderLinks).get();
      expect(occurrences, hasLength(3));
      expect(
        alertRules.map((rule) => rule.offsetMinutes),
        containsAll([0, -1440, -4320]),
      );
      expect(links.map((link) => link.displayNameSnapshot), ['赵六', '钱七']);

      await repository.complete(
        reminder.id,
        occurrenceId: occurrences.first.id,
      );
      final refreshed = await database
          .select(database.reminderOccurrences)
          .get();
      expect(refreshed.first.status, 'completed');
      expect(refreshed.first.completedAt, isNotNull);
      expect(
        refreshed.skip(1).every((item) => item.status == 'pending'),
        isTrue,
      );
      expect((await repository.findById(reminder.id))?.isCompleted, isFalse);
    },
  );

  test(
    'editing a series keeps completed history and rebuilds future instances',
    () async {
      final original = ReminderSchedule(
        repeatUnit: ReminderRepeatUnit.week,
        repeatEnd: ReminderRepeatEnd.count,
        endCount: 3,
      );
      final reminder = await repository.save(
        draft: ReminderDraft(
          title: '周例会',
          reminderType: 'custom',
          dueDate: DateTime(2026, 9, 21, 10),
          leadDays: 0,
          repeatRule: original.encode(),
          isEnabled: true,
        ),
      );
      final originalOccurrences = await database
          .select(database.reminderOccurrences)
          .get();
      await repository.complete(
        reminder.id,
        occurrenceId: originalOccurrences.first.id,
      );

      final changed = ReminderSchedule(
        repeatUnit: ReminderRepeatUnit.day,
        repeatEnd: ReminderRepeatEnd.count,
        endCount: 2,
        alertMinutes: const [60],
      );
      await repository.save(
        id: reminder.id,
        draft: ReminderDraft(
          title: '每日例会',
          reminderType: 'custom',
          dueDate: DateTime(2026, 9, 22, 10),
          leadDays: 0,
          repeatRule: changed.encode(),
          isEnabled: true,
        ),
      );

      final occurrences = await database
          .select(database.reminderOccurrences)
          .get();
      expect(
        occurrences.where((item) => item.status == 'completed'),
        hasLength(1),
      );
      expect(
        occurrences.where((item) => item.status == 'pending'),
        hasLength(2),
      );
      expect(
        occurrences
            .where((item) => item.status == 'completed')
            .single
            .scheduledAt,
        DateTime(2026, 9, 21, 10),
      );
    },
  );
}
