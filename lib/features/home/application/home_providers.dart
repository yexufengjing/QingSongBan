import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/date_utils.dart';

class HomeDashboardStats {
  const HomeDashboardStats({
    required this.activeEmployees,
    required this.newEmployees,
    required this.terminatedEmployees,
    required this.todayAttendance,
    required this.anomalies,
    required this.pendingReminders,
  });

  final int activeEmployees;
  final int newEmployees;
  final int terminatedEmployees;
  final int todayAttendance;
  final int anomalies;
  final int pendingReminders;
}

final homeDashboardProvider = FutureProvider.autoDispose<HomeDashboardStats>(
  (ref) => _loadDashboardStats(ref.watch(appDatabaseProvider)),
);

Future<HomeDashboardStats> _loadDashboardStats(AppDatabase database) async {
  final now = DateTime.now();
  final today = AppDateUtils.dateOnly(now);
  final month = AppDateUtils.yearMonth(now);
  final employees = await database.listEmployees();
  final terminations = await (database.select(
    database.terminationRecords,
  )..where((table) => table.isDeleted.equals(false))).get();
  final attendance = await (database.select(
    database.attendanceRecords,
  )..where((table) => table.isDeleted.equals(false))).get();
  final summaries = await (database.select(
    database.monthlyAttendanceSummaries,
  )..where((table) => table.isDeleted.equals(false))).get();
  final reminders = await (database.select(
    database.reminders,
  )..where((table) => table.isDeleted.equals(false))).get();
  return HomeDashboardStats(
    activeEmployees: employees
        .where((employee) => employee.status == EmployeeStatus.active)
        .length,
    newEmployees: employees
        .where((employee) => AppDateUtils.yearMonth(employee.hireDate) == month)
        .length,
    terminatedEmployees: terminations
        .where(
          (record) =>
              record.terminationDate.year == now.year &&
              record.terminationDate.month == now.month,
        )
        .length,
    todayAttendance: attendance
        .where(
          (record) =>
              record.attendanceDate == today &&
              (record.morningStatus != AttendanceHalfStatus.unregistered ||
                  record.afternoonStatus != AttendanceHalfStatus.unregistered),
        )
        .length,
    anomalies: summaries
        .where(
          (summary) => summary.yearMonth == month && summary.anomalyCount > 0,
        )
        .length,
    pendingReminders: reminders
        .where((reminder) => reminder.isEnabled && !reminder.isCompleted)
        .length,
  );
}
