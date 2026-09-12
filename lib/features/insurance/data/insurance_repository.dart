import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/insurance_options.dart';

class InsuranceRepository {
  const InsuranceRepository(this._database);

  final AppDatabase _database;

  Stream<List<InsuranceProfileView>> watchProfiles() {
    final profiles = _database.insuranceProfiles;
    final employees = _database.employees;
    final query =
        _database.select(profiles).join([
            innerJoin(employees, employees.id.equalsExp(profiles.employeeId)),
          ])
          ..where(
            profiles.isDeleted.equals(false) &
                employees.isDeleted.equals(false),
          )
          ..orderBy([OrderingTerm(expression: employees.name)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          InsuranceProfileView(
            profile: row.readTable(profiles),
            employee: row.readTable(employees),
          ),
      ],
    );
  }

  Stream<List<InsuranceChangeView>> watchChanges({DateTime? month}) {
    final changes = _database.insuranceChangeRecords;
    final employees = _database.employees;
    final query =
        _database.select(changes).join([
          innerJoin(employees, employees.id.equalsExp(changes.employeeId)),
        ])..where(
          changes.isDeleted.equals(false) & employees.isDeleted.equals(false),
        );
    if (month != null) {
      final value = AppDateUtils.yearMonth(month);
      query.where(changes.effectiveMonth.equals(value));
    }
    query.orderBy([
      OrderingTerm(expression: changes.effectiveMonth, mode: OrderingMode.desc),
      OrderingTerm(expression: employees.name),
    ]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          InsuranceChangeView(
            change: row.readTable(changes),
            employee: row.readTable(employees),
          ),
      ],
    );
  }

  Future<InsuranceProfile?> findProfile(int employeeId) {
    return (_database.select(_database.insuranceProfiles)..where(
          (table) =>
              table.employeeId.equals(employeeId) &
              table.isDeleted.equals(false),
        ))
        .getSingleOrNull();
  }

  Future<InsuranceChangeRecord?> findChange(int id) => _findChange(id);

  Stream<List<InsuranceHistoryView>> watchBaseHistory({int? employeeId}) {
    final history = _database.socialSecurityBaseHistory;
    final employees = _database.employees;
    final query =
        _database.select(history).join([
            innerJoin(employees, employees.id.equalsExp(history.employeeId)),
          ])
          ..where(
            history.isDeleted.equals(false) & employees.isDeleted.equals(false),
          )
          ..orderBy([
            OrderingTerm(
              expression: history.effectiveMonth,
              mode: OrderingMode.desc,
            ),
            OrderingTerm(
              expression: history.createdAt,
              mode: OrderingMode.desc,
            ),
          ]);
    if (employeeId != null) {
      query.where(history.employeeId.equals(employeeId));
    }
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          InsuranceHistoryView(
            history: row.readTable(history),
            employee: row.readTable(employees),
          ),
      ],
    );
  }

  Future<InsuranceProfile> saveProfile({
    required InsuranceProfileDraft draft,
  }) async {
    await _requireEmployee(draft.employeeId);
    final now = DateTime.now();
    final existing = await findProfile(draft.employeeId);
    late final int profileId;
    await _database.transaction(() async {
      if (existing == null) {
        profileId = await _database
            .into(_database.insuranceProfiles)
            .insert(
              InsuranceProfilesCompanion.insert(
                employeeId: draft.employeeId,
                isInsured: Value(draft.isInsured),
                insuranceType: Value(_nullableText(draft.insuranceType)),
                contributionBase: Value(draft.contributionBase),
                effectiveMonth: Value(_nullableText(draft.effectiveMonth)),
                remark: Value(_nullableText(draft.remark)),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else {
        profileId = existing.id;
        await (_database.update(
          _database.insuranceProfiles,
        )..where((table) => table.id.equals(existing.id))).write(
          InsuranceProfilesCompanion(
            isInsured: Value(draft.isInsured),
            insuranceType: Value(_nullableText(draft.insuranceType)),
            contributionBase: Value(draft.contributionBase),
            effectiveMonth: Value(_nullableText(draft.effectiveMonth)),
            remark: Value(_nullableText(draft.remark)),
            isDeleted: const Value(false),
            updatedAt: Value(now),
          ),
        );
      }
      await _database
          .into(_database.socialSecurityBaseHistory)
          .insert(
            SocialSecurityBaseHistoryCompanion.insert(
              employeeId: draft.employeeId,
              insuranceType: Value(_nullableText(draft.insuranceType)),
              contributionBase: Value(draft.contributionBase),
              effectiveMonth: _normalizeMonth(draft.effectiveMonth),
              source: const Value('profile'),
              createdAt: Value(now),
            ),
          );
    });
    return (_database.select(
      _database.insuranceProfiles,
    )..where((table) => table.id.equals(profileId))).getSingle();
  }

  Future<InsuranceChangeRecord> saveChange({
    int? id,
    required InsuranceChangeDraft draft,
  }) async {
    await _requireEmployee(draft.employeeId);
    final month = _normalizeMonth(draft.effectiveMonth);
    final current = id == null ? null : await _findChange(id);
    if (id != null && current == null) {
      throw StateError('保险变更记录不存在或已被删除');
    }
    if (current != null && current.employeeId != draft.employeeId) {
      throw StateError('编辑保险变更时不能更换人员');
    }
    final now = DateTime.now();
    late final int changeId;
    await _database.transaction(() async {
      if (id == null) {
        changeId = await _database
            .into(_database.insuranceChangeRecords)
            .insert(
              InsuranceChangeRecordsCompanion.insert(
                employeeId: draft.employeeId,
                changeType: draft.changeType,
                processingStatus: Value(draft.processingStatus),
                insuranceType: Value(_nullableText(draft.insuranceType)),
                contributionBase: Value(draft.contributionBase),
                effectiveMonth: month,
                remark: Value(_nullableText(draft.remark)),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else {
        changeId = id;
        await (_database.update(
          _database.insuranceChangeRecords,
        )..where((table) => table.id.equals(id))).write(
          InsuranceChangeRecordsCompanion(
            changeType: Value(draft.changeType),
            processingStatus: Value(draft.processingStatus),
            insuranceType: Value(_nullableText(draft.insuranceType)),
            contributionBase: Value(draft.contributionBase),
            effectiveMonth: Value(month),
            remark: Value(_nullableText(draft.remark)),
            isDeleted: const Value(false),
            updatedAt: Value(now),
          ),
        );
      }
      if (draft.processingStatus == 'completed') {
        await _applyCompletedChange(
          employeeId: draft.employeeId,
          changeType: draft.changeType,
          insuranceType: draft.insuranceType,
          contributionBase: draft.contributionBase,
          effectiveMonth: month,
          now: now,
        );
      }
    });
    return (_database.select(
      _database.insuranceChangeRecords,
    )..where((table) => table.id.equals(changeId))).getSingle();
  }

  Future<void> updateChangeStatus(int id, String processingStatus) async {
    final change = await _findChange(id);
    if (change == null) throw StateError('保险变更记录不存在或已被删除');
    final now = DateTime.now();
    await _database.transaction(() async {
      await (_database.update(
        _database.insuranceChangeRecords,
      )..where((table) => table.id.equals(id))).write(
        InsuranceChangeRecordsCompanion(
          processingStatus: Value(processingStatus),
          updatedAt: Value(now),
        ),
      );
      if (processingStatus == 'completed') {
        await _applyCompletedChange(
          employeeId: change.employeeId,
          changeType: change.changeType,
          insuranceType: change.insuranceType,
          contributionBase: change.contributionBase,
          effectiveMonth: change.effectiveMonth,
          now: now,
        );
      }
    });
  }

  Future<void> deleteChange(int id) async {
    final change = await _findChange(id);
    if (change == null) throw StateError('保险变更记录不存在或已被删除');
    await (_database.update(
      _database.insuranceChangeRecords,
    )..where((table) => table.id.equals(id))).write(
      InsuranceChangeRecordsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _applyCompletedChange({
    required int employeeId,
    required String changeType,
    required String? insuranceType,
    required double? contributionBase,
    required String effectiveMonth,
    required DateTime now,
  }) async {
    final current = await findProfile(employeeId);
    final isInsured = changeType == 'stop'
        ? false
        : changeType == 'enroll' || changeType == 'restore'
        ? true
        : current?.isInsured ?? false;
    final nextType = changeType == 'stop'
        ? current?.insuranceType
        : _nullableText(insuranceType) ?? current?.insuranceType;
    final nextBase = contributionBase ?? current?.contributionBase;
    final values = InsuranceProfileDraft(
      employeeId: employeeId,
      isInsured: isInsured,
      insuranceType: nextType,
      contributionBase: nextBase,
      effectiveMonth: effectiveMonth,
      remark: current?.remark,
    );
    await _upsertProfileWithoutHistory(values, now);
    await _database
        .into(_database.socialSecurityBaseHistory)
        .insert(
          SocialSecurityBaseHistoryCompanion.insert(
            employeeId: employeeId,
            insuranceType: Value(_nullableText(nextType)),
            contributionBase: Value(nextBase),
            effectiveMonth: effectiveMonth,
            source: Value('change:$changeType'),
            createdAt: Value(now),
          ),
        );
  }

  Future<void> _upsertProfileWithoutHistory(
    InsuranceProfileDraft draft,
    DateTime now,
  ) async {
    final existing = await findProfile(draft.employeeId);
    final values = InsuranceProfilesCompanion(
      isInsured: Value(draft.isInsured),
      insuranceType: Value(_nullableText(draft.insuranceType)),
      contributionBase: Value(draft.contributionBase),
      effectiveMonth: Value(_nullableText(draft.effectiveMonth)),
      remark: Value(_nullableText(draft.remark)),
      isDeleted: const Value(false),
      updatedAt: Value(now),
    );
    if (existing == null) {
      await _database
          .into(_database.insuranceProfiles)
          .insert(
            InsuranceProfilesCompanion.insert(
              employeeId: draft.employeeId,
              isInsured: Value(draft.isInsured),
              insuranceType: Value(_nullableText(draft.insuranceType)),
              contributionBase: Value(draft.contributionBase),
              effectiveMonth: Value(_nullableText(draft.effectiveMonth)),
              remark: Value(_nullableText(draft.remark)),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    } else {
      await (_database.update(
        _database.insuranceProfiles,
      )..where((table) => table.id.equals(existing.id))).write(values);
    }
  }

  Future<Employee> _requireEmployee(int employeeId) async {
    final employee = await _database.findEmployeeById(employeeId);
    if (employee == null || employee.isDeleted) {
      throw StateError('人员不存在或已被移除');
    }
    return employee;
  }

  Future<InsuranceChangeRecord?> _findChange(int id) {
    return (_database.select(_database.insuranceChangeRecords)..where(
          (table) => table.id.equals(id) & table.isDeleted.equals(false),
        ))
        .getSingleOrNull();
  }

  String _normalizeMonth(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return AppDateUtils.yearMonth(DateTime.now());
    return AppDateUtils.yearMonth(AppDateUtils.parseYearMonth(text));
  }

  String? _nullableText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
