import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/termination_options.dart';

class TerminationRepository {
  const TerminationRepository(this._database);

  final AppDatabase _database;

  Stream<List<TerminationRecordView>> watchTerminations() {
    final terminations = _database.terminationRecords;
    final employees = _database.employees;
    final query =
        _database.select(terminations).join([
          innerJoin(employees, employees.id.equalsExp(terminations.employeeId)),
        ])..where(
          terminations.isDeleted.equals(false) &
              employees.isDeleted.equals(false),
        );
    query.orderBy([
      OrderingTerm(
        expression: terminations.terminationDate,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(expression: employees.name),
    ]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          TerminationRecordView(
            termination: row.readTable(terminations),
            employee: row.readTable(employees),
          ),
      ],
    );
  }

  Future<TerminationRecord?> findById(int id) {
    return (_database.select(_database.terminationRecords)..where(
          (table) => table.id.equals(id) & table.isDeleted.equals(false),
        ))
        .getSingleOrNull();
  }

  Future<TerminationRecord?> findActiveForEmployee(int employeeId) {
    return (_database.select(_database.terminationRecords)..where(
          (table) =>
              table.employeeId.equals(employeeId) &
              table.isDeleted.equals(false),
        ))
        .getSingleOrNull();
  }

  Future<TerminationRecord> save({
    int? id,
    required TerminationRecordDraft draft,
  }) async {
    final date = AppDateUtils.dateOnly(draft.terminationDate);
    final employee = await _database.findEmployeeById(draft.employeeId);
    if (employee == null || employee.isDeleted) {
      throw StateError('人员不存在或已被移除');
    }
    if (date.isBefore(AppDateUtils.dateOnly(employee.hireDate))) {
      throw const FormatException('离职日期不能早于入职日期');
    }
    final current = id == null ? null : await findById(id);
    if (id != null && current == null) {
      throw StateError('离职记录不存在或已被撤销');
    }
    final otherActive = await findActiveForEmployee(draft.employeeId);
    if (otherActive != null && otherActive.id != id) {
      throw const FormatException('该人员已有有效离职记录');
    }

    final now = DateTime.now();
    late final int terminationId;
    await _database.transaction(() async {
      if (id == null) {
        terminationId = await _database
            .into(_database.terminationRecords)
            .insert(
              TerminationRecordsCompanion.insert(
                employeeId: draft.employeeId,
                terminationDate: date,
                terminationType: Value(_normalizedType(draft.terminationType)),
                isInsuranceStopped: Value(draft.isInsuranceStopped),
                stopInsuranceMonth: Value(
                  _nullableText(draft.stopInsuranceMonth),
                ),
                toolsReturned: Value(draft.toolsReturned),
                materialsTransferred: Value(draft.materialsTransferred),
                hasUnsettledItems: Value(draft.hasUnsettledItems),
                remark: Value(_nullableText(draft.remark)),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else {
        terminationId = id;
        await (_database.update(
          _database.terminationRecords,
        )..where((table) => table.id.equals(id))).write(
          TerminationRecordsCompanion(
            terminationDate: Value(date),
            terminationType: Value(_normalizedType(draft.terminationType)),
            isInsuranceStopped: Value(draft.isInsuranceStopped),
            stopInsuranceMonth: Value(_nullableText(draft.stopInsuranceMonth)),
            toolsReturned: Value(draft.toolsReturned),
            materialsTransferred: Value(draft.materialsTransferred),
            hasUnsettledItems: Value(draft.hasUnsettledItems),
            remark: Value(_nullableText(draft.remark)),
            isDeleted: const Value(false),
            updatedAt: Value(now),
          ),
        );
      }
      await (_database.update(
        _database.employees,
      )..where((table) => table.id.equals(draft.employeeId))).write(
        EmployeesCompanion(
          status: const Value(EmployeeStatus.terminated),
          updatedAt: Value(now),
        ),
      );
      await _syncInsuranceReminder(
        terminationId: terminationId,
        employeeName: employee.name,
        terminationDate: date,
        stopInsuranceMonth: draft.stopInsuranceMonth,
        isInsuranceStopped: draft.isInsuranceStopped,
        now: now,
      );
    });

    return (_database.select(
      _database.terminationRecords,
    )..where((table) => table.id.equals(terminationId))).getSingle();
  }

  Future<void> revoke(int id) async {
    final record = await findById(id);
    if (record == null) {
      throw StateError('离职记录不存在或已被撤销');
    }
    await _database.transaction(() async {
      await (_database.update(
        _database.terminationRecords,
      )..where((table) => table.id.equals(id))).write(
        TerminationRecordsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
      final employee = await _database.findEmployeeById(record.employeeId);
      if (employee != null && employee.status == EmployeeStatus.terminated) {
        await (_database.update(
          _database.employees,
        )..where((table) => table.id.equals(record.employeeId))).write(
          EmployeesCompanion(
            status: const Value(EmployeeStatus.active),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
      await (_database.update(_database.reminders)..where(
            (table) =>
                table.sourceEntityType.equals('termination') &
                table.sourceEntityId.equals(id) &
                table.isDeleted.equals(false),
          ))
          .write(
            RemindersCompanion(
              isDeleted: const Value(true),
              updatedAt: Value(DateTime.now()),
            ),
          );
    });
  }

  Future<void> _syncInsuranceReminder({
    required int terminationId,
    required String employeeName,
    required DateTime terminationDate,
    required String? stopInsuranceMonth,
    required bool isInsuranceStopped,
    required DateTime now,
  }) async {
    final existing =
        await (_database.select(_database.reminders)..where(
              (table) =>
                  table.sourceEntityType.equals('termination') &
                  table.sourceEntityId.equals(terminationId) &
                  table.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (isInsuranceStopped) {
      if (existing != null) {
        await (_database.update(
          _database.reminders,
        )..where((table) => table.id.equals(existing.id))).write(
          RemindersCompanion(
            isCompleted: const Value(true),
            updatedAt: Value(now),
          ),
        );
      }
      return;
    }
    final month = _normalizeMonth(
      stopInsuranceMonth,
      fallback: terminationDate,
    );
    final dueDate = DateTime(month.year, month.month, 1, 9);
    if (existing == null) {
      await _database
          .into(_database.reminders)
          .insert(
            RemindersCompanion.insert(
              title: '办理 $employeeName 停保',
              reminderType: 'terminationInsurance',
              dueDate: Value(dueDate),
              leadDays: const Value(0),
              isEnabled: const Value(true),
              isCompleted: const Value(false),
              sourceEntityType: const Value('termination'),
              sourceEntityId: Value(terminationId),
              remark: const Value('离职停保待确认'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    } else {
      await (_database.update(
        _database.reminders,
      )..where((table) => table.id.equals(existing.id))).write(
        RemindersCompanion(
          title: Value('办理 $employeeName 停保'),
          reminderType: const Value('terminationInsurance'),
          dueDate: Value(dueDate),
          leadDays: const Value(0),
          isEnabled: const Value(true),
          isCompleted: const Value(false),
          sourceEntityType: const Value('termination'),
          sourceEntityId: Value(terminationId),
          remark: const Value('离职停保待确认'),
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );
    }
  }

  DateTime _normalizeMonth(String? value, {required DateTime fallback}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return DateTime(fallback.year, fallback.month);
    return AppDateUtils.parseYearMonth(text);
  }

  String _normalizedType(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? 'personal' : normalized;
  }

  String? _nullableText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
