import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../../reminders/domain/reminder_options.dart';

class HomeDashboardStats {
  const HomeDashboardStats({
    required this.activeEmployees,
    required this.newEmployees,
    required this.terminatedEmployees,
    required this.todayAttendance,
    required this.anomalies,
    required this.pendingReminders,
    this.todayLeave = 0,
    this.upcomingReminders = 0,
  });

  final int activeEmployees;
  final int newEmployees;
  final int terminatedEmployees;
  final int todayAttendance;
  final int anomalies;
  final int pendingReminders;
  final int todayLeave;
  final int upcomingReminders;
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
  final leaves = await (database.select(
    database.leaveRecords,
  )..where((table) => table.isDeleted.equals(false))).get();
  final summaries = await (database.select(
    database.monthlyAttendanceSummaries,
  )..where((table) => table.isDeleted.equals(false))).get();
  final reminders =
      await (database.select(database.reminders)..where(
            (table) =>
                table.isDeleted.equals(false) & table.archivedAt.isNull(),
          ))
          .get();
  final reminderOccurrences = await (database.select(
    database.reminderOccurrences,
  )..where((table) => table.status.equals('pending'))).get();
  final enabledReminderIds = reminders
      .where((reminder) => reminder.isEnabled && !reminder.isCompleted)
      .map((reminder) => reminder.id)
      .toSet();
  final visibleReminderIds = reminders
      .where(
        (reminder) =>
            reminder.isEnabled &&
            (reminder.reminderType == 'custom' ||
                !ReminderOptions.types.contains(reminder.reminderType)),
      )
      .map((reminder) => reminder.id)
      .toSet();
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final upcomingEnd = today.add(const Duration(days: 30));
  final upcomingEndOfDay = DateTime(
    upcomingEnd.year,
    upcomingEnd.month,
    upcomingEnd.day,
    23,
    59,
    59,
  );
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
              (record.morningStatus == AttendanceHalfStatus.present ||
                  record.afternoonStatus == AttendanceHalfStatus.present),
        )
        .map((record) => record.employeeId)
        .toSet()
        .length,
    todayLeave: leaves
        .where(
          (record) =>
              !record.startDate.isAfter(today) &&
              !record.endDate.isBefore(today),
        )
        .map((record) => record.employeeId)
        .toSet()
        .length,
    upcomingReminders: reminderOccurrences
        .where(
          (occurrence) =>
              enabledReminderIds.contains(occurrence.reminderId) &&
              !occurrence.scheduledAt.isBefore(today) &&
              !occurrence.scheduledAt.isAfter(upcomingEndOfDay),
        )
        .map((occurrence) => occurrence.reminderId)
        .toSet()
        .length,
    anomalies: summaries
        .where(
          (summary) => summary.yearMonth == month && summary.anomalyCount > 0,
        )
        .length,
    pendingReminders: reminderOccurrences
        .where(
          (occurrence) =>
              visibleReminderIds.contains(occurrence.reminderId) &&
              !occurrence.scheduledAt.isAfter(todayEnd),
        )
        .map((occurrence) => occurrence.reminderId)
        .toSet()
        .length,
  );
}
