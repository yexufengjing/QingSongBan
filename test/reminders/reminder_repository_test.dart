import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/features/reminders/data/reminder_repository.dart';
import 'package:qingsongban/features/reminders/domain/reminder_options.dart';

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
}
