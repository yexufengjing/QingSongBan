import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/monthly_attendance_table_options.dart';

class MonthlyAttendanceTableRepository {
  const MonthlyAttendanceTableRepository(this._database);

  final AppDatabase _database;

  Stream<MonthlyAttendanceTableView> watchTable({
    required String yearMonth,
    required int groupId,
  }) {
    final normalizedMonth = AppDateUtils.yearMonth(
      AppDateUtils.parseYearMonth(yearMonth),
    );
    final month = AppDateUtils.parseYearMonth(normalizedMonth);
    final monthStart = DateTime(month.year, month.month);
    final nextMonth = DateTime(month.year, month.month + 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
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
                  records.attendanceDate.isBiggerOrEqualValue(monthStart) &
                  records.attendanceDate.isSmallerThanValue(nextMonth) &
                  records.isDeleted.equals(false),
            ),
            leftOuterJoin(
              terminations,
              terminations.employeeId.equalsExp(rosters.employeeId) &
                  terminations.isDeleted.equals(false),
            ),
          ])
          ..where(
            rosters.yearMonth.equals(normalizedMonth) &
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
      final byEmployee = <int, MonthlyAttendanceTableRow>{};
      for (final row in rows) {
        final employee = row.readTable(employees);
        final tableRow = byEmployee.putIfAbsent(
          employee.id,
          () => MonthlyAttendanceTableRow(
            employee: employee,
            terminationDate: row.readTableOrNull(terminations)?.terminationDate,
          ),
        );
        final record = row.readTableOrNull(records);
        if (record != null) tableRow.addRecord(record);
      }
      return MonthlyAttendanceTableView(
        yearMonth: normalizedMonth,
        daysInMonth: daysInMonth,
        rows: byEmployee.values.toList(),
      );
    });
  }
}
