import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/features/calendar/data/calendar_repository.dart';
import 'package:qingsongban/features/calendar/domain/calendar_models.dart';
import 'package:qingsongban/features/reminders/data/reminder_repository.dart';
import 'package:qingsongban/features/reminders/domain/reminder_options.dart';
import 'package:qingsongban/features/reminders/domain/reminder_schedule.dart';

void main() {
  late AppDatabase database;
  late CalendarRepository calendar;
  late ReminderRepository reminders;

  setUp(() {
    database = AppDatabase.forTesting();
    calendar = CalendarRepository(database);
    reminders = ReminderRepository(database);
  });

  tearDown(() => database.close());

  test(
    'creates and moves one-off todos while keeping completed state',
    () async {
      final created = await calendar.saveTodo(
        title: '  整理仓库  ',
        date: DateTime(2026, 10, 23),
        time: DateTime(2020, 1, 1, 14, 35),
        isAllDay: false,
        remark: '清点工具',
      );
      expect(created.title, '整理仓库');
      expect(created.dueDate, DateTime(2026, 10, 23, 14, 35));
      expect(created.isEnabled, isFalse);
      expect(await database.select(database.reminderAlertRules).get(), isEmpty);

      final item = await reminders.findItemById(created.id);
      expect(item, isNotNull);
      await calendar.setCompleted(item!, true);
      final moved = await calendar.saveTodo(
        id: created.id,
        title: '整理仓库',
        date: DateTime(2026, 10, 24),
        time: DateTime(2000, 1, 1, 9, 10),
        isAllDay: false,
        remark: '已调整日期',
      );
      expect(moved.id, created.id);
      expect(moved.priority, 'normal');
      expect(moved.category, 'general');
      expect(moved.isCompleted, isTrue);
      expect(moved.dueDate, DateTime(2026, 10, 24, 9, 10));
      final movedItem = await reminders.findItemById(created.id);
      expect(movedItem?.occurrence?.status, 'completed');
      await calendar.setCompleted(movedItem!, false);
      expect((await reminders.findById(created.id))?.isCompleted, isFalse);
    },
  );

  test(
    'all-day defaults and legacy reminders retain their timed meaning',
    () async {
      final old = await reminders.save(
        draft: ReminderDraft(
          title: '旧提醒',
          reminderType: 'custom',
          dueDate: DateTime(2026, 10, 23, 0),
          leadDays: 0,
          isEnabled: true,
        ),
      );
      expect(old.isAllDay, isFalse);
      final allDay = await calendar.saveTodo(
        title: '全天任务',
        date: DateTime(2026, 10, 24),
        isAllDay: true,
      );
      expect(allDay.isAllDay, isTrue);
      expect(allDay.isEnabled, isFalse);
      expect(allDay.dueDate, DateTime(2026, 10, 24));
      expect(
        calendar.saveTodo(
          title: '缺少时刻',
          date: DateTime(2026, 10, 24),
          isAllDay: false,
        ),
        throwsArgumentError,
      );
    },
  );

  test('month snapshot includes every date in the natural week grid', () async {
    await calendar.saveEntry(date: DateTime(2026, 9, 28), content: '月历首日');
    await calendar.saveEntry(date: DateTime(2026, 11, 1), content: '月历末日');
    final snapshot = await calendar.watchMonth(DateTime(2026, 10)).first;
    expect(
      snapshot.entries.map((entry) => entry.recordDate),
      containsAll(['2026-09-28', '2026-11-01']),
    );
  });

  test(
    'fills remote recurring months through count end without resetting history',
    () async {
      final series = await reminders.save(
        draft: ReminderDraft(
          title: '远期月度事项',
          reminderType: 'custom',
          dueDate: DateTime(2024, 1, 15, 8),
          leadDays: 0,
          repeatRule: ReminderSchedule(
            repeatUnit: ReminderRepeatUnit.month,
            repeatEnd: ReminderRepeatEnd.count,
            endCount: 80,
          ).encode(),
          isEnabled: true,
        ),
      );
      final firstThirty = await database
          .select(database.reminderOccurrences)
          .get();
      expect(firstThirty.length, 30);
      final pastSeededHorizon = await calendar
          .watchMonth(DateTime(2030, 6))
          .first;
      final june = pastSeededHorizon.todos
          .where((item) => item.reminder.id == series.id)
          .toList();
      expect(june, hasLength(1));
      expect(june.single.scheduledAt, DateTime(2030, 6, 15, 8));

      await calendar.setCompleted(june.single, true);
      final july = await calendar.watchMonth(DateTime(2030, 7)).first;
      final julyItem = july.todos.singleWhere(
        (item) => item.reminder.id == series.id,
      );
      await calendar.skipOccurrence(julyItem);
      final replay = await calendar.watchMonth(DateTime(2030, 6)).first;
      expect(
        replay.todos
            .singleWhere((item) => item.reminder.id == series.id)
            .status,
        'completed',
      );
      final finalOccurrence = await calendar
          .watchMonth(DateTime(2030, 8))
          .first;
      expect(
        finalOccurrence.todos.where((item) => item.reminder.id == series.id),
        hasLength(1),
      );
      final countEnd = await calendar.watchMonth(DateTime(2030, 9)).first;
      expect(
        countEnd.todos.where((item) => item.reminder.id == series.id),
        isEmpty,
      );
      final history = await (database.select(
        database.reminderOccurrences,
      )..where((row) => row.reminderId.equals(series.id))).get();
      expect(history.where((row) => row.status == 'completed'), hasLength(1));
      expect(history.where((row) => row.status == 'skipped'), hasLength(1));
    },
  );

  test(
    'includes existing business reminders and refreshes on instance writes',
    () async {
      final business = await reminders.save(
        draft: ReminderDraft(
          title: '车辆保养',
          reminderType: 'vehicleMaintenance',
          dueDate: DateTime(2026, 10, 25, 10),
          leadDays: 0,
          isEnabled: true,
          sourceEntityType: 'vehicle',
          sourceEntityId: 9,
        ),
      );
      final iterator = StreamIterator<CalendarSnapshot>(
        calendar.watchMonth(DateTime(2026, 10)),
      );
      try {
        expect(await iterator.moveNext(), isTrue);
        final initial = iterator.current;
        expect(initial.todos.single.reminder.id, business.id);
        final added = await database
            .into(database.reminderOccurrences)
            .insert(
              ReminderOccurrencesCompanion.insert(
                reminderId: business.id,
                scheduledAt: DateTime(2026, 10, 26, 10),
              ),
            );
        expect(await iterator.moveNext(), isTrue);
        expect(
          iterator.current.todos.any((item) => item.occurrenceId == added),
          isTrue,
        );
        expect(initial.todos, hasLength(1));
      } finally {
        await iterator.cancel();
      }
    },
  );

  test('daily entries are independent, editable, and soft-deletable', () async {
    final todo = await calendar.saveTodo(
      title: '事项',
      date: DateTime(2026, 10, 23),
      time: DateTime(2026, 1, 1, 9),
      isAllDay: false,
    );
    final entry = await calendar.saveEntry(
      date: DateTime(2026, 10, 23),
      content: '  今日记录\n第二行  ',
    );
    expect(entry.recordDate, '2026-10-23');
    expect(entry.content, '今日记录\n第二行');
    final edited = await calendar.saveEntry(
      id: entry.id,
      date: DateTime(2026, 10, 24),
      content: '修改后的记录',
    );
    expect(edited.createdAt, entry.createdAt);
    expect(edited.recordDate, '2026-10-24');
    await calendar.deleteEntry(entry.id);
    expect((await reminders.findById(todo.id))?.isDeleted, isFalse);
    final month = await calendar.watchMonth(DateTime(2026, 10)).first;
    expect(month.entries, isEmpty);
    expect(month.todos, hasLength(1));
  });
}
