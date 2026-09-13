// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/payroll_calculator.dart';
import '../domain/payroll_options.dart';

class WageJobTypeDraft {
  const WageJobTypeDraft({
    required this.name,
    required this.defaultDailyWage,
    this.isActive = true,
    this.sortOrder = 0,
    this.remark,
  });

  final String name;
  final double defaultDailyWage;
  final bool isActive;
  final int sortOrder;
  final String? remark;
}

class WageRateDraft {
  const WageRateDraft({
    required this.jobTypeId,
    required this.dailyWage,
    required this.effectiveMonth,
    this.remark,
  });

  final int jobTypeId;
  final double dailyWage;
  final String effectiveMonth;
  final String? remark;
}

class EmployeeWageProfileDraft {
  const EmployeeWageProfileDraft({
    required this.employeeId,
    required this.participatesInPayroll,
    this.jobTypeId,
    this.useJobDefaultWage = true,
    this.personalDailyWage,
    this.remark,
  });

  final int employeeId;
  final bool participatesInPayroll;
  final int? jobTypeId;
  final bool useJobDefaultWage;
  final double? personalDailyWage;
  final String? remark;
}

class WageSettingsRepository {
  const WageSettingsRepository(this._database);

  final AppDatabase _database;

  Future<void> ensureDefaultJobTypes() async {
    final existing = await (_database.select(
      _database.wageJobTypes,
    )..where((table) => table.isDeleted.equals(false))).get();
    if (existing.isNotEmpty) return;
    final now = DateTime.now();
    await _database.transaction(() async {
      for (
        var index = 0;
        index < PayrollOptions.defaultJobTypes.length;
        index++
      ) {
        await _database
            .into(_database.wageJobTypes)
            .insert(
              WageJobTypesCompanion.insert(
                name: PayrollOptions.defaultJobTypes[index],
                defaultDailyWage: const Value(0),
                sortOrder: Value(index),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }
    });
  }

  Stream<List<WageJobType>> watchJobTypes({bool includeInactive = true}) {
    final query = _database.select(_database.wageJobTypes)
      ..where((table) => table.isDeleted.equals(false))
      ..orderBy([
        (table) => OrderingTerm(expression: table.sortOrder),
        (table) => OrderingTerm(expression: table.name),
      ]);
    if (!includeInactive) {
      query.where((table) => table.isActive.equals(true));
    }
    return query.watch();
  }

  Future<WageJobType> saveJobType({
    int? id,
    required WageJobTypeDraft draft,
  }) async {
    _validateMoney(draft.defaultDailyWage);
    final name = draft.name.trim();
    if (name.isEmpty) throw const FormatException('工种名称不能为空');
    final normalizedWage = PayrollCalculator.roundMoney(draft.defaultDailyWage);
    final now = DateTime.now();
    if (id == null) {
      final newId = await _database
          .into(_database.wageJobTypes)
          .insert(
            WageJobTypesCompanion.insert(
              name: name,
              defaultDailyWage: Value(normalizedWage),
              isActive: Value(draft.isActive),
              sortOrder: Value(draft.sortOrder),
              remark: Value(_nullable(draft.remark)),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _record(
        operationType: 'create_wage_job_type',
        entityType: 'wage_job_type',
        entityId: newId,
        detail: {
          'name': name,
          'defaultDailyWage': normalizedWage,
          'isActive': draft.isActive,
        },
      );
      return _findJobType(newId);
    }
    final old = await _findJobType(id);
    await (_database.update(
      _database.wageJobTypes,
    )..where((table) => table.id.equals(id))).write(
      WageJobTypesCompanion(
        name: Value(name),
        defaultDailyWage: Value(normalizedWage),
        isActive: Value(draft.isActive),
        sortOrder: Value(draft.sortOrder),
        remark: Value(_nullable(draft.remark)),
        isDeleted: const Value(false),
        updatedAt: Value(now),
      ),
    );
    await _record(
      operationType: 'update_wage_job_type',
      entityType: 'wage_job_type',
      entityId: id,
      detail: {
        'old': {
          'name': old.name,
          'defaultDailyWage': old.defaultDailyWage,
          'isActive': old.isActive,
        },
        'new': {
          'name': name,
          'defaultDailyWage': normalizedWage,
          'isActive': draft.isActive,
        },
      },
    );
    return _findJobType(id);
  }

  Future<void> deactivateJobType(int id) async {
    final old = await _findJobType(id);
    await (_database.update(
      _database.wageJobTypes,
    )..where((table) => table.id.equals(id))).write(
      WageJobTypesCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _record(
      operationType: 'deactivate_wage_job_type',
      entityType: 'wage_job_type',
      entityId: id,
      detail: {'oldIsActive': old.isActive, 'newIsActive': false},
    );
  }

  Future<void> activateJobType(int id) async {
    final old = await _findJobType(id);
    if (old.isActive) return;
    await (_database.update(
      _database.wageJobTypes,
    )..where((table) => table.id.equals(id))).write(
      WageJobTypesCompanion(
        isActive: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _record(
      operationType: 'activate_wage_job_type',
      entityType: 'wage_job_type',
      entityId: id,
      detail: {'oldIsActive': old.isActive, 'newIsActive': true},
    );
  }

  Future<WageRateHistoryData> saveRate(WageRateDraft draft) async {
    _validateMoney(draft.dailyWage);
    final normalizedWage = PayrollCalculator.roundMoney(draft.dailyWage);
    final month = _normalizeMonth(draft.effectiveMonth);
    final now = DateTime.now();
    final existing =
        await (_database.select(_database.wageRateHistory)..where(
              (table) =>
                  table.jobTypeId.equals(draft.jobTypeId) &
                  table.effectiveMonth.equals(month),
            ))
            .getSingleOrNull();
    if (existing == null) {
      final id = await _database
          .into(_database.wageRateHistory)
          .insert(
            WageRateHistoryCompanion.insert(
              jobTypeId: draft.jobTypeId,
              dailyWage: normalizedWage,
              effectiveMonth: month,
              remark: Value(_nullable(draft.remark)),
              createdAt: Value(now),
            ),
          );
      await _record(
        operationType: 'create_wage_rate',
        entityType: 'wage_rate_history',
        entityId: id,
        detail: {
          'jobTypeId': draft.jobTypeId,
          'effectiveMonth': month,
          'dailyWage': normalizedWage,
        },
      );
      return (_database.select(
        _database.wageRateHistory,
      )..where((table) => table.id.equals(id))).getSingle();
    }
    await (_database.update(
      _database.wageRateHistory,
    )..where((table) => table.id.equals(existing.id))).write(
      WageRateHistoryCompanion(
        dailyWage: Value(normalizedWage),
        remark: Value(_nullable(draft.remark)),
      ),
    );
    await _record(
      operationType: 'update_wage_rate',
      entityType: 'wage_rate_history',
      entityId: existing.id,
      detail: {
        'jobTypeId': draft.jobTypeId,
        'effectiveMonth': month,
        'oldDailyWage': existing.dailyWage,
        'newDailyWage': normalizedWage,
      },
    );
    return (_database.select(
      _database.wageRateHistory,
    )..where((table) => table.id.equals(existing.id))).getSingle();
  }

  Stream<List<WageRateHistoryData>> watchRates(int jobTypeId) {
    return (_database.select(_database.wageRateHistory)
          ..where(
            (table) =>
                table.jobTypeId.equals(jobTypeId) &
                table.isDeleted.equals(false),
          )
          ..orderBy([
            (table) => OrderingTerm(
              expression: table.effectiveMonth,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  Future<EmployeeWageProfile?> findProfile(int employeeId) {
    return (_database.select(_database.employeeWageProfiles)..where(
          (table) =>
              table.employeeId.equals(employeeId) &
              table.isDeleted.equals(false),
        ))
        .getSingleOrNull();
  }

  Future<EmployeeWageProfile> saveProfile(
    EmployeeWageProfileDraft draft,
  ) async {
    if (!draft.useJobDefaultWage && draft.personalDailyWage == null) {
      throw const FormatException('未使用工种默认日薪时，必须填写个人特殊日薪');
    }
    if (draft.personalDailyWage != null)
      _validateMoney(draft.personalDailyWage!);
    final normalizedPersonalWage = draft.personalDailyWage == null
        ? null
        : PayrollCalculator.roundMoney(draft.personalDailyWage!);
    final employee = await _database.findEmployeeById(draft.employeeId);
    if (employee == null || employee.isDeleted) throw StateError('人员不存在或已被移除');
    final now = DateTime.now();
    final existing = await findProfile(draft.employeeId);
    if (existing == null) {
      final id = await _database
          .into(_database.employeeWageProfiles)
          .insert(
            EmployeeWageProfilesCompanion.insert(
              employeeId: draft.employeeId,
              participatesInPayroll: Value(draft.participatesInPayroll),
              jobTypeId: Value(draft.jobTypeId),
              useJobDefaultWage: Value(draft.useJobDefaultWage),
              personalDailyWage: Value(normalizedPersonalWage),
              remark: Value(_nullable(draft.remark)),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _record(
        operationType: 'create_employee_wage_profile',
        entityType: 'employee_wage_profile',
        entityId: id,
        detail: {
          'employeeId': draft.employeeId,
          'participatesInPayroll': draft.participatesInPayroll,
          'jobTypeId': draft.jobTypeId,
          'useJobDefaultWage': draft.useJobDefaultWage,
          'personalDailyWage': normalizedPersonalWage,
        },
      );
      return (_database.select(
        _database.employeeWageProfiles,
      )..where((table) => table.id.equals(id))).getSingle();
    }
    await (_database.update(
      _database.employeeWageProfiles,
    )..where((table) => table.id.equals(existing.id))).write(
      EmployeeWageProfilesCompanion(
        participatesInPayroll: Value(draft.participatesInPayroll),
        jobTypeId: Value(draft.jobTypeId),
        useJobDefaultWage: Value(draft.useJobDefaultWage),
        personalDailyWage: Value(normalizedPersonalWage),
        remark: Value(_nullable(draft.remark)),
        isDeleted: const Value(false),
        updatedAt: Value(now),
      ),
    );
    await _record(
      operationType: 'update_employee_wage_profile',
      entityType: 'employee_wage_profile',
      entityId: existing.id,
      detail: {
        'employeeId': draft.employeeId,
        'old': {
          'participatesInPayroll': existing.participatesInPayroll,
          'jobTypeId': existing.jobTypeId,
          'useJobDefaultWage': existing.useJobDefaultWage,
          'personalDailyWage': existing.personalDailyWage,
        },
        'new': {
          'participatesInPayroll': draft.participatesInPayroll,
          'jobTypeId': draft.jobTypeId,
          'useJobDefaultWage': draft.useJobDefaultWage,
          'personalDailyWage': normalizedPersonalWage,
        },
      },
    );
    return (_database.select(
      _database.employeeWageProfiles,
    )..where((table) => table.id.equals(existing.id))).getSingle();
  }

  Future<WageJobType> _findJobType(int id) {
    return (_database.select(
      _database.wageJobTypes,
    )..where((table) => table.id.equals(id))).getSingle();
  }

  String _normalizeMonth(String value) =>
      AppDateUtils.yearMonth(AppDateUtils.parseYearMonth(value));

  String? _nullable(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  void _validateMoney(double value) {
    if (!value.isFinite || value < 0)
      throw const FormatException('金额必须是大于等于 0 的有效数字');
  }

  Future<void> _record({
    required String operationType,
    required String entityType,
    required int entityId,
    required Map<String, Object?> detail,
  }) async {
    await _database
        .into(_database.operationLogs)
        .insert(
          OperationLogsCompanion.insert(
            operationType: operationType,
            entityType: entityType,
            entityId: Value(entityId),
            detail: Value(jsonEncode(detail)),
          ),
        );
  }
}
