import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/reminder_options.dart';
import '../domain/reminder_schedule.dart';

class ReminderRepository {
  const ReminderRepository(this._database);

  final AppDatabase _database;

  Stream<List<Reminder>> watchReminders() {
    return (_database.select(_database.reminders)
          ..where((table) => table.isDeleted.equals(false))
          ..orderBy([
            (table) => OrderingTerm(expression: table.dueDate),
            (table) => OrderingTerm(expression: table.title),
          ]))
        .watch();
  }

  Stream<List<ReminderItem>> watchReminderItems() {
    return watchReminders().asyncMap(_hydrateItems);
  }

  Future<List<ReminderItem>> _hydrateItems(List<Reminder> reminders) async {
    if (reminders.isEmpty) return const <ReminderItem>[];
    final ids = reminders.map((item) => item.id).toList();
    final occurrences =
        await (_database.select(_database.reminderOccurrences)
              ..where((table) => table.reminderId.isIn(ids))
              ..orderBy([
                (table) => OrderingTerm(expression: table.scheduledAt),
              ]))
            .get();
    final links =
        await (_database.select(_database.reminderLinks)
              ..where((table) => table.reminderId.isIn(ids))
              ..orderBy([
                (table) => OrderingTerm(expression: table.displayNameSnapshot),
              ]))
            .get();
    final result = <ReminderItem>[];
    for (final reminder in reminders) {
      final reminderOccurrences = occurrences
          .where((item) => item.reminderId == reminder.id)
          .toList();
      final reminderLinks = links
          .where((item) => item.reminderId == reminder.id)
          .toList();
      if (reminderOccurrences.isEmpty) {
        result.add(ReminderItem(reminder: reminder, links: reminderLinks));
      } else {
        result.addAll([
          for (final occurrence in reminderOccurrences)
            ReminderItem(
              reminder: reminder,
              occurrence: occurrence,
              links: reminderLinks,
            ),
        ]);
      }
    }
    result.sort((a, b) {
      final aDate = a.scheduledAt;
      final bDate = b.scheduledAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return result;
  }

  Future<Reminder?> findById(int id) {
    return (_database.select(_database.reminders)..where(
          (table) => table.id.equals(id) & table.isDeleted.equals(false),
        ))
        .getSingleOrNull();
  }

  Future<ReminderItem?> findItemById(int id) async {
    final reminder = await findById(id);
    if (reminder == null) return null;
    return (await _hydrateItems([reminder])).single;
  }

  Future<List<DateTime>> listPendingOccurrenceTimes(int reminderId) async {
    final rows =
        await (_database.select(_database.reminderOccurrences)
              ..where(
                (table) =>
                    table.reminderId.equals(reminderId) &
                    table.status.equals('pending'),
              )
              ..orderBy([
                (table) => OrderingTerm(expression: table.scheduledAt),
              ]))
            .get();
    return rows.map((row) => row.scheduledAt).toList();
  }

  Future<Reminder?> findByType(String reminderType) {
    return (_database.select(_database.reminders)..where(
          (table) =>
              table.reminderType.equals(reminderType) &
              table.isDeleted.equals(false),
        ))
        .getSingleOrNull();
  }

  Future<Reminder?> findBySource(String entityType, int entityId) {
    return (_database.select(_database.reminders)..where(
          (table) =>
              table.sourceEntityType.equals(entityType) &
              table.sourceEntityId.equals(entityId) &
              table.isDeleted.equals(false),
        ))
        .getSingleOrNull();
  }

  Future<Reminder> save({int? id, required ReminderDraft draft}) async {
    final title = draft.title.trim();
    if (title.isEmpty) throw ArgumentError('提醒标题不能为空');
    if (draft.leadDays < 0 || draft.leadDays > 365) {
      throw ArgumentError('提前天数须在 0 到 365 天之间');
    }
    if (!ReminderPriorities.values.contains(draft.priority)) {
      throw ArgumentError('提醒优先级无效');
    }

    return _database.transaction(() async {
      final now = DateTime.now();
      final values = RemindersCompanion(
        title: Value(title),
        reminderType: Value(draft.reminderType),
        priority: Value(draft.priority),
        category: Value(draft.category),
        dueDate: Value(draft.dueDate),
        leadDays: Value(draft.leadDays),
        repeatRule: Value(_nullable(draft.repeatRule)),
        timezoneId: Value(_nullable(draft.timezoneId)),
        isEnabled: Value(draft.isEnabled),
        isCompleted: const Value(false),
        sourceEntityType: Value(_nullable(draft.sourceEntityType)),
        sourceEntityId: Value(draft.sourceEntityId),
        remark: Value(_nullable(draft.remark)),
        updatedAt: Value(now),
        archivedAt: const Value(null),
        isDeleted: const Value(false),
      );
      late final int reminderId;
      if (id != null) {
        final existing = await findById(id);
        if (existing == null) throw StateError('提醒不存在或已被删除');
        reminderId = id;
        await (_database.update(
          _database.reminders,
        )..where((table) => table.id.equals(id))).write(values);
      } else {
        final existing =
            draft.sourceEntityType != null && draft.sourceEntityId != null
            ? await findBySource(draft.sourceEntityType!, draft.sourceEntityId!)
            : await findByType(draft.reminderType);
        final hasSource =
            draft.sourceEntityType != null && draft.sourceEntityId != null;
        if (existing != null && (hasSource || draft.reminderType != 'custom')) {
          reminderId = existing.id;
          await (_database.update(
            _database.reminders,
          )..where((table) => table.id.equals(existing.id))).write(values);
        } else {
          reminderId = await _database
              .into(_database.reminders)
              .insert(
                RemindersCompanion.insert(
                  title: title,
                  reminderType: draft.reminderType,
                  priority: Value(draft.priority),
                  category: Value(draft.category),
                  dueDate: Value(draft.dueDate),
                  leadDays: Value(draft.leadDays),
                  repeatRule: Value(_nullable(draft.repeatRule)),
                  timezoneId: Value(_nullable(draft.timezoneId)),
                  isEnabled: Value(draft.isEnabled),
                  sourceEntityType: Value(_nullable(draft.sourceEntityType)),
                  sourceEntityId: Value(draft.sourceEntityId),
                  remark: Value(_nullable(draft.remark)),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
        }
      }
      await _replaceScheduleData(reminderId, draft, now);
      return (await findById(reminderId))!;
    });
  }

  Future<void> _replaceScheduleData(
    int reminderId,
    ReminderDraft draft,
    DateTime now,
  ) async {
    await (_database.delete(_database.reminderOccurrences)..where(
          (table) =>
              table.reminderId.equals(reminderId) &
              table.status.equals('pending'),
        ))
        .go();
    await (_database.delete(
      _database.reminderAlertRules,
    )..where((table) => table.reminderId.equals(reminderId))).go();
    await (_database.delete(
      _database.reminderLinks,
    )..where((table) => table.reminderId.equals(reminderId))).go();

    final dueDate = draft.dueDate;
    if (dueDate != null) {
      final schedule = ReminderSchedule.decode(
        draft.repeatRule,
        legacyLeadDays: draft.leadDays,
      );
      final occurrences = schedule.upcoming(dueDate, limit: 30);
      await _database.batch((batch) {
        batch.insertAll(_database.reminderOccurrences, [
          for (final scheduledAt in occurrences)
            ReminderOccurrencesCompanion.insert(
              reminderId: reminderId,
              scheduledAt: scheduledAt,
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
        ], mode: InsertMode.insertOrIgnore);
        batch.insertAll(_database.reminderAlertRules, [
          for (var index = 0; index < schedule.alertMinutes.length; index++)
            ReminderAlertRulesCompanion.insert(
              reminderId: reminderId,
              offsetMinutes: Value(-schedule.alertMinutes[index]),
              sortOrder: Value(index),
              isEnabled: Value(draft.isEnabled),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
        ]);
      });
    }
    if (draft.links.isNotEmpty) {
      await _database.batch((batch) {
        batch.insertAll(_database.reminderLinks, [
          for (final link in draft.links)
            ReminderLinksCompanion.insert(
              reminderId: reminderId,
              entityType: link.entityType,
              entityId: link.entityId,
              displayNameSnapshot: link.displayName.trim(),
              createdAt: Value(now),
            ),
        ], mode: InsertMode.insertOrIgnore);
      });
    }
  }

  Future<Reminder> saveSetting({
    required String reminderType,
    required String title,
    required bool isEnabled,
    required int leadDays,
  }) {
    return save(
      draft: ReminderDraft(
        title: title,
        reminderType: reminderType,
        isEnabled: isEnabled,
        leadDays: leadDays,
        repeatRule: 'monthly',
      ),
    );
  }

  Future<void> complete(
    int id, {
    bool completed = true,
    int? occurrenceId,
  }) async {
    await _database.transaction(() async {
      final reminder = await findById(id);
      if (reminder == null) return;
      final occurrence = await _targetOccurrence(
        id,
        completed ? 'pending' : 'completed',
        occurrenceId: occurrenceId,
      );
      if (occurrence != null) {
        await (_database.update(
          _database.reminderOccurrences,
        )..where((table) => table.id.equals(occurrence.id))).write(
          ReminderOccurrencesCompanion(
            status: Value(completed ? 'completed' : 'pending'),
            completedAt: Value(completed ? DateTime.now() : null),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
      final schedule = ReminderSchedule.decode(
        reminder.repeatRule,
        legacyLeadDays: reminder.leadDays,
      );
      await (_database.update(
        _database.reminders,
      )..where((table) => table.id.equals(id))).write(
        RemindersCompanion(
          isCompleted: Value(!schedule.repeats && completed),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<ReminderOccurrence?> _targetOccurrence(
    int reminderId,
    String status, {
    int? occurrenceId,
  }) {
    if (occurrenceId != null) {
      return (_database.select(
        _database.reminderOccurrences,
      )..where((table) => table.id.equals(occurrenceId))).getSingleOrNull();
    }
    final query = _database.select(_database.reminderOccurrences)
      ..where(
        (table) =>
            table.reminderId.equals(reminderId) & table.status.equals(status),
      )
      ..orderBy([
        (table) => OrderingTerm(
          expression: status == 'completed'
              ? table.completedAt
              : table.scheduledAt,
          mode: status == 'completed' ? OrderingMode.desc : OrderingMode.asc,
        ),
      ])
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<void> skip(int id, {int? occurrenceId}) async {
    final occurrence = await _targetOccurrence(
      id,
      'pending',
      occurrenceId: occurrenceId,
    );
    if (occurrence == null) return;
    await _database.transaction(() async {
      await (_database.update(
        _database.reminderOccurrences,
      )..where((table) => table.id.equals(occurrence.id))).write(
        ReminderOccurrencesCompanion(
          status: const Value('skipped'),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await (_database.update(_database.reminders)
            ..where((table) => table.id.equals(id)))
          .write(RemindersCompanion(updatedAt: Value(DateTime.now())));
    });
  }

  Future<void> setEnabled(int id, bool enabled) async {
    await (_database.update(
      _database.reminders,
    )..where((table) => table.id.equals(id))).write(
      RemindersCompanion(
        isEnabled: Value(enabled),
        archivedAt: Value(enabled ? null : DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> delete(int id) async {
    await (_database.update(
      _database.reminders,
    )..where((table) => table.id.equals(id))).write(
      RemindersCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  String? _nullable(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
