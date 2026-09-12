import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/daily_attendance_options.dart';

class DailyAttendanceRepository {
  const DailyAttendanceRepository(this._database);

  final AppDatabase _database;

  Stream<List<DailyAttendanceEntryView>> watchEntries({
    required DateTime attendanceDate,
    required int groupId,
  }) {
    final date = AppDateUtils.dateOnly(attendanceDate);
    final yearMonth = AppDateUtils.yearMonth(date);
    final rosters = _database.monthlyAttendanceRosters;
    final employees = _database.employees;
    final records = _database.attendanceRecords;
    final terminations = _database.terminationRecords;
    final query =
        _database.select(rosters).join([
            innerJoin(employees, employees.id.equalsExp(rosters.employeeId)),
            leftOuterJoin(
              records,
              records.employeeId.equalsExp(rosters.employeeId) &
                  records.attendanceDate.equals(date) &
                  records.isDeleted.equals(false),
            ),
            leftOuterJoin(
              terminations,
              terminations.employeeId.equalsExp(rosters.employeeId) &
                  terminations.isDeleted.equals(false),
            ),
          ])
          ..where(
            rosters.yearMonth.equals(yearMonth) &
                rosters.attendanceGroupId.equals(groupId) &
                rosters.isActive.equals(true) &
                rosters.isDeleted.equals(false) &
                employees.isDeleted.equals(false),
          )
          ..orderBy([
            OrderingTerm(expression: employees.name),
            OrderingTerm(expression: employees.employeeNo),
          ]);

    return query.watch().map((rows) {
      return [
        for (final row in rows)
          _buildEntry(
            employee: row.readTable(employees),
            date: date,
            record: row.readTableOrNull(records),
            termination: row.readTableOrNull(terminations),
          ),
      ];
    });
  }

  Future<void> save(DailyAttendanceDraft draft) async {
    final date = AppDateUtils.dateOnly(draft.attendanceDate);
    _validateEditableStatuses(draft);
    await _database.transaction(() async {
      final employee = await _database.findEmployeeById(draft.employeeId);
      if (employee == null || employee.isDeleted) {
        throw StateError('人员不存在或已被移除');
      }
      if (_isBeforeHire(employee, date)) {
        throw StateError('人员入职前不能登记考勤');
      }
      final termination = await _findActiveTermination(employee.id);
      if (_isAfterTermination(employee, date, termination)) {
        throw StateError('已离职人员不能登记考勤');
      }
      await _upsertRecord(
        employeeId: draft.employeeId,
        date: date,
        morningStatus: draft.morningStatus,
        afternoonStatus: draft.afternoonStatus,
        remark: draft.remark,
      );
    });
  }

  Future<int> applyAction({
    required DateTime attendanceDate,
    required int groupId,
    required DailyAttendanceAction action,
  }) async {
    final date = AppDateUtils.dateOnly(attendanceDate);
    final group =
        await (_database.select(_database.attendanceGroups)..where(
              (table) =>
                  table.id.equals(groupId) &
                  table.isDeleted.equals(false) &
                  table.isEnabled.equals(true),
            ))
            .getSingleOrNull();
    if (group == null) {
      throw StateError('考勤组不存在、已停用或已被移除');
    }

    final employees = await _listRosterEmployees(date, groupId);
    return _database.transaction(() async {
      var changedCount = 0;
      for (final employee in employees) {
        if (!await _canEdit(employee, date)) continue;

        switch (action) {
          case DailyAttendanceAction.allPresent:
            await _upsertRecord(
              employeeId: employee.id,
              date: date,
              morningStatus: AttendanceHalfStatus.present,
              afternoonStatus: AttendanceHalfStatus.present,
              preserveRemark: true,
            );
            changedCount++;
          case DailyAttendanceAction.rest:
            await _upsertRecord(
              employeeId: employee.id,
              date: date,
              morningStatus: AttendanceHalfStatus.rest,
              afternoonStatus: AttendanceHalfStatus.rest,
              preserveRemark: true,
            );
            changedCount++;
          case DailyAttendanceAction.stopped:
            await _upsertRecord(
              employeeId: employee.id,
              date: date,
              morningStatus: AttendanceHalfStatus.stopped,
              afternoonStatus: AttendanceHalfStatus.stopped,
              preserveRemark: true,
            );
            changedCount++;
          case DailyAttendanceAction.copyPrevious:
            final previous = await _findRecord(
              employee.id,
              date.subtract(const Duration(days: 1)),
            );
            if (previous == null || previous.isDeleted) continue;
            await _upsertRecord(
              employeeId: employee.id,
              date: date,
              morningStatus: previous.morningStatus,
              afternoonStatus: previous.afternoonStatus,
              remark: previous.remark,
            );
            changedCount++;
        }
      }
      return changedCount;
    });
  }

  Future<List<Employee>> _listRosterEmployees(DateTime date, int groupId) {
    final rosters = _database.monthlyAttendanceRosters;
    final employees = _database.employees;
    final query =
        _database.select(employees).join([
            innerJoin(rosters, rosters.employeeId.equalsExp(employees.id)),
          ])
          ..where(
            rosters.yearMonth.equals(AppDateUtils.yearMonth(date)) &
                rosters.attendanceGroupId.equals(groupId) &
                rosters.isActive.equals(true) &
                rosters.isDeleted.equals(false) &
                employees.isDeleted.equals(false),
          )
          ..orderBy([OrderingTerm(expression: employees.name)]);
    return query.get().then(
      (rows) => [for (final row in rows) row.readTable(employees)],
    );
  }

  Future<AttendanceRecord?> _findRecord(int employeeId, DateTime date) {
    return (_database.select(_database.attendanceRecords)..where(
          (table) =>
              table.employeeId.equals(employeeId) &
              table.attendanceDate.equals(AppDateUtils.dateOnly(date)),
        ))
        .getSingleOrNull();
  }

  Future<void> _upsertRecord({
    required int employeeId,
    required DateTime date,
    required AttendanceHalfStatus morningStatus,
    required AttendanceHalfStatus afternoonStatus,
    String? remark,
    bool preserveRemark = false,
  }) async {
    final now = DateTime.now();
    final existing = await _findRecord(employeeId, date);
    final normalizedRemark = preserveRemark ? null : _nullableText(remark);
    if (existing == null) {
      await _database
          .into(_database.attendanceRecords)
          .insert(
            AttendanceRecordsCompanion.insert(
              employeeId: employeeId,
              attendanceDate: AppDateUtils.dateOnly(date),
              morningStatus: Value(morningStatus),
              afternoonStatus: Value(afternoonStatus),
              remark: preserveRemark
                  ? const Value.absent()
                  : Value(normalizedRemark),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      return;
    }

    await (_database.update(
      _database.attendanceRecords,
    )..where((table) => table.id.equals(existing.id))).write(
      AttendanceRecordsCompanion(
        morningStatus: Value(morningStatus),
        afternoonStatus: Value(afternoonStatus),
        remark: preserveRemark ? const Value.absent() : Value(normalizedRemark),
        isDeleted: const Value(false),
        updatedAt: Value(now),
      ),
    );
  }

  DailyAttendanceEntryView _buildEntry({
    required Employee employee,
    required DateTime date,
    required AttendanceRecord? record,
    required TerminationRecord? termination,
  }) {
    if (_isBeforeHire(employee, date)) {
      return DailyAttendanceEntryView(
        employee: employee,
        attendanceDate: date,
        morningStatus: AttendanceHalfStatus.notEmployed,
        afternoonStatus: AttendanceHalfStatus.notEmployed,
        remark: record?.remark,
        record: record,
        isEditable: false,
        lockReason: '入职日期为 ${AppDateUtils.formatDate(employee.hireDate)}',
      );
    }
    if (_isAfterTermination(employee, date, termination)) {
      return DailyAttendanceEntryView(
        employee: employee,
        attendanceDate: date,
        morningStatus: AttendanceHalfStatus.terminated,
        afternoonStatus: AttendanceHalfStatus.terminated,
        remark: record?.remark,
        record: record,
        isEditable: false,
        lockReason: '人员已离职，不能登记考勤',
      );
    }
    return DailyAttendanceEntryView(
      employee: employee,
      attendanceDate: date,
      morningStatus: record?.morningStatus ?? AttendanceHalfStatus.unregistered,
      afternoonStatus:
          record?.afternoonStatus ?? AttendanceHalfStatus.unregistered,
      remark: record?.remark,
      record: record,
      isEditable: true,
    );
  }

  Future<bool> _canEdit(Employee employee, DateTime date) async {
    final termination = await _findActiveTermination(employee.id);
    return !_isBeforeHire(employee, date) &&
        !_isAfterTermination(employee, date, termination);
  }

  Future<TerminationRecord?> _findActiveTermination(int employeeId) async {
    final records =
        await (_database.select(_database.terminationRecords)..where(
              (table) =>
                  table.employeeId.equals(employeeId) &
                  table.isDeleted.equals(false),
            ))
            .get();
    return records.isEmpty ? null : records.first;
  }

  bool _isAfterTermination(
    Employee employee,
    DateTime date,
    TerminationRecord? termination,
  ) {
    if (employee.status != EmployeeStatus.terminated) return false;
    if (termination == null) return true;
    return AppDateUtils.dateOnly(termination.terminationDate).isBefore(date);
  }

  bool _isBeforeHire(Employee employee, DateTime date) {
    return AppDateUtils.dateOnly(employee.hireDate).isAfter(date);
  }

  void _validateEditableStatuses(DailyAttendanceDraft draft) {
    if (!DailyAttendanceOptions.editableStatuses.contains(
          draft.morningStatus,
        ) ||
        !DailyAttendanceOptions.editableStatuses.contains(
          draft.afternoonStatus,
        )) {
      throw const FormatException('请选择有效的半天考勤状态');
    }
  }

  String? _nullableText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
