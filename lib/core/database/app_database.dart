import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:drift/native.dart';

import '../constants/database_constants.dart';
import '../utils/date_utils.dart';
import 'database_enums.dart';
import 'database_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Employees,
    WageJobTypes,
    WageRateHistory,
    EmployeeWageProfiles,
    PayrollBatches,
    PayrollItems,
    PayrollAdjustments,
    EmployeeAttachments,
    AttendanceGroups,
    AttendanceGroupMembers,
    MonthlyAttendanceRosters,
    AttendanceRecords,
    LeaveRecords,
    OvertimeRecords,
    TerminationRecords,
    MonthlyAttendanceSummaries,
    InsuranceProfiles,
    InsuranceChangeRecords,
    SocialSecurityBaseHistory,
    OperationLogs,
    DictionaryItems,
    AppSettings,
    Reminders,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: DatabaseConstants.databaseName));

  /// In-memory database for repository and migration tests.
  AppDatabase.forTesting({QueryExecutor? executor})
    : super(executor ?? NativeDatabase.memory());

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Version 1 is the initial schema. Version 2 adds independent leave
      // records while retaining all existing attendance data.
      if (from < 1 && to >= 1) {
        await m.createAll();
      }
      if (from < 2 && to >= 2) {
        await m.createTable(leaveRecords);
      }
      if (from < 3 && to >= 3) {
        await m.createTable(overtimeRecords);
      }
      if (from < 4 && to >= 4) {
        await m.createTable(terminationRecords);
      }
      if (from < 5 && to >= 5) {
        await m.createTable(monthlyAttendanceSummaries);
      }
      if (from < 6 && to >= 6) {
        await m.createTable(insuranceProfiles);
        await m.createTable(insuranceChangeRecords);
        await m.createTable(socialSecurityBaseHistory);
      }
      if (from < 7 && to >= 7) {
        await m.createTable(reminders);
      }
      if (from < 8 && to >= 8) {
        await m.createTable(employeeAttachments);
      }
      if (from < 9 && to >= 9) {
        await m.createTable(wageJobTypes);
        await m.createTable(wageRateHistory);
        await m.createTable(employeeWageProfiles);
        await m.createTable(payrollBatches);
        await m.createTable(payrollItems);
        await m.createTable(payrollAdjustments);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<int> insertEmployee(EmployeesCompanion employee) {
    return into(employees).insert(employee);
  }

  Future<Employee?> findEmployeeById(int id) {
    return (select(
      employees,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Future<List<Employee>> listEmployees({bool includeDeleted = false}) {
    final query = select(employees)
      ..orderBy([(table) => OrderingTerm(expression: table.name)]);
    if (!includeDeleted) {
      query.where((table) => table.isDeleted.equals(false));
    }
    return query.get();
  }

  Stream<List<Employee>> watchEmployees({bool includeDeleted = false}) {
    final query = select(employees)
      ..orderBy([(table) => OrderingTerm(expression: table.name)]);
    if (!includeDeleted) {
      query.where((table) => table.isDeleted.equals(false));
    }
    return query.watch();
  }

  Future<int> softDeleteEmployee(int id) {
    return (update(employees)..where((table) => table.id.equals(id))).write(
      EmployeesCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> restoreEmployee(int id) {
    return (update(employees)..where((table) => table.id.equals(id))).write(
      EmployeesCompanion(
        isDeleted: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<AttendanceRecord?> findAttendanceRecord(
    int employeeId,
    DateTime attendanceDate,
  ) {
    final date = AppDateUtils.dateOnly(attendanceDate);
    return (select(attendanceRecords)..where(
          (table) =>
              table.employeeId.equals(employeeId) &
              table.attendanceDate.equals(date),
        ))
        .getSingleOrNull();
  }
}
