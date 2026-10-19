import 'dart:math';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/assistant/data/assistant_attendance_reader.dart';
import 'package:qingsongban/features/assistant/application/assistant_answer_formatter.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';
import 'package:qingsongban/features/attendance/data/attendance_group_repository.dart';
import 'package:qingsongban/features/attendance/data/daily_attendance_repository.dart';
import 'package:qingsongban/features/attendance/data/monthly_attendance_table_repository.dart';
import 'package:qingsongban/features/attendance/data/monthly_roster_repository.dart';
import 'package:qingsongban/features/attendance/domain/attendance_group_options.dart';
import 'package:qingsongban/features/attendance/domain/daily_attendance_options.dart';
import 'package:qingsongban/features/attendance/domain/monthly_attendance_table_options.dart';
import 'package:qingsongban/features/overtime/data/overtime_repository.dart';
import 'package:qingsongban/features/overtime/domain/overtime_options.dart';
import 'package:qingsongban/features/personnel/data/personnel_repository.dart';
import 'package:qingsongban/features/personnel/domain/personnel_options.dart';

void main() {
  late AppDatabase database;
  late AttendanceGroupRepository groups;
  late MonthlyRosterRepository rosters;
  late DailyAttendanceRepository attendance;
  late OvertimeRepository overtime;
  late PersonnelRepository personnel;
  late AssistantAttendanceReader reader;

  setUp(() {
    database = AppDatabase.forTesting();
    groups = AttendanceGroupRepository(database);
    rosters = MonthlyRosterRepository(database);
    attendance = DailyAttendanceRepository(database);
    overtime = OvertimeRepository(database);
    personnel = PersonnelRepository(database);
    reader = AssistantAttendanceReader(
      database,
      random: Random(12),
      clock: () => DateTime(2026, 10, 17, 12),
    );
  });

  tearDown(() async => database.close());

  Future<Employee> createEmployee(String number, String name) => personnel.save(
    draft: EmployeeDraft(
      employeeNo: number,
      name: name,
      hireDate: DateTime(2025, 1),
      status: EmployeeStatus.active,
    ),
  );

  Future<int> addOvertimeReturningId(
    int employeeId,
    DateTime date,
    int minutes,
  ) async {
    final record = await overtime.save(
      draft: OvertimeRecordDraft(
        employeeId: employeeId,
        overtimeDate: date,
        startTime: DateTime(date.year, date.month, date.day, 18),
        endTime: DateTime(
          date.year,
          date.month,
          date.day,
          18,
        ).add(Duration(minutes: minutes)),
        overtimeType: 'weekday',
      ),
    );
    return record.id;
  }

  Future<void> addOvertime(int employeeId, DateTime date, int minutes) async {
    await addOvertimeReturningId(employeeId, date, minutes);
  }

  Future<void> addTermination(int employeeId, DateTime date) async {
    await database
        .into(database.terminationRecords)
        .insert(
          TerminationRecordsCompanion.insert(
            employeeId: employeeId,
            terminationDate: date,
          ),
        );
  }

  Future<Map<String, Object?>> snapshotAllTables() async {
    final snapshot = <String, Object?>{};
    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    for (final table in tables) {
      final tableName = table.read<String>('name');
      final escapedName = tableName.replaceAll('"', '""');
      final rows = await database
          .customSelect('SELECT * FROM "$escapedName" ORDER BY rowid')
          .get();
      snapshot[tableName] = rows.map((row) => row.data).toList();
    }
    return snapshot;
  }

  test(
    'reuses monthly row rules and counts multi-group attendance once',
    () async {
      final employee = await createEmployee('EMP-A001', '张三');
      final groupA = await groups.save(
        draft: const AttendanceGroupDraft(name: '月表测试A'),
      );
      final groupB = await groups.save(
        draft: const AttendanceGroupDraft(name: '月表测试B'),
      );
      await rosters.addEmployee(
        yearMonth: '2026-09',
        groupId: groupA.id,
        employeeId: employee.id,
      );
      await rosters.addEmployee(
        yearMonth: '2026-09',
        groupId: groupB.id,
        employeeId: employee.id,
      );
      await attendance.save(
        DailyAttendanceDraft(
          employeeId: employee.id,
          attendanceDate: DateTime(2026, 9, 1),
          morningStatus: AttendanceHalfStatus.present,
          afternoonStatus: AttendanceHalfStatus.leave,
        ),
      );
      await attendance.save(
        DailyAttendanceDraft(
          employeeId: employee.id,
          attendanceDate: DateTime(2026, 9, 2),
          morningStatus: AttendanceHalfStatus.rest,
          afternoonStatus: AttendanceHalfStatus.rest,
        ),
      );
      await addOvertime(employee.id, DateTime(2026, 9, 4), 75);
      await addOvertime(employee.id, DateTime(2026, 9, 8), 45);

      final result = await reader.readMonth(
        ResolvedAttendanceQuery(
          employee: ResolvedEmployee(employeeId: employee.id, label: '张三'),
          yearMonth: '2026-09',
          yearMonthSource: AssistantFieldSource.input,
        ),
      );
      final reference = await MonthlyAttendanceTableRepository(database)
          .watchTable(yearMonth: '2026-09', groupId: groupA.id)
          .first;
      final row = reference.rows.single;

      expect(result.status, AttendanceReadStatus.success);
      expect(result.attendanceDays, row.attendanceDays);
      expect(result.leaveAndRestDays, row.leaveDays);
      expect(result.attendanceDays, 0.5);
      expect(result.leaveAndRestDays, 1.5);
      expect(result.overtimeMinutes, 120);
      expect(result.groupLabels, containsAll(['月表测试A', '月表测试B']));
      expect(result.groupIds, containsAll([groupA.id, groupB.id]));
      expect(
        const AssistantAnswerFormatter().formatAnswer(result).groupLabels,
        containsAll(['月表测试A', '月表测试B']),
      );
      expect(
        const AssistantAnswerFormatter().formatAnswer(result).groupIds,
        containsAll([groupA.id, groupB.id]),
      );
      expect(result.completeness, AttendanceCompleteness.notEvaluated);
      expect(result.details!.attendanceDaysByDate[0].morningStatus, '出勤');
      expect(result.details!.attendanceDaysByDate[0].afternoonStatus, '请假');
      expect(result.details!.attendanceDaysByDate[3].morningStatus, '未登记');
      expect(result.details!.overtime, hasLength(2));
    },
  );

  test(
    'does not treat a person outside the effective roster as zero attendance',
    () async {
      final employee = await createEmployee('EMP-A002', '李四');
      final result = await reader.readMonth(
        ResolvedAttendanceQuery(
          employee: ResolvedEmployee(employeeId: employee.id, label: '李四'),
          yearMonth: '2026-09',
          yearMonthSource: AssistantFieldSource.currentYear,
        ),
      );

      expect(result.status, AttendanceReadStatus.notInRoster);
      expect(result.attendanceDays, isNull);
      expect(result.error, AssistantErrorCode.notInRoster);
    },
  );

  test(
    'an empty roster month remains visibly unregistered and unverified',
    () async {
      final employee = await createEmployee('EMP-A007', '孙七');
      final group = await groups.save(
        draft: const AttendanceGroupDraft(name: '未登记测试组'),
      );
      await rosters.addEmployee(
        yearMonth: '2026-09',
        groupId: group.id,
        employeeId: employee.id,
      );

      final result = await reader.readMonth(
        ResolvedAttendanceQuery(
          employee: ResolvedEmployee(employeeId: employee.id, label: '孙七'),
          yearMonth: '2026-09',
          yearMonthSource: AssistantFieldSource.input,
        ),
      );
      final answer = const AssistantAnswerFormatter().formatAnswer(result);

      expect(result.status, AttendanceReadStatus.success);
      expect(result.completeness, AttendanceCompleteness.notEvaluated);
      expect(result.attendanceDays, 0);
      expect(result.details!.attendanceDaysByDate.first.morningStatus, '未登记');
      expect(answer.text, contains('当前已登记汇总'));
      expect(answer.text, isNot(contains('考勤正常')));
    },
  );

  test(
    'exact employee number wins while duplicate exact names remain candidates',
    () async {
      final first = await createEmployee('EMP-A003', '王五');
      await createEmployee('EMP-A004', '王五');
      final duplicateNames = await reader.resolveEmployee(
        const EmployeeSelector(employeeText: '王五', yearMonth: '2026-09'),
      );
      final exactNumber = await reader.resolveEmployee(
        const EmployeeSelector(employeeText: 'EMP-A003', yearMonth: '2026-09'),
      );
      final pageEmployee = await reader.resolveEmployee(
        EmployeeSelector(
          employeeId: first.id,
          existingEmployee: ResolvedEmployee(
            employeeId: first.id,
            label: first.name,
          ),
          yearMonth: '2026-09',
        ),
      );

      expect(duplicateNames.status, EmployeeResolutionStatus.candidates);
      expect(duplicateNames.candidates, hasLength(2));
      expect(exactNumber.status, EmployeeResolutionStatus.unique);
      expect(exactNumber.employee!.employeeId, first.id);
      expect(pageEmployee.status, EmployeeResolutionStatus.unique);
      expect(pageEmployee.employee!.employeeId, first.id);
    },
  );

  test(
    'candidate reference is one-time and rechecks deletion before use',
    () async {
      final first = await createEmployee('EMP-A005', '赵六');
      await createEmployee('EMP-A006', '赵六');
      final resolution = await reader.resolveEmployee(
        const EmployeeSelector(employeeText: '赵六', yearMonth: '2026-09'),
      );
      final candidate = resolution.candidates.firstWhere(
        (item) => item.employeeId == first.id,
      );
      await database.softDeleteEmployee(first.id);

      final stale = await reader.resolveCandidate(candidate.candidateRef);
      final replayed = await reader.resolveCandidate(candidate.candidateRef);
      expect(stale.status, EmployeeResolutionStatus.unavailable);
      expect(replayed.status, EmployeeResolutionStatus.unavailable);
    },
  );

  test('malformed month is returned as a controlled read failure', () async {
    final result = await reader.readMonth(
      const ResolvedAttendanceQuery(
        employee: ResolvedEmployee(employeeId: 1, label: '无效条件'),
        yearMonth: '2026-13',
        yearMonthSource: AssistantFieldSource.input,
      ),
    );

    expect(result.status, AttendanceReadStatus.failure);
    expect(result.error, AssistantErrorCode.invalidArgument);
  });

  test('conflicting active termination dates return a data conflict', () async {
    final employee = await personnel.save(
      draft: EmployeeDraft(
        employeeNo: 'EMP-A008',
        name: '离职冲突员工',
        hireDate: DateTime(2025, 1),
        status: EmployeeStatus.terminated,
      ),
    );
    final group = await groups.save(
      draft: const AttendanceGroupDraft(name: '离职冲突组'),
    );
    await rosters.addEmployee(
      yearMonth: '2026-09',
      groupId: group.id,
      employeeId: employee.id,
    );
    await addTermination(employee.id, DateTime(2026, 9, 10));
    await addTermination(employee.id, DateTime(2026, 9, 12));

    final result = await reader.readMonth(
      ResolvedAttendanceQuery(
        employee: ResolvedEmployee(
          employeeId: employee.id,
          label: employee.name,
        ),
        yearMonth: '2026-09',
        yearMonthSource: AssistantFieldSource.input,
      ),
    );

    expect(result.status, AttendanceReadStatus.dataConflict);
    expect(result.error, AssistantErrorCode.dataConflict);
    expect(result.groupIds, [group.id]);
    expect(result.attendanceDays, isNull);
  });

  test(
    'hire and termination boundaries follow MonthlyAttendanceTableRow rules',
    () async {
      final employee = await personnel.save(
        draft: EmployeeDraft(
          employeeNo: 'EMP-A009',
          name: '边界员工',
          hireDate: DateTime(2026, 9, 5),
          status: EmployeeStatus.terminated,
        ),
      );
      final group = await groups.save(
        draft: const AttendanceGroupDraft(name: '边界测试组'),
      );
      await rosters.addEmployee(
        yearMonth: '2026-09',
        groupId: group.id,
        employeeId: employee.id,
      );
      await addTermination(employee.id, DateTime(2026, 9, 15));
      for (final day in [2, 5, 15, 16]) {
        await database
            .into(database.attendanceRecords)
            .insert(
              AttendanceRecordsCompanion.insert(
                employeeId: employee.id,
                attendanceDate: DateTime(2026, 9, day),
                morningStatus: const Value(AttendanceHalfStatus.present),
                afternoonStatus: const Value(AttendanceHalfStatus.present),
              ),
            );
      }

      final result = await reader.readMonth(
        ResolvedAttendanceQuery(
          employee: ResolvedEmployee(
            employeeId: employee.id,
            label: employee.name,
          ),
          yearMonth: '2026-09',
          yearMonthSource: AssistantFieldSource.input,
        ),
      );
      final reference = MonthlyAttendanceTableRow(
        employee: employee,
        terminationDate: DateTime(2026, 9, 15),
        records: {
          for (final record in await (database.select(
            database.attendanceRecords,
          )..where((table) => table.employeeId.equals(employee.id))).get())
            record.attendanceDate.day: record,
        },
      );

      expect(result.attendanceDays, reference.attendanceDays);
      expect(result.details!.attendanceDaysByDate[1].morningStatus, '未入职');
      expect(result.details!.attendanceDaysByDate[4].morningStatus, '出勤');
      expect(result.details!.attendanceDaysByDate[14].morningStatus, '出勤');
      expect(result.details!.attendanceDaysByDate[15].morningStatus, '已离职');
    },
  );

  test('overtime is month-bounded and deleted records are excluded', () async {
    final employee = await createEmployee('EMP-A010', '加班员工');
    final group = await groups.save(
      draft: const AttendanceGroupDraft(name: '加班月份组'),
    );
    await rosters.addEmployee(
      yearMonth: '2026-09',
      groupId: group.id,
      employeeId: employee.id,
    );
    await addOvertime(employee.id, DateTime(2026, 9, 30), 60);
    await addOvertime(employee.id, DateTime(2026, 10, 1), 90);
    final deleted = await addOvertimeReturningId(
      employee.id,
      DateTime(2026, 9, 20),
      120,
    );
    await overtime.delete(deleted);

    final result = await reader.readMonth(
      ResolvedAttendanceQuery(
        employee: ResolvedEmployee(
          employeeId: employee.id,
          label: employee.name,
        ),
        yearMonth: '2026-09',
        yearMonthSource: AssistantFieldSource.input,
      ),
    );

    expect(result.overtimeMinutes, 60);
    expect(result.details!.overtime.map((detail) => detail.durationMinutes), [
      60,
    ]);
  });

  test(
    'reading a snapshot leaves every business table content unchanged',
    () async {
      final employee = await createEmployee('EMP-A011', '只读快照员工');
      final group = await groups.save(
        draft: const AttendanceGroupDraft(name: '只读快照组'),
      );
      await rosters.addEmployee(
        yearMonth: '2026-09',
        groupId: group.id,
        employeeId: employee.id,
      );
      await attendance.save(
        DailyAttendanceDraft(
          employeeId: employee.id,
          attendanceDate: DateTime(2026, 9, 7),
          morningStatus: AttendanceHalfStatus.present,
          afternoonStatus: AttendanceHalfStatus.leave,
        ),
      );
      await addOvertime(employee.id, DateTime(2026, 9, 8), 45);
      await addTermination(employee.id, DateTime(2026, 9, 25));
      final before = await snapshotAllTables();

      await reader.readMonth(
        ResolvedAttendanceQuery(
          employee: ResolvedEmployee(
            employeeId: employee.id,
            label: employee.name,
          ),
          yearMonth: '2026-09',
          yearMonthSource: AssistantFieldSource.input,
        ),
      );

      expect(await snapshotAllTables(), before);
    },
  );

  test(
    'database read exception remains a controlled failure, never zero success',
    () async {
      final employee = await createEmployee('EMP-A012', '读取异常员工');
      final group = await groups.save(
        draft: const AttendanceGroupDraft(name: '读取异常组'),
      );
      await rosters.addEmployee(
        yearMonth: '2026-09',
        groupId: group.id,
        employeeId: employee.id,
      );
      await database.customStatement('DROP TABLE attendance_records');

      final result = await reader.readMonth(
        ResolvedAttendanceQuery(
          employee: ResolvedEmployee(
            employeeId: employee.id,
            label: employee.name,
          ),
          yearMonth: '2026-09',
          yearMonthSource: AssistantFieldSource.input,
        ),
      );
      final answer = const AssistantAnswerFormatter().formatAnswer(result);

      expect(result.status, AttendanceReadStatus.failure);
      expect(result.error, AssistantErrorCode.unknown);
      expect(answer.attendanceDays, isNull);
      expect(answer.text, '本地考勤读取失败，请重试。');
      expect(answer.text, isNot(contains('出勤 0 天')));
    },
  );
}
