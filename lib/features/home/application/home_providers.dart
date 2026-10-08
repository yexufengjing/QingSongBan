import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_enums.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../../reminders/domain/reminder_options.dart';

class HomeAttendanceProgress {
  const HomeAttendanceProgress({
    required this.rosterCount,
    required this.morningRegistered,
    required this.afternoonRegistered,
  });

  final int rosterCount;
  final int morningRegistered;
  final int afternoonRegistered;
}

final homeAttendanceProgressProvider =
    StreamProvider.autoDispose<HomeAttendanceProgress>((ref) {
      final database = ref.watch(appDatabaseProvider);
      final today = AppDateUtils.dateOnly(DateTime.now());
      final rosters = database.monthlyAttendanceRosters;
      final employees = database.employees;
      final groups = database.attendanceGroups;
      final records = database.attendanceRecords;
      final terminations = database.terminationRecords;
      final query =
          database.select(rosters).join([
            innerJoin(employees, employees.id.equalsExp(rosters.employeeId)),
            innerJoin(groups, groups.id.equalsExp(rosters.attendanceGroupId)),
            leftOuterJoin(
              records,
              records.employeeId.equalsExp(rosters.employeeId) &
                  records.attendanceDate.equals(today) &
                  records.isDeleted.equals(false),
            ),
            leftOuterJoin(
              terminations,
              terminations.employeeId.equalsExp(rosters.employeeId) &
                  terminations.isDeleted.equals(false),
            ),
          ])..where(
            rosters.yearMonth.equals(AppDateUtils.yearMonth(today)) &
                rosters.isActive.equals(true) &
                rosters.isDeleted.equals(false) &
                employees.isDeleted.equals(false) &
                groups.isEnabled.equals(true) &
                groups.isDeleted.equals(false),
          );
      return query.watch().map((rows) {
        final uniqueEmployees =
            <
              int,
              ({
                Employee employee,
                AttendanceRecord? record,
                TerminationRecord? termination,
              })
            >{};
        for (final row in rows) {
          final employee = row.readTable(employees);
          uniqueEmployees.putIfAbsent(
            employee.id,
            () => (
              employee: employee,
              record: row.readTableOrNull(records),
              termination: row.readTableOrNull(terminations),
            ),
          );
        }

        var rosterCount = 0;
        var morningRegistered = 0;
        var afternoonRegistered = 0;
        for (final entry in uniqueEmployees.values) {
          final employee = entry.employee;
          if (AppDateUtils.dateOnly(employee.hireDate).isAfter(today)) {
            continue;
          }
          // Match DailyAttendanceRepository: termination locks only terminated
          // employees after their effective date; a former record on an active
          // employee does not change that employee's editability.
          if (employee.status == EmployeeStatus.terminated &&
              (entry.termination == null ||
                  AppDateUtils.dateOnly(entry.termination!.terminationDate)
                      .isBefore(today))) {
            continue;
          }
          rosterCount++;
          final record = entry.record;
          if (record != null && _isRegisteredHalf(record.morningStatus)) {
            morningRegistered++;
          }
          if (record != null && _isRegisteredHalf(record.afternoonStatus)) {
            afternoonRegistered++;
          }
        }
        return HomeAttendanceProgress(
          rosterCount: rosterCount,
          morningRegistered: morningRegistered,
          afternoonRegistered: afternoonRegistered,
        );
      });
    });

bool _isRegisteredHalf(AttendanceHalfStatus status) =>
    status != AttendanceHalfStatus.unregistered &&
    status != AttendanceHalfStatus.notEmployed &&
    status != AttendanceHalfStatus.terminated;

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
