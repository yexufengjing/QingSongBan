import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/item_distribution_models.dart';

class ItemDistributionRepository {
  ItemDistributionRepository(this.db);

  final AppDatabase db;

  Future<int> getSweeperCount() =>
      _getIntSetting('distribution.sweeper_count', 6);

  Future<int> getPublicCount() =>
      _getIntSetting('distribution.public_count', 1);

  Future<void> setSweeperCount(int value) =>
      _setSetting('distribution.sweeper_count', value.clamp(0, 99).toString());

  Future<void> setPublicCount(int value) =>
      _setSetting('distribution.public_count', value.clamp(0, 99).toString());

  Future<List<WelfareCandidate>> listTemporaryCandidates(String month) async {
    final rosterRows = await db
        .customSelect(
          '''
      SELECT DISTINCT e.id, e.name, e.employee_no, e.employment_type, e.status
      FROM monthly_attendance_rosters r
      JOIN employees e ON e.id = r.employee_id
      WHERE r.year_month = ?
        AND r.is_deleted = 0
        AND e.is_deleted = 0
        AND e.employment_type = '临时工'
      ORDER BY e.name
      ''',
          variables: [Variable.withString(month)],
        )
        .get();
    if (rosterRows.isNotEmpty) return _candidatesFromRows(rosterRows);

    final range = _monthRange(month);
    final fallbackRows = await db
        .customSelect(
          '''
      SELECT e.id, e.name, e.employee_no, e.employment_type, e.status
      FROM employees e
      WHERE e.is_deleted = 0
        AND e.employment_type = '临时工'
        AND e.hire_date <= ?
        AND NOT EXISTS (
          SELECT 1 FROM termination_records t
          WHERE t.employee_id = e.id
            AND t.is_deleted = 0
            AND t.termination_date < ?
        )
      ORDER BY e.name
      ''',
          variables: [
            Variable.withDateTime(range.$2),
            Variable.withDateTime(range.$1),
          ],
        )
        .get();
    return _candidatesFromRows(fallbackRows);
  }

  Future<List<WelfareCandidate>> listFormalCandidates() async {
    final rows = await db.customSelect('''
      SELECT id, name, employee_no, employment_type, status
      FROM employees
      WHERE is_deleted = 0 AND employment_type = '正式工'
      ORDER BY position, name
      ''').get();
    return _candidatesFromRows(rows);
  }

  Future<int> ensureWelfareBatch({
    required String month,
    required Set<int> temporaryEmployeeIds,
    bool includeFormalTowels = false,
  }) async {
    final batchId = await _ensureWelfareBatch(month);
    await _generateEmployeeWelfare(
      batchId: batchId,
      month: month,
      employmentType: '正式工',
      includeEmployeeIds: null,
      includeFormalTowels: includeFormalTowels,
    );
    await _generateEmployeeWelfare(
      batchId: batchId,
      month: month,
      employmentType: '临时工',
      includeEmployeeIds: temporaryEmployeeIds,
      includeFormalTowels: false,
    );

    await db.customStatement(
      '''UPDATE item_distribution_entries
         SET is_deleted = 1, updated_at = ?
         WHERE batch_id = ? AND recipient_type = 'sweeper'
           AND recipient_key = 'sweeper' AND is_deleted = 0''',
      [DateTime.now().toIso8601String(), batchId],
    );
    await _ensurePublicRecipient(batchId, month);
    return batchId;
  }

  Future<List<DistributionRecipientGroup>> listGroupsForMonth(
    String month, {
    DistributionCategory category = DistributionCategory.welfare,
  }) async {
    final rows = await db
        .customSelect(
          '''
      SELECT e.* FROM item_distribution_entries e
      JOIN item_distribution_batches b ON b.id = e.batch_id
      WHERE b.benefit_month = ? AND b.category = ?
        AND b.is_deleted = 0 AND e.is_deleted = 0
      ORDER BY e.recipient_type, e.welfare_position, e.recipient_name, e.id
      ''',
          variables: [
            Variable.withString(month),
            Variable.withString(category.name),
          ],
        )
        .get();

    final grouped = <String, List<DistributionEntry>>{};
    for (final row in rows) {
      final data = row.data;
      final entry = DistributionEntry(
        id: data['id'] as int,
        batchId: data['batch_id'] as int,
        recipientType: data['recipient_type'] as String,
        recipientKey: data['recipient_key'] as String,
        employeeId: data['employee_id'] as int?,
        recipientName: data['recipient_name'] as String,
        employmentType: data['employment_type'] as String?,
        welfarePosition: data['welfare_position'] as String?,
        itemCode: data['item_code'] as String,
        itemName: data['item_name'] as String,
        quantity: (data['quantity'] as num).toDouble(),
        unit: data['unit'] as String,
        status: data['status'] == 'received'
            ? DistributionStatus.received
            : DistributionStatus.notReceived,
        signedAt: data['signed_at'] == null
            ? null
            : DateTime.tryParse(data['signed_at'] as String),
        createdAt: data['created_at'] == null
            ? null
            : DateTime.tryParse(data['created_at'] as String),
        actualDistributionMonth: data['actual_distribution_month'] as String?,
        standardQuantity: (data['standard_quantity'] as num?)?.toDouble(),
        note: data['note'] as String?,
      );
      grouped.putIfAbsent(entry.recipientKey, () => []).add(entry);
    }

    final groups = grouped.entries.map((group) {
      final first = group.value.first;
      return DistributionRecipientGroup(
        recipientKey: group.key,
        recipientName: first.recipientName,
        recipientType: first.recipientType,
        employeeId: first.employeeId,
        employmentType: first.employmentType,
        welfarePosition: first.welfarePosition,
        entries: group.value,
      );
    }).toList();
    groups.sort((a, b) {
      final typeOrder = _recipientTypeOrder(a.recipientType)
          .compareTo(_recipientTypeOrder(b.recipientType));
      if (typeOrder != 0) return typeOrder;
      final position = (a.welfarePosition ?? '').compareTo(
        b.welfarePosition ?? '',
      );
      return position != 0
          ? position
          : a.recipientName.compareTo(b.recipientName);
    });
    return groups;
  }

  Future<DistributionSummary> summaryForMonth(String month) async {
    final groups = await listGroupsForMonth(month);
    final entries = groups.expand((group) => group.entries).toList();
    return DistributionSummary(
      recipientCount: groups.length,
      receivedCount: groups.where((group) => group.allReceived).length,
      notReceivedCount: groups.where((group) => group.hasNotReceived).length,
      entryReceivedCount: entries
          .where((entry) => entry.status == DistributionStatus.received)
          .length,
      entryNotReceivedCount: entries
          .where((entry) => entry.status == DistributionStatus.notReceived)
          .length,
    );
  }

  Future<List<DistributionRecipientGroup>> listSweeperAssignments(
    String month,
  ) async {
    final groups = await listGroupsForMonth(month);
    return groups.where((group) => group.recipientType == 'sweeper').toList();
  }

  Future<void> saveSweeperAssignments(
    String month,
    Set<int> employeeIds,
  ) async {
    final batchId = await _ensureWelfareBatch(month);
    final existingRows = await db
        .customSelect(
          '''SELECT recipient_key, status FROM item_distribution_entries
         WHERE batch_id = ? AND recipient_type = 'sweeper' AND is_deleted = 0''',
          variables: [Variable.withInt(batchId)],
        )
        .get();
    final existingKeys = existingRows
        .map((row) => row.data['recipient_key'] as String)
        .toSet();
    final selectedKeys = employeeIds.map((id) => 'sweeper:$id').toSet();
    final removedReceived = existingRows.any(
      (row) =>
          row.data['status'] == 'received' &&
          !selectedKeys.contains(row.data['recipient_key']),
    );
    if (removedReceived) {
      throw StateError('已领取的扫路车福利不能直接移除，请先改为未领取');
    }

    await db.customStatement(
      '''UPDATE item_distribution_entries SET is_deleted = 1, updated_at = ?
         WHERE batch_id = ? AND recipient_type = 'sweeper' AND is_deleted = 0''',
      [DateTime.now().toIso8601String(), batchId],
    );

    final employees = await _employeeRowsByIds(employeeIds);
    for (final employee in employees) {
      final id = employee['id'] as int;
      // The entry has a unique key even after a soft delete. Restore it when
      // a previously removed driver is selected again instead of relying on
      // INSERT OR IGNORE to create a duplicate row.
      await db.customStatement(
        '''UPDATE item_distribution_entries
           SET is_deleted = 0, recipient_name = ?, employee_id = ?,
               employment_type = ?, welfare_position = ?,
               updated_at = ?
           WHERE batch_id = ? AND recipient_key = ?
             AND item_code = 'sweeper_washing_paste' ''',
        [
          employee['name'],
          id,
          employee['employment_type'],
          employee['position'],
          DateTime.now().toIso8601String(),
          batchId,
          'sweeper:$id',
        ],
      );
      await _insertEntry(
        batchId: batchId,
        recipientType: 'sweeper',
        recipientKey: 'sweeper:$id',
        employeeId: id,
        recipientName: employee['name'] as String,
        employmentType: employee['employment_type'] as String?,
        welfarePosition: employee['position'] as String?,
        itemCode: 'sweeper_washing_paste',
        itemName: '洗衣膏',
        quantity: 1,
        unit: '袋',
        note: employee['employee_no'] as String?,
        actualDistributionMonth: _nextMonth(month),
      );
    }
    if (existingKeys.length != selectedKeys.length || existingKeys.isNotEmpty) {
      await _recordLog(
        operationType: 'distribution_assignment',
        entityType: 'sweeper_welfare',
        detail: '$month 扫路车福利分配 ${employeeIds.length} 人',
      );
    }
  }

  Future<List<WelfareCandidate>> listPublicCandidates() =>
      listFormalCandidates();

  Future<void> savePublicRecipient(String month, int employeeId) async {
    final batchId = await _ensureWelfareBatch(month);
    final employeeRows = await _employeeRowsByIds({employeeId});
    if (employeeRows.isEmpty) throw StateError('领取人不存在');
    final employee = employeeRows.first;
    await db.customStatement(
      '''UPDATE item_distribution_entries SET is_deleted = 1, updated_at = ?
         WHERE batch_id = ? AND recipient_type = 'public' AND is_deleted = 0''',
      [DateTime.now().toIso8601String(), batchId],
    );
    final count = await getPublicCount();
    if (count > 0) {
      await _insertEntry(
        batchId: batchId,
        recipientType: 'public',
        recipientKey: 'public:$employeeId',
        employeeId: employeeId,
        recipientName: employee['name'] as String,
        employmentType: employee['employment_type'] as String?,
        welfarePosition: employee['position'] as String?,
        itemCode: 'public_washing_paste',
        itemName: '洗衣膏',
        quantity: count.toDouble(),
        unit: '袋',
        note: employee['employee_no'] as String?,
        actualDistributionMonth: _nextMonth(month),
      );
    }
    await _recordLog(
      operationType: 'distribution_recipient',
      entityType: 'public_welfare',
      entityId: employeeId,
      detail: '$month 公用福利领取人改为${employee['name']}',
    );
  }

  Future<void> setSourceStatus(
    String month,
    String recipientKey,
    DistributionStatus status, {
    DistributionCategory category = DistributionCategory.welfare,
  }) async {
    final row = await db
        .customSelect(
          '''SELECT e.recipient_name, e.employment_type, e.item_name
         FROM item_distribution_entries e
         JOIN item_distribution_batches b ON b.id = e.batch_id
         WHERE b.benefit_month = ? AND b.category = ?
           AND e.recipient_key = ? AND e.is_deleted = 0 AND b.is_deleted = 0
         LIMIT 1''',
          variables: [
            Variable.withString(month),
            Variable.withString(category.name),
            Variable.withString(recipientKey),
          ],
        )
        .getSingleOrNull();
    if (row == null) return;
    final now = DateTime.now().toIso8601String();
    final value = status == DistributionStatus.received
        ? 'received'
        : 'not_received';
    final signedAt = status == DistributionStatus.received ? now : null;
    await db.customStatement(
      '''UPDATE item_distribution_entries
         SET status = ?, signed_at = ?, updated_at = ?
         WHERE recipient_key = ? AND is_deleted = 0
           AND batch_id IN (
             SELECT id FROM item_distribution_batches
             WHERE benefit_month = ? AND category = ? AND is_deleted = 0
           )''',
      [value, signedAt, now, recipientKey, month, category.name],
    );
    await _recordLog(
      operationType: status == DistributionStatus.received
          ? 'distribution_received'
          : 'distribution_not_received',
      entityType: 'welfare_source',
      detail:
          '$month ${row.data['recipient_name']} ${row.data['employment_type'] ?? row.data['item_name']}',
    );
  }

  Future<void> addReplenishment({
    required String month,
    required DistributionRecipientGroup group,
    required DistributionEntry sourceEntry,
    required String reason,
    String? note,
  }) async {
    final batchId = await _ensureWelfareBatch(month);
    final now = DateTime.now().toIso8601String();
    await _insertEntry(
      batchId: batchId,
      recipientType: group.recipientType,
      recipientKey: group.recipientKey,
      employeeId: group.employeeId,
      recipientName: group.recipientName,
      employmentType: group.employmentType,
      welfarePosition: group.welfarePosition,
      itemCode: 'replenishment:${sourceEntry.itemCode}:$now',
      itemName: '${sourceEntry.itemName}（补领）',
      quantity: sourceEntry.quantity,
      unit: sourceEntry.unit,
      note: [
        reason,
        note,
      ].whereType<String>().where((item) => item.isNotEmpty).join(' · '),
      actualDistributionMonth: _nextMonth(month),
      status: 'received',
      signedAt: now,
    );
    await _recordLog(
      operationType: 'distribution_replenishment',
      entityType: 'welfare_source',
      entityId: group.employeeId,
      detail:
          '$month ${group.recipientName} ${sourceEntry.itemName} 补领：$reason',
    );
  }

  Future<void> addFormalTowelForMonth(String month) async {
    await ensureWelfareBatch(
      month: month,
      temporaryEmployeeIds: const {},
      includeFormalTowels: true,
    );
  }

  Future<int> duplicateCount(ManualDistributionDraft draft) async {
    final row = await db
        .customSelect(
          '''SELECT COUNT(*) AS c
         FROM item_distribution_entries e
         JOIN item_distribution_batches b ON b.id = e.batch_id
         WHERE b.benefit_month = ? AND b.category = ?
           AND e.recipient_key = ? AND e.item_name = ?
           AND b.is_deleted = 0 AND e.is_deleted = 0''',
          variables: [
            Variable.withString(draft.month),
            Variable.withString(draft.category.name),
            Variable.withString(draft.recipientKey),
            Variable.withString(draft.itemName.trim()),
          ],
        )
        .getSingle();
    return row.data['c'] as int;
  }

  Future<void> addManualDistribution(ManualDistributionDraft draft) async {
    final now = DateTime.now().toIso8601String();
    final batchId = await db.customInsert(
      '''INSERT INTO item_distribution_batches
         (benefit_month, category, title, status, created_at, updated_at, is_deleted)
         VALUES (?, ?, ?, 'active', ?, ?, 0)''',
      variables: [
        Variable.withString(draft.month),
        Variable.withString(draft.category.name),
        Variable.withString(
          '${draft.month} ${draft.category == DistributionCategory.office ? '办公用品' : '工具'}领用',
        ),
        Variable.withString(now),
        Variable.withString(now),
      ],
    );
    await _insertEntry(
      batchId: batchId,
      recipientType: draft.recipientType,
      recipientKey: draft.recipientKey,
      employeeId: draft.employeeId,
      recipientName: draft.recipientName,
      employmentType: null,
      welfarePosition: null,
      itemCode: 'manual:${draft.itemName.trim()}',
      itemName: draft.itemName.trim(),
      quantity: draft.quantity,
      unit: draft.unit,
      note: draft.note,
    );
    await _recordLog(
      operationType: 'distribution_manual_add',
      entityType: draft.category.name,
      detail: '${draft.month} ${draft.recipientName} ${draft.itemName.trim()}',
    );
  }

  Future<void> deleteManualEntry(int entryId) async {
    final row = await db
        .customSelect(
          '''SELECT e.recipient_name, e.item_name, b.benefit_month, b.category
         FROM item_distribution_entries e
         JOIN item_distribution_batches b ON b.id = e.batch_id
         WHERE e.id = ? AND e.is_deleted = 0
           AND b.is_deleted = 0 AND b.category IN ('office', 'tool')''',
          variables: [Variable.withInt(entryId)],
        )
        .getSingleOrNull();
    if (row == null) return;

    final data = row.data;
    final now = DateTime.now().toIso8601String();
    await db.transaction(() async {
      await db.customStatement(
        '''UPDATE item_distribution_entries
           SET is_deleted = 1, updated_at = ?
           WHERE id = ? AND is_deleted = 0''',
        [now, entryId],
      );
      await db
          .into(db.operationLogs)
          .insert(
            OperationLogsCompanion.insert(
              operationType: 'distribution_manual_delete',
              entityType: data['category'] as String,
              entityId: Value(entryId),
              detail: Value(
                '${data['benefit_month']} ${data['recipient_name']} ${data['item_name']} 删除',
              ),
            ),
          );
    });
  }

  Future<int> _ensureWelfareBatch(String month) async {
    final existing = await db
        .customSelect(
          '''SELECT id FROM item_distribution_batches
         WHERE category = 'welfare' AND benefit_month = ? AND is_deleted = 0
         ORDER BY id DESC LIMIT 1''',
          variables: [Variable.withString(month)],
        )
        .getSingleOrNull();
    return existing?.data['id'] as int? ??
        await db.customInsert(
          '''INSERT INTO item_distribution_batches
             (benefit_month, category, title, status, created_at, updated_at, is_deleted)
             VALUES (?, 'welfare', ?, 'active', ?, ?, 0)''',
          variables: [
            Variable.withString(month),
            Variable.withString('$month 劳保福利'),
            Variable.withString(DateTime.now().toIso8601String()),
            Variable.withString(DateTime.now().toIso8601String()),
          ],
        );
  }

  Future<void> _ensurePublicRecipient(int batchId, String month) async {
    final existing = await db
        .customSelect(
          '''SELECT id, employee_id FROM item_distribution_entries
         WHERE batch_id = ? AND recipient_type = 'public' AND is_deleted = 0
         LIMIT 1''',
          variables: [Variable.withInt(batchId)],
        )
        .getSingleOrNull();
    if (existing != null && existing.data['employee_id'] != null) {
      final count = await getPublicCount();
      await db.customStatement(
        '''UPDATE item_distribution_entries
           SET quantity = ?, standard_quantity = ?, actual_distribution_month = ?,
               updated_at = ?
           WHERE id = ?''',
        [
          count,
          count,
          _nextMonth(month),
          DateTime.now().toIso8601String(),
          existing.data['id'],
        ],
      );
      return;
    }
    if (existing != null) {
      await db.customStatement(
        'UPDATE item_distribution_entries SET is_deleted = 1, updated_at = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), existing.data['id']],
      );
    }
    final count = await getPublicCount();
    if (count <= 0) return;
    final candidates = await listPublicCandidates();
    final candidate =
        candidates.where((item) => item.isCurrentlyActive).firstOrNull ??
        candidates.firstOrNull;
    if (candidate == null) {
      await _insertEntry(
        batchId: batchId,
        recipientType: 'public',
        recipientKey: 'public',
        recipientName: '待指定领取人',
        employmentType: null,
        welfarePosition: null,
        itemCode: 'public_washing_paste',
        itemName: '洗衣膏',
        quantity: count.toDouble(),
        unit: '袋',
        actualDistributionMonth: _nextMonth(month),
      );
      return;
    }
    final employees = await _employeeRowsByIds({candidate.id});
    final employee = employees.first;
    await _insertEntry(
      batchId: batchId,
      recipientType: 'public',
      recipientKey: 'public:${candidate.id}',
      employeeId: candidate.id,
      recipientName: candidate.name,
      employmentType: candidate.employmentType,
      welfarePosition: employee['position'] as String?,
      itemCode: 'public_washing_paste',
      itemName: '洗衣膏',
      quantity: count.toDouble(),
      unit: '袋',
      note: candidate.employeeNo,
      actualDistributionMonth: _nextMonth(month),
    );
  }

  Future<void> _generateEmployeeWelfare({
    required int batchId,
    required String month,
    required String employmentType,
    required Set<int>? includeEmployeeIds,
    required bool includeFormalTowels,
  }) async {
    final range = _monthRange(month);
    final allowRosterTerminatedEmployees =
        employmentType == '临时工' && includeEmployeeIds != null;
    final rows = await db
        .customSelect(
          '''SELECT e.id, e.name, e.employee_no, e.employment_type, e.position
         FROM employees e
         WHERE e.is_deleted = 0 AND e.employment_type = ?
           AND e.hire_date <= ?
           AND (
             ? = 1 OR NOT EXISTS (
               SELECT 1 FROM termination_records t
               WHERE t.employee_id = e.id AND t.is_deleted = 0
                 AND t.termination_date < ?
             )
           )
         ORDER BY e.position, e.name''',
          variables: [
            Variable.withString(employmentType),
            Variable.withDateTime(range.$2),
            Variable.withInt(allowRosterTerminatedEmployees ? 1 : 0),
            Variable.withDateTime(range.$1),
          ],
        )
        .get();

    final monthNumber = int.parse(month.substring(5, 7));
    for (final row in rows) {
      final data = row.data;
      final id = data['id'] as int;
      if (includeEmployeeIds != null && !includeEmployeeIds.contains(id)) {
        continue;
      }
      final name = data['name'] as String;
      final key = 'employee:$id';
      final rawPosition = (data['position'] as String?)?.trim();
      final position = rawPosition == null || rawPosition.isEmpty
          ? '其他'
          : rawPosition;
      await _insertEntry(
        batchId: batchId,
        recipientType: 'employee',
        recipientKey: key,
        employeeId: id,
        recipientName: name,
        employmentType: employmentType,
        welfarePosition: position,
        itemCode: 'washing_paste',
        itemName: '洗衣膏',
        quantity: 1,
        unit: '袋',
        note: data['employee_no'] as String?,
        actualDistributionMonth: _nextMonth(month),
      );
      final gloves =
          employmentType == '正式工' ||
          (employmentType == '临时工' && monthNumber.isOdd);
      if (gloves) {
        await _insertEntry(
          batchId: batchId,
          recipientType: 'employee',
          recipientKey: key,
          employeeId: id,
          recipientName: name,
          employmentType: employmentType,
          welfarePosition: position,
          itemCode: 'gloves',
          itemName: '线手套',
          quantity: 1,
          unit: '副',
          actualDistributionMonth: _nextMonth(month),
        );
      }
      final towel =
          monthNumber == 1 ||
          monthNumber == 7 ||
          (employmentType == '正式工' && includeFormalTowels);
      if (towel) {
        await _insertEntry(
          batchId: batchId,
          recipientType: 'employee',
          recipientKey: key,
          employeeId: id,
          recipientName: name,
          employmentType: employmentType,
          welfarePosition: position,
          itemCode: 'towel',
          itemName: '毛巾',
          quantity: 1,
          unit: '条',
          actualDistributionMonth: _nextMonth(month),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _employeeRowsByIds(Set<int> ids) async {
    if (ids.isEmpty) return const [];
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await db.customSelect(
      '''SELECT id, name, employee_no, employment_type, position, status
         FROM employees WHERE is_deleted = 0 AND id IN ($placeholders)''',
      variables: ids.map(Variable.withInt).toList(),
    ).get();
    return rows.map((row) => row.data).toList();
  }

  Future<void> _insertEntry({
    required int batchId,
    required String recipientType,
    required String recipientKey,
    required String recipientName,
    required String? employmentType,
    required String? welfarePosition,
    required String itemCode,
    required String itemName,
    required double quantity,
    required String unit,
    int? employeeId,
    String? note,
    String? actualDistributionMonth,
    String status = 'not_received',
    String? signedAt,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.customStatement(
      '''INSERT OR IGNORE INTO item_distribution_entries
         (batch_id, recipient_type, recipient_key, employee_id, recipient_name,
          employment_type, welfare_position, item_code, item_name, quantity,
          standard_quantity, unit, status, signed_at, actual_distribution_month, note,
          created_at, updated_at, is_deleted)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)''',
      [
        batchId,
        recipientType,
        recipientKey,
        employeeId,
        recipientName,
        employmentType,
        welfarePosition,
        itemCode,
        itemName,
        quantity,
        quantity,
        unit,
        status,
        signedAt,
        actualDistributionMonth,
        note,
        now,
        now,
      ],
    );
  }

  Future<void> _recordLog({
    required String operationType,
    required String entityType,
    int? entityId,
    required String detail,
  }) async {
    await db
        .into(db.operationLogs)
        .insert(
          OperationLogsCompanion.insert(
            operationType: operationType,
            entityType: entityType,
            entityId: Value(entityId),
            detail: Value(detail),
          ),
        );
  }

  List<WelfareCandidate> _candidatesFromRows(List<QueryRow> rows) =>
      rows.map((row) {
        final data = row.data;
        return WelfareCandidate(
          id: data['id'] as int,
          name: data['name'] as String,
          employeeNo: data['employee_no'] as String,
          employmentType: (data['employment_type'] as String?) ?? '正式工',
          isCurrentlyActive: data['status'] == 'active',
        );
      }).toList();

  int _recipientTypeOrder(String type) => switch (type) {
    'employee' => 0,
    'sweeper' => 1,
    'public' => 2,
    _ => 3,
  };

  Future<int> _getIntSetting(String key, int fallback) async {
    final row = await db
        .customSelect(
          'SELECT setting_value FROM item_distribution_settings WHERE setting_key = ?',
          variables: [Variable.withString(key)],
        )
        .getSingleOrNull();
    return int.tryParse(row?.data['setting_value'] as String? ?? '') ??
        fallback;
  }

  Future<void> _setSetting(String key, String value) async {
    await db.customStatement(
      '''INSERT INTO item_distribution_settings(setting_key, setting_value, updated_at)
         VALUES (?, ?, ?)
         ON CONFLICT(setting_key) DO UPDATE SET
           setting_value = excluded.setting_value,
           updated_at = excluded.updated_at''',
      [key, value, DateTime.now().toIso8601String()],
    );
  }

  (DateTime, DateTime) _monthRange(String month) {
    final year = int.parse(month.substring(0, 4));
    final monthNumber = int.parse(month.substring(5, 7));
    final start = DateTime(year, monthNumber, 1);
    final end = DateTime(year, monthNumber + 1, 0, 23, 59, 59, 999);
    return (start, end);
  }

  String _nextMonth(String month) {
    final date = DateTime(
      int.parse(month.substring(0, 4)),
      int.parse(month.substring(5, 7)) + 1,
    );
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
  }
}
