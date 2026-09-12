import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/attendance/data/attendance_group_repository.dart';
import 'package:qingsongban/features/attendance/data/daily_attendance_repository.dart';
import 'package:qingsongban/features/attendance/data/monthly_attendance_table_repository.dart';
import 'package:qingsongban/features/attendance/data/monthly_roster_repository.dart';
import 'package:qingsongban/features/attendance/domain/attendance_group_options.dart';
import 'package:qingsongban/features/attendance/domain/daily_attendance_options.dart';
import 'package:qingsongban/features/personnel/data/personnel_repository.dart';
import 'package:qingsongban/features/personnel/domain/personnel_options.dart';

void main() {
  late AppDatabase database;
  late AttendanceGroupRepository groupRepository;
  late MonthlyRosterRepository rosterRepository;
  late DailyAttendanceRepository dailyRepository;
  late MonthlyAttendanceTableRepository tableRepository;
  late PersonnelRepository personnelRepository;

  setUp(() {
    database = AppDatabase.forTesting();
    groupRepository = AttendanceGroupRepository(database);
    rosterRepository = MonthlyRosterRepository(database);
    dailyRepository = DailyAttendanceRepository(database);
    tableRepository = MonthlyAttendanceTableRepository(database);
    personnelRepository = PersonnelRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<Employee> createEmployee(String employeeNo, String name) {
    return personnelRepository.save(
      draft: EmployeeDraft(
        employeeNo: employeeNo,
        name: name,
        hireDate: DateTime(2026, 1, 1),
        status: EmployeeStatus.active,
      ),
    );
  }

  test('builds the month matrix and calculates half-day totals', () async {
    final group = await groupRepository.save(
      draft: const AttendanceGroupDraft(name: '月表测试组'),
    );
    final employee = await createEmployee('EMP-M001', '张三');
    await rosterRepository.addEmployee(
      yearMonth: '2026-09',
      groupId: group.id,
      employeeId: employee.id,
    );

    await dailyRepository.save(
      DailyAttendanceDraft(
        employeeId: employee.id,
        attendanceDate: DateTime(2026, 9, 1),
        morningStatus: AttendanceHalfStatus.present,
        afternoonStatus: AttendanceHalfStatus.present,
      ),
    );
    await dailyRepository.save(
      DailyAttendanceDraft(
        employeeId: employee.id,
        attendanceDate: DateTime(2026, 9, 2),
        morningStatus: AttendanceHalfStatus.present,
        afternoonStatus: AttendanceHalfStatus.leave,
      ),
    );
    await dailyRepository.save(
      DailyAttendanceDraft(
        employeeId: employee.id,
        attendanceDate: DateTime(2026, 9, 3),
        morningStatus: AttendanceHalfStatus.absent,
        afternoonStatus: AttendanceHalfStatus.absent,
      ),
    );

    final table = await tableRepository
        .watchTable(yearMonth: '2026-09', groupId: group.id)
        .first;
    final row = table.rows.single;

    expect(table.daysInMonth, 30);
    expect(row.attendanceDays, 1.5);
    expect(row.leaveDays, 0.5);
    expect(row.cellForDay(month: DateTime(2026, 9), day: 1).symbol, '力');
    expect(row.cellForDay(month: DateTime(2026, 9), day: 2).symbol, '半');
    expect(row.cellForDay(month: DateTime(2026, 9), day: 3).symbol, '🔺');
    expect(row.cellForDay(month: DateTime(2026, 9), day: 4).symbol, '·');
    expect(table.totalAttendanceDays, 1.5);
    expect(table.totalLeaveDays, 0.5);
  });

  test('reflects daily changes and locks dates before hire', () async {
    final group = await groupRepository.save(
      draft: const AttendanceGroupDraft(name: '同步月表组'),
    );
    final employee = await createEmployee('EMP-M101', '李四');
    final futureHire = await personnelRepository.save(
      draft: EmployeeDraft(
        employeeNo: 'EMP-M102',
        name: '王五',
        hireDate: DateTime(2026, 9, 20),
        status: EmployeeStatus.active,
      ),
    );
    await rosterRepository.addEmployee(
      yearMonth: '2026-09',
      groupId: group.id,
      employeeId: employee.id,
    );
    await rosterRepository.addEmployee(
      yearMonth: '2026-09',
      groupId: group.id,
      employeeId: futureHire.id,
    );

    await dailyRepository.save(
      DailyAttendanceDraft(
        employeeId: employee.id,
        attendanceDate: DateTime(2026, 9, 5),
        morningStatus: AttendanceHalfStatus.present,
        afternoonStatus: AttendanceHalfStatus.leave,
      ),
    );
    var table = await tableRepository
        .watchTable(yearMonth: '2026-09', groupId: group.id)
        .first;
    expect(
      table.rows.singleWhere((row) => row.employee.id == employee.id).leaveDays,
      0.5,
    );

    await dailyRepository.save(
      DailyAttendanceDraft(
        employeeId: employee.id,
        attendanceDate: DateTime(2026, 9, 5),
        morningStatus: AttendanceHalfStatus.present,
        afternoonStatus: AttendanceHalfStatus.present,
      ),
    );
    table = await tableRepository
        .watchTable(yearMonth: '2026-09', groupId: group.id)
        .first;
    expect(table.totalAttendanceDays, 1);
    expect(table.totalLeaveDays, 0);

    final locked = table.rows
        .singleWhere((row) => row.employee.id == futureHire.id)
        .cellForDay(month: DateTime(2026, 9), day: 5);
    expect(locked.isEditable, isFalse);
    expect(locked.symbol, '未');
  });

  test('keeps historical rows visible for a disabled group', () async {
    final group = await groupRepository.save(
      draft: const AttendanceGroupDraft(name: '历史月表组'),
    );
    final employee = await createEmployee('EMP-M201', '赵六');
    await rosterRepository.addEmployee(
      yearMonth: '2026-08',
      groupId: group.id,
      employeeId: employee.id,
    );
    await dailyRepository.save(
      DailyAttendanceDraft(
        employeeId: employee.id,
        attendanceDate: DateTime(2026, 8, 1),
        morningStatus: AttendanceHalfStatus.rest,
        afternoonStatus: AttendanceHalfStatus.rest,
      ),
    );
    await groupRepository.setEnabled(group.id, false);

    final table = await tableRepository
        .watchTable(yearMonth: '2026-08', groupId: group.id)
        .first;
    expect(table.rows, hasLength(1));
    expect(
      table.rows.single.cellForDay(month: DateTime(2026, 8), day: 1).symbol,
      '休',
    );
  });
}
