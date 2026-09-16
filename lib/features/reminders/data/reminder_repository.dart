import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/recurrence_service.dart';
import '../domain/reminder_options.dart';

class ReminderRepository {
  ReminderRepository(this._database, {RecurrenceService? recurrenceService})
    : _recurrenceService = recurrenceService ?? const RecurrenceService();

  final AppDatabase _database;
  final RecurrenceService _recurrenceService;

  Stream<List<Reminder>> watchReminders() {
    return (_database.select(_database.reminders)
          ..where((table) => table.isDeleted.equals(false))
          ..orderBy([
            (table) => OrderingTerm(expression: table.dueDate),
            (table) => OrderingTerm(expression: table.title),
          ]))
        .watch();
  }

  /// The task list is occurrence-first. This keeps recurring history visible
  /// while avoiding the old single boolean as the source of truth.
  Stream<List<ReminderListItem>> watchReminderItems({
    String search = '',
    String view = 'todo',
  }) {
    final query = _database.select(_database.reminderOccurrences).join([
      innerJoin(
        _database.reminders,
        _database.reminders.id.equalsExp(
          _database.reminderOccurrences.reminderId,
        ),
      ),
      leftOuterJoin(
        _database.reminderLinks,
        _database.reminderLinks.reminderId.equalsExp(_database.reminders.id),
      ),
    ]);
    query.where(_database.reminders.isDeleted.equals(false));
    if (search.trim().isNotEmpty) {
      query.where(
        _database.reminders.title.contains(search.trim()) |
            _database.reminders.remark.contains(search.trim()),
      );
    }
    if (view == 'completed') {
      query.where(
        _database.reminderOccurrences.status.isIn(['completed', 'skipped']),
      );
    } else if (view == 'plan') {
      query.where(_database.reminders.category.equals('plan'));
      query.where(_database.reminderOccurrences.status.equals('pending'));
    } else {
      query.where(_database.reminderOccurrences.status.equals('pending'));
    }
    query
      ..orderBy([
        OrderingTerm(
          expression: _database.reminderOccurrences.status,
          mode: OrderingMode.asc,
        ),
        OrderingTerm(expression: _database.reminderOccurrences.scheduledAt),
        OrderingTerm(expression: _database.reminders.title),
      ])
      ..limit(200);
    return query.watch().map((rows) {
      final items = <int, ReminderListItem>{};
      final links = <int, List<ReminderLinkDisplay>>{};
      for (final row in rows) {
        final reminder = row.readTable(_database.reminders);
        final occurrence = row.readTable(_database.reminderOccurrences);
        items[occurrence.id] ??= ReminderListItem(
          reminder: reminder,
          occurrence: occurrence,
        );
        final link = row.readTableOrNull(_database.reminderLinks);
        if (link != null) {
          links
              .putIfAbsent(occurrence.id, () => [])
              .add(
                ReminderLinkDisplay(
                  entityType: link.entityType,
                  entityId: link.entityId,
                  displayName: link.displayNameSnapshot,
                ),
              );
        }
      }
      return [
        for (final item in items.values)
          ReminderListItem(
            reminder: item.reminder,
            occurrence: item.occurrence,
            links: links[item.occurrence.id] ?? const [],
          ),
      ];
    });
  }

  Future<List<ReminderListItem>> listReminderItems({
    String search = '',
    String view = 'todo',
  }) async {
    final query = _database.select(_database.reminderOccurrences).join([
      innerJoin(
        _database.reminders,
        _database.reminders.id.equalsExp(
          _database.reminderOccurrences.reminderId,
        ),
      ),
      leftOuterJoin(
        _database.reminderLinks,
        _database.reminderLinks.reminderId.equalsExp(_database.reminders.id),
      ),
    ]);
    query.where(_database.reminders.isDeleted.equals(false));
    if (search.trim().isNotEmpty) {
      query.where(
        _database.reminders.title.contains(search.trim()) |
            _database.reminders.remark.contains(search.trim()),
      );
    }
    if (view == 'completed') {
      query.where(
        _database.reminderOccurrences.status.isIn(['completed', 'skipped']),
      );
    } else if (view == 'plan') {
      query.where(_database.reminders.category.equals('plan'));
      query.where(_database.reminderOccurrences.status.equals('pending'));
    } else {
      query.where(_database.reminderOccurrences.status.equals('pending'));
    }
    query
      ..orderBy([
        OrderingTerm(expression: _database.reminderOccurrences.scheduledAt),
      ])
      ..limit(200);
    final rows = await query.get();
    final items = <int, ReminderListItem>{};
    final links = <int, List<ReminderLinkDisplay>>{};
    for (final row in rows) {
      final reminder = row.readTable(_database.reminders);
      final occurrence = row.readTable(_database.reminderOccurrences);
      items[occurrence.id] ??= ReminderListItem(
        reminder: reminder,
        occurrence: occurrence,
      );
      final link = row.readTableOrNull(_database.reminderLinks);
      if (link != null) {
        links
            .putIfAbsent(occurrence.id, () => [])
            .add(
              ReminderLinkDisplay(
                entityType: link.entityType,
                entityId: link.entityId,
                displayName: link.displayNameSnapshot,
              ),
            );
      }
    }
    return [
      for (final item in items.values)
        ReminderListItem(
          reminder: item.reminder,
          occurrence: item.occurrence,
          links: links[item.occurrence.id] ?? const [],
        ),
    ];
  }

  Future<List<ReminderListItem>> listPendingItems({
    DateTime? from,
    DateTime? until,
    int limit = 50,
  }) async {
    final now = from ?? DateTime.now();
    final end = until ?? now.add(const Duration(days: 30));
    final query =
        _database.select(_database.reminderOccurrences).join([
            innerJoin(
              _database.reminders,
              _database.reminders.id.equalsExp(
                _database.reminderOccurrences.reminderId,
              ),
            ),
          ])
          ..where(
            _database.reminders.isDeleted.equals(false) &
                _database.reminders.isEnabled.equals(true) &
                _database.reminderOccurrences.status.equals('pending') &
                _database.reminderOccurrences.scheduledAt.isBiggerOrEqualValue(
                  now,
                ) &
                _database.reminderOccurrences.scheduledAt.isSmallerOrEqualValue(
                  end,
                ),
          )
          ..orderBy([
            OrderingTerm(expression: _database.reminderOccurrences.scheduledAt),
          ])
          ..limit(limit);
    final rows = await query.get();
    final items = rows
        .map(
          (row) => ReminderListItem(
            reminder: row.readTable(_database.reminders),
            occurrence: row.readTable(_database.reminderOccurrences),
          ),
        )
        .toList(growable: false);
    final links = await _loadLinkDisplays([
      for (final item in items) item.reminder.id,
    ]);
    return [
      for (final item in items)
        ReminderListItem(
          reminder: item.reminder,
          occurrence: item.occurrence,
          links: links[item.reminder.id] ?? const [],
        ),
    ];
  }

  Future<List<ReminderListItem>> listItemsForEntity(
    String entityType,
    int entityId,
  ) async {
    final query =
        _database.select(_database.reminderLinks).join([
            innerJoin(
              _database.reminders,
              _database.reminders.id.equalsExp(
                _database.reminderLinks.reminderId,
              ),
            ),
            innerJoin(
              _database.reminderOccurrences,
              _database.reminderOccurrences.reminderId.equalsExp(
                _database.reminderLinks.reminderId,
              ),
            ),
          ])
          ..where(
            _database.reminderLinks.entityType.equals(entityType) &
                _database.reminderLinks.entityId.equals(entityId) &
                _database.reminders.isDeleted.equals(false),
          )
          ..orderBy([
            OrderingTerm(expression: _database.reminderOccurrences.scheduledAt),
          ])
          ..limit(50);
    final rows = await query.get();
    final linkDisplays = await findLinkDisplaysForEntity(entityType, entityId);
    return [
      for (final row in rows)
        ReminderListItem(
          reminder: row.readTable(_database.reminders),
          occurrence: row.readTable(_database.reminderOccurrences),
          links: linkDisplays,
        ),
    ];
  }

  Future<List<ReminderLinkDisplay>> findLinkDisplaysForEntity(
    String entityType,
    int entityId,
  ) async {
    if (entityType != 'employee') {
      final rows =
          await (_database.select(_database.reminderLinks)..where(
                (table) =>
                    table.entityType.equals(entityType) &
                    table.entityId.equals(entityId),
              ))
              .get();
      return [
        for (final row in rows)
          ReminderLinkDisplay(
            entityType: row.entityType,
            entityId: row.entityId,
            displayName: row.displayNameSnapshot,
          ),
      ];
    }
    final employee = await _database.findEmployeeById(entityId);
    final rows =
        await (_database.select(_database.reminderLinks)..where(
              (table) =>
                  table.entityType.equals(entityType) &
                  table.entityId.equals(entityId),
            ))
            .get();
    return [
      for (final row in rows)
        ReminderLinkDisplay(
          entityType: row.entityType,
          entityId: row.entityId,
          displayName: employee?.name ?? row.displayNameSnapshot,
          status: employee?.status.name,
        ),
    ];
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

  Future<List<ReminderOccurrence>> findOccurrences(
    int reminderId, {
    bool includeHistory = true,
  }) {
    final query = _database.select(_database.reminderOccurrences)
      ..where((table) => table.reminderId.equals(reminderId));
    if (!includeHistory) {
      query.where((table) => table.status.equals('pending'));
    }
    query.orderBy([
      (table) =>
          OrderingTerm(expression: table.scheduledAt, mode: OrderingMode.desc),
    ]);
    return query.get();
  }

  Future<ReminderOccurrence?> findOccurrenceById(int id) {
    return (_database.select(
      _database.reminderOccurrences,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Future<List<ReminderAlertRule>> findAlertRules(int reminderId) {
    return (_database.select(_database.reminderAlertRules)
          ..where(
            (table) =>
                table.reminderId.equals(reminderId) &
                table.isEnabled.equals(true),
          )
          ..orderBy([
            (table) => OrderingTerm(expression: table.sortOrder),
            (table) => OrderingTerm(expression: table.offsetMinutes),
          ]))
        .get();
  }

  Future<List<ReminderLinkDisplay>> findLinkDisplays(int reminderId) async {
    final map = await _loadLinkDisplays([reminderId]);
    return map[reminderId] ?? const [];
  }

  Future<Reminder> save({int? id, required ReminderDraft draft}) async {
    final title = draft.title.trim();
    if (title.isEmpty) throw ArgumentError('提醒标题不能为空');
    if (draft.leadDays < 0 || draft.leadDays > 365) {
      throw ArgumentError('提前天数须在 0 到 365 天之间');
    }
    if (draft.repeatCount != null &&
        (draft.repeatCount! < 1 || draft.repeatCount! > 10000)) {
      throw ArgumentError('重复次数须在 1 到 10000 之间');
    }
    final now = DateTime.now();
    final offsets = _normalizeOffsets(draft);
    final legacyLeadDays = _legacyLeadDays(draft.leadDays, offsets);
    final normalizedRepeatRule = _normalizeRepeatRule(
      draft.repeatRule,
      draft.dueDate,
    );
    final values = RemindersCompanion(
      title: Value(title),
      reminderType: Value(draft.reminderType),
      priority: Value(_validPriority(draft.priority)),
      category: Value(_validCategory(draft.category)),
      dueDate: Value(draft.dueDate),
      leadDays: Value(legacyLeadDays),
      repeatRule: Value(_nullable(normalizedRepeatRule)),
      repeatMode: Value(draft.repeatMode),
      repeatEndsAt: Value(draft.repeatEndsAt),
      repeatCount: Value(draft.repeatCount),
      timezoneId: Value(_nullable(draft.timezoneId)),
      isEnabled: Value(draft.isEnabled),
      sourceEntityType: Value(_nullable(draft.sourceEntityType)),
      sourceEntityId: Value(draft.sourceEntityId),
      remark: Value(_nullable(draft.remark)),
      updatedAt: Value(now),
      isDeleted: const Value(false),
    );
    late final int reminderId;
    await _database.transaction(() async {
      if (id != null) {
        final existing = await findById(id);
        if (existing == null) throw StateError('提醒不存在或已被删除');
        reminderId = id;
        await (_database.update(
          _database.reminders,
        )..where((table) => table.id.equals(id))).write(values);
        await _removeFuturePendingOccurrences(id);
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
          await _removeFuturePendingOccurrences(existing.id);
        } else {
          reminderId = await _database
              .into(_database.reminders)
              .insert(
                RemindersCompanion.insert(
                  title: title,
                  reminderType: draft.reminderType,
                  priority: Value(_validPriority(draft.priority)),
                  category: Value(_validCategory(draft.category)),
                  dueDate: Value(draft.dueDate),
                  leadDays: Value(legacyLeadDays),
                  repeatRule: Value(_nullable(normalizedRepeatRule)),
                  repeatMode: Value(draft.repeatMode),
                  repeatEndsAt: Value(draft.repeatEndsAt),
                  repeatCount: Value(draft.repeatCount),
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
      await _replaceAlertRules(
        reminderId,
        offsets: offsets,
        isEnabled: draft.isEnabled,
        nagRepeatIntervalMinutes: draft.nagRepeatIntervalMinutes,
        nagMaxRepeatCount: draft.nagMaxRepeatCount,
        nagEndsAfterMinutes: draft.nagEndsAfterMinutes,
        now: now,
      );
      await _ensureOccurrencesInTransaction(reminderId, now: now);
      if (draft.links != null) {
        await _replaceLinks(reminderId, draft.links!, now: now);
      }
    });
    final reminder = await findById(reminderId);
    if (reminder == null) throw StateError('提醒保存后无法读取');
    return reminder;
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
        repeatRule: 'RRULE:FREQ=MONTHLY',
        category: 'general',
        alertOffsetsMinutes: [-leadDays * 1440],
      ),
    );
  }

  Future<void> ensureOccurrences(int reminderId) async {
    final reminder = await findById(reminderId);
    if (reminder == null) return;
    await _database.transaction(
      () => _ensureOccurrencesInTransaction(reminderId),
    );
  }

  Future<void> complete(int id, {bool completed = true}) async {
    final occurrence = await _currentOccurrence(id);
    if (occurrence == null) {
      await (_database.update(
        _database.reminders,
      )..where((table) => table.id.equals(id))).write(
        RemindersCompanion(
          isCompleted: Value(completed),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return;
    }
    await completeOccurrence(occurrence.id, completed: completed);
    // Existing business modules use the legacy series flag as a coarse
    // “action required” marker. Keep it in sync for that API while the task
    // UI uses occurrence rows as the source of truth.
    await (_database.update(_database.reminders)..where(
          (table) => table.id.equals(id),
        ))
        .write(
          RemindersCompanion(
            isCompleted: Value(completed),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<void> completeOccurrence(
    int occurrenceId, {
    bool completed = true,
  }) async {
    final occurrence = await findOccurrenceById(occurrenceId);
    if (occurrence == null) return;
    final now = DateTime.now();
    await (_database.update(
      _database.reminderOccurrences,
    )..where((table) => table.id.equals(occurrenceId))).write(
      ReminderOccurrencesCompanion(
        status: Value(completed ? 'completed' : 'pending'),
        completedAt: Value(completed ? now : null),
        snoozedUntil: const Value(null),
        updatedAt: Value(now),
      ),
    );
    final reminder = await findById(occurrence.reminderId);
    if (reminder != null &&
        (reminder.repeatRule == null || reminder.repeatRule!.isEmpty)) {
      await (_database.update(
        _database.reminders,
      )..where((table) => table.id.equals(reminder.id))).write(
        RemindersCompanion(
          isCompleted: Value(completed),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Future<void> skipOccurrence(int occurrenceId) async {
    final now = DateTime.now();
    final occurrence = await findOccurrenceById(occurrenceId);
    if (occurrence == null) return;
    await (_database.update(
      _database.reminderOccurrences,
    )..where((table) => table.id.equals(occurrenceId))).write(
      ReminderOccurrencesCompanion(
        status: const Value('skipped'),
        completedAt: const Value(null),
        snoozedUntil: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> snoozeOccurrence(int occurrenceId, DateTime until) async {
    final occurrence = await findOccurrenceById(occurrenceId);
    if (occurrence == null || until.isBefore(DateTime.now())) return;
    await (_database.update(
      _database.reminderOccurrences,
    )..where((table) => table.id.equals(occurrenceId))).write(
      ReminderOccurrencesCompanion(
        snoozedUntil: Value(until),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setEnabled(int id, bool enabled) async {
    await (_database.update(
      _database.reminders,
    )..where((table) => table.id.equals(id))).write(
      RemindersCompanion(
        isEnabled: Value(enabled),
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

  Future<void> replaceLinks(
    int reminderId,
    List<ReminderLinkDraft> links,
  ) async {
    await _replaceLinks(reminderId, links, now: DateTime.now());
  }

  Future<void> _ensureOccurrencesInTransaction(
    int reminderId, {
    DateTime? now,
  }) async {
    final reminder = await findById(reminderId);
    if (reminder?.dueDate == null) return;
    final existing = await (_database.select(
      _database.reminderOccurrences,
    )..where((table) => table.reminderId.equals(reminderId))).get();
    final current = now ?? DateTime.now();
    if (existing.isEmpty) {
      await _database
          .into(_database.reminderOccurrences)
          .insert(
            ReminderOccurrencesCompanion.insert(
              reminderId: reminderId,
              scheduledAt: reminder!.dueDate!,
              status: Value(reminder.isCompleted ? 'completed' : 'pending'),
              completedAt: Value(
                reminder.isCompleted ? reminder.updatedAt : null,
              ),
              createdAt: Value(current),
              updatedAt: Value(current),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
    final updated = await findById(reminderId);
    if (updated == null || updated.repeatRule?.isEmpty != false) return;
    final dates = _recurrenceService.generateOccurrences(
      updated,
      from: current,
    );
    for (final date in dates) {
      await _database
          .into(_database.reminderOccurrences)
          .insert(
            ReminderOccurrencesCompanion.insert(
              reminderId: reminderId,
              scheduledAt: date,
              createdAt: Value(current),
              updatedAt: Value(current),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  Future<void> _removeFuturePendingOccurrences(int reminderId) {
    return (_database.delete(_database.reminderOccurrences)..where(
          (table) =>
              table.reminderId.equals(reminderId) &
              table.status.equals('pending'),
        ))
        .go();
  }

  Future<ReminderOccurrence?> _currentOccurrence(int reminderId) {
    return (_database.select(_database.reminderOccurrences)
          ..where(
            (table) =>
                table.reminderId.equals(reminderId) &
                table.status.equals('pending'),
          )
          ..orderBy([(table) => OrderingTerm(expression: table.scheduledAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> _replaceAlertRules(
    int reminderId, {
    required List<int> offsets,
    required bool isEnabled,
    required int? nagRepeatIntervalMinutes,
    required int? nagMaxRepeatCount,
    required int? nagEndsAfterMinutes,
    required DateTime now,
  }) async {
    await (_database.delete(
      _database.reminderAlertRules,
    )..where((table) => table.reminderId.equals(reminderId))).go();
    var order = 0;
    for (final offset in offsets) {
      await _database
          .into(_database.reminderAlertRules)
          .insert(
            ReminderAlertRulesCompanion.insert(
              reminderId: reminderId,
              offsetMinutes: Value(offset),
              sortOrder: Value(order++),
              isEnabled: Value(isEnabled),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }
    if (nagRepeatIntervalMinutes != null ||
        nagMaxRepeatCount != null ||
        nagEndsAfterMinutes != null) {
      await _database
          .into(_database.reminderAlertRules)
          .insert(
            ReminderAlertRulesCompanion.insert(
              reminderId: reminderId,
              isNagRule: const Value(true),
              repeatIntervalMinutes: Value(nagRepeatIntervalMinutes ?? 1440),
              maxRepeatCount: Value(nagMaxRepeatCount),
              nagEndsAfterMinutes: Value(nagEndsAfterMinutes),
              sortOrder: Value(order),
              isEnabled: Value(isEnabled),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }
  }

  Future<void> _replaceLinks(
    int reminderId,
    List<ReminderLinkDraft> links, {
    required DateTime now,
  }) async {
    await (_database.delete(
      _database.reminderLinks,
    )..where((table) => table.reminderId.equals(reminderId))).go();
    for (final link in links) {
      final name = link.displayNameSnapshot.trim();
      if (name.isEmpty) continue;
      await _database
          .into(_database.reminderLinks)
          .insert(
            ReminderLinksCompanion.insert(
              reminderId: reminderId,
              entityType: link.entityType,
              entityId: link.entityId,
              displayNameSnapshot: name,
              createdAt: Value(now),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  Future<Map<int, List<ReminderLinkDisplay>>> _loadLinkDisplays(
    List<int> reminderIds,
  ) async {
    if (reminderIds.isEmpty) return const {};
    final rows = await (_database.select(
      _database.reminderLinks,
    )..where((table) => table.reminderId.isIn(reminderIds))).get();
    final employeeIds = rows
        .where((row) => row.entityType == 'employee')
        .map((row) => row.entityId)
        .toSet();
    final employees = employeeIds.isEmpty
        ? const <Employee>[]
        : await (_database.select(
            _database.employees,
          )..where((table) => table.id.isIn(employeeIds))).get();
    final employeeMap = {
      for (final employee in employees) employee.id: employee,
    };
    final result = <int, List<ReminderLinkDisplay>>{};
    for (final row in rows) {
      final employee = employeeMap[row.entityId];
      result
          .putIfAbsent(row.reminderId, () => [])
          .add(
            ReminderLinkDisplay(
              entityType: row.entityType,
              entityId: row.entityId,
              displayName: employee?.name ?? row.displayNameSnapshot,
              status: employee?.status.name,
            ),
          );
    }
    return result;
  }

  List<int> _normalizeOffsets(ReminderDraft draft) {
    final values = draft.alertOffsetsMinutes ?? [-draft.leadDays * 1440];
    final unique =
        values.where((value) => value >= -525600 && value <= 0).toSet().toList()
          ..sort();
    return unique.isEmpty ? const [0] : unique;
  }

  int _legacyLeadDays(int fallback, List<int> offsets) {
    final first = offsets.firstWhere((value) => value < 0, orElse: () => 0);
    return first == 0 ? fallback : (-first ~/ 1440);
  }

  String _validPriority(String value) =>
      ReminderOptions.priorities.contains(value) ? value : 'normal';

  String _validCategory(String value) =>
      ReminderOptions.categories.contains(value) ? value : 'general';

  String? _normalizeRepeatRule(String? value, DateTime? dueDate) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty || normalized == 'none') {
      return null;
    }
    if (normalized.startsWith('RRULE:')) return normalized;
    final date = dueDate ?? DateTime.now();
    return switch (normalized.toLowerCase()) {
      'daily' => 'RRULE:FREQ=DAILY',
      'weekly' => 'RRULE:FREQ=WEEKLY;BYDAY=${_weekdayCode(date.weekday)}',
      'monthly' => 'RRULE:FREQ=MONTHLY;BYMONTHDAY=${date.day}',
      'quarterly' => 'RRULE:FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=${date.day}',
      'yearly' =>
        'RRULE:FREQ=YEARLY;BYMONTH=${date.month};BYMONTHDAY=${date.day}',
      _ => normalized,
    };
  }

  String _weekdayCode(int weekday) =>
      const {
        1: 'MO',
        2: 'TU',
        3: 'WE',
        4: 'TH',
        5: 'FR',
        6: 'SA',
        7: 'SU',
      }[weekday] ??
      'MO';

  String? _nullable(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
