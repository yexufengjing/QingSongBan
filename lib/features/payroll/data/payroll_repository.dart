// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../../reminders/data/reminder_repository.dart';
import '../../reminders/domain/reminder_options.dart';
import '../domain/payroll_calculator.dart';
import '../domain/payroll_models.dart';
import '../domain/payroll_options.dart';
import 'payroll_validation_service.dart';

class PayrollRepository {
  const PayrollRepository(this._database);

  final AppDatabase _database;

  Stream<List<PayrollBatche>> watchBatches() {
    return (_database.select(_database.payrollBatches)
          ..where((table) => table.isDeleted.equals(false))
          ..orderBy([
            (table) => OrderingTerm(
              expression: table.payrollMonth,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  Future<PayrollBatche?> findBatch(int id) {
    return (_database.select(_database.payrollBatches)..where(
          (table) => table.id.equals(id) & table.isDeleted.equals(false),
        ))
        .getSingleOrNull();
  }

  Future<PayrollBatche?> findBatchByMonth(String yearMonth) {
    final month = _normalizeMonth(yearMonth);
    return (_database.select(
      _database.payrollBatches,
    )..where((table) => table.payrollMonth.equals(month))).getSingleOrNull();
  }

  Stream<List<PayrollItemWithEmployee>> watchItems(int batchId) {
    final items = _database.payrollItems;
    final employees = _database.employees;
    final query =
        _database.select(items).join([
            leftOuterJoin(employees, employees.id.equalsExp(items.employeeId)),
          ])
          ..where(items.payrollBatchId.equals(batchId))
          ..orderBy([OrderingTerm(expression: items.displayOrder)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          PayrollItemWithEmployee(
            item: row.readTable(items),
            employee: row.readTableOrNull(employees),
          ),
      ],
    );
  }

  Future<List<AttendanceGroup>> listGroupsForBatch(int batchId) async {
    final batch = await _requireBatch(batchId);
    final rosterRows =
        await (_database.select(_database.monthlyAttendanceRosters)..where(
              (table) =>
                  table.yearMonth.equals(batch.payrollMonth) &
                  table.isActive.equals(true) &
                  table.isDeleted.equals(false),
            ))
            .get();
    final groupIds = rosterRows.map((row) => row.attendanceGroupId).toSet();
    if (groupIds.isEmpty) return const <AttendanceGroup>[];
    return (_database.select(_database.attendanceGroups)
          ..where(
            (table) => table.id.isIn(groupIds) & table.isDeleted.equals(false),
          )
          ..orderBy([
            (table) => OrderingTerm(expression: table.sortOrder),
            (table) => OrderingTerm(expression: table.name),
          ]))
        .get();
  }

  Future<Map<int, Set<int>>> employeeGroupIdsForBatch(int batchId) async {
    final batch = await _requireBatch(batchId);
    final rosterRows =
        await (_database.select(_database.monthlyAttendanceRosters)..where(
              (table) =>
                  table.yearMonth.equals(batch.payrollMonth) &
                  table.isActive.equals(true) &
                  table.isDeleted.equals(false),
            ))
            .get();
    final result = <int, Set<int>>{};
    for (final row in rosterRows) {
      result
          .putIfAbsent(row.employeeId, () => <int>{})
          .add(row.attendanceGroupId);
    }
    return result;
  }

  Future<PayrollItemWithEmployee> findItemWithEmployee(int itemId) async {
    final items = _database.payrollItems;
    final employees = _database.employees;
    final row = await (_database.select(items).join([
      leftOuterJoin(employees, employees.id.equalsExp(items.employeeId)),
    ])..where(items.id.equals(itemId))).getSingleOrNull();
    if (row == null) throw StateError('工资明细不存在');
    return PayrollItemWithEmployee(
      item: row.readTable(items),
      employee: row.readTableOrNull(employees),
    );
  }

  Stream<List<PayrollHistoryEntry>> watchEmployeeHistory(int employeeId) {
    final items = _database.payrollItems;
    final batches = _database.payrollBatches;
    final query =
        _database.select(items).join([
            innerJoin(batches, batches.id.equalsExp(items.payrollBatchId)),
          ])
          ..where(
            items.employeeId.equals(employeeId) &
                items.isManuallyRemoved.equals(false) &
                batches.isDeleted.equals(false),
          )
          ..orderBy([
            OrderingTerm(
              expression: batches.payrollMonth,
              mode: OrderingMode.desc,
            ),
          ]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          PayrollHistoryEntry(
            batch: row.readTable(batches),
            item: row.readTable(items),
          ),
      ],
    );
  }

  Future<PayrollBatche> ensureDraft(String yearMonth) async {
    final month = _normalizeMonth(yearMonth);
    final existing = await findBatchByMonth(month);
    if (existing != null) {
      if (existing.isDeleted) {
        await (_database.update(
          _database.payrollBatches,
        )..where((table) => table.id.equals(existing.id))).write(
          PayrollBatchesCompanion(
            isDeleted: const Value(false),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await _record(
          operationType: 'restore_payroll_batch',
          entityType: 'payroll_batch',
          entityId: existing.id,
          detail: {'oldIsDeleted': true, 'newIsDeleted': false},
        );
      }
      return (await findBatch(existing.id))!;
    }
    final now = DateTime.now();
    final id = await _database
        .into(_database.payrollBatches)
        .insert(
          PayrollBatchesCompanion.insert(
            payrollMonth: month,
            name: '${month.substring(0, 4)}年${month.substring(5)}月临时工工资',
            status: const Value(PayrollStatus.draft),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _record(
      operationType: 'create_payroll_batch',
      entityType: 'payroll_batch',
      entityId: id,
      detail: {'payrollMonth': month},
    );
    await _syncReminder(await findBatch(id));
    return (await findBatch(id))!;
  }

  Future<PayrollBatche> generateRoster(int batchId) async {
    final batch = await _requireBatch(batchId);
    _requireEditable(batch);
    final source = await _loadAttendanceSource(batch.payrollMonth);
    final candidates = <int, PayrollCandidate>{};
    for (final summary in source.summaries) {
      if (summary.attendanceDays <= 0) continue;
      final employee = source.employees[summary.employeeId];
      if (employee == null ||
          employee.isDeleted ||
          employee.employmentType != '临时工') {
        continue;
      }
      final profile = await _findProfile(employee.id);
      if (profile != null && !profile.participatesInPayroll) continue;
      final candidate = PayrollCandidate(
        employee: employee,
        attendanceHalfDays: (summary.attendanceDays * 2).round(),
        summaryId: summary.id,
      );
      final previous = candidates[employee.id];
      if (previous == null ||
          candidate.attendanceHalfDays > previous.attendanceHalfDays) {
        candidates[employee.id] = candidate;
      }
    }
    final candidateList = candidates.values.toList();

    final result = await _database.transaction(() async {
      final existing = await _listItems(batchId);
      if (existing.isEmpty) {
        final previous = await _findPreviousBatch(batch.payrollMonth);
        if (previous != null) {
          final previousItems = await _listItems(previous.id);
          final previousOrder = <int, int>{
            for (final item in previousItems)
              item.employeeId: item.displayOrder,
          };
          candidateList.sort((first, second) {
            final firstOrder = previousOrder[first.employee.id];
            final secondOrder = previousOrder[second.employee.id];
            if (firstOrder == null && secondOrder == null)
              return first.employee.id.compareTo(second.employee.id);
            if (firstOrder == null) return 1;
            if (secondOrder == null) return -1;
            return firstOrder.compareTo(secondOrder);
          });
        }
      }
      final byEmployee = {for (final item in existing) item.employeeId: item};
      var nextOrder =
          existing.fold<int>(
            -1,
            (value, item) =>
                value > item.displayOrder ? value : item.displayOrder,
          ) +
          1;
      for (final candidate in candidateList) {
        final old = byEmployee[candidate.employee.id];
        if (old == null) {
          final item = await _insertItem(
            batch: batch,
            candidate: candidate,
            displayOrder: nextOrder++,
          );
          byEmployee[candidate.employee.id] = item;
        } else {
          await _updateAttendanceForItem(
            old,
            candidate.attendanceHalfDays,
            changed:
                candidate.attendanceHalfDays != old.attendanceHalfDaysSnapshot,
          );
        }
      }
      for (final item in existing) {
        if (!candidates.containsKey(item.employeeId) &&
            !item.isManuallyAdded &&
            !item.isManuallyRemoved) {
          await (_database.update(
            _database.payrollItems,
          )..where((table) => table.id.equals(item.id))).write(
            const PayrollItemsCompanion(isManuallyRemoved: Value(true)),
          );
        }
      }
      await _updateBatchSnapshot(batchId, source.version);
      await _recalculateBatch(batchId);
      await _record(
        operationType: 'generate_payroll_roster',
        entityType: 'payroll_batch',
        entityId: batchId,
        detail: {
          'oldEmployeeIds': existing.map((item) => item.employeeId).toList(),
          'newEmployeeIds': candidates.keys.toList(),
          'candidateCount': candidates.length,
        },
      );
      return (await findBatch(batchId))!;
    });
    await _syncReminder(result);
    return result;
  }

  Future<PayrollItem> addEmployee({
    required int batchId,
    required int employeeId,
  }) async {
    final batch = await _requireBatch(batchId);
    _requireEditable(batch);
    final employee = await _database.findEmployeeById(employeeId);
    if (employee == null || employee.isDeleted) throw StateError('人员不存在或已被移除');
    if (employee.employmentType != '临时工') {
      throw StateError('只有临时工可以加入临时工工资名单');
    }
    final old =
        await (_database.select(_database.payrollItems)..where(
              (table) =>
                  table.payrollBatchId.equals(batchId) &
                  table.employeeId.equals(employeeId),
            ))
            .getSingleOrNull();
    if (old != null) {
      if (old.isManuallyRemoved) {
        await (_database.update(
          _database.payrollItems,
        )..where((table) => table.id.equals(old.id))).write(
          PayrollItemsCompanion(
            isManuallyRemoved: const Value(false),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await _record(
          operationType: 'restore_payroll_employee',
          entityType: 'payroll_item',
          entityId: old.id,
          detail: {
            'old': {'isManuallyRemoved': true},
            'new': {'isManuallyRemoved': false},
            'employeeId': employeeId,
          },
        );
        await _recalculateBatch(batchId);
      }
      return _findItem(old.id);
    }
    final source = await _loadAttendanceSource(batch.payrollMonth);
    final candidate = await _candidateForEmployee(employee, source);
    final items = await _listItems(batchId);
    final order =
        items.fold<int>(
          -1,
          (value, item) =>
              value > item.displayOrder ? value : item.displayOrder,
        ) +
        1;
    final item = await _insertItem(
      batch: batch,
      candidate: candidate,
      displayOrder: order,
      manuallyAdded: true,
    );
    await _recalculateBatch(batchId);
    await _record(
      operationType: 'add_payroll_employee',
      entityType: 'payroll_item',
      entityId: item.id,
      detail: {
        'old': null,
        'new': {'employeeId': employeeId, 'isManuallyRemoved': false},
      },
    );
    return item;
  }

  Future<void> setItemRemoved({
    required int itemId,
    required bool removed,
  }) async {
    final item = await _findItem(itemId);
    final batch = await _requireBatch(item.payrollBatchId);
    _requireEditable(batch);
    await (_database.update(
      _database.payrollItems,
    )..where((table) => table.id.equals(itemId))).write(
      PayrollItemsCompanion(
        isManuallyRemoved: Value(removed),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _recalculateBatch(batch.id);
    await _record(
      operationType: removed
          ? 'remove_payroll_employee'
          : 'restore_payroll_employee',
      entityType: 'payroll_item',
      entityId: itemId,
      detail: {
        'old': {'isManuallyRemoved': item.isManuallyRemoved},
        'new': {'isManuallyRemoved': removed},
      },
    );
  }

  Future<PayrollItem> updateItem({
    required int itemId,
    double? dailyWage,
    double? subsidy,
    double? insuranceDeduction,
    String? remark,
    int? jobTypeId,
    String? jobTypeNameSnapshot,
  }) async {
    final old = await _findItem(itemId);
    final batch = await _requireBatch(old.payrollBatchId);
    _requireEditable(batch);
    final nextDailyWage = dailyWage == null ? old.dailyWage : _money(dailyWage);
    final nextSubsidy = subsidy == null ? old.subsidy : _money(subsidy);
    final nextInsurance = insuranceDeduction == null
        ? old.insuranceDeduction
        : _money(insuranceDeduction);
    final calculation = PayrollCalculator.calculate(
      attendanceHalfDays: old.attendanceHalfDaysSnapshot,
      dailyWage: nextDailyWage,
      subsidy: nextSubsidy,
      insuranceDeduction: nextInsurance,
    );
    await (_database.update(
      _database.payrollItems,
    )..where((table) => table.id.equals(itemId))).write(
      PayrollItemsCompanion(
        jobTypeId: jobTypeId == null ? const Value.absent() : Value(jobTypeId),
        jobTypeNameSnapshot: jobTypeNameSnapshot == null
            ? const Value.absent()
            : Value(jobTypeNameSnapshot),
        dailyWage: Value(nextDailyWage),
        dailyWageSource: dailyWage == null
            ? const Value.absent()
            : const Value('batch'),
        baseWage: Value(calculation.baseWage),
        subsidy: Value(nextSubsidy),
        insuranceDeduction: Value(nextInsurance),
        finalWage: Value(calculation.finalWage),
        remark: Value(remark == null ? old.remark : _nullable(remark)),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _recalculateBatch(batch.id);
    await _record(
      operationType: 'update_payroll_item',
      entityType: 'payroll_item',
      entityId: itemId,
      detail: {
        'old': {
          'dailyWage': old.dailyWage,
          'subsidy': old.subsidy,
          'insuranceDeduction': old.insuranceDeduction,
        },
        'new': {
          'dailyWage': nextDailyWage,
          'subsidy': nextSubsidy,
          'insuranceDeduction': nextInsurance,
        },
      },
    );
    return _findItem(itemId);
  }

  Future<void> reorder({
    required int batchId,
    required List<int> itemIds,
  }) async {
    final batch = await _requireBatch(batchId);
    _requireEditable(batch);
    final existing = await _listItems(batchId);
    final existingIds = existing.map((item) => item.id).toSet();
    if (itemIds.toSet().length != itemIds.length ||
        !existingIds.containsAll(itemIds)) {
      throw const FormatException('工资名单排序数据无效');
    }
    final ordered = [...itemIds, ...existingIds.difference(itemIds.toSet())];
    await _database.transaction(() async {
      for (var index = 0; index < ordered.length; index++) {
        await (_database.update(
          _database.payrollItems,
        )..where((table) => table.id.equals(ordered[index]))).write(
          PayrollItemsCompanion(
            displayOrder: Value(index),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
      await _record(
        operationType: 'reorder_payroll_items',
        entityType: 'payroll_batch',
        entityId: batchId,
        detail: {
          'oldItemIds': existing.map((item) => item.id).toList(),
          'newItemIds': ordered,
        },
      );
    });
  }

  Future<int> attendanceHalfDaysForEmployee({
    required int batchId,
    required int employeeId,
  }) async {
    final batch = await _requireBatch(batchId);
    final source = await _loadAttendanceSource(batch.payrollMonth);
    return source.candidates[employeeId]?.attendanceHalfDays ?? 0;
  }

  Future<PayrollBatche> syncAttendance(int batchId) async {
    final batch = await _requireBatch(batchId);
    _requireEditable(batch);
    final source = await _loadAttendanceSource(batch.payrollMonth);
    final items = await _listItems(batchId);
    for (final item in items) {
      final candidate = source.candidates[item.employeeId];
      await _updateAttendanceForItem(
        item,
        candidate?.attendanceHalfDays ?? 0,
        changed: false,
      );
    }
    await _updateBatchSnapshot(batchId, source.version);
    await _recalculateBatch(batchId);
    await _record(
      operationType: 'sync_payroll_attendance',
      entityType: 'payroll_batch',
      entityId: batchId,
      detail: {
        'oldAttendanceSnapshotVersion': batch.attendanceSnapshotVersion,
        'newAttendanceSnapshotVersion': source.version,
      },
    );
    return (await findBatch(batchId))!;
  }

  Future<PayrollValidationResult> validate(int batchId) async {
    final batch = await _requireBatch(batchId);
    final source = await _loadAttendanceSource(batch.payrollMonth);
    final result = await _validateBatch(batch, source);
    if (batch.status == PayrollStatus.draft) {
      await (_database.update(
        _database.payrollBatches,
      )..where((table) => table.id.equals(batchId))).write(
        PayrollBatchesCompanion(
          status: const Value(PayrollStatus.pendingReview),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
    await _syncReminder(
      await findBatch(batchId),
      attendanceChanged: source.version != batch.attendanceSnapshotVersion,
    );
    return result;
  }

  Future<PayrollValidationResult> previewValidation(int batchId) async {
    final batch = await _requireBatch(batchId);
    final source = await _loadAttendanceSource(batch.payrollMonth);
    final result = await _validateBatch(batch, source);
    await _syncReminder(
      batch,
      attendanceChanged: source.version != batch.attendanceSnapshotVersion,
    );
    return result;
  }

  Future<void> setStatus({
    required int batchId,
    required PayrollStatus status,
    String? reason,
  }) async {
    var batch = await _requireBatch(batchId);
    if (status == PayrollStatus.confirmed) {
      final validation = await validate(batchId);
      if (!validation.canConfirm)
        throw StateError(
          validation.errors.map((item) => item.message).join('；'),
        );
      if (validation.warnings.isNotEmpty &&
          (reason == null || reason.trim().isEmpty)) {
        throw StateError('存在工资警告，请填写确认说明后继续');
      }
      batch = await _requireBatch(batchId);
    }
    if ((batch.status == PayrollStatus.confirmed ||
            batch.status == PayrollStatus.locked) &&
        status == PayrollStatus.pendingReview &&
        (reason == null || reason.trim().isEmpty)) {
      throw const FormatException('撤销确认或解锁前请填写原因');
    }
    if (batch.status == PayrollStatus.locked &&
        status != PayrollStatus.pendingReview)
      throw StateError('工资批次已锁定，请先解锁');
    if (status == PayrollStatus.locked &&
        batch.status != PayrollStatus.confirmed)
      throw StateError('工资批次必须先确认后才能锁定');
    _requireValidStatusTransition(batch.status, status);
    final now = DateTime.now();
    await _database.transaction(() async {
      await (_database.update(
        _database.payrollBatches,
      )..where((table) => table.id.equals(batchId))).write(
        PayrollBatchesCompanion(
          status: Value(status),
          confirmedAt: switch (status) {
            PayrollStatus.confirmed => Value(now),
            PayrollStatus.locked => Value(batch.confirmedAt),
            _ => const Value(null),
          },
          lockedAt: status == PayrollStatus.locked
              ? Value(now)
              : const Value(null),
          updatedAt: Value(now),
        ),
      );
      await _record(
        operationType: _statusOperation(batch.status, status),
        entityType: 'payroll_batch',
        entityId: batchId,
        detail: {
          'old': batch.status.name,
          'new': status.name,
          'reason': reason?.trim(),
        },
      );
    });
    await _syncReminder(await findBatch(batchId));
  }

  Future<void> deleteDraft(int batchId) async {
    final batch = await _requireBatch(batchId);
    if (batch.status == PayrollStatus.confirmed ||
        batch.status == PayrollStatus.locked)
      throw StateError('已确认或已锁定工资不能删除');
    await (_database.update(
      _database.payrollBatches,
    )..where((table) => table.id.equals(batchId))).write(
      PayrollBatchesCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _record(
      operationType: 'delete_payroll_draft',
      entityType: 'payroll_batch',
      entityId: batchId,
      detail: {
        'old': {'isDeleted': false, 'status': batch.status.name},
        'new': {'isDeleted': true},
      },
    );
    final reminder = await ReminderRepository(_database)
        .findBySource('payroll_batch', batchId);
    if (reminder != null) {
      await ReminderRepository(_database).delete(reminder.id);
    }
  }

  Future<PayrollBatche?> _findPreviousBatch(String yearMonth) {
    final month = AppDateUtils.parseYearMonth(yearMonth);
    final previous = DateTime(month.year, month.month - 1);
    return findBatchByMonth(AppDateUtils.yearMonth(previous));
  }

  Future<PayrollBatche> _requireBatch(int id) async {
    final batch = await findBatch(id);
    if (batch == null) throw StateError('工资批次不存在或已被删除');
    return batch;
  }

  void _requireEditable(PayrollBatche batch) {
    if (batch.status == PayrollStatus.confirmed ||
        batch.status == PayrollStatus.locked)
      throw StateError('工资批次已确认，请先撤销确认');
  }

  Future<PayrollItem?> _findItemOrNull(int id) => (_database.select(
    _database.payrollItems,
  )..where((table) => table.id.equals(id))).getSingleOrNull();

  Future<PayrollItem> _findItem(int id) async {
    final item = await _findItemOrNull(id);
    if (item == null) throw StateError('工资明细不存在');
    return item;
  }

  Future<List<PayrollItem>> _listItems(int batchId) =>
      (_database.select(_database.payrollItems)
            ..where((table) => table.payrollBatchId.equals(batchId))
            ..orderBy([
              (table) => OrderingTerm(expression: table.displayOrder),
            ]))
          .get();

  Future<PayrollItem> _insertItem({
    required PayrollBatche batch,
    required PayrollCandidate candidate,
    required int displayOrder,
    bool manuallyAdded = false,
  }) async {
    final wage = await _resolveWage(candidate.employee.id, batch.payrollMonth);
    final calculation = PayrollCalculator.calculate(
      attendanceHalfDays: candidate.attendanceHalfDays,
      dailyWage: wage.dailyWage,
      subsidy: 0,
      insuranceDeduction: 0,
    );
    final id = await _database
        .into(_database.payrollItems)
        .insert(
          PayrollItemsCompanion.insert(
            payrollBatchId: batch.id,
            employeeId: candidate.employee.id,
            displayOrder: displayOrder,
            employeeNameSnapshot: candidate.employee.name,
            employeeNoSnapshot: candidate.employee.employeeNo,
            jobTypeId: Value(wage.jobTypeId),
            jobTypeNameSnapshot: Value(wage.jobTypeName),
            attendanceHalfDaysSnapshot: candidate.attendanceHalfDays,
            dailyWage: Value(wage.dailyWage),
            dailyWageSource: Value(wage.source),
            baseWage: Value(calculation.baseWage),
            finalWage: Value(calculation.finalWage),
            isManuallyAdded: Value(manuallyAdded),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return _findItem(id);
  }

  Future<void> _updateAttendanceForItem(
    PayrollItem item,
    int halfDays, {
    bool changed = true,
  }) async {
    final calculation = PayrollCalculator.calculate(
      attendanceHalfDays: halfDays,
      dailyWage: item.dailyWage,
      subsidy: item.subsidy,
      insuranceDeduction: item.insuranceDeduction,
    );
    await (_database.update(
      _database.payrollItems,
    )..where((table) => table.id.equals(item.id))).write(
      PayrollItemsCompanion(
        attendanceHalfDaysSnapshot: Value(halfDays),
        baseWage: Value(calculation.baseWage),
        finalWage: Value(calculation.finalWage),
        attendanceChanged: Value(changed),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _updateBatchSnapshot(int batchId, String? version) async {
    await (_database.update(
      _database.payrollBatches,
    )..where((table) => table.id.equals(batchId))).write(
      PayrollBatchesCompanion(
        attendanceSnapshotVersion: Value(version),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _recalculateBatch(int batchId) async {
    final items = (await _listItems(batchId))
        .where((item) => !item.isManuallyRemoved)
        .toList();
    await (_database.update(
      _database.payrollBatches,
    )..where((table) => table.id.equals(batchId))).write(
      PayrollBatchesCompanion(
        employeeCount: Value(items.length),
        attendanceHalfDaysTotal: Value(
          items.fold(0, (sum, item) => sum + item.attendanceHalfDaysSnapshot),
        ),
        baseWageTotal: Value(
          PayrollCalculator.roundMoney(
            items.fold(0.0, (sum, item) => sum + item.baseWage),
          ),
        ),
        subsidyTotal: Value(
          PayrollCalculator.roundMoney(
            items.fold(0.0, (sum, item) => sum + item.subsidy),
          ),
        ),
        insuranceDeductionTotal: Value(
          PayrollCalculator.roundMoney(
            items.fold(0.0, (sum, item) => sum + item.insuranceDeduction),
          ),
        ),
        finalWageTotal: Value(
          PayrollCalculator.roundMoney(
            items.fold(0.0, (sum, item) => sum + item.finalWage),
          ),
        ),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<_AttendanceSource> _loadAttendanceSource(String yearMonth) async {
    final month = _normalizeMonth(yearMonth);
    final summaries =
        await (_database.select(_database.monthlyAttendanceSummaries)..where(
              (table) =>
                  table.yearMonth.equals(month) & table.isDeleted.equals(false),
            ))
            .get();
    final employeeIds = summaries.map((row) => row.employeeId).toSet();
    final employees = await (_database.select(
      _database.employees,
    )..where((table) => table.id.isIn(employeeIds))).get();
    final byId = {for (final employee in employees) employee.id: employee};
    final candidates = <int, PayrollCandidate>{};
    for (final summary in summaries) {
      final employee = byId[summary.employeeId];
      if (employee == null) continue;
      final candidate = PayrollCandidate(
        employee: employee,
        attendanceHalfDays: (summary.attendanceDays * 2).round(),
        summaryId: summary.id,
      );
      final old = candidates[employee.id];
      if (old == null || candidate.attendanceHalfDays > old.attendanceHalfDays)
        candidates[employee.id] = candidate;
    }
    final version = _attendanceSnapshotVersion(summaries);
    return _AttendanceSource(
      summaries: summaries,
      employees: byId,
      candidates: candidates,
      version: version,
      summaryConfirmed:
          summaries.isNotEmpty &&
          summaries.every(
            (row) => row.status == MonthlySummaryStatus.confirmed,
          ),
    );
  }

  Future<PayrollCandidate> _candidateForEmployee(
    Employee employee,
    _AttendanceSource source,
  ) async {
    return source.candidates[employee.id] ??
        PayrollCandidate(
          employee: employee,
          attendanceHalfDays: 0,
          summaryId: 0,
        );
  }

  Future<EmployeeWageProfile?> _findProfile(int employeeId) =>
      (_database.select(_database.employeeWageProfiles)..where(
            (table) =>
                table.employeeId.equals(employeeId) &
                table.isDeleted.equals(false),
          ))
          .getSingleOrNull();

  Future<_WageResolution> _resolveWage(int employeeId, String month) async {
    final profile = await _findProfile(employeeId);
    if (profile == null) return const _WageResolution.none();
    final profileJobTypeId = profile.jobTypeId;
    if (profileJobTypeId == null) return const _WageResolution.none();
    final jobType =
        await (_database.select(_database.wageJobTypes)..where(
              (table) =>
                  table.id.equals(profileJobTypeId) &
                  table.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (jobType == null) return const _WageResolution.none();
    final personalDailyWage = profile.personalDailyWage;
    if (!profile.useJobDefaultWage && personalDailyWage != null) {
      return _WageResolution(
        jobType.id,
        jobType.name,
        PayrollCalculator.roundMoney(personalDailyWage),
        'personal',
      );
    }
    final rates =
        await (_database.select(_database.wageRateHistory)
              ..where(
                (table) =>
                    table.jobTypeId.equals(jobType.id) &
                    table.effectiveMonth.isSmallerOrEqualValue(month) &
                    table.isDeleted.equals(false),
              )
              ..orderBy([
                (table) => OrderingTerm(
                  expression: table.effectiveMonth,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    if (rates.isNotEmpty)
      return _WageResolution(
        jobType.id,
        jobType.name,
        PayrollCalculator.roundMoney(rates.first.dailyWage),
        'job_history',
      );
    return _WageResolution(
      jobType.id,
      jobType.name,
      PayrollCalculator.roundMoney(jobType.defaultDailyWage),
      'job_default',
    );
  }

  Future<void> _record({
    required String operationType,
    required String entityType,
    int? entityId,
    Map<String, Object?>? detail,
  }) async {
    await _database
        .into(_database.operationLogs)
        .insert(
          OperationLogsCompanion.insert(
            operationType: operationType,
            entityType: entityType,
            entityId: Value(entityId),
            detail: Value(detail == null ? null : jsonEncode(detail)),
          ),
        );
  }

  String _statusOperation(PayrollStatus oldStatus, PayrollStatus newStatus) {
    if (newStatus == PayrollStatus.confirmed) return 'confirm_payroll';
    if (newStatus == PayrollStatus.locked) return 'lock_payroll';
    if (oldStatus == PayrollStatus.locked) return 'unlock_payroll';
    if (oldStatus == PayrollStatus.confirmed)
      return 'revoke_payroll_confirmation';
    return 'update_payroll_status';
  }

  void _requireValidStatusTransition(
    PayrollStatus current,
    PayrollStatus next,
  ) {
    if (current == next) return;
    final allowed = switch (current) {
      PayrollStatus.draft => {PayrollStatus.pendingReview},
      PayrollStatus.pendingReview => {PayrollStatus.confirmed},
      PayrollStatus.confirmed => {
        PayrollStatus.locked,
        PayrollStatus.pendingReview,
      },
      PayrollStatus.locked => {PayrollStatus.pendingReview},
    };
    if (!allowed.contains(next)) {
      throw StateError(
        '工资批次不能从${PayrollOptions.statusLabel(current)}变更为${PayrollOptions.statusLabel(next)}',
      );
    }
  }

  Future<PayrollValidationResult> _validateBatch(
    PayrollBatche batch,
    _AttendanceSource source,
  ) async {
    return PayrollValidationService(_database).validate(
      batch: batch,
      items: await _listItems(batch.id),
      currentAttendanceSnapshotVersion: source.version,
      attendanceSummaryConfirmed: source.summaryConfirmed,
    );
  }

  Future<void> _syncReminder(
    PayrollBatche? batch, {
    bool attendanceChanged = false,
  }) async {
    if (batch == null || batch.isDeleted) return;
    final reminders = ReminderRepository(_database);
    final existing = await reminders.findBySource('payroll_batch', batch.id);
    if (batch.status == PayrollStatus.locked) {
      if (existing != null && !existing.isCompleted) {
        await reminders.complete(existing.id);
        // A payroll reminder is stored with a recurring schedule so that
        // unlocked batches continue to surface monthly. Once this specific
        // batch is locked, the reminder itself is complete regardless of the
        // recurring schedule used by the generic reminder workflow.
        await (_database.update(
          _database.reminders,
        )..where((table) => table.id.equals(existing.id))).write(
          RemindersCompanion(
            isCompleted: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
      return;
    }
    if (existing != null && existing.isCompleted) {
      await reminders.complete(existing.id, completed: false);
    }
    final month = AppDateUtils.parseYearMonth(batch.payrollMonth);
    final dueDate = DateTime(month.year, month.month + 1, 0);
    final title = switch ((batch.status, attendanceChanged)) {
      (_, true) => '${batch.name}考勤数据已变化',
      (PayrollStatus.draft, _) => '${batch.name}尚未完成造资',
      (PayrollStatus.pendingReview, _) => '${batch.name}待检查或确认',
      (PayrollStatus.confirmed, _) => '${batch.name}已确认待锁定',
      (PayrollStatus.locked, _) => '${batch.name}已锁定',
    };
    await reminders.save(
      id: existing?.id,
      draft: ReminderDraft(
        title: title,
        reminderType: 'payroll',
        leadDays: attendanceChanged ? 0 : 3,
        isEnabled: true,
        dueDate: attendanceChanged ? DateTime.now() : dueDate,
        repeatRule: 'monthly',
        sourceEntityType: 'payroll_batch',
        sourceEntityId: batch.id,
        remark: attendanceChanged
            ? '工资批次状态：${batch.status.name}，请同步最新考勤'
            : '工资批次状态：${batch.status.name}',
      ),
    );
  }

  double _money(double value) {
    if (!value.isFinite || value < 0)
      throw const FormatException('金额必须是大于等于 0 的有效数字');
    return PayrollCalculator.roundMoney(value);
  }

  String? _nullable(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  String _normalizeMonth(String value) =>
      AppDateUtils.yearMonth(AppDateUtils.parseYearMonth(value));
}

String? _attendanceSnapshotVersion(List<MonthlyAttendanceSummary> summaries) {
  if (summaries.isEmpty) return null;
  final snapshots = [
    for (final row in summaries)
      jsonEncode([
        row.employeeId,
        row.attendanceGroupId,
        row.participates,
        row.attendanceDays,
        row.leaveDays,
        row.absentDays,
        row.restDays,
        row.stoppedDays,
        row.overtimeCount,
        row.overtimeMinutes,
        row.monthStartStatus,
        row.monthEndStatus,
        row.joinedDuringMonth,
        row.terminatedDuringMonth,
        row.isComplete,
        row.anomalyCount,
      ]),
  ]..sort();
  return jsonEncode(snapshots);
}

class _AttendanceSource {
  const _AttendanceSource({
    required this.summaries,
    required this.employees,
    required this.candidates,
    required this.version,
    required this.summaryConfirmed,
  });

  final List<MonthlyAttendanceSummary> summaries;
  final Map<int, Employee> employees;
  final Map<int, PayrollCandidate> candidates;
  final String? version;
  final bool summaryConfirmed;
}

class _WageResolution {
  const _WageResolution(
    this.jobTypeId,
    this.jobTypeName,
    this.dailyWage,
    this.source,
  );
  const _WageResolution.none()
    : jobTypeId = null,
      jobTypeName = null,
      dailyWage = 0,
      source = 'none';

  final int? jobTypeId;
  final String? jobTypeName;
  final double dailyWage;
  final String source;
}
