import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/item_distribution_models.dart';

class ItemDistributionRepository {
  ItemDistributionRepository(this.db);

  final AppDatabase db;

  Future<int> getSweeperCount() => _getIntSetting('distribution.sweeper_count', 6);
  Future<int> getPublicCount() => _getIntSetting('distribution.public_count', 1);

  Future<void> setSweeperCount(int value) => _setSetting('distribution.sweeper_count', value.toString());
  Future<void> setPublicCount(int value) => _setSetting('distribution.public_count', value.toString());

  Future<List<WelfareCandidate>> listTemporaryCandidates(String month) async {
    final range = _monthRange(month);
    final rows = await db.customSelect(
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
      variables: [Variable.withDateTime(range.$2), Variable.withDateTime(range.$1)],
    ).get();

    return rows.map((row) {
      final data = row.data;
      return WelfareCandidate(
        id: data['id'] as int,
        name: data['name'] as String,
        employeeNo: data['employee_no'] as String,
        employmentType: (data['employment_type'] as String?) ?? '临时工',
        isCurrentlyActive: data['status'] == 'active',
      );
    }).toList();
  }

  Future<int> ensureWelfareBatch({
    required String month,
    required Set<int> temporaryEmployeeIds,
    bool includeFormalTowels = false,
  }) async {
    final existing = await db.customSelect(
      '''SELECT id FROM item_distribution_batches
         WHERE category = 'welfare' AND benefit_month = ? AND is_deleted = 0
         ORDER BY id DESC LIMIT 1''',
      variables: [Variable.withString(month)],
    ).getSingleOrNull();

    final batchId = existing?.data['id'] as int? ?? await db.customInsert(
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

    final sweeperCount = await getSweeperCount();
    if (sweeperCount > 0) {
      await _insertEntry(
        batchId: batchId,
        recipientType: 'sweeper',
        recipientKey: 'sweeper',
        recipientName: '扫路车辆',
        employmentType: null,
        itemCode: 'washing_paste',
        itemName: '洗衣膏',
        quantity: sweeperCount.toDouble(),
        unit: '袋',
      );
    }

    final publicCount = await getPublicCount();
    if (publicCount > 0) {
      await _insertEntry(
        batchId: batchId,
        recipientType: 'public',
        recipientKey: 'public',
        recipientName: '公用',
        employmentType: null,
        itemCode: 'washing_paste',
        itemName: '洗衣膏',
        quantity: publicCount.toDouble(),
        unit: '袋',
      );
    }

    return batchId;
  }

  Future<void> _generateEmployeeWelfare({
    required int batchId,
    required String month,
    required String employmentType,
    required Set<int>? includeEmployeeIds,
    required bool includeFormalTowels,
  }) async {
    final range = _monthRange(month);
    final rows = await db.customSelect(
      '''
      SELECT e.id, e.name, e.employee_no, e.employment_type
      FROM employees e
      WHERE e.is_deleted = 0
        AND e.employment_type = ?
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
        Variable.withString(employmentType),
        Variable.withDateTime(range.$2),
        Variable.withDateTime(range.$1),
      ],
    ).get();

    final monthNumber = int.parse(month.substring(5, 7));
    for (final row in rows) {
      final id = row.data['id'] as int;
      if (includeEmployeeIds != null && !includeEmployeeIds.contains(id)) continue;
      final name = row.data['name'] as String;
      final employeeNo = row.data['employee_no'] as String;
      final key = 'employee:$id';

      await _insertEntry(
        batchId: batchId,
        recipientType: 'employee',
        recipientKey: key,
        employeeId: id,
        recipientName: name,
        employmentType: employmentType,
        itemCode: 'washing_paste',
        itemName: '洗衣膏',
        quantity: 1,
        unit: '袋',
        note: employeeNo,
      );

      final gloves = employmentType == '正式工' || (employmentType == '临时工' && monthNumber.isOdd);
      if (gloves) {
        await _insertEntry(
          batchId: batchId,
          recipientType: 'employee',
          recipientKey: key,
          employeeId: id,
          recipientName: name,
          employmentType: employmentType,
          itemCode: 'gloves',
          itemName: '手套',
          quantity: 1,
          unit: '副',
        );
      }

      final towel = employmentType == '临时工'
          ? (monthNumber == 1 || monthNumber == 7)
          : includeFormalTowels;
      if (towel) {
        await _insertEntry(
          batchId: batchId,
          recipientType: 'employee',
          recipientKey: key,
          employeeId: id,
          recipientName: name,
          employmentType: employmentType,
          itemCode: 'towel',
          itemName: '毛巾',
          quantity: 1,
          unit: '条',
        );
      }
    }
  }

  Future<List<DistributionRecipientGroup>> listGroupsForMonth(String month) async {
    final rows = await db.customSelect(
      '''
      SELECT e.* FROM item_distribution_entries e
      JOIN item_distribution_batches b ON b.id = e.batch_id
      WHERE b.benefit_month = ? AND b.is_deleted = 0 AND e.is_deleted = 0
      ORDER BY e.recipient_name, e.id
      ''',
      variables: [Variable.withString(month)],
    ).get();

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
        itemCode: data['item_code'] as String,
        itemName: data['item_name'] as String,
        quantity: (data['quantity'] as num).toDouble(),
        unit: data['unit'] as String,
        status: switch (data['status']) {
          'received' => DistributionStatus.received,
          'not_received' => DistributionStatus.notReceived,
          _ => DistributionStatus.pending,
        },
        signedAt: data['signed_at'] == null ? null : DateTime.tryParse(data['signed_at'] as String),
        note: data['note'] as String?,
      );
      grouped.putIfAbsent(entry.recipientKey, () => []).add(entry);
    }

    return grouped.entries.map((group) {
      final first = group.value.first;
      return DistributionRecipientGroup(
        recipientKey: group.key,
        recipientName: first.recipientName,
        recipientType: first.recipientType,
        employeeId: first.employeeId,
        employmentType: first.employmentType,
        entries: group.value,
      );
    }).toList();
  }

  Future<void> setRecipientStatus(String month, String recipientKey, DistributionStatus status) async {
    final value = switch (status) {
      DistributionStatus.received => 'received',
      DistributionStatus.notReceived => 'not_received',
      DistributionStatus.pending => 'pending',
    };
    final signedAt = status == DistributionStatus.received ? DateTime.now().toIso8601String() : null;
    await db.customStatement(
      '''
      UPDATE item_distribution_entries
      SET status = ?, signed_at = ?, updated_at = ?
      WHERE recipient_key = ? AND is_deleted = 0
        AND batch_id IN (
          SELECT id FROM item_distribution_batches
          WHERE benefit_month = ? AND is_deleted = 0
        )
      ''',
      [value, signedAt, DateTime.now().toIso8601String(), recipientKey, month],
    );
  }

  Future<int> duplicateCount(ManualDistributionDraft draft) async {
    final row = await db.customSelect(
      '''
      SELECT COUNT(*) AS c
      FROM item_distribution_entries e
      JOIN item_distribution_batches b ON b.id = e.batch_id
      WHERE b.benefit_month = ?
        AND e.recipient_key = ?
        AND e.item_name = ?
        AND b.is_deleted = 0 AND e.is_deleted = 0
      ''',
      variables: [
        Variable.withString(draft.month),
        Variable.withString(draft.recipientKey),
        Variable.withString(draft.itemName.trim()),
      ],
    ).getSingle();
    return row.data['c'] as int;
  }

  Future<void> addManualDistribution(ManualDistributionDraft draft) async {
    final category = draft.category.name;
    final now = DateTime.now().toIso8601String();
    final batchId = await db.customInsert(
      '''INSERT INTO item_distribution_batches
         (benefit_month, category, title, status, created_at, updated_at, is_deleted)
         VALUES (?, ?, ?, 'active', ?, ?, 0)''',
      variables: [
        Variable.withString(draft.month),
        Variable.withString(category),
        Variable.withString('${draft.month} ${draft.category == DistributionCategory.office ? '办公用品' : '工具'}领用'),
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
      itemCode: 'manual:${draft.itemName.trim()}',
      itemName: draft.itemName.trim(),
      quantity: draft.quantity,
      unit: draft.unit,
      note: draft.note,
    );
  }

  Future<void> addFormalTowelForMonth(String month) async {
    await ensureWelfareBatch(month: month, temporaryEmployeeIds: const {}, includeFormalTowels: true);
  }

  Future<DistributionSummary> summaryForMonth(String month) async {
    final groups = await listGroupsForMonth(month);
    return DistributionSummary(
      recipientCount: groups.length,
      receivedCount: groups.where((g) => g.allReceived).length,
      pendingCount: groups.where((g) => g.hasPending).length,
      notReceivedCount: groups.where((g) => g.hasNotReceived).length,
    );
  }

  Future<void> _insertEntry({
    required int batchId,
    required String recipientType,
    required String recipientKey,
    required String recipientName,
    required String? employmentType,
    required String itemCode,
    required String itemName,
    required double quantity,
    required String unit,
    int? employeeId,
    String? note,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.customStatement(
      '''
      INSERT OR IGNORE INTO item_distribution_entries
      (batch_id, recipient_type, recipient_key, employee_id, recipient_name,
       employment_type, item_code, item_name, quantity, unit, status, note,
       created_at, updated_at, is_deleted)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?, 0)
      ''',
      [
        batchId,
        recipientType,
        recipientKey,
        employeeId,
        recipientName,
        employmentType,
        itemCode,
        itemName,
        quantity,
        unit,
        note,
        now,
        now,
      ],
    );
  }

  Future<int> _getIntSetting(String key, int fallback) async {
    final row = await db.customSelect(
      'SELECT setting_value FROM item_distribution_settings WHERE setting_key = ?',
      variables: [Variable.withString(key)],
    ).getSingleOrNull();
    return int.tryParse(row?.data['setting_value'] as String? ?? '') ?? fallback;
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
}
