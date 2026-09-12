import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/utils/date_utils.dart';
import '../../leave/domain/leave_options.dart';
import '../domain/monthly_summary_options.dart';

class MonthlySummaryRepository {
  const MonthlySummaryRepository(this._database);

  final AppDatabase _database;

  Stream<MonthlySummaryView> watchSummary({required String yearMonth}) {
    final normalized = _normalizeMonth(yearMonth);
    final summaries = _database.monthlyAttendanceSummaries;
    final employees = _database.employees;
    final groups = _database.attendanceGroups;
    final query =
        _database.select(summaries).join([
            innerJoin(employees, employees.id.equalsExp(summaries.employeeId)),
            leftOuterJoin(
              groups,
              groups.id.equalsExp(summaries.attendanceGroupId),
            ),
          ])
          ..where(
            summaries.yearMonth.equals(normalized) &
                summaries.isDeleted.equals(false) &
                employees.isDeleted.equals(false),
          )
          ..orderBy([
            OrderingTerm(expression: employees.name),
            OrderingTerm(expression: employees.employeeNo),
          ]);

    return query.watch().asyncMap((rows) async {
      final items = [
        for (final row in rows)
          MonthlySummaryRowView(
            summary: row.readTable(summaries),
            employee: row.readTable(employees),
            group: row.readTableOrNull(groups),
          ),
      ];
      final anomalies = await _collectAnomalies(normalized, items);
      return MonthlySummaryView(
        yearMonth: normalized,
        status: items.isEmpty
            ? MonthlySummaryStatus.notGenerated
            : items.first.summary.status,
        rows: items,
        anomalies: anomalies,
      );
    });
  }

  Future<MonthlySummaryView> generate({required String yearMonth}) async {
    final normalized = _normalizeMonth(yearMonth);
    final month = AppDateUtils.parseYearMonth(normalized);
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final existing =
        await (_database.select(_database.monthlyAttendanceSummaries)..where(
              (table) =>
                  table.yearMonth.equals(normalized) &
                  table.isDeleted.equals(false),
            ))
            .get();
    if (existing.any((row) => row.status == MonthlySummaryStatus.locked)) {
      throw StateError('本月汇总已锁定，请先解锁后再重新生成');
    }

    final rosterRows =
        await (_database.select(_database.monthlyAttendanceRosters)..where(
              (table) =>
                  table.yearMonth.equals(normalized) &
                  table.isActive.equals(true) &
                  table.isDeleted.equals(false),
            ))
            .get();
    final employeeIds = rosterRows.map((row) => row.employeeId).toSet();
    final employees =
        await (_database.select(_database.employees)..where(
              (table) =>
                  table.id.isIn(employeeIds) & table.isDeleted.equals(false),
            ))
            .get();
    final employeesById = {
      for (final employee in employees) employee.id: employee,
    };
    final anomalies = await _collectAnomalies(normalized, [
      for (final roster in rosterRows)
        if (employeesById[roster.employeeId] != null)
          MonthlySummaryRowView(
            summary: _placeholderSummary(normalized, roster),
            employee: employeesById[roster.employeeId]!,
            group: null,
          ),
    ]);
    final anomalyCountByEmployee = <int, int>{};
    for (final anomaly in anomalies) {
      anomalyCountByEmployee.update(
        anomaly.employee.id,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    await _database.transaction(() async {
      await (_database.update(_database.monthlyAttendanceSummaries)..where(
            (table) =>
                table.yearMonth.equals(normalized) &
                table.isDeleted.equals(false),
          ))
          .write(
            const MonthlyAttendanceSummariesCompanion(isDeleted: Value(true)),
          );

      final now = DateTime.now();
      final handled = <String>{};
      for (final roster in rosterRows) {
        final employee = employeesById[roster.employeeId];
        if (employee == null) continue;
        final key = '${roster.employeeId}:${roster.attendanceGroupId}';
        if (!handled.add(key)) continue;
        final records =
            await (_database.select(_database.attendanceRecords)..where(
                  (table) =>
                      table.employeeId.equals(employee.id) &
                      table.attendanceDate.isBiggerOrEqualValue(monthStart) &
                      table.attendanceDate.isSmallerOrEqualValue(monthEnd) &
                      table.isDeleted.equals(false),
                ))
                .get();
        final overtime =
            await (_database.select(_database.overtimeRecords)..where(
                  (table) =>
                      table.employeeId.equals(employee.id) &
                      table.overtimeDate.isBiggerOrEqualValue(monthStart) &
                      table.overtimeDate.isSmallerOrEqualValue(monthEnd) &
                      table.isDeleted.equals(false),
                ))
                .get();
        final termination = await _findTermination(employee.id);
        final summary = MonthlySummaryDraft(
          yearMonth: normalized,
          employeeId: employee.id,
          attendanceGroupId: roster.attendanceGroupId,
          participates: true,
          attendanceDays: _countHalfDays(records, AttendanceHalfStatus.present),
          leaveDays: _countHalfDays(records, AttendanceHalfStatus.leave),
          absentDays: _countHalfDays(records, AttendanceHalfStatus.absent),
          restDays: _countHalfDays(records, AttendanceHalfStatus.rest),
          stoppedDays: _countHalfDays(records, AttendanceHalfStatus.stopped),
          overtimeCount: overtime.length,
          overtimeMinutes: overtime.fold(
            0,
            (total, record) => total + record.durationMinutes,
          ),
          monthStartStatus: _statusAt(employee, termination, monthStart),
          monthEndStatus: _statusAt(employee, termination, monthEnd),
          joinedDuringMonth: _sameMonth(employee.hireDate, month),
          terminatedDuringMonth:
              termination != null &&
              _sameMonth(termination.terminationDate, month),
          isComplete: (anomalyCountByEmployee[employee.id] ?? 0) == 0,
          anomalyCount: anomalyCountByEmployee[employee.id] ?? 0,
        );
        final old =
            await (_database.select(
                  _database.monthlyAttendanceSummaries,
                )..where(
                  (table) =>
                      table.yearMonth.equals(normalized) &
                      table.employeeId.equals(employee.id) &
                      table.attendanceGroupId.equals(roster.attendanceGroupId),
                ))
                .getSingleOrNull();
        final values = MonthlyAttendanceSummariesCompanion(
          yearMonth: Value(summary.yearMonth),
          employeeId: Value(summary.employeeId),
          attendanceGroupId: Value(summary.attendanceGroupId),
          participates: Value(summary.participates),
          attendanceDays: Value(summary.attendanceDays),
          leaveDays: Value(summary.leaveDays),
          absentDays: Value(summary.absentDays),
          restDays: Value(summary.restDays),
          stoppedDays: Value(summary.stoppedDays),
          overtimeCount: Value(summary.overtimeCount),
          overtimeMinutes: Value(summary.overtimeMinutes),
          monthStartStatus: Value(summary.monthStartStatus),
          monthEndStatus: Value(summary.monthEndStatus),
          joinedDuringMonth: Value(summary.joinedDuringMonth),
          terminatedDuringMonth: Value(summary.terminatedDuringMonth),
          isComplete: Value(summary.isComplete),
          anomalyCount: Value(summary.anomalyCount),
          status: const Value(MonthlySummaryStatus.pendingReview),
          generatedAt: Value(now),
          updatedAt: Value(now),
          isDeleted: const Value(false),
        );
        if (old == null) {
          await _database
              .into(_database.monthlyAttendanceSummaries)
              .insert(
                MonthlyAttendanceSummariesCompanion.insert(
                  yearMonth: summary.yearMonth,
                  employeeId: summary.employeeId,
                  attendanceGroupId: Value(summary.attendanceGroupId),
                  participates: Value(summary.participates),
                  attendanceDays: Value(summary.attendanceDays),
                  leaveDays: Value(summary.leaveDays),
                  absentDays: Value(summary.absentDays),
                  restDays: Value(summary.restDays),
                  stoppedDays: Value(summary.stoppedDays),
                  overtimeCount: Value(summary.overtimeCount),
                  overtimeMinutes: Value(summary.overtimeMinutes),
                  monthStartStatus: Value(summary.monthStartStatus),
                  monthEndStatus: Value(summary.monthEndStatus),
                  joinedDuringMonth: Value(summary.joinedDuringMonth),
                  terminatedDuringMonth: Value(summary.terminatedDuringMonth),
                  isComplete: Value(summary.isComplete),
                  anomalyCount: Value(summary.anomalyCount),
                  status: const Value(MonthlySummaryStatus.pendingReview),
                  generatedAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
        } else {
          await (_database.update(
            _database.monthlyAttendanceSummaries,
          )..where((table) => table.id.equals(old.id))).write(values);
        }
      }
    });
    return watchSummary(yearMonth: normalized).first;
  }

  Future<void> setStatus({
    required String yearMonth,
    required MonthlySummaryStatus status,
    String? reason,
  }) async {
    final normalized = _normalizeMonth(yearMonth);
    final rows =
        await (_database.select(_database.monthlyAttendanceSummaries)..where(
              (table) =>
                  table.yearMonth.equals(normalized) &
                  table.isDeleted.equals(false),
            ))
            .get();
    if (rows.isEmpty) throw StateError('请先生成本月汇总');
    final current = rows.first.status;
    if (current == MonthlySummaryStatus.locked &&
        status != MonthlySummaryStatus.pendingReview) {
      throw StateError('汇总已锁定，请先解锁');
    }
    if (current == MonthlySummaryStatus.locked &&
        (reason == null || reason.trim().isEmpty)) {
      throw const FormatException('解锁前请填写原因');
    }
    await _database.transaction(() async {
      await (_database.update(_database.monthlyAttendanceSummaries)..where(
            (table) =>
                table.yearMonth.equals(normalized) &
                table.isDeleted.equals(false),
          ))
          .write(
            MonthlyAttendanceSummariesCompanion(
              status: Value(status),
              updatedAt: Value(DateTime.now()),
            ),
          );
      if (current == MonthlySummaryStatus.locked && reason != null) {
        await _database
            .into(_database.operationLogs)
            .insert(
              OperationLogsCompanion.insert(
                operationType: 'unlock',
                entityType: 'monthly_attendance_summary',
                detail: Value(reason.trim()),
              ),
            );
      }
    });
  }

  Future<List<MonthlySummaryAnomaly>> _collectAnomalies(
    String yearMonth,
    List<MonthlySummaryRowView> rows,
  ) async {
    final month = AppDateUtils.parseYearMonth(yearMonth);
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final employeeById = {
      for (final row in rows) row.employee.id: row.employee,
    };
    final anomalies = <MonthlySummaryAnomaly>[];

    for (final employee in employeeById.values) {
      final termination = await _findTermination(employee.id);
      if (termination != null &&
          AppDateUtils.dateOnly(termination.terminationDate)
              .isBefore(monthStart)) {
        anomalies.add(
          MonthlySummaryAnomaly(
            kind: MonthlySummaryAnomalyKind.rosterStatusMismatch,
            employee: employee,
            message: '人员在本月开始前已离职，但仍在月度考勤名单中',
          ),
        );
      }
      final records =
          await (_database.select(_database.attendanceRecords)..where(
                (table) =>
                    table.employeeId.equals(employee.id) &
                    table.attendanceDate.isBiggerOrEqualValue(monthStart) &
                    table.attendanceDate.isSmallerOrEqualValue(monthEnd) &
                    table.isDeleted.equals(false),
              ))
              .get();
      final recordsByDay = {
        for (final record in records) record.attendanceDate.day: record,
      };
      final leaves =
          await (_database.select(_database.leaveRecords)..where(
                (table) =>
                    table.employeeId.equals(employee.id) &
                    table.isDeleted.equals(false) &
                    table.startDate.isSmallerOrEqualValue(monthEnd) &
                    table.endDate.isBiggerOrEqualValue(monthStart),
              ))
              .get();
      var date = monthStart;
      final today = AppDateUtils.dateOnly(DateTime.now());
      final inspectionEnd = monthEnd.isAfter(today) ? today : monthEnd;
      while (!date.isAfter(inspectionEnd)) {
        final beforeHire = AppDateUtils.dateOnly(employee.hireDate)
            .isAfter(date);
        final afterTermination =
            termination != null &&
            AppDateUtils.dateOnly(termination.terminationDate).isBefore(date);
        final record = recordsByDay[date.day];
        if (beforeHire && record != null) {
          anomalies.add(
            MonthlySummaryAnomaly(
              kind: MonthlySummaryAnomalyKind.preHire,
              employee: employee,
              date: date,
              message: '入职前存在考勤记录',
            ),
          );
        } else if (afterTermination && record != null) {
          anomalies.add(
            MonthlySummaryAnomaly(
              kind: MonthlySummaryAnomalyKind.postTermination,
              employee: employee,
              date: date,
              message: '离职日之后存在考勤记录',
            ),
          );
        } else if (!beforeHire &&
            !afterTermination &&
            (record == null ||
                record.morningStatus == AttendanceHalfStatus.unregistered ||
                record.afternoonStatus == AttendanceHalfStatus.unregistered)) {
          anomalies.add(
            MonthlySummaryAnomaly(
              kind: MonthlySummaryAnomalyKind.unregistered,
              employee: employee,
              date: date,
              message: '存在未登记的上午或下午考勤',
            ),
          );
        }
        if (!beforeHire && !afterTermination) {
          final morningLeave = leaves.any(
            (leave) =>
                LeaveOptions.covers(leave, date, LeaveHalfPeriod.morning),
          );
          final afternoonLeave = leaves.any(
            (leave) =>
                LeaveOptions.covers(leave, date, LeaveHalfPeriod.afternoon),
          );
          if ((morningLeave &&
                  record?.morningStatus != AttendanceHalfStatus.leave) ||
              (afternoonLeave &&
                  record?.afternoonStatus != AttendanceHalfStatus.leave)) {
            anomalies.add(
              MonthlySummaryAnomaly(
                kind: MonthlySummaryAnomalyKind.leaveConflict,
                employee: employee,
                date: date,
                message: '请假记录与半天考勤状态不一致',
              ),
            );
          }
        }
        date = date.add(const Duration(days: 1));
      }
    }

    final overtime =
        await (_database.select(_database.overtimeRecords)..where(
              (table) =>
                  table.overtimeDate.isBiggerOrEqualValue(monthStart) &
                  table.overtimeDate.isSmallerOrEqualValue(monthEnd) &
                  table.isDeleted.equals(false),
            ))
            .get();
    final overtimeByPersonDay = <String, List<OvertimeRecord>>{};
    for (final record in overtime) {
      overtimeByPersonDay
          .putIfAbsent(
            '${record.employeeId}:${record.overtimeDate.day}',
            () => [],
          )
          .add(record);
    }
    for (final entry in overtimeByPersonDay.entries) {
      final recordsForDay = entry.value
        ..sort((first, second) => first.startTime.compareTo(second.startTime));
      for (var index = 1; index < recordsForDay.length; index++) {
        final previous = recordsForDay[index - 1];
        final current = recordsForDay[index];
        if (current.startTime.isBefore(previous.endTime)) {
          final employee = employeeById[current.employeeId];
          if (employee != null) {
            anomalies.add(
              MonthlySummaryAnomaly(
                kind: MonthlySummaryAnomalyKind.overtimeOverlap,
                employee: employee,
                date: current.overtimeDate,
                message: '同一天存在重叠的加班时间段',
              ),
            );
          }
        }
      }
    }
    return anomalies;
  }

  Future<TerminationRecord?> _findTermination(int employeeId) async {
    final rows =
        await (_database.select(_database.terminationRecords)..where(
              (table) =>
                  table.employeeId.equals(employeeId) &
                  table.isDeleted.equals(false),
            ))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  MonthlyAttendanceSummary _placeholderSummary(
    String yearMonth,
    MonthlyAttendanceRoster roster,
  ) {
    return MonthlyAttendanceSummary(
      id: 0,
      yearMonth: yearMonth,
      employeeId: roster.employeeId,
      attendanceGroupId: roster.attendanceGroupId,
      participates: true,
      attendanceDays: 0,
      leaveDays: 0,
      absentDays: 0,
      restDays: 0,
      stoppedDays: 0,
      overtimeCount: 0,
      overtimeMinutes: 0,
      monthStartStatus: null,
      monthEndStatus: null,
      joinedDuringMonth: false,
      terminatedDuringMonth: false,
      isComplete: false,
      anomalyCount: 0,
      status: MonthlySummaryStatus.pendingReview,
      generatedAt: null,
      updatedAt: DateTime.now(),
      isDeleted: false,
    );
  }

  double _countHalfDays(
    List<AttendanceRecord> records,
    AttendanceHalfStatus status,
  ) {
    var count = 0;
    for (final record in records) {
      if (record.morningStatus == status) count++;
      if (record.afternoonStatus == status) count++;
    }
    return count / 2;
  }

  String _statusAt(
    Employee employee,
    TerminationRecord? termination,
    DateTime date,
  ) {
    if (termination != null &&
        !AppDateUtils.dateOnly(termination.terminationDate).isAfter(date)) {
      return EmployeeStatus.terminated.name;
    }
    return EmployeeStatus.active.name;
  }

  bool _sameMonth(DateTime date, DateTime month) {
    return date.year == month.year && date.month == month.month;
  }

  String _normalizeMonth(String value) {
    return AppDateUtils.yearMonth(AppDateUtils.parseYearMonth(value));
  }
}
