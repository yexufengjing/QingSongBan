import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/attendance/data/attendance_group_repository.dart';
import 'package:qingsongban/features/attendance/data/daily_attendance_repository.dart';
import 'package:qingsongban/features/attendance/data/monthly_roster_repository.dart';
import 'package:qingsongban/features/attendance/domain/attendance_group_options.dart';
import 'package:qingsongban/features/attendance/domain/daily_attendance_options.dart';
import 'package:qingsongban/features/leave/data/leave_repository.dart';
import 'package:qingsongban/features/leave/domain/leave_options.dart';
import 'package:qingsongban/features/overtime/data/overtime_repository.dart';
import 'package:qingsongban/features/overtime/domain/overtime_options.dart';
import 'package:qingsongban/features/personnel/data/personnel_repository.dart';
import 'package:qingsongban/features/personnel/domain/personnel_options.dart';
import 'package:qingsongban/features/reports/data/monthly_summary_repository.dart';
import 'package:qingsongban/features/reports/domain/monthly_summary_options.dart';

void main() {
  late AppDatabase database;
  late AttendanceGroupRepository groupRepository;
  late DailyAttendanceRepository dailyRepository;
  late LeaveRepository leaveRepository;
  late MonthlyRosterRepository rosterRepository;
  late MonthlySummaryRepository summaryRepository;
  late OvertimeRepository overtimeRepository;
  late PersonnelRepository personnelRepository;

  setUp(() {
    database = AppDatabase.forTesting();
    groupRepository = AttendanceGroupRepository(database);
    dailyRepository = DailyAttendanceRepository(database);
    leaveRepository = LeaveRepository(database);
    rosterRepository = MonthlyRosterRepository(database);
    summaryRepository = MonthlySummaryRepository(database);
    overtimeRepository = OvertimeRepository(database);
    personnelRepository = PersonnelRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('generates half-day attendance and overtime totals', () async {
    final group = await groupRepository.save(
      draft: const AttendanceGroupDraft(name: '汇总测试组'),
    );
    final employee = await personnelRepository.save(
      draft: EmployeeDraft(
        employeeNo: 'EMP-S001',
        name: '张三',
        hireDate: DateTime(2026, 1, 1),
        status: EmployeeStatus.active,
      ),
    );
    await rosterRepository.addEmployee(
      yearMonth: '2026-08',
      groupId: group.id,
      employeeId: employee.id,
    );
    await dailyRepository.save(
      DailyAttendanceDraft(
        employeeId: employee.id,
        attendanceDate: DateTime(2026, 8, 5),
        morningStatus: AttendanceHalfStatus.present,
        afternoonStatus: AttendanceHalfStatus.present,
      ),
    );
    await dailyRepository.save(
      DailyAttendanceDraft(
        employeeId: employee.id,
        attendanceDate: DateTime(2026, 8, 6),
        morningStatus: AttendanceHalfStatus.present,
        afternoonStatus: AttendanceHalfStatus.leave,
      ),
    );
    await overtimeRepository.save(
      draft: OvertimeRecordDraft(
        employeeId: employee.id,
        overtimeDate: DateTime(2026, 8, 5),
        startTime: DateTime(2026, 8, 5, 18),
        endTime: DateTime(2026, 8, 5, 20, 30),
        overtimeType: 'weekday',
      ),
    );
    await overtimeRepository.save(
      draft: OvertimeRecordDraft(
        employeeId: employee.id,
        overtimeDate: DateTime(2026, 8, 6),
        startTime: DateTime(2026, 8, 6, 18),
        endTime: DateTime(2026, 8, 6, 19),
        overtimeType: 'weekday',
      ),
    );

    final summary = await summaryRepository.generate(yearMonth: '2026-08');
    final row = summary.rows.single;
    expect(row.summary.attendanceDays, 1.5);
    expect(row.summary.leaveDays, 0.5);
    expect(row.summary.absentDays, 0);
    expect(row.summary.overtimeCount, 2);
    expect(row.summary.overtimeMinutes, 210);
    expect(summary.status, MonthlySummaryStatus.pendingReview);
    expect(summary.anomalies, isNotEmpty);
    expect(row.summary.isComplete, isFalse);
  });

  test(
    'tracks leave conflicts and legacy overtime overlaps as anomalies',
    () async {
      final group = await groupRepository.save(
        draft: const AttendanceGroupDraft(name: '异常检查组'),
      );
      final employee = await personnelRepository.save(
        draft: EmployeeDraft(
          employeeNo: 'EMP-S101',
          name: '李四',
          hireDate: DateTime(2026, 1, 1),
          status: EmployeeStatus.active,
        ),
      );
      await rosterRepository.addEmployee(
        yearMonth: '2026-08',
        groupId: group.id,
        employeeId: employee.id,
      );
      await leaveRepository.save(
        draft: LeaveRecordDraft(
          employeeId: 1,
          leaveType: LeaveType.personal,
          startDate: DateTime(2026, 8, 10),
          endDate: DateTime(2026, 8, 10),
          startPeriod: LeaveHalfPeriod.morning,
          endPeriod: LeaveHalfPeriod.afternoon,
        ),
      );
      await dailyRepository.save(
        DailyAttendanceDraft(
          employeeId: employee.id,
          attendanceDate: DateTime(2026, 8, 10),
          morningStatus: AttendanceHalfStatus.present,
          afternoonStatus: AttendanceHalfStatus.leave,
        ),
      );
      await database
          .into(database.overtimeRecords)
          .insert(
            OvertimeRecordsCompanion.insert(
              employeeId: employee.id,
              overtimeDate: DateTime(2026, 8, 12),
              startTime: DateTime(2026, 8, 12, 18),
              endTime: DateTime(2026, 8, 12, 20),
              durationMinutes: 120,
            ),
          );
      await database
          .into(database.overtimeRecords)
          .insert(
            OvertimeRecordsCompanion.insert(
              employeeId: employee.id,
              overtimeDate: DateTime(2026, 8, 12),
              startTime: DateTime(2026, 8, 12, 19),
              endTime: DateTime(2026, 8, 12, 21),
              durationMinutes: 120,
            ),
          );

      final summary = await summaryRepository.generate(yearMonth: '2026-08');
      expect(
        summary.anomalies.any(
          (item) => item.kind == MonthlySummaryAnomalyKind.leaveConflict,
        ),
        isTrue,
      );
      expect(
        summary.anomalies.any(
          (item) => item.kind == MonthlySummaryAnomalyKind.overtimeOverlap,
        ),
        isTrue,
      );
    },
  );

  test('supports confirm, lock, and reasoned unlock', () async {
    final group = await groupRepository.save(
      draft: const AttendanceGroupDraft(name: '状态汇总组'),
    );
    final employee = await personnelRepository.save(
      draft: EmployeeDraft(
        employeeNo: 'EMP-S201',
        name: '王五',
        hireDate: DateTime(2026, 1, 1),
        status: EmployeeStatus.active,
      ),
    );
    await rosterRepository.addEmployee(
      yearMonth: '2026-08',
      groupId: group.id,
      employeeId: employee.id,
    );
    await summaryRepository.generate(yearMonth: '2026-08');
    await summaryRepository.setStatus(
      yearMonth: '2026-08',
      status: MonthlySummaryStatus.confirmed,
    );
    await summaryRepository.setStatus(
      yearMonth: '2026-08',
      status: MonthlySummaryStatus.locked,
    );
    await expectLater(
      summaryRepository.generate(yearMonth: '2026-08'),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      summaryRepository.setStatus(
        yearMonth: '2026-08',
        status: MonthlySummaryStatus.pendingReview,
      ),
      throwsA(isA<FormatException>()),
    );
    await summaryRepository.setStatus(
      yearMonth: '2026-08',
      status: MonthlySummaryStatus.pendingReview,
      reason: '补录考勤后重新检查',
    );
    expect(
      (await summaryRepository.watchSummary(yearMonth: '2026-08').first).status,
      MonthlySummaryStatus.pendingReview,
    );
    expect(await (database.select(database.operationLogs)).get(), hasLength(1));
  });
}
