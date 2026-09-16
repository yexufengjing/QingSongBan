import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
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

  test(
    'creates idempotent recurring occurrences and multiple alert rules',
    () async {
      final reminder = await repository.save(
        draft: ReminderDraft(
          title: '每月福利领取',
          reminderType: 'custom',
          dueDate: DateTime.now().add(const Duration(days: 1)),
          leadDays: 3,
          isEnabled: true,
          repeatRule: 'RRULE:FREQ=MONTHLY;BYMONTHDAY=17',
          alertOffsetsMinutes: const [-4320, -1440, 0],
          nagRepeatIntervalMinutes: 1440,
          nagMaxRepeatCount: 7,
        ),
      );
      await repository.ensureOccurrences(reminder.id);
      final occurrences = await repository.findOccurrences(reminder.id);
      final rules = await repository.findAlertRules(reminder.id);
      expect(
        occurrences.map((item) => item.scheduledAt).toSet(),
        hasLength(13),
      );
      expect(rules.where((rule) => !rule.isNagRule), hasLength(3));
      expect(rules.where((rule) => rule.isNagRule).single.maxRepeatCount, 7);

      await repository.ensureOccurrences(reminder.id);
      expect(await repository.findOccurrences(reminder.id), hasLength(13));

      final current = occurrences.firstWhere(
        (item) => item.status == 'pending',
      );
      await repository.completeOccurrence(current.id);
      expect(
        (await repository.findOccurrenceById(current.id))?.completedAt,
        isNotNull,
      );
      expect(
        (await repository.findOccurrences(reminder.id))
            .where((item) => item.status == 'pending'),
        isNotEmpty,
      );
    },
  );

  test(
    'links multiple employees and retains a display snapshot after deletion',
    () async {
      final firstEmployee = await database.insertEmployee(
        EmployeesCompanion.insert(
          employeeNo: 'EMP-1001',
          name: '张三',
          hireDate: DateTime(2026, 1, 1),
        ),
      );
      final secondEmployee = await database.insertEmployee(
        EmployeesCompanion.insert(
          employeeNo: 'EMP-1002',
          name: '李四',
          hireDate: DateTime(2026, 1, 1),
        ),
      );
      final reminder = await repository.save(
        draft: ReminderDraft(
          title: '人员事务',
          reminderType: 'custom',
          dueDate: DateTime.now().add(const Duration(days: 1)),
          leadDays: 0,
          isEnabled: true,
          links: [
            ReminderLinkDraft(
              entityType: 'employee',
              entityId: firstEmployee,
              displayNameSnapshot: '张三',
            ),
            ReminderLinkDraft(
              entityType: 'employee',
              entityId: secondEmployee,
              displayNameSnapshot: '李四',
            ),
          ],
        ),
      );
      expect(
        (await repository.findLinkDisplays(reminder.id))
            .map((link) => link.displayName),
        ['张三', '李四'],
      );
      await (database.update(
        database.employees,
      )..where((table) => table.id.equals(secondEmployee))).write(
        EmployeesCompanion(status: const Value(EmployeeStatus.terminated)),
      );
      final displays = await repository.findLinkDisplays(reminder.id);
      expect(displays.last.displayName, '李四');
      expect(displays.last.status, 'terminated');
    },
  );
}
