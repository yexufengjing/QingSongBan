import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/attendance/data/attendance_group_repository.dart';
import 'package:qingsongban/features/attendance/data/monthly_roster_repository.dart';
import 'package:qingsongban/features/attendance/domain/attendance_group_options.dart';
import 'package:qingsongban/features/personnel/data/personnel_repository.dart';
import 'package:qingsongban/features/personnel/domain/personnel_options.dart';

void main() {
  late AppDatabase database;
  late AttendanceGroupRepository groupRepository;
  late MonthlyRosterRepository rosterRepository;
  late PersonnelRepository personnelRepository;

  setUp(() {
    database = AppDatabase.forTesting();
    groupRepository = AttendanceGroupRepository(database);
    rosterRepository = MonthlyRosterRepository(database);
    personnelRepository = PersonnelRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<AttendanceGroup> createGroup(String name, {bool enabled = true}) {
    return groupRepository.save(
      draft: AttendanceGroupDraft(name: name, isEnabled: enabled),
    );
  }

  Future<Employee> createEmployee(
    String employeeNo,
    String name, {
    DateTime? hireDate,
    EmployeeStatus status = EmployeeStatus.active,
    int? defaultGroupId,
  }) {
    return personnelRepository.save(
      draft: EmployeeDraft(
        employeeNo: employeeNo,
        name: name,
        hireDate: hireDate ?? DateTime(2026, 7, 1),
        status: status,
        defaultAttendanceGroupId: defaultGroupId,
      ),
    );
  }

  test(
    'adds, removes, restores, and does not duplicate a monthly roster',
    () async {
      final group = await createGroup('七月考勤组');
      final employee = await createEmployee('EMP-7001', '张三');

      expect(
        await rosterRepository.addEmployee(
          yearMonth: '2026-07',
          groupId: group.id,
          employeeId: employee.id,
        ),
        1,
      );
      expect(
        await rosterRepository.addEmployee(
          yearMonth: '2026-07',
          groupId: group.id,
          employeeId: employee.id,
        ),
        0,
      );
      expect(
        (await database.select(database.monthlyAttendanceRosters).get()),
        hasLength(1),
      );
      expect(
        (await rosterRepository
            .watchRoster(yearMonth: '2026-07', groupId: group.id)
            .first),
        hasLength(1),
      );

      await rosterRepository.removeEmployee(
        yearMonth: '2026-07',
        groupId: group.id,
        employeeId: employee.id,
      );
      expect(
        await rosterRepository
            .watchRoster(yearMonth: '2026-07', groupId: group.id)
            .first,
        isEmpty,
      );
      expect(
        await rosterRepository
            .watchRoster(
              yearMonth: '2026-07',
              groupId: group.id,
              includeRemoved: true,
            )
            .first,
        hasLength(1),
      );

      await rosterRepository.restoreEmployee(
        yearMonth: '2026-07',
        groupId: group.id,
        employeeId: employee.id,
      );
      final restored = await rosterRepository
          .watchRoster(yearMonth: '2026-07', groupId: group.id)
          .first;
      expect(restored.single.roster.isActive, isTrue);
      expect(restored.single.roster.source, 'manual');
      expect(
        (await database.findEmployeeById(employee.id))?.status,
        EmployeeStatus.active,
      );
    },
  );

  test(
    'keeps historical months independent and allows re-adding in a later month',
    () async {
      final group = await createGroup('跨月考勤组');
      final employee = await createEmployee('EMP-8001', '李四');

      await rosterRepository.addEmployee(
        yearMonth: '2026-07',
        groupId: group.id,
        employeeId: employee.id,
      );
      await rosterRepository.addEmployee(
        yearMonth: '2026-08',
        groupId: group.id,
        employeeId: employee.id,
      );
      await rosterRepository.removeEmployee(
        yearMonth: '2026-08',
        groupId: group.id,
        employeeId: employee.id,
      );
      await rosterRepository.addEmployee(
        yearMonth: '2026-09',
        groupId: group.id,
        employeeId: employee.id,
      );

      expect(
        await rosterRepository
            .watchRoster(yearMonth: '2026-07', groupId: group.id)
            .first,
        hasLength(1),
      );
      expect(
        await rosterRepository
            .watchRoster(yearMonth: '2026-08', groupId: group.id)
            .first,
        isEmpty,
      );
      expect(
        await rosterRepository
            .watchRoster(yearMonth: '2026-09', groupId: group.id)
            .first,
        hasLength(1),
      );
      expect(
        (await database.select(database.monthlyAttendanceRosters).get()),
        hasLength(3),
      );
      expect(
        (await database.findEmployeeById(employee.id))?.status,
        EmployeeStatus.active,
      );
    },
  );

  test('copies only missing previous-month entries and preserves current manual entries', () async {
    final group = await createGroup('复制考勤组');
    final previousEmployee = await createEmployee('EMP-9001', '王五');
    final currentEmployee = await createEmployee('EMP-9002', '赵六');

    await rosterRepository.addEmployee(
      yearMonth: '2026-07',
      groupId: group.id,
      employeeId: previousEmployee.id,
    );
    await rosterRepository.addEmployee(
      yearMonth: '2026-08',
      groupId: group.id,
      employeeId: currentEmployee.id,
    );

    final result = await rosterRepository.copyFromPreviousMonth(
      yearMonth: '2026-08',
      groupId: group.id,
    );
    expect(result.sourceYearMonth, '2026-07');
    expect(result.count, 1);

    final rows = await database.select(database.monthlyAttendanceRosters).get();
    expect(rows, hasLength(3));
    final copied = rows.singleWhere(
      (row) =>
          row.yearMonth == '2026-08' && row.employeeId == previousEmployee.id,
    );
    final manual = rows.singleWhere(
      (row) =>
          row.yearMonth == '2026-08' && row.employeeId == currentEmployee.id,
    );
    expect(copied.source, 'copied');
    expect(manual.source, 'manual');

    final secondCopy = await rosterRepository.copyFromPreviousMonth(
      yearMonth: '2026-08',
      groupId: group.id,
    );
    expect(secondCopy.count, 0);
    expect(
      (await database.select(database.monthlyAttendanceRosters).get()),
      hasLength(3),
    );
  });

  test('rejects employees hired after the selected month ends', () async {
    final group = await createGroup('入职日期考勤组');
    final employee = await createEmployee(
      'EMP-1001',
      '钱七',
      hireDate: DateTime(2026, 8, 1),
    );

    await expectLater(
      rosterRepository.addEmployee(
        yearMonth: '2026-07',
        groupId: group.id,
        employeeId: employee.id,
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      await rosterRepository.watchEligibleEmployees(yearMonth: '2026-07').first,
      isEmpty,
    );
  });

  test(
    'adds eligible employees whose default group matches without duplicates',
    () async {
      final group = await createGroup('批量加入组');
      final first = await createEmployee(
        'EMP-1051',
        '郑十一',
        defaultGroupId: group.id,
      );
      final second = await createEmployee(
        'EMP-1052',
        '王十二',
        defaultGroupId: group.id,
      );
      await createEmployee('EMP-1053', '冯十三');
      await createEmployee(
        'EMP-1054',
        '陈十四',
        defaultGroupId: group.id,
        hireDate: DateTime(2026, 9, 1),
      );

      expect(
        await rosterRepository.addDefaultGroupEmployees(
          yearMonth: '2026-08',
          groupId: group.id,
        ),
        2,
      );
      expect(
        await rosterRepository.addDefaultGroupEmployees(
          yearMonth: '2026-08',
          groupId: group.id,
        ),
        0,
      );
      final entries = await rosterRepository
          .watchRoster(yearMonth: '2026-08', groupId: group.id)
          .first;
      expect(
        entries.map((entry) => entry.employee.id),
        containsAll([first.id, second.id]),
      );
      expect(
        (await database.select(database.monthlyAttendanceRosters).get()),
        hasLength(2),
      );
    },
  );

  test(
    'disabled groups keep historical rosters but block new roster operations',
    () async {
      final group = await createGroup('历史考勤组');
      final existing = await createEmployee('EMP-1101', '孙八');
      final newEmployee = await createEmployee(
        'EMP-1102',
        '周九',
        defaultGroupId: group.id,
      );

      await rosterRepository.addEmployee(
        yearMonth: '2026-07',
        groupId: group.id,
        employeeId: existing.id,
      );
      await groupRepository.setEnabled(group.id, false);

      expect(
        await rosterRepository
            .watchRoster(yearMonth: '2026-07', groupId: group.id)
            .first,
        hasLength(1),
      );
      await expectLater(
        rosterRepository.addEmployee(
          yearMonth: '2026-08',
          groupId: group.id,
          employeeId: existing.id,
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        rosterRepository.copyFromPreviousMonth(
          yearMonth: '2026-08',
          groupId: group.id,
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        rosterRepository.addDefaultGroupEmployees(
          yearMonth: '2026-08',
          groupId: group.id,
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        (await database.findEmployeeById(newEmployee.id))?.status,
        EmployeeStatus.active,
      );
    },
  );

  test(
    'changing the default group does not change historical monthly rosters',
    () async {
      final first = await createGroup('默认组一');
      final second = await createGroup('默认组二');
      final employee = await createEmployee(
        'EMP-1201',
        '吴十',
        defaultGroupId: first.id,
      );

      await rosterRepository.addEmployee(
        yearMonth: '2026-07',
        groupId: first.id,
        employeeId: employee.id,
      );
      await groupRepository.assignEmployeeToGroup(
        employeeId: employee.id,
        groupId: second.id,
      );

      final historical = await rosterRepository
          .watchRoster(yearMonth: '2026-07', groupId: first.id)
          .first;
      expect(historical, hasLength(1));
      expect(
        (await database.findEmployeeById(employee.id))
            ?.defaultAttendanceGroupId,
        second.id,
      );
    },
  );
}
