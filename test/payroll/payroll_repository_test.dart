import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/features/attendance/data/attendance_group_repository.dart';
import 'package:qingsongban/features/attendance/data/daily_attendance_repository.dart';
import 'package:qingsongban/features/attendance/data/monthly_roster_repository.dart';
import 'package:qingsongban/features/attendance/domain/attendance_group_options.dart';
import 'package:qingsongban/features/attendance/domain/daily_attendance_options.dart';
import 'package:qingsongban/features/personnel/data/personnel_repository.dart';
import 'package:qingsongban/features/personnel/domain/personnel_options.dart';
import 'package:qingsongban/features/payroll/data/payroll_repository.dart';
import 'package:qingsongban/features/payroll/data/wage_settings_repository.dart';

void main() {
  late AppDatabase database;
  late PersonnelRepository personnel;
  late AttendanceGroupRepository groups;
  late MonthlyRosterRepository rosters;
  late DailyAttendanceRepository attendance;
  late PayrollRepository payroll;
  late WageSettingsRepository wages;

  setUp(() {
    database = AppDatabase.forTesting();
    personnel = PersonnelRepository(database);
    groups = AttendanceGroupRepository(database);
    rosters = MonthlyRosterRepository(database);
    attendance = DailyAttendanceRepository(database);
    payroll = PayrollRepository(database);
    wages = WageSettingsRepository(database);
  });

  tearDown(() => database.close());

  test(
    'generates a deduplicated temporary-worker roster from confirmed summary',
    () async {
      final group = await groups.save(
        draft: const AttendanceGroupDraft(name: '工资测试组'),
      );
      final employee = await personnel.save(
        draft: EmployeeDraft(
          employeeNo: 'EMP-P001',
          name: '张三',
          hireDate: DateTime(2026, 9, 1),
          status: EmployeeStatus.active,
          employmentType: '临时工',
        ),
      );
      final jobType = await wages.saveJobType(
        draft: const WageJobTypeDraft(name: '绿化工', defaultDailyWage: 120),
      );
      await wages.saveProfile(
        EmployeeWageProfileDraft(
          employeeId: employee.id,
          participatesInPayroll: true,
          jobTypeId: jobType.id,
        ),
      );
      await rosters.addEmployee(
        yearMonth: '2026-09',
        groupId: group.id,
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
      final summary = await _generateSummary(database, employee.id, group.id);
      await database
          .update(database.monthlyAttendanceSummaries)
          .write(
            const MonthlyAttendanceSummariesCompanion(
              status: Value(MonthlySummaryStatus.confirmed),
            ),
          );

      final batch = await payroll.ensureDraft('2026-09');
      await payroll.generateRoster(batch.id);
      final item = await payroll.watchItems(batch.id).first;
      expect(item, hasLength(1));
      expect(item.single.item.attendanceHalfDaysSnapshot, 1);
      expect(item.single.item.dailyWage, 120);
      expect(summary, isA<int>());
    },
  );

  test(
    'preserves manual values while syncing attendance and clamps negative pay',
    () async {
      final group = await groups.save(
        draft: const AttendanceGroupDraft(name: '同步工资组'),
      );
      final employee = await personnel.save(
        draft: EmployeeDraft(
          employeeNo: 'EMP-P002',
          name: '李四',
          hireDate: DateTime(2026, 9, 1),
          status: EmployeeStatus.active,
          employmentType: '临时工',
        ),
      );
      final jobType = await wages.saveJobType(
        draft: const WageJobTypeDraft(name: '环卫工', defaultDailyWage: 100),
      );
      await wages.saveProfile(
        EmployeeWageProfileDraft(
          employeeId: employee.id,
          participatesInPayroll: true,
          jobTypeId: jobType.id,
        ),
      );
      await rosters.addEmployee(
        yearMonth: '2026-09',
        groupId: group.id,
        employeeId: employee.id,
      );
      await attendance.save(
        DailyAttendanceDraft(
          employeeId: employee.id,
          attendanceDate: DateTime(2026, 9, 2),
          morningStatus: AttendanceHalfStatus.present,
          afternoonStatus: AttendanceHalfStatus.present,
        ),
      );
      await _generateSummary(database, employee.id, group.id);
      await database
          .update(database.monthlyAttendanceSummaries)
          .write(
            const MonthlyAttendanceSummariesCompanion(
              status: Value(MonthlySummaryStatus.confirmed),
            ),
          );
      final batch = await payroll.ensureDraft('2026-09');
      await payroll.generateRoster(batch.id);
      final item = (await payroll.watchItems(batch.id).first).single.item;
      await payroll.updateItem(
        itemId: item.id,
        subsidy: 0,
        insuranceDeduction: 500,
      );
      await attendance.save(
        DailyAttendanceDraft(
          employeeId: employee.id,
          attendanceDate: DateTime(2026, 9, 3),
          morningStatus: AttendanceHalfStatus.present,
          afternoonStatus: AttendanceHalfStatus.present,
        ),
      );
      await _generateSummary(database, employee.id, group.id);
      await database
          .update(database.monthlyAttendanceSummaries)
          .write(
            const MonthlyAttendanceSummariesCompanion(
              status: Value(MonthlySummaryStatus.confirmed),
            ),
          );
      await payroll.syncAttendance(batch.id);
      final synced = (await payroll.watchItems(batch.id).first).single.item;
      expect(synced.insuranceDeduction, 500);
      expect(synced.finalWage, 0);
      expect(synced.attendanceHalfDaysSnapshot, 4);
    },
  );

  test(
    'resolves wage priority, inherits order, and requires status reasons',
    () async {
      final first = await personnel.save(
        draft: EmployeeDraft(
          employeeNo: 'EMP-P003',
          name: '王五',
          hireDate: DateTime(2026, 9, 1),
          status: EmployeeStatus.active,
          employmentType: '临时工',
        ),
      );
      final second = await personnel.save(
        draft: EmployeeDraft(
          employeeNo: 'EMP-P004',
          name: '赵六',
          hireDate: DateTime(2026, 9, 1),
          status: EmployeeStatus.active,
          employmentType: '临时工',
        ),
      );
      final jobType = await wages.saveJobType(
        draft: const WageJobTypeDraft(name: '临时工', defaultDailyWage: 100),
      );
      await wages.saveRate(
        WageRateDraft(
          jobTypeId: jobType.id,
          dailyWage: 110,
          effectiveMonth: '2026-08',
        ),
      );
      await wages.saveRate(
        WageRateDraft(
          jobTypeId: jobType.id,
          dailyWage: 120,
          effectiveMonth: '2026-09',
        ),
      );
      await wages.saveProfile(
        EmployeeWageProfileDraft(
          employeeId: first.id,
          participatesInPayroll: true,
          jobTypeId: jobType.id,
          useJobDefaultWage: false,
          personalDailyWage: 150,
        ),
      );
      await wages.saveProfile(
        EmployeeWageProfileDraft(
          employeeId: second.id,
          participatesInPayroll: true,
          jobTypeId: jobType.id,
        ),
      );
      await _insertConfirmedSummary(
        database,
        yearMonth: '2026-09',
        employeeId: first.id,
        attendanceDays: 1,
      );
      await _insertConfirmedSummary(
        database,
        yearMonth: '2026-09',
        employeeId: second.id,
        attendanceDays: 1,
      );

      final previousBatch = await payroll.ensureDraft('2026-09');
      await payroll.generateRoster(previousBatch.id);
      await payroll.generateRoster(previousBatch.id);
      final previousItems = await payroll.watchItems(previousBatch.id).first;
      expect(previousItems.every((row) => !row.item.attendanceChanged), isTrue);
      await payroll.reorder(
        batchId: previousBatch.id,
        itemIds: [previousItems.last.item.id, previousItems.first.item.id],
      );
      final previousAfterOrder = await payroll
          .watchItems(previousBatch.id)
          .first;
      expect(previousAfterOrder.first.item.employeeId, second.id);
      expect(previousAfterOrder.first.item.dailyWage, 120);
      expect(previousAfterOrder.last.item.dailyWage, 150);

      await _insertConfirmedSummary(
        database,
        yearMonth: '2026-10',
        employeeId: first.id,
        attendanceDays: 1,
      );
      await _insertConfirmedSummary(
        database,
        yearMonth: '2026-10',
        employeeId: second.id,
        attendanceDays: 1,
      );
      final batch = await payroll.ensureDraft('2026-10');
      await payroll.generateRoster(batch.id);
      final items = await payroll.watchItems(batch.id).first;
      expect(items.map((row) => row.item.employeeId), [second.id, first.id]);
      expect(items.first.item.dailyWage, 120);
      expect(items.last.item.dailyWage, 150);
      final payrollReminders = await (database.select(
        database.reminders,
      )..where((table) => table.reminderType.equals('payroll'))).get();
      expect(payrollReminders, hasLength(2));

      await payroll.validate(batch.id);
      expect(
        (await payroll.findBatch(batch.id))?.status,
        PayrollStatus.pendingReview,
      );
      var batchReminder = await (database.select(
        database.reminders,
      )..where((table) => table.sourceEntityId.equals(batch.id))).getSingle();
      expect(batchReminder.title, contains('待检查'));
      await payroll.setStatus(
        batchId: batch.id,
        status: PayrollStatus.confirmed,
      );
      expect(
        (await payroll.findBatch(batch.id))?.status,
        PayrollStatus.confirmed,
      );
      batchReminder = await (database.select(
        database.reminders,
      )..where((table) => table.sourceEntityId.equals(batch.id))).getSingle();
      expect(batchReminder.title, contains('待锁定'));
      expect(batchReminder.isCompleted, isFalse);
      await payroll.setStatus(batchId: batch.id, status: PayrollStatus.locked);
      batchReminder = await (database.select(
        database.reminders,
      )..where((table) => table.sourceEntityId.equals(batch.id))).getSingle();
      expect(batchReminder.isCompleted, isTrue);
      await expectLater(
        payroll.setStatus(
          batchId: batch.id,
          status: PayrollStatus.pendingReview,
        ),
        throwsA(isA<FormatException>()),
      );
      await payroll.setStatus(
        batchId: batch.id,
        status: PayrollStatus.pendingReview,
        reason: '重新核对出勤',
      );
      batchReminder = await (database.select(
        database.reminders,
      )..where((table) => table.sourceEntityId.equals(batch.id))).getSingle();
      expect(batchReminder.isCompleted, isFalse);
      final riskyItem = (await payroll.watchItems(batch.id).first).first.item;
      await payroll.updateItem(itemId: riskyItem.id, insuranceDeduction: 1000);
      await expectLater(
        payroll.setStatus(batchId: batch.id, status: PayrollStatus.confirmed),
        throwsA(isA<StateError>()),
      );
      await payroll.setStatus(
        batchId: batch.id,
        status: PayrollStatus.confirmed,
        reason: '保险扣除已人工复核',
      );

      final logs = await database.select(database.operationLogs).get();
      expect(logs.any((log) => log.operationType == 'confirm_payroll'), isTrue);
      final unlockLog = logs.firstWhere(
        (log) => log.operationType == 'unlock_payroll',
      );
      expect(jsonDecode(unlockLog.detail!)['reason'], '重新核对出勤');
    },
  );
}

Future<Object?> _generateSummary(
  AppDatabase database,
  int employeeId,
  int groupId,
) async {
  final records = await (database.select(
    database.attendanceRecords,
  )..where((table) => table.employeeId.equals(employeeId))).get();
  final attendanceDays =
      records.fold<int>(
        0,
        (sum, record) =>
            sum +
            (record.morningStatus == AttendanceHalfStatus.present ? 1 : 0) +
            (record.afternoonStatus == AttendanceHalfStatus.present ? 1 : 0),
      ) /
      2;
  final old =
      await (database.select(database.monthlyAttendanceSummaries)..where(
            (table) =>
                table.yearMonth.equals('2026-09') &
                table.employeeId.equals(employeeId) &
                table.attendanceGroupId.equals(groupId),
          ))
          .getSingleOrNull();
  if (old == null) {
    return database
        .into(database.monthlyAttendanceSummaries)
        .insert(
          MonthlyAttendanceSummariesCompanion.insert(
            yearMonth: '2026-09',
            employeeId: employeeId,
            attendanceGroupId: Value(groupId),
            attendanceDays: Value(attendanceDays),
            status: const Value(MonthlySummaryStatus.confirmed),
          ),
        );
  }
  await (database.update(
    database.monthlyAttendanceSummaries,
  )..where((table) => table.id.equals(old.id))).write(
    MonthlyAttendanceSummariesCompanion(
      attendanceDays: Value(attendanceDays),
      status: const Value(MonthlySummaryStatus.confirmed),
      updatedAt: Value(DateTime.now()),
    ),
  );
  return old.id;
}

Future<int> _insertConfirmedSummary(
  AppDatabase database, {
  required String yearMonth,
  required int employeeId,
  required double attendanceDays,
}) {
  return database
      .into(database.monthlyAttendanceSummaries)
      .insert(
        MonthlyAttendanceSummariesCompanion.insert(
          yearMonth: yearMonth,
          employeeId: employeeId,
          attendanceDays: Value(attendanceDays),
          status: const Value(MonthlySummaryStatus.confirmed),
        ),
      );
}
