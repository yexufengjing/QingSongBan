import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';

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
import 'package:qingsongban/features/termination/data/termination_repository.dart';
import 'package:qingsongban/features/termination/domain/termination_options.dart';

void main() {
  late AppDatabase database;
  late AttendanceGroupRepository groupRepository;
  late DailyAttendanceRepository dailyRepository;
  late MonthlyAttendanceTableRepository tableRepository;
  late MonthlyRosterRepository rosterRepository;
  late PersonnelRepository personnelRepository;
  late TerminationRepository terminationRepository;

  setUp(() {
    database = AppDatabase.forTesting();
    groupRepository = AttendanceGroupRepository(database);
    dailyRepository = DailyAttendanceRepository(database);
    tableRepository = MonthlyAttendanceTableRepository(database);
    rosterRepository = MonthlyRosterRepository(database);
    personnelRepository = PersonnelRepository(database);
    terminationRepository = TerminationRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('keeps pre-termination history and blocks later attendance', () async {
    final group = await groupRepository.save(
      draft: const AttendanceGroupDraft(name: '离职联动组'),
    );
    final employee = await personnelRepository.save(
      draft: EmployeeDraft(
        employeeNo: 'EMP-T001',
        name: '张三',
        hireDate: DateTime(2026, 1, 1),
        status: EmployeeStatus.active,
        defaultAttendanceGroupId: group.id,
      ),
    );
    await rosterRepository.addEmployee(
      yearMonth: '2026-09',
      groupId: group.id,
      employeeId: employee.id,
    );
    await dailyRepository.save(
      DailyAttendanceDraft(
        employeeId: employee.id,
        attendanceDate: DateTime(2026, 9, 10),
        morningStatus: AttendanceHalfStatus.present,
        afternoonStatus: AttendanceHalfStatus.present,
      ),
    );

    final termination = await terminationRepository.save(
      draft: TerminationRecordDraft(
        employeeId: employee.id,
        terminationDate: DateTime(2026, 9, 15),
        terminationType: 'personal',
        isInsuranceStopped: true,
        stopInsuranceMonth: '2026-10',
        toolsReturned: true,
        materialsTransferred: true,
        hasUnsettledItems: false,
      ),
    );
    expect(termination.isInsuranceStopped, isTrue);
    expect(termination.stopInsuranceMonth, '2026-10');
    expect(
      (await personnelRepository.findById(employee.id))?.status,
      EmployeeStatus.terminated,
    );

    final before =
        (await dailyRepository
                .watchEntries(
                  attendanceDate: DateTime(2026, 9, 10),
                  groupId: group.id,
                )
                .first)
            .single;
    expect(before.isEditable, isTrue);
    expect(before.morningStatus, AttendanceHalfStatus.present);

    final after =
        (await dailyRepository
                .watchEntries(
                  attendanceDate: DateTime(2026, 9, 16),
                  groupId: group.id,
                )
                .first)
            .single;
    expect(after.isEditable, isFalse);
    expect(after.morningStatus, AttendanceHalfStatus.terminated);
    await expectLater(
      dailyRepository.save(
        DailyAttendanceDraft(
          employeeId: employee.id,
          attendanceDate: DateTime(2026, 9, 16),
          morningStatus: AttendanceHalfStatus.present,
          afternoonStatus: AttendanceHalfStatus.present,
        ),
      ),
      throwsA(isA<StateError>()),
    );

    final table = await tableRepository
        .watchTable(yearMonth: '2026-09', groupId: group.id)
        .first;
    final row = table.rows.single;
    expect(row.cellForDay(month: DateTime(2026, 9), day: 10).symbol, '力');
    expect(row.cellForDay(month: DateTime(2026, 9), day: 16).symbol, '离');
    expect(
      await rosterRepository.watchEligibleEmployees(yearMonth: '2026-10').first,
      isEmpty,
    );
  });

  test(
    'revoking termination restores status without rewriting history',
    () async {
      final employee = await personnelRepository.save(
        draft: EmployeeDraft(
          employeeNo: 'EMP-T101',
          name: '李四',
          hireDate: DateTime(2026, 1, 1),
          status: EmployeeStatus.active,
        ),
      );
      await dailyRepository.save(
        DailyAttendanceDraft(
          employeeId: employee.id,
          attendanceDate: DateTime(2026, 9, 12),
          morningStatus: AttendanceHalfStatus.present,
          afternoonStatus: AttendanceHalfStatus.leave,
          remark: '离职前记录',
        ),
      );
      final termination = await terminationRepository.save(
        draft: TerminationRecordDraft(
          employeeId: employee.id,
          terminationDate: DateTime(2026, 9, 15),
          terminationType: 'contractEnded',
          isInsuranceStopped: false,
          toolsReturned: false,
          materialsTransferred: false,
          hasUnsettledItems: true,
        ),
      );

      await terminationRepository.revoke(termination.id);
      expect(
        (await personnelRepository.findById(employee.id))?.status,
        EmployeeStatus.active,
      );
      final history = await database.findAttendanceRecord(
        employee.id,
        DateTime(2026, 9, 12),
      );
      expect(history?.morningStatus, AttendanceHalfStatus.present);
      expect(history?.afternoonStatus, AttendanceHalfStatus.leave);
      expect(history?.remark, '离职前记录');
      expect(await terminationRepository.watchTerminations().first, isEmpty);
    },
  );

  test('creates and revokes a stop-insurance reminder', () async {
    final employee = await personnelRepository.save(
      draft: EmployeeDraft(
        employeeNo: 'EMP-T150',
        name: '赵六',
        hireDate: DateTime(2026, 1, 1),
        status: EmployeeStatus.active,
      ),
    );

    final termination = await terminationRepository.save(
      draft: TerminationRecordDraft(
        employeeId: employee.id,
        terminationDate: DateTime(2026, 9, 15),
        terminationType: 'contractEnded',
        isInsuranceStopped: false,
        stopInsuranceMonth: '2026-10',
        toolsReturned: true,
        materialsTransferred: true,
        hasUnsettledItems: false,
      ),
    );

    final reminder =
        await (database.select(database.reminders)..where(
              (table) =>
                  table.sourceEntityType.equals('termination') &
                  table.sourceEntityId.equals(termination.id),
            ))
            .getSingle();
    expect(reminder.title, '办理 赵六 停保');
    expect(reminder.reminderType, 'terminationInsurance');
    expect(reminder.dueDate, DateTime(2026, 10, 1, 9));
    expect(reminder.isCompleted, isFalse);

    await terminationRepository.revoke(termination.id);

    final revoked = await (database.select(
      database.reminders,
    )..where((table) => table.id.equals(reminder.id))).getSingle();
    expect(revoked.isDeleted, isTrue);
  });

  test('does not allow duplicate active termination records', () async {
    final employee = await personnelRepository.save(
      draft: EmployeeDraft(
        employeeNo: 'EMP-T201',
        name: '王五',
        hireDate: DateTime(2026, 1, 1),
        status: EmployeeStatus.active,
      ),
    );
    await terminationRepository.save(
      draft: TerminationRecordDraft(
        employeeId: employee.id,
        terminationDate: DateTime(2026, 9, 1),
        terminationType: 'personal',
        isInsuranceStopped: false,
        toolsReturned: false,
        materialsTransferred: false,
        hasUnsettledItems: false,
      ),
    );
    await expectLater(
      terminationRepository.save(
        draft: TerminationRecordDraft(
          employeeId: employee.id,
          terminationDate: DateTime(2026, 9, 2),
          terminationType: 'other',
          isInsuranceStopped: false,
          toolsReturned: false,
          materialsTransferred: false,
          hasUnsettledItems: false,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
