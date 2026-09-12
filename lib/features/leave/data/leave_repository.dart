import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/leave_options.dart';

class LeaveRepository {
  const LeaveRepository(this._database);

  final AppDatabase _database;

  Stream<List<LeaveRecordView>> watchLeaves({DateTime? month}) {
    final leaves = _database.leaveRecords;
    final employees = _database.employees;
    final query =
        _database.select(leaves).join([
          innerJoin(employees, employees.id.equalsExp(leaves.employeeId)),
        ])..where(
          leaves.isDeleted.equals(false) & employees.isDeleted.equals(false),
        );
    if (month != null) {
      final firstDay = DateTime(month.year, month.month);
      final lastDay = DateTime(month.year, month.month + 1, 0);
      query.where(
        leaves.startDate.isSmallerOrEqualValue(lastDay) &
            leaves.endDate.isBiggerOrEqualValue(firstDay),
      );
    }
    query.orderBy([
      OrderingTerm(expression: leaves.startDate, mode: OrderingMode.desc),
      OrderingTerm(expression: employees.name),
    ]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          LeaveRecordView(
            leave: row.readTable(leaves),
            employee: row.readTable(employees),
          ),
      ],
    );
  }

  Future<LeaveRecord?> findById(int id) {
    return (_database.select(_database.leaveRecords)..where(
          (table) => table.id.equals(id) & table.isDeleted.equals(false),
        ))
        .getSingleOrNull();
  }

  Future<LeaveRecord> save({int? id, required LeaveRecordDraft draft}) async {
    final startDate = AppDateUtils.dateOnly(draft.startDate);
    final endDate = AppDateUtils.dateOnly(draft.endDate);
    _validateDates(startDate, endDate, draft.startPeriod, draft.endPeriod);

    final employee = await _database.findEmployeeById(draft.employeeId);
    if (employee == null || employee.isDeleted) {
      throw StateError('人员不存在或已被移除');
    }
    if (startDate.isBefore(AppDateUtils.dateOnly(employee.hireDate))) {
      throw StateError('请假日期不能早于入职日期');
    }

    final previous = id == null ? null : await findById(id);
    if (id != null && previous == null) {
      throw StateError('请假记录不存在或已被删除');
    }
    if (previous != null && previous.employeeId != draft.employeeId) {
      throw StateError('编辑请假记录时不能更换人员');
    }

    final now = DateTime.now();
    late final int leaveId;
    await _database.transaction(() async {
      if (id == null) {
        leaveId = await _database
            .into(_database.leaveRecords)
            .insert(
              LeaveRecordsCompanion.insert(
                employeeId: draft.employeeId,
                leaveType: Value(draft.leaveType),
                startDate: startDate,
                endDate: endDate,
                startPeriod: Value(draft.startPeriod),
                endPeriod: Value(draft.endPeriod),
                remark: Value(_nullableText(draft.remark)),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else {
        leaveId = id;
        await (_database.update(
          _database.leaveRecords,
        )..where((table) => table.id.equals(id))).write(
          LeaveRecordsCompanion(
            leaveType: Value(draft.leaveType),
            startDate: Value(startDate),
            endDate: Value(endDate),
            startPeriod: Value(draft.startPeriod),
            endPeriod: Value(draft.endPeriod),
            remark: Value(_nullableText(draft.remark)),
            isDeleted: const Value(false),
            updatedAt: Value(now),
          ),
        );
      }

      final impactedStart = previous == null
          ? startDate
          : _minDate(previous.startDate, startDate);
      final impactedEnd = previous == null
          ? endDate
          : _maxDate(previous.endDate, endDate);
      await _syncAttendance(
        employeeId: draft.employeeId,
        startDate: impactedStart,
        endDate: impactedEnd,
      );
    });

    final result = await (_database.select(
      _database.leaveRecords,
    )..where((table) => table.id.equals(leaveId))).getSingle();
    return result;
  }

  Future<void> delete(int id) async {
    final leave = await findById(id);
    if (leave == null) {
      throw StateError('请假记录不存在或已被删除');
    }
    final now = DateTime.now();
    await _database.transaction(() async {
      await (_database.update(
        _database.leaveRecords,
      )..where((table) => table.id.equals(id))).write(
        LeaveRecordsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(now),
        ),
      );
      await _syncAttendance(
        employeeId: leave.employeeId,
        startDate: leave.startDate,
        endDate: leave.endDate,
      );
    });
  }

  Future<void> _syncAttendance({
    required int employeeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    var date = AppDateUtils.dateOnly(startDate);
    final lastDate = AppDateUtils.dateOnly(endDate);
    while (!date.isAfter(lastDate)) {
      final activeLeaves =
          await (_database.select(_database.leaveRecords)..where(
                (table) =>
                    table.employeeId.equals(employeeId) &
                    table.isDeleted.equals(false) &
                    table.startDate.isSmallerOrEqualValue(date) &
                    table.endDate.isBiggerOrEqualValue(date),
              ))
              .get();
      final morningLeave = activeLeaves.any(
        (leave) => LeaveOptions.covers(leave, date, LeaveHalfPeriod.morning),
      );
      final afternoonLeave = activeLeaves.any(
        (leave) => LeaveOptions.covers(leave, date, LeaveHalfPeriod.afternoon),
      );
      final existing =
          await (_database.select(_database.attendanceRecords)..where(
                (table) =>
                    table.employeeId.equals(employeeId) &
                    table.attendanceDate.equals(date),
              ))
              .getSingleOrNull();

      if (existing == null) {
        if (morningLeave || afternoonLeave) {
          await _database
              .into(_database.attendanceRecords)
              .insert(
                AttendanceRecordsCompanion.insert(
                  employeeId: employeeId,
                  attendanceDate: date,
                  morningStatus: Value(
                    morningLeave
                        ? AttendanceHalfStatus.leave
                        : AttendanceHalfStatus.unregistered,
                  ),
                  afternoonStatus: Value(
                    afternoonLeave
                        ? AttendanceHalfStatus.leave
                        : AttendanceHalfStatus.unregistered,
                  ),
                ),
              );
        }
      } else {
        final morningStatus = _syncedStatus(
          existing.morningStatus,
          shouldLeave: morningLeave,
        );
        final afternoonStatus = _syncedStatus(
          existing.afternoonStatus,
          shouldLeave: afternoonLeave,
        );
        if (existing.isDeleted ||
            morningStatus != existing.morningStatus ||
            afternoonStatus != existing.afternoonStatus) {
          await (_database.update(
            _database.attendanceRecords,
          )..where((table) => table.id.equals(existing.id))).write(
            AttendanceRecordsCompanion(
              morningStatus: Value(morningStatus),
              afternoonStatus: Value(afternoonStatus),
              isDeleted: const Value(false),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }
      date = date.add(const Duration(days: 1));
    }
  }

  AttendanceHalfStatus _syncedStatus(
    AttendanceHalfStatus current, {
    required bool shouldLeave,
  }) {
    if (shouldLeave) return AttendanceHalfStatus.leave;
    if (current == AttendanceHalfStatus.leave) {
      return AttendanceHalfStatus.unregistered;
    }
    return current;
  }

  void _validateDates(
    DateTime startDate,
    DateTime endDate,
    LeaveHalfPeriod startPeriod,
    LeaveHalfPeriod endPeriod,
  ) {
    if (endDate.isBefore(startDate)) {
      throw const FormatException('结束日期不能早于开始日期');
    }
    if (startDate == endDate &&
        startPeriod == LeaveHalfPeriod.afternoon &&
        endPeriod == LeaveHalfPeriod.morning) {
      throw const FormatException('同一天的请假时段无效');
    }
  }

  DateTime _minDate(DateTime first, DateTime second) => first.isBefore(second)
      ? AppDateUtils.dateOnly(first)
      : AppDateUtils.dateOnly(second);

  DateTime _maxDate(DateTime first, DateTime second) => first.isAfter(second)
      ? AppDateUtils.dateOnly(first)
      : AppDateUtils.dateOnly(second);

  String? _nullableText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
