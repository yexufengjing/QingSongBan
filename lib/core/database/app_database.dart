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
    AttendanceGroups,
    AttendanceGroupMembers,
    MonthlyAttendanceRosters,
    AttendanceRecords,
    OperationLogs,
    DictionaryItems,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: DatabaseConstants.databaseName));

  /// In-memory database for repository and migration tests.
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Version 1 is the initial schema. Keeping the branch explicit gives
      // later stages a safe place to append incremental migrations.
      if (from < 1 && to >= 1) {
        await m.createAll();
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
