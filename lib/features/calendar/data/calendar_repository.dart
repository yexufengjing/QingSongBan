import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../reminders/domain/reminder_options.dart';
import '../../reminders/domain/reminder_schedule.dart';
import '../domain/calendar_models.dart';

class CalendarRepository {
  const CalendarRepository(this._database);

  final AppDatabase _database;

  /// Emits a single snapshot for the natural Monday-to-Sunday calendar grid.
  /// Any reminder, occurrence, link, or daily-entry write invalidates it.
  Stream<CalendarSnapshot> watchMonth(DateTime month) {
    final first = DateTime(month.year, month.month);
    final gridStart = DateTime(month.year, month.month, 2 - first.weekday);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final gridEnd = DateTime(
      month.year,
      month.month,
      lastDay.day + 8 - lastDay.weekday,
    );
    return _database
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _database.reminders,
            _database.reminderOccurrences,
            _database.reminderLinks,
            _database.dailyEntries,
          },
        )
        .watch()
        .asyncMap(
          (_) => _database.transaction(() => _loadSnapshot(gridStart, gridEnd)),
        );
  }

  Future<CalendarSnapshot> _loadSnapshot(DateTime start, DateTime end) async {
    final reminders =
        await (_database.select(_database.reminders)
              ..where(
                (table) =>
                    table.isDeleted.equals(false) &
                    table.reminderType.isNotIn(
                      ReminderOptions.types.where((type) => type != 'custom'),
                    ) &
                    table.dueDate.isNotNull() &
                    table.dueDate.isSmallerOrEqualValue(end),
              )
              ..orderBy([(table) => OrderingTerm(expression: table.dueDate)]))
            .get();
    await _ensureOccurrences(reminders, start, end);

    final reminderIds = reminders.map((item) => item.id).toList();
    final occurrences = reminderIds.isEmpty
        ? <ReminderOccurrence>[]
        : await (_database.select(_database.reminderOccurrences)
                ..where(
                  (table) =>
                      table.reminderId.isIn(reminderIds) &
                      table.scheduledAt.isBiggerOrEqualValue(start) &
                      table.scheduledAt.isSmallerThanValue(end),
                )
                ..orderBy([
                  (table) => OrderingTerm(expression: table.scheduledAt),
                ]))
              .get();
    final links = reminderIds.isEmpty
        ? <ReminderLink>[]
        : await (_database.select(
            _database.reminderLinks,
          )..where((table) => table.reminderId.isIn(reminderIds))).get();
    final items = <ReminderItem>[];
    for (final reminder in reminders) {
      final reminderLinks = links
          .where((link) => link.reminderId == reminder.id)
          .toList(growable: false);
      final reminderOccurrences = occurrences
          .where((occurrence) => occurrence.reminderId == reminder.id)
          .toList(growable: false);
      if (reminderOccurrences.isEmpty) {
        // Legacy/one-off rows may not yet have an occurrence row.
        if (!ReminderSchedule.decode(
          reminder.repeatRule,
          legacyLeadDays: reminder.leadDays,
        ).repeats) {
          final dueDate = reminder.dueDate;
          if (dueDate != null &&
              !dueDate.isBefore(start) &&
              dueDate.isBefore(end)) {
            items.add(ReminderItem(reminder: reminder, links: reminderLinks));
          }
        }
        continue;
      }
      items.addAll([
        for (final occurrence in reminderOccurrences)
          ReminderItem(
            reminder: reminder,
            occurrence: occurrence,
            links: reminderLinks,
          ),
      ]);
    }
    items.sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
    final entries =
        await (_database.select(_database.dailyEntries)
              ..where(
                (table) =>
                    table.isDeleted.equals(false) &
                    table.recordDate.isBiggerOrEqualValue(_dateKey(start)) &
                    table.recordDate.isSmallerThanValue(_dateKey(end)),
              )
              ..orderBy([
                (table) => OrderingTerm(
                  expression: table.createdAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    return CalendarSnapshot(todos: items, entries: entries);
  }

  Future<void> _ensureOccurrences(
    List<Reminder> reminders,
    DateTime start,
    DateTime end,
  ) async {
    final now = DateTime.now();
    final rows = <ReminderOccurrencesCompanion>[];
    for (final reminder in reminders) {
      final base = reminder.dueDate;
      if (base == null) continue;
      final schedule = ReminderSchedule.decode(
        reminder.repeatRule,
        legacyLeadDays: reminder.leadDays,
      );
      if (!schedule.repeats) continue;
      for (final scheduledAt in schedule.between(base, start, end)) {
        final exists =
            await (_database.select(_database.reminderOccurrences)
                  ..where(
                    (table) =>
                        table.reminderId.equals(reminder.id) &
                        table.scheduledAt.equals(scheduledAt),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (exists != null) continue;
        rows.add(
          ReminderOccurrencesCompanion.insert(
            reminderId: reminder.id,
            scheduledAt: scheduledAt,
            status: const Value('pending'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }
    }
    if (rows.isEmpty) return;
    await _database.batch((batch) {
      batch.insertAll(
        _database.reminderOccurrences,
        rows,
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  Future<Reminder> saveTodo({
    int? id,
    required String title,
    required DateTime date,
    DateTime? time,
    required bool isAllDay,
    String? remark,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) throw ArgumentError('待办标题不能为空');
    if (!isAllDay && time == null) {
      throw ArgumentError('指定时间的待办必须提供时间');
    }
    final scheduledAt = DateTime(
      date.year,
      date.month,
      date.day,
      isAllDay ? 0 : time?.hour ?? 0,
      isAllDay ? 0 : time?.minute ?? 0,
    );
    return _database.transaction(() async {
      final now = DateTime.now();
      if (id == null) {
        final reminderId = await _database
            .into(_database.reminders)
            .insert(
              RemindersCompanion.insert(
                title: normalizedTitle,
                reminderType: 'custom',
                dueDate: Value(scheduledAt),
                isAllDay: Value(isAllDay),
                isEnabled: const Value(false),
                remark: Value(_nullable(remark)),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        await _database
            .into(_database.reminderOccurrences)
            .insert(
              ReminderOccurrencesCompanion.insert(
                reminderId: reminderId,
                scheduledAt: scheduledAt,
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        return (await (_database.select(
          _database.reminders,
        )..where((table) => table.id.equals(reminderId))).getSingle());
      }

      final existing =
          await (_database.select(_database.reminders)..where(
                (table) =>
                    table.id.equals(id) &
                    table.isDeleted.equals(false) &
                    table.reminderType.isNotIn(
                      ReminderOptions.types.where((type) => type != 'custom'),
                    ),
              ))
              .getSingleOrNull();
      if (existing == null) throw StateError('待办不存在或不支持快捷编辑');
      final schedule = ReminderSchedule.decode(
        existing.repeatRule,
        legacyLeadDays: existing.leadDays,
      );
      if (schedule.repeats) throw StateError('重复待办请使用完整编辑页');
      await (_database.update(
        _database.reminders,
      )..where((table) => table.id.equals(id))).write(
        RemindersCompanion(
          title: Value(normalizedTitle),
          dueDate: Value(scheduledAt),
          isAllDay: Value(isAllDay),
          isEnabled: Value(isAllDay ? false : existing.isEnabled),
          remark: Value(_nullable(remark)),
          updatedAt: Value(now),
        ),
      );
      if (isAllDay) {
        await (_database.update(
          _database.reminderAlertRules,
        )..where((table) => table.reminderId.equals(id))).write(
          ReminderAlertRulesCompanion(
            isEnabled: const Value(false),
            updatedAt: Value(now),
          ),
        );
      }
      final previous =
          await (_database.select(_database.reminderOccurrences)
                ..where((table) => table.reminderId.equals(id))
                ..orderBy([(table) => OrderingTerm(expression: table.id)])
                ..limit(1))
              .getSingleOrNull();
      if (previous == null) {
        await _database
            .into(_database.reminderOccurrences)
            .insert(
              ReminderOccurrencesCompanion.insert(
                reminderId: id,
                scheduledAt: scheduledAt,
                status: Value(existing.isCompleted ? 'completed' : 'pending'),
                completedAt: Value(
                  existing.isCompleted ? existing.updatedAt : null,
                ),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else {
        await (_database.update(
          _database.reminderOccurrences,
        )..where((table) => table.id.equals(previous.id))).write(
          ReminderOccurrencesCompanion(
            scheduledAt: Value(scheduledAt),
            updatedAt: Value(now),
          ),
        );
      }
      return (await (_database.select(
        _database.reminders,
      )..where((table) => table.id.equals(id))).getSingle());
    });
  }

  Future<void> setCompleted(ReminderItem item, bool completed) async {
    final reminder = await _findCalendarReminder(item.id);
    final schedule = ReminderSchedule.decode(
      reminder.repeatRule,
      legacyLeadDays: reminder.leadDays,
    );
    final occurrenceId = item.occurrenceId;
    if (schedule.repeats && occurrenceId == null) {
      throw StateError('重复待办必须指定 occurrenceId');
    }
    await _database.transaction(() async {
      final occurrence = occurrenceId == null
          ? await (_database.select(_database.reminderOccurrences)
                  ..where((table) => table.reminderId.equals(item.id)))
                .getSingleOrNull()
          : await (_database.select(_database.reminderOccurrences)..where(
                  (table) =>
                      table.id.equals(occurrenceId) &
                      table.reminderId.equals(item.id),
                ))
                .getSingleOrNull();
      if (occurrenceId != null && occurrence == null) {
        throw StateError('待办实例已不存在');
      }
      final now = DateTime.now();
      if (occurrence != null) {
        await (_database.update(
          _database.reminderOccurrences,
        )..where((table) => table.id.equals(occurrence.id))).write(
          ReminderOccurrencesCompanion(
            status: Value(completed ? 'completed' : 'pending'),
            completedAt: Value(completed ? now : null),
            updatedAt: Value(now),
          ),
        );
      }
      if (!schedule.repeats) {
        await (_database.update(
          _database.reminders,
        )..where((table) => table.id.equals(item.id))).write(
          RemindersCompanion(
            isCompleted: Value(completed),
            updatedAt: Value(now),
          ),
        );
      } else {
        await (_database.update(_database.reminders)
              ..where((table) => table.id.equals(item.id)))
            .write(RemindersCompanion(updatedAt: Value(now)));
      }
    });
  }

  Future<void> deleteTodo(ReminderItem item) async {
    final reminder = await _findCalendarReminder(item.id);
    if (ReminderSchedule.decode(
      reminder.repeatRule,
      legacyLeadDays: reminder.leadDays,
    ).repeats) {
      throw StateError('重复待办不能通过快捷操作删除');
    }
    await (_database.update(
      _database.reminders,
    )..where((table) => table.id.equals(item.id))).write(
      RemindersCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> skipOccurrence(ReminderItem item) async {
    final occurrenceId = item.occurrenceId;
    if (occurrenceId == null) throw StateError('待办实例不存在');
    final reminder = await _findCalendarReminder(item.id);
    if (!ReminderSchedule.decode(
      reminder.repeatRule,
      legacyLeadDays: reminder.leadDays,
    ).repeats) {
      throw StateError('仅重复待办支持跳过本次');
    }
    await (_database.update(_database.reminderOccurrences)..where(
          (table) =>
              table.id.equals(occurrenceId) & table.reminderId.equals(item.id),
        ))
        .write(
          ReminderOccurrencesCompanion(
            status: const Value('skipped'),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<DailyEntry> saveEntry({
    int? id,
    required DateTime date,
    required String content,
  }) async {
    final normalized = content.trim();
    if (normalized.isEmpty) throw ArgumentError('日记录内容不能为空');
    final now = DateTime.now();
    if (id == null) {
      final newId = await _database
          .into(_database.dailyEntries)
          .insert(
            DailyEntriesCompanion.insert(
              recordDate: _dateKey(date),
              content: normalized,
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      return (_database.select(
        _database.dailyEntries,
      )..where((table) => table.id.equals(newId))).getSingle();
    }
    await (_database.update(_database.dailyEntries)..where(
          (table) => table.id.equals(id) & table.isDeleted.equals(false),
        ))
        .write(
          DailyEntriesCompanion(
            recordDate: Value(_dateKey(date)),
            content: Value(normalized),
            updatedAt: Value(now),
          ),
        );
    final saved =
        await (_database.select(_database.dailyEntries)..where(
              (table) => table.id.equals(id) & table.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (saved == null) throw StateError('日记录不存在或已被删除');
    return saved;
  }

  Future<void> deleteEntry(int id) async {
    await (_database.update(
      _database.dailyEntries,
    )..where((table) => table.id.equals(id))).write(
      DailyEntriesCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<Reminder> _findCalendarReminder(int id) async {
    final reminder =
        await (_database.select(_database.reminders)..where(
              (table) =>
                  table.id.equals(id) &
                  table.isDeleted.equals(false) &
                  table.reminderType.isNotIn(
                    ReminderOptions.types.where((type) => type != 'custom'),
                  ),
            ))
            .getSingleOrNull();
    if (reminder == null) throw StateError('待办不存在或不可在日历操作');
    return reminder;
  }

  String? _nullable(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
