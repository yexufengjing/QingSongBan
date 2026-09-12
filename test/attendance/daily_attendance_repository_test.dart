import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/attendance/data/attendance_group_repository.dart';
import 'package:qingsongban/features/attendance/data/daily_attendance_repository.dart';
import 'package:qingsongban/features/attendance/domain/attendance_group_options.dart';
import 'package:qingsongban/features/attendance/domain/daily_attendance_options.dart';
import 'package:qingsongban/features/attendance/data/monthly_roster_repository.dart';
import 'package:qingsongban/features/personnel/data/personnel_repository.dart';
import 'package:qingsongban/features/personnel/domain/personnel_options.dart';

void main() {
  late AppDatabase database;
  late AttendanceGroupRepository groupRepository;
  late MonthlyRosterRepository rosterRepository;
  late DailyAttendanceRepository attendanceRepository;
  late PersonnelRepository personnelRepository;

  setUp(() {
    database = AppDatabase.forTesting();
    groupRepository = AttendanceGroupRepository(database);
    rosterRepository = MonthlyRosterRepository(database);
    attendanceRepository = DailyAttendanceRepository(database);
    personnelRepository = PersonnelRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<AttendanceGroup> createGroup(String name) {
    return groupRepository.save(draft: AttendanceGroupDraft(name: name));
  }

  Future<Employee> createEmployee(
    String employeeNo,
    String name, {
    DateTime? hireDate,
    EmployeeStatus status = EmployeeStatus.active,
  }) {
    return personnelRepository.save(
      draft: EmployeeDraft(
        employeeNo: employeeNo,
        name: name,
        hireDate: hireDate ?? DateTime(2026, 1, 1),
        status: status,
      ),
    );
  }

  Future<void> addToRoster({
    required AttendanceGroup group,
    required Employee employee,
    String month = '2026-09',
  }) {
    return rosterRepository.addEmployee(
      yearMonth: month,
      groupId: group.id,
      employeeId: employee.id,
    );
  }

  test(
    'saves one daily record and updates it instead of duplicating',
    () async {
      final group = await createGroup('每日考勤组');
      final employee = await createEmployee('EMP-D001', '张三');
      await addToRoster(group: group, employee: employee);
      final date = DateTime(2026, 9, 12);

      await attendanceRepository.save(
        DailyAttendanceDraft(
          employeeId: employee.id,
          attendanceDate: date,
          morningStatus: AttendanceHalfStatus.present,
          afternoonStatus: AttendanceHalfStatus.leave,
          remark: '上午到岗',
        ),
      );
      await attendanceRepository.save(
        DailyAttendanceDraft(
          employeeId: employee.id,
          attendanceDate: date,
          morningStatus: AttendanceHalfStatus.absent,
          afternoonStatus: AttendanceHalfStatus.present,
          remark: '已补录',
        ),
      );

      final rows = await database.select(database.attendanceRecords).get();
      expect(rows, hasLength(1));
      expect(rows.single.morningStatus, AttendanceHalfStatus.absent);
      expect(rows.single.afternoonStatus, AttendanceHalfStatus.present);
      expect(rows.single.remark, '已补录');
    },
  );

  test('shows roster employees and applies bulk attendance actions', () async {
    final group = await createGroup('快捷操作组');
    final first = await createEmployee('EMP-D101', '李四');
    final second = await createEmployee('EMP-D102', '王五');
    await addToRoster(group: group, employee: first);
    await addToRoster(group: group, employee: second);
    final date = DateTime(2026, 9, 12);

    expect(
      await attendanceRepository
          .watchEntries(attendanceDate: date, groupId: group.id)
          .first,
      hasLength(2),
    );
    expect(
      await attendanceRepository.applyAction(
        attendanceDate: date,
        groupId: group.id,
        action: DailyAttendanceAction.allPresent,
      ),
      2,
    );
    expect(
      await attendanceRepository.applyAction(
        attendanceDate: date,
        groupId: group.id,
        action: DailyAttendanceAction.rest,
      ),
      2,
    );
    final entries = await attendanceRepository
        .watchEntries(attendanceDate: date, groupId: group.id)
        .first;
    expect(
      entries.every(
        (entry) => entry.morningStatus == AttendanceHalfStatus.rest,
      ),
      isTrue,
    );
    expect(
      entries.every(
        (entry) => entry.afternoonStatus == AttendanceHalfStatus.rest,
      ),
      isTrue,
    );
  });

  test(
    'copies the previous day and preserves a single record per day',
    () async {
      final group = await createGroup('复制考勤组');
      final employee = await createEmployee('EMP-D201', '赵六');
      await addToRoster(group: group, employee: employee);
      final previous = DateTime(2026, 9, 11);
      final current = DateTime(2026, 9, 12);

      await attendanceRepository.save(
        DailyAttendanceDraft(
          employeeId: employee.id,
          attendanceDate: previous,
          morningStatus: AttendanceHalfStatus.present,
          afternoonStatus: AttendanceHalfStatus.stopped,
          remark: '前一天备注',
        ),
      );
      expect(
        await attendanceRepository.applyAction(
          attendanceDate: current,
          groupId: group.id,
          action: DailyAttendanceAction.copyPrevious,
        ),
        1,
      );

      final record = await database.findAttendanceRecord(employee.id, current);
      expect(record?.morningStatus, AttendanceHalfStatus.present);
      expect(record?.afternoonStatus, AttendanceHalfStatus.stopped);
      expect(record?.remark, '前一天备注');
      expect(
        await database.select(database.attendanceRecords).get(),
        hasLength(2),
      );
    },
  );

  test('locks dates before hire and terminated employees', () async {
    final group = await createGroup('状态锁定组');
    final futureHire = await createEmployee(
      'EMP-D301',
      '钱七',
      hireDate: DateTime(2026, 9, 20),
    );
    final terminated = await createEmployee(
      'EMP-D302',
      '孙八',
      status: EmployeeStatus.terminated,
    );
    await addToRoster(group: group, employee: futureHire);
    await addToRoster(group: group, employee: terminated);
    final entries = await attendanceRepository
        .watchEntries(attendanceDate: DateTime(2026, 9, 12), groupId: group.id)
        .first;

    final futureEntry = entries.singleWhere(
      (entry) => entry.employee.id == futureHire.id,
    );
    final terminatedEntry = entries.singleWhere(
      (entry) => entry.employee.id == terminated.id,
    );
    expect(futureEntry.isEditable, isFalse);
    expect(futureEntry.morningStatus, AttendanceHalfStatus.notEmployed);
    expect(terminatedEntry.isEditable, isFalse);
    expect(terminatedEntry.morningStatus, AttendanceHalfStatus.terminated);
    await expectLater(
      attendanceRepository.save(
        DailyAttendanceDraft(
          employeeId: futureHire.id,
          attendanceDate: DateTime(2026, 9, 12),
          morningStatus: AttendanceHalfStatus.present,
          afternoonStatus: AttendanceHalfStatus.present,
        ),
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      attendanceRepository.save(
        DailyAttendanceDraft(
          employeeId: terminated.id,
          attendanceDate: DateTime(2026, 9, 12),
          morningStatus: AttendanceHalfStatus.present,
          afternoonStatus: AttendanceHalfStatus.present,
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('disabled groups reject daily writes', () async {
    final group = await createGroup('停用考勤组');
    final employee = await createEmployee('EMP-D401', '周九');
    await addToRoster(group: group, employee: employee);
    await groupRepository.setEnabled(group.id, false);

    await expectLater(
      attendanceRepository.applyAction(
        attendanceDate: DateTime(2026, 9, 12),
        groupId: group.id,
        action: DailyAttendanceAction.allPresent,
      ),
      throwsA(isA<StateError>()),
    );
  });
}
