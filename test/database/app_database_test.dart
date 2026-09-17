import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/utils/date_utils.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
  });

  tearDown(() async {
    await database.close();
  });

  test('creates the complete version twelve schema', () async {
    final rows = await database
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    final tableNames = rows.map((row) => row.read<String>('name')).toSet();

    expect(database.schemaVersion, 12);
    expect(
      tableNames,
      containsAll([
        'employees',
        'wage_job_types',
        'wage_rate_history',
        'employee_wage_profiles',
        'payroll_batches',
        'payroll_items',
        'payroll_adjustments',
        'employee_attachments',
        'attendance_groups',
        'attendance_group_members',
        'monthly_attendance_rosters',
        'attendance_records',
        'leave_records',
        'overtime_records',
        'termination_records',
        'monthly_attendance_summaries',
        'insurance_profiles',
        'insurance_change_records',
        'social_security_base_history',
        'reminders',
        'reminder_occurrences',
        'reminder_alert_rules',
        'reminder_links',
        'operation_logs',
        'dictionary_items',
        'app_settings',
        'item_distribution_batches',
        'item_distribution_entries',
        'item_distribution_settings',
      ]),
    );
  });

  test('inserts, queries, soft deletes, and restores an employee', () async {
    final employeeId = await database.insertEmployee(
      EmployeesCompanion.insert(
        employeeNo: 'EMP-0001',
        name: '张三',
        hireDate: DateTime(2026, 9, 1),
      ),
    );

    final inserted = await database.findEmployeeById(employeeId);
    expect(inserted?.name, '张三');
    expect(inserted?.status, EmployeeStatus.active);
    expect((await database.listEmployees()).map((item) => item.id), [
      employeeId,
    ]);

    expect(await database.softDeleteEmployee(employeeId), 1);
    expect(await database.listEmployees(), isEmpty);
    expect(await database.listEmployees(includeDeleted: true), hasLength(1));

    expect(await database.restoreEmployee(employeeId), 1);
    expect(await database.listEmployees(), hasLength(1));
  });

  test('stores attendance statuses as stable enum names', () async {
    final employeeId = await database.insertEmployee(
      EmployeesCompanion.insert(
        employeeNo: 'EMP-0002',
        name: '李四',
        hireDate: DateTime(2026, 9, 1),
        status: const Value(EmployeeStatus.paused),
      ),
    );
    final attendanceDate = AppDateUtils.dateOnly(DateTime(2026, 9, 12, 8));

    final recordId = await database
        .into(database.attendanceRecords)
        .insert(
          AttendanceRecordsCompanion.insert(
            employeeId: employeeId,
            attendanceDate: attendanceDate,
            morningStatus: const Value(AttendanceHalfStatus.present),
            afternoonStatus: const Value(AttendanceHalfStatus.leave),
          ),
        );
    final record = await database.findAttendanceRecord(
      employeeId,
      DateTime(2026, 9, 12, 23),
    );

    expect(record?.id, recordId);
    expect(record?.morningStatus, AttendanceHalfStatus.present);
    expect(record?.afternoonStatus, AttendanceHalfStatus.leave);
  });

  test('enforces one attendance record per employee and date', () async {
    final employeeId = await database.insertEmployee(
      EmployeesCompanion.insert(
        employeeNo: 'EMP-0003',
        name: '王五',
        hireDate: DateTime(2026, 9, 1),
      ),
    );
    final first = AttendanceRecordsCompanion.insert(
      employeeId: employeeId,
      attendanceDate: DateTime(2026, 9, 12),
    );
    final duplicate = AttendanceRecordsCompanion.insert(
      employeeId: employeeId,
      attendanceDate: DateTime(2026, 9, 12),
    );

    await database.into(database.attendanceRecords).insert(first);
    await expectLater(
      database.into(database.attendanceRecords).insert(duplicate),
      throwsA(isA<Exception>()),
    );
  });

  test('normalizes and validates year-month values', () {
    expect(AppDateUtils.yearMonth(DateTime(2026, 9, 12)), '2026-09');
    expect(AppDateUtils.parseYearMonth('2026-09'), DateTime(2026, 9));
    expect(
      () => AppDateUtils.parseYearMonth('2026-13'),
      throwsA(isA<FormatException>()),
    );
  });
}
