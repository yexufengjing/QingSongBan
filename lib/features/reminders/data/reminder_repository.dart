import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/reminder_options.dart';

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

  Future<Reminder?> findById(int id) {
    return (_database.select(_database.reminders)..where(
          (table) => table.id.equals(id) & table.isDeleted.equals(false),
        ))
        .getSingleOrNull();
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
    final now = DateTime.now();
    final values = RemindersCompanion(
      title: Value(title),
      reminderType: Value(draft.reminderType),
      dueDate: Value(draft.dueDate),
      leadDays: Value(draft.leadDays),
      repeatRule: Value(_nullable(draft.repeatRule)),
      isEnabled: Value(draft.isEnabled),
      sourceEntityType: Value(_nullable(draft.sourceEntityType)),
      sourceEntityId: Value(draft.sourceEntityId),
      remark: Value(_nullable(draft.remark)),
      updatedAt: Value(now),
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
      final existing = await findByType(draft.reminderType);
      if (existing != null && draft.reminderType != 'custom') {
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
                dueDate: Value(draft.dueDate),
                leadDays: Value(draft.leadDays),
                repeatRule: Value(_nullable(draft.repeatRule)),
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
    return (await findById(reminderId))!;
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

  Future<void> complete(int id, {bool completed = true}) async {
    await (_database.update(
      _database.reminders,
    )..where((table) => table.id.equals(id))).write(
      RemindersCompanion(
        isCompleted: Value(completed),
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
