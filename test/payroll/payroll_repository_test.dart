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
import 'package:qingsongban/features/reports/data/monthly_summary_repository.dart';

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
      expect((await payroll.listGroupsForBatch(batch.id)).single.id, group.id);
      expect(
        (await payroll.employeeGroupIdsForBatch(batch.id))[employee.id],
        contains(group.id),
      );
      expect(summary, isA<int>());
    },
  );

  test('confirms payroll after attendance summary status changes without false warning', () async {
    final group = await groups.save(
      draft: const AttendanceGroupDraft(name: '汇总确认测试组'),
    );
    final employee = await personnel.save(
      draft: EmployeeDraft(
        employeeNo: 'EMP-P001-STATUS',
        name: '汇总确认测试员',
        hireDate: DateTime(2026, 9, 1),
        status: EmployeeStatus.active,
        employmentType: '临时工',
      ),
    );
    final jobType = await wages.saveJobType(
      draft: const WageJobTypeDraft(name: '汇总确认工种', defaultDailyWage: 120),
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
        afternoonStatus: AttendanceHalfStatus.present,
      ),
    );
    await _generateSummary(database, employee.id, group.id);

    final batch = await payroll.ensureDraft('2026-09');
    await payroll.generateRoster(batch.id);
    await (database.update(
      database.monthlyAttendanceSummaries,
    )..where((table) => table.employeeId.equals(employee.id))).write(
      const MonthlyAttendanceSummariesCompanion(
        status: Value(MonthlySummaryStatus.pendingReview),
      ),
    );
    await MonthlySummaryRepository(
      database,
    ).setStatus(yearMonth: '2026-09', status: MonthlySummaryStatus.confirmed);

    final validation = await payroll.previewValidation(batch.id);
    expect(
      validation.warnings.any((issue) => issue.code == 'attendance_changed'),
      isFalse,
    );
    await payroll.setStatus(batchId: batch.id, status: PayrollStatus.confirmed);
    expect(
      (await payroll.findBatch(batch.id))?.status,
      PayrollStatus.confirmed,
    );
  });

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
      await payroll.updateItem(
        itemId: riskyItem.id,
        subsidy: 1000,
        insuranceDeduction: 0,
      );
      final warningPreview = await payroll.previewValidation(batch.id);
      expect(
        warningPreview.warnings.any((issue) => issue.code == 'subsidy_high'),
        isTrue,
      );
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

  test('requires a personal wage when job default wage is disabled', () async {
    final employee = await personnel.save(
      draft: EmployeeDraft(
        employeeNo: 'EMP-P005',
        name: '钱七',
        hireDate: DateTime(2026, 9, 1),
        status: EmployeeStatus.active,
        employmentType: '临时工',
      ),
    );

    await expectLater(
      wages.saveProfile(
        EmployeeWageProfileDraft(
          employeeId: employee.id,
          participatesInPayroll: true,
          useJobDefaultWage: false,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('can re-enable a deactivated wage job type', () async {
    final type = await wages.saveJobType(
      draft: const WageJobTypeDraft(name: '临时装卸', defaultDailyWage: 140),
    );

    await wages.deactivateJobType(type.id);
    expect((await wages.watchJobTypes().first).single.isActive, isFalse);

    await wages.activateJobType(type.id);
    expect((await wages.watchJobTypes().first).single.isActive, isTrue);
  });

  test(
    'keeps confirmation time when locking and rejects invalid rollback',
    () async {
      final confirmedAt = DateTime(2026, 9, 20, 10);
      final batchId = await database
          .into(database.payrollBatches)
          .insert(
            PayrollBatchesCompanion.insert(
              payrollMonth: '2026-09',
              name: '2026年09月临时工工资',
              status: const Value(PayrollStatus.confirmed),
              confirmedAt: Value(confirmedAt),
            ),
          );

      await payroll.setStatus(batchId: batchId, status: PayrollStatus.locked);
      final locked = await payroll.findBatch(batchId);
      expect(locked?.confirmedAt, confirmedAt);
      expect(locked?.lockedAt, isA<DateTime>());

      await expectLater(
        payroll.setStatus(batchId: batchId, status: PayrollStatus.draft),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('reports invalid persisted monetary data during validation', () async {
    final employeeId = await database
        .into(database.employees)
        .insert(
          EmployeesCompanion.insert(
            employeeNo: 'EMP-P006',
            name: '孙八',
            hireDate: DateTime(2026, 9, 1),
            employmentType: const Value('临时工'),
          ),
        );
    final batchId = await database
        .into(database.payrollBatches)
        .insert(
          PayrollBatchesCompanion.insert(
            payrollMonth: '2026-09',
            name: '2026年09月临时工工资',
          ),
        );
    await database
        .into(database.payrollItems)
        .insert(
          PayrollItemsCompanion.insert(
            payrollBatchId: batchId,
            employeeId: employeeId,
            displayOrder: 0,
            employeeNameSnapshot: '孙八',
            employeeNoSnapshot: 'EMP-P006',
            attendanceHalfDaysSnapshot: 1,
            dailyWage: const Value(100),
            subsidy: const Value(-1),
          ),
        );

    final result = await payroll.validate(batchId);
    expect(
      result.errors.any((issue) => issue.code == 'invalid_amount'),
      isTrue,
    );
  });

  test('rejects adding a non-temporary worker to a payroll batch', () async {
    final employee = await personnel.save(
      draft: EmployeeDraft(
        employeeNo: 'EMP-P007',
        name: '周九',
        hireDate: DateTime(2026, 9, 1),
        status: EmployeeStatus.active,
        employmentType: '正式工',
      ),
    );
    final batch = await payroll.ensureDraft('2026-09');

    await expectLater(
      payroll.addEmployee(batchId: batch.id, employeeId: employee.id),
      throwsA(isA<StateError>()),
    );
  });
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
