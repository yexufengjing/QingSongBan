import 'package:flutter_test/flutter_test.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/attendance/data/daily_attendance_repository.dart';
import 'package:qingsongban/features/attendance/domain/daily_attendance_options.dart';
import 'package:qingsongban/features/leave/data/leave_repository.dart';
import 'package:qingsongban/features/leave/domain/leave_options.dart';
import 'package:qingsongban/features/personnel/data/personnel_repository.dart';
import 'package:qingsongban/features/personnel/domain/personnel_options.dart';

void main() {
  late AppDatabase database;
  late LeaveRepository leaveRepository;
  late DailyAttendanceRepository dailyRepository;
  late PersonnelRepository personnelRepository;

  setUp(() {
    database = AppDatabase.forTesting();
    leaveRepository = LeaveRepository(database);
    dailyRepository = DailyAttendanceRepository(database);
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

  LeaveRecordDraft draft({
    required int employeeId,
    required DateTime startDate,
    DateTime? endDate,
    LeaveHalfPeriod startPeriod = LeaveHalfPeriod.morning,
    LeaveHalfPeriod endPeriod = LeaveHalfPeriod.afternoon,
    LeaveType leaveType = LeaveType.personal,
  }) {
    return LeaveRecordDraft(
      employeeId: employeeId,
      leaveType: leaveType,
      startDate: startDate,
      endDate: endDate ?? startDate,
      startPeriod: startPeriod,
      endPeriod: endPeriod,
    );
  }

  test('syncs half-day and full-day leave into attendance records', () async {
    final employee = await createEmployee('EMP-L001', '张三');

    final halfDay = await leaveRepository.save(
      draft: draft(
        employeeId: employee.id,
        startDate: DateTime(2026, 9, 5),
        startPeriod: LeaveHalfPeriod.morning,
        endPeriod: LeaveHalfPeriod.morning,
      ),
    );
    expect(LeaveOptions.halfDays(halfDay), 0.5);
    var record = await database.findAttendanceRecord(
      employee.id,
      DateTime(2026, 9, 5),
    );
    expect(record?.morningStatus, AttendanceHalfStatus.leave);
    expect(record?.afternoonStatus, AttendanceHalfStatus.unregistered);

    final fullDay = await leaveRepository.save(
      draft: draft(employeeId: employee.id, startDate: DateTime(2026, 9, 6)),
    );
    expect(LeaveOptions.halfDays(fullDay), 1);
    record = await database.findAttendanceRecord(
      employee.id,
      DateTime(2026, 9, 6),
    );
    expect(record?.morningStatus, AttendanceHalfStatus.leave);
    expect(record?.afternoonStatus, AttendanceHalfStatus.leave);
    expect(
      await leaveRepository.watchLeaves(month: DateTime(2026, 9)).first,
      hasLength(2),
    );
  });

  test('splits cross-month leave into both calendar months', () async {
    final employee = await createEmployee('EMP-L101', '李四');
    final leave = await leaveRepository.save(
      draft: draft(
        employeeId: employee.id,
        startDate: DateTime(2026, 9, 30),
        endDate: DateTime(2026, 10, 1),
        startPeriod: LeaveHalfPeriod.afternoon,
        endPeriod: LeaveHalfPeriod.morning,
        leaveType: LeaveType.sick,
      ),
    );

    expect(LeaveOptions.halfDays(leave), 1);
    final september = await database.findAttendanceRecord(
      employee.id,
      DateTime(2026, 9, 30),
    );
    final october = await database.findAttendanceRecord(
      employee.id,
      DateTime(2026, 10, 1),
    );
    expect(september?.morningStatus, AttendanceHalfStatus.unregistered);
    expect(september?.afternoonStatus, AttendanceHalfStatus.leave);
    expect(october?.morningStatus, AttendanceHalfStatus.leave);
    expect(october?.afternoonStatus, AttendanceHalfStatus.unregistered);
    expect(
      (await leaveRepository.watchLeaves(month: DateTime(2026, 9)).first)
          .single
          .leave
          .leaveType,
      LeaveType.sick,
    );
    expect(
      await leaveRepository.watchLeaves(month: DateTime(2026, 10)).first,
      hasLength(1),
    );
  });

  test('editing a leave resyncs the old and new date ranges', () async {
    final employee = await createEmployee('EMP-L201', '王五');
    final leave = await leaveRepository.save(
      draft: draft(employeeId: employee.id, startDate: DateTime(2026, 9, 10)),
    );

    final updated = await leaveRepository.save(
      id: leave.id,
      draft: draft(
        employeeId: employee.id,
        startDate: DateTime(2026, 9, 11),
        startPeriod: LeaveHalfPeriod.afternoon,
        endPeriod: LeaveHalfPeriod.afternoon,
      ),
    );
    expect(updated.id, leave.id);
    final oldDate = await database.findAttendanceRecord(
      employee.id,
      DateTime(2026, 9, 10),
    );
    final newDate = await database.findAttendanceRecord(
      employee.id,
      DateTime(2026, 9, 11),
    );
    expect(oldDate?.morningStatus, AttendanceHalfStatus.unregistered);
    expect(oldDate?.afternoonStatus, AttendanceHalfStatus.unregistered);
    expect(newDate?.morningStatus, AttendanceHalfStatus.unregistered);
    expect(newDate?.afternoonStatus, AttendanceHalfStatus.leave);
  });

  test(
    'deleting leave restores only unchanged automatic leave statuses',
    () async {
      final employee = await createEmployee('EMP-L301', '赵六');
      final leave = await leaveRepository.save(
        draft: draft(employeeId: employee.id, startDate: DateTime(2026, 9, 12)),
      );

      await dailyRepository.save(
        DailyAttendanceDraft(
          employeeId: employee.id,
          attendanceDate: DateTime(2026, 9, 12),
          morningStatus: AttendanceHalfStatus.present,
          afternoonStatus: AttendanceHalfStatus.leave,
          remark: '后来手动确认',
        ),
      );
      await leaveRepository.delete(leave.id);

      final record = await database.findAttendanceRecord(
        employee.id,
        DateTime(2026, 9, 12),
      );
      expect(record?.morningStatus, AttendanceHalfStatus.present);
      expect(record?.afternoonStatus, AttendanceHalfStatus.unregistered);
      expect(record?.remark, '后来手动确认');
      expect(
        await leaveRepository.watchLeaves(month: DateTime(2026, 9)).first,
        isEmpty,
      );
    },
  );

  test(
    'overlapping leave remains effective until all records are deleted',
    () async {
      final employee = await createEmployee('EMP-L401', '钱七');
      final first = await leaveRepository.save(
        draft: draft(employeeId: employee.id, startDate: DateTime(2026, 9, 20)),
      );
      final second = await leaveRepository.save(
        draft: draft(employeeId: employee.id, startDate: DateTime(2026, 9, 20)),
      );

      await leaveRepository.delete(first.id);
      var record = await database.findAttendanceRecord(
        employee.id,
        DateTime(2026, 9, 20),
      );
      expect(record?.morningStatus, AttendanceHalfStatus.leave);
      expect(record?.afternoonStatus, AttendanceHalfStatus.leave);

      await leaveRepository.delete(second.id);
      record = await database.findAttendanceRecord(
        employee.id,
        DateTime(2026, 9, 20),
      );
      expect(record?.morningStatus, AttendanceHalfStatus.unregistered);
      expect(record?.afternoonStatus, AttendanceHalfStatus.unregistered);
    },
  );
}
