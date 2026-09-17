import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/app/app.dart';
import 'package:qingsongban/app/router/app_router.dart';
import 'package:qingsongban/features/attendance/application/attendance_group_providers.dart';
import 'package:qingsongban/features/attendance/application/daily_attendance_providers.dart';
import 'package:qingsongban/features/attendance/application/monthly_roster_providers.dart';
import 'package:qingsongban/features/attendance/application/monthly_attendance_table_providers.dart';
import 'package:qingsongban/features/attendance/data/attendance_group_repository.dart';
import 'package:qingsongban/features/attendance/domain/attendance_group_options.dart';
import 'package:qingsongban/features/attendance/domain/daily_attendance_options.dart';
import 'package:qingsongban/features/attendance/domain/monthly_roster_options.dart';
import 'package:qingsongban/features/attendance/domain/monthly_attendance_table_options.dart';
import 'package:qingsongban/features/leave/application/leave_providers.dart';
import 'package:qingsongban/features/leave/domain/leave_options.dart';
import 'package:qingsongban/features/overtime/application/overtime_providers.dart';
import 'package:qingsongban/features/overtime/domain/overtime_options.dart';
import 'package:qingsongban/features/personnel/application/personnel_providers.dart';
import 'package:qingsongban/features/reports/application/monthly_summary_providers.dart';
import 'package:qingsongban/features/reports/domain/monthly_summary_options.dart';
import 'package:qingsongban/features/insurance/application/insurance_providers.dart';
import 'package:qingsongban/features/insurance/domain/insurance_options.dart';
import 'package:qingsongban/features/reminders/application/reminder_providers.dart';
import 'package:qingsongban/features/operation_logs/application/operation_log_providers.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    List<AttendanceGroup>? attendanceGroupOverride,
    MonthlyAttendanceTableView? monthlyTableOverride,
    List<LeaveRecordView>? leaveOverride,
    List<Employee>? personnelOverride,
    List<Employee>? personnelListOverride,
    List<OvertimeRecordView>? overtimeOverride,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          allPersonnelProvider.overrideWith(
            (ref) => Stream.value(personnelOverride ?? <Employee>[]),
          ),
          if (personnelListOverride != null)
            personnelListProvider.overrideWith(
              (ref) => Stream.value(personnelListOverride),
            ),
          attendanceGroupsProvider.overrideWith(
            (ref) =>
                Stream.value(attendanceGroupOverride ?? <AttendanceGroup>[]),
          ),
          attendanceGroupSummariesProvider.overrideWith(
            (ref) => Stream.value(<AttendanceGroupSummary>[]),
          ),
          attendanceGroupMembersProvider.overrideWith(
            (ref, groupId) => Stream.value(<AttendanceGroupMemberView>[]),
          ),
          attendanceGroupAssignableEmployeesProvider.overrideWith(
            (ref) => Stream.value(<Employee>[]),
          ),
          monthlyRosterGroupsProvider.overrideWith(
            (ref) =>
                Stream.value(attendanceGroupOverride ?? <AttendanceGroup>[]),
          ),
          monthlyRosterEntriesProvider.overrideWith(
            (ref) => Stream.value(<MonthlyRosterEntryView>[]),
          ),
          monthlyRosterCountsProvider.overrideWith(
            (ref) => Stream.value(const MonthlyRosterCounts()),
          ),
          monthlyRosterCandidatesProvider.overrideWith(
            (ref) => Stream.value(<Employee>[]),
          ),
          dailyAttendanceGroupsProvider.overrideWith(
            (ref) =>
                Stream.value(attendanceGroupOverride ?? <AttendanceGroup>[]),
          ),
          dailyAttendanceEntriesProvider.overrideWith(
            (ref) => Stream.value(<DailyAttendanceEntryView>[]),
          ),
          monthlyAttendanceTableGroupsProvider.overrideWith(
            (ref) =>
                Stream.value(attendanceGroupOverride ?? <AttendanceGroup>[]),
          ),
          monthlyAttendanceTableProvider.overrideWith(
            (ref) => Stream.value(
              monthlyTableOverride ??
                  const MonthlyAttendanceTableView.empty(yearMonth: '2026-09'),
            ),
          ),
          leaveRecordsProvider.overrideWith(
            (ref) => Stream.value(leaveOverride ?? <LeaveRecordView>[]),
          ),
          overtimeRecordsProvider.overrideWith(
            (ref) => Stream.value(overtimeOverride ?? <OvertimeRecordView>[]),
          ),
          monthlySummaryProvider.overrideWith(
            (ref) => Stream.value(
              const MonthlySummaryView.empty(yearMonth: '2026-09'),
            ),
          ),
          insuranceProfilesProvider.overrideWith(
            (ref) => Stream.value(<InsuranceProfileView>[]),
          ),
          insuranceChangesProvider.overrideWith(
            (ref) => Stream.value(<InsuranceChangeView>[]),
          ),
          insuranceBaseHistoryProvider.overrideWith(
            (ref) => Stream.value(<InsuranceHistoryView>[]),
          ),
          remindersProvider.overrideWith((ref) => Stream.value(<Reminder>[])),
          operationLogsProvider.overrideWith(
            (ref) => Stream.value(<OperationLog>[]),
          ),
        ],
        child: const QingSongBanApp(),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets('starts on the home tab with five destinations', (tester) async {
    await pumpApp(tester);

    expect(find.text('轻松办'), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('人员'), findsOneWidget);
    expect(find.text('考勤'), findsOneWidget);
    expect(find.text('汇总'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('今日概览'), findsOneWidget);
    expect(find.text('设计基线'), findsNothing);
  });

  testWidgets('shows the home shortcuts', (tester) async {
    await pumpApp(tester);

    for (final label in [
      '新增人员',
      '今日考勤',
      '请假登记',
      '加班登记',
      '离职登记',
      '保险变更',
      '工资造资',
      '新建提醒',
    ]) {
      expect(find.byKey(Key('home-action-$label')), findsOneWidget);
    }
  });

  testWidgets('navigates from every home dashboard metric', (tester) async {
    await pumpApp(tester);

    const markers = {
      '当前在岗': '人员名单',
      '本月新增': '人员名单',
      '本月离职': '离职管理',
      '今日已登记': '每日考勤',
      '异常记录': '本月尚未生成汇总',
      '待处理提醒': '备忘提醒',
    };

    for (final entry in markers.entries) {
      appRouter.go('/home');
      await tester.pumpAndSettle();
      final metric = find.byKey(Key('home-metric-${entry.key}'));
      expect(metric, findsOneWidget);
      await tester.tap(metric);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
    }

    appRouter.go('/home');
    await tester.pumpAndSettle();
  });

  testWidgets('switches between all five tabs', (tester) async {
    await pumpApp(tester);

    const markers = {
      '人员': '档案概览',
      '考勤': '考勤组管理',
      '汇总': '本月尚未生成汇总',
      '我的': '社保保险',
      '首页': '今日概览',
    };

    for (final entry in markers.entries) {
      final destination = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(entry.key),
      );
      await tester.tap(destination);
      await tester.pumpAndSettle();
      expect(destination, findsOneWidget);
      expect(find.text(entry.value), findsOneWidget);
    }
  });

  testWidgets('navigates personnel overview cards to filtered lists', (
    tester,
  ) async {
    await pumpApp(tester, personnelListOverride: const []);
    await tester.tap(find.text('人员'));
    await tester.pumpAndSettle();

    const statusCards = {'在岗': '在岗', '暂停工作': '暂停工作', '已离职': '已离职'};
    for (final entry in statusCards.entries) {
      appRouter.go('/personnel');
      await tester.pumpAndSettle();
      final card = find.byKey(Key('personnel-stat-${entry.key}'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('人员名单'), findsOneWidget);
      expect(find.text(entry.value), findsOneWidget);
    }

    appRouter.go('/personnel');
    await tester.pumpAndSettle();
    final newCard = find.byKey(const Key('personnel-stat-本月新增'));
    await tester.ensureVisible(newCard);
    await tester.tap(newCard);
    await tester.pumpAndSettle();
    expect(find.text('人员名单'), findsOneWidget);
    expect(find.textContaining('入职月份：'), findsOneWidget);

    appRouter.go('/personnel');
    await tester.pumpAndSettle();
  });

  testWidgets('uses the stage zero visual baseline', (tester) async {
    await pumpApp(tester);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.colorScheme.primary, const Color(0xFF00C16B));
    expect(materialApp.theme?.scaffoldBackgroundColor, const Color(0xFFF6F9FC));
    expect(materialApp.locale, const Locale('zh', 'CN'));
    expect(materialApp.supportedLocales, const [Locale('zh', 'CN')]);
  });

  testWidgets('creates and edits a personnel record', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('人员'));
    await tester.pumpAndSettle();
    final createAction = find.text('新增人员');
    await tester.ensureVisible(createAction);
    await tester.tap(createAction);
    await tester.pumpAndSettle();

    final nameField = find.byKey(const Key('personnel-name-field'));
    await tester.tap(nameField);
    await tester.enterText(nameField, '张三');
    final firstSave = find.text('保存档案');
    await tester.ensureVisible(firstSave);
    await tester.tap(firstSave);
    await tester.pumpAndSettle();

    expect(find.text('张三'), findsOneWidget);
    expect(find.text('EMP-0001'), findsOneWidget);

    await tester.tap(find.byTooltip('编辑档案'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('personnel-name-field')), '李四');
    final secondSave = find.text('保存档案');
    await tester.ensureVisible(secondSave);
    await tester.tap(secondSave);
    await tester.pumpAndSettle();

    expect(find.text('李四'), findsOneWidget);
    expect(find.text('张三'), findsNothing);
  });

  testWidgets('creates an attendance group and opens its detail page', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('考勤'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('考勤组管理'));
    await tester.pumpAndSettle();
    expect(find.text('还没有考勤组'), findsOneWidget);

    await tester.tap(find.text('新增考勤组'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('attendance-group-name-field')),
      '司机组',
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    final saveGroup = find.text('保存考勤组');
    await tester.tap(saveGroup);
    await tester.pumpAndSettle();

    expect(find.text('司机组'), findsOneWidget);
    expect(find.text('还没有组成员'), findsOneWidget);
  });

  testWidgets('opens the monthly roster from the attendance tab', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('考勤'));
    await tester.pumpAndSettle();
    final monthlyEntry = find.text('月度考勤名单');
    await tester.ensureVisible(monthlyEntry);
    await tester.tap(monthlyEntry);
    await tester.pumpAndSettle();

    expect(find.text('月度考勤名单'), findsOneWidget);
    expect(find.text('暂无考勤组'), findsOneWidget);
    expect(find.text('去管理考勤组'), findsOneWidget);
  });

  testWidgets('opens monthly summary and exposes direct Excel export', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('考勤'));
    await tester.pumpAndSettle();
    final reportsEntry = find.byKey(const Key('attendance-reports-entry'));
    await tester.ensureVisible(reportsEntry);
    await tester.tap(reportsEntry);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('summary-export-button')), findsOneWidget);
    expect(find.byKey(const Key('summary-back-to-attendance')), findsOneWidget);

    await tester.tap(find.byKey(const Key('summary-back-to-attendance')));
    await tester.pumpAndSettle();
    expect(find.text('考勤组管理'), findsOneWidget);
  });

  testWidgets('opens the employee attachment center from personnel detail', (
    tester,
  ) async {
    await database.insertEmployee(
      EmployeesCompanion.insert(
        employeeNo: 'EMP-ATT01',
        name: '附件人员',
        hireDate: DateTime(2026, 1, 1),
      ),
    );
    final employee = await database.findEmployeeById(1);
    await pumpApp(tester, personnelOverride: [employee!]);

    appRouter.go('/personnel/1');
    await tester.pumpAndSettle();
    final attachmentsEntry = find.byKey(
      const Key('personnel-attachments-entry'),
    );
    await tester.ensureVisible(attachmentsEntry);
    await tester.tap(attachmentsEntry);
    await tester.pumpAndSettle();

    expect(find.text('附件资料'), findsOneWidget);
    expect(find.text('暂无附件资料'), findsOneWidget);
  });

  testWidgets('opens daily attendance with selectors and empty state', (
    tester,
  ) async {
    final group = await AttendanceGroupRepository(database)
        .save(draft: const AttendanceGroupDraft(name: '每日登记组'));
    await pumpApp(tester, attendanceGroupOverride: [group]);

    await tester.tap(find.text('考勤'));
    await tester.pumpAndSettle();
    final dailyEntry = find.text('每日考勤');
    await tester.ensureVisible(dailyEntry);
    await tester.tap(dailyEntry);
    await tester.pumpAndSettle();

    expect(find.text('每日登记'), findsOneWidget);
    expect(
      find.byKey(const Key('daily-attendance-date-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('daily-attendance-group-field')),
      findsOneWidget,
    );
    expect(find.text('快捷操作'), findsOneWidget);

    await tester.tap(find.byKey(const Key('daily-attendance-date-button')));
    await tester.pumpAndSettle();
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    final emptyDailyRoster = find.text('本月暂无考勤人员');
    await tester.scrollUntilVisible(
      emptyDailyRoster,
      450,
      scrollable: find.byType(Scrollable).last,
    );
    expect(emptyDailyRoster, findsOneWidget);
    expect(find.text('考勤'), findsWidgets);
  });

  testWidgets('opens the monthly attendance table with an empty roster', (
    tester,
  ) async {
    final group = await AttendanceGroupRepository(database)
        .save(draft: const AttendanceGroupDraft(name: '月表入口组'));
    await pumpApp(tester, attendanceGroupOverride: [group]);

    await tester.tap(find.text('考勤'));
    await tester.pumpAndSettle();
    final monthlyTableEntry = find.text('月考勤表');
    await tester.ensureVisible(monthlyTableEntry);
    await tester.tap(monthlyTableEntry);
    await tester.pumpAndSettle();

    expect(find.text('月考勤表'), findsOneWidget);
    expect(
      find.byKey(const Key('monthly-attendance-table-month-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('monthly-attendance-table-group-field')),
      findsOneWidget,
    );
    expect(find.text('本月暂无考勤名单'), findsOneWidget);
  });

  testWidgets('opens the leave page with an empty state', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('考勤'));
    await tester.pumpAndSettle();
    final leaveEntry = find.text('请假记录');
    await tester.ensureVisible(leaveEntry);
    await tester.tap(leaveEntry);
    await tester.pumpAndSettle();

    expect(find.text('请假记录'), findsOneWidget);
    expect(find.byKey(const Key('leave-month-label')), findsOneWidget);
    expect(find.textContaining('暂无请假记录'), findsOneWidget);
    expect(find.text('新增请假'), findsOneWidget);
  });

  testWidgets('creates a leave record from the leave form', (tester) async {
    final employeeId = await database.insertEmployee(
      EmployeesCompanion.insert(
        employeeNo: 'EMP-LW01',
        name: '张三',
        hireDate: DateTime(2026, 1, 1),
      ),
    );
    final employee = (await database.findEmployeeById(employeeId))!;
    await pumpApp(tester, personnelOverride: [employee]);

    await tester.tap(find.text('考勤'));
    await tester.pumpAndSettle();
    final leaveEntry = find.text('请假记录');
    await tester.ensureVisible(leaveEntry);
    await tester.tap(leaveEntry);
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增请假'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('leave-employee-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('张三 · EMP-LW01').last);
    await tester.pumpAndSettle();
    final saveLeave = find.byKey(const Key('leave-save-button'));
    await tester.ensureVisible(saveLeave);
    await tester.tap(saveLeave);
    await tester.pumpAndSettle();

    expect(find.text('请假记录'), findsOneWidget);
    expect(await database.select(database.leaveRecords).get(), hasLength(1));
    final record = await database.findAttendanceRecord(
      employee.id,
      DateTime.now(),
    );
    expect(record?.morningStatus, AttendanceHalfStatus.leave);
    expect(record?.afternoonStatus, AttendanceHalfStatus.leave);
  });

  testWidgets('opens the overtime page with an empty state', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('考勤'));
    await tester.pumpAndSettle();
    final overtimeEntry = find.text('加班记录');
    await tester.ensureVisible(overtimeEntry);
    await tester.tap(overtimeEntry);
    await tester.pumpAndSettle();

    expect(find.text('加班记录'), findsOneWidget);
    expect(find.byKey(const Key('overtime-month-label')), findsOneWidget);
    expect(find.textContaining('暂无加班记录'), findsOneWidget);
    expect(find.text('新增加班'), findsOneWidget);
  });

  testWidgets('opens the insurance page from settings', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    final insuranceEntry = find.text('社保保险');
    await tester.ensureVisible(insuranceEntry);
    await tester.tap(insuranceEntry);
    await tester.pumpAndSettle();

    expect(find.text('社保保险'), findsOneWidget);
    expect(find.text('还没有参保档案'), findsOneWidget);
    expect(find.text('本月暂无保险变更'), findsOneWidget);
  });

  testWidgets('opens Excel import and export from settings', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    final excelEntry = find.text('Excel 导入导出');
    await tester.ensureVisible(excelEntry);
    await tester.tap(excelEntry);
    await tester.pumpAndSettle();

    expect(find.text('Excel 导入导出'), findsOneWidget);
    expect(find.byKey(const Key('excel-export-button')), findsOneWidget);
    expect(find.byKey(const Key('excel-import-button')), findsOneWidget);
  });

  testWidgets('opens local reminders from settings', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    final reminderEntry = find.text('备忘提醒');
    await tester.ensureVisible(reminderEntry);
    await tester.tap(reminderEntry);
    await tester.pumpAndSettle();

    expect(find.text('备忘提醒'), findsOneWidget);
    final reminderTestButton = find.byKey(
      const Key('reminder-test-button'),
      skipOffstage: false,
    );
    await tester.ensureVisible(reminderTestButton);
    expect(reminderTestButton, findsOneWidget);
    expect(find.byKey(const Key('reminder-add-button')), findsOneWidget);
    expect(find.byKey(const Key('reminder-filter-pending')), findsOneWidget);
    expect(find.text('把事情记下来，到点提醒'), findsOneWidget);
    expect(find.text('业务提醒偏好'), findsOneWidget);
  });

  testWidgets('opens backup and restore from settings', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    final backupEntry = find.text('备份与恢复');
    await tester.ensureVisible(backupEntry);
    await tester.tap(backupEntry);
    await tester.pumpAndSettle();

    expect(find.text('备份与恢复'), findsOneWidget);
    expect(find.byKey(const Key('backup-create-button')), findsOneWidget);
    expect(find.byKey(const Key('backup-restore-button')), findsOneWidget);
  });

  testWidgets('opens operation logs from settings', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    final logEntry = find.text('操作日志');
    await tester.ensureVisible(logEntry);
    await tester.tap(logEntry);
    await tester.pumpAndSettle();

    expect(find.text('操作日志'), findsOneWidget);
    expect(find.text('暂无操作日志'), findsOneWidget);
  });

  testWidgets('renders month cells and opens the cell editor', (tester) async {
    final group = await AttendanceGroupRepository(database)
        .save(draft: const AttendanceGroupDraft(name: '月表编辑组'));
    final employee = Employee(
      id: 1,
      employeeNo: 'EMP-W001',
      name: '张三',
      hireDate: DateTime(2026, 1, 1),
      status: EmployeeStatus.active,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      isDeleted: false,
    );
    final record = AttendanceRecord(
      id: 1,
      employeeId: 1,
      attendanceDate: DateTime(2026, 9, 1),
      morningStatus: AttendanceHalfStatus.present,
      afternoonStatus: AttendanceHalfStatus.leave,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      isDeleted: false,
    );
    final table = MonthlyAttendanceTableView(
      yearMonth: '2026-09',
      daysInMonth: 30,
      rows: [
        MonthlyAttendanceTableRow(employee: employee, records: {1: record}),
      ],
    );
    await pumpApp(
      tester,
      attendanceGroupOverride: [group],
      monthlyTableOverride: table,
    );

    await tester.tap(find.text('考勤'));
    await tester.pumpAndSettle();
    final monthlyTableEntry = find.text('月考勤表');
    await tester.ensureVisible(monthlyTableEntry);
    await tester.tap(monthlyTableEntry);
    await tester.pumpAndSettle();

    expect(find.text('张三'), findsOneWidget);
    expect(find.text('1日'), findsOneWidget);
    expect(find.text('半'), findsOneWidget);
    final cell = find.byKey(const Key('monthly-attendance-cell-1-1'));
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(find.text('张三 · 9月1日'), findsOneWidget);
    expect(
      find.byKey(const Key('monthly-attendance-morning-field')),
      findsOneWidget,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('shows monthly roster selectors and an empty state for a group', (
    tester,
  ) async {
    final group = await AttendanceGroupRepository(database)
        .save(draft: const AttendanceGroupDraft(name: '月度名单组'));
    await pumpApp(tester, attendanceGroupOverride: [group]);

    await tester.tap(find.text('考勤'));
    await tester.pumpAndSettle();
    final monthlyEntry = find.text('月度考勤名单');
    await tester.ensureVisible(monthlyEntry);
    await tester.tap(monthlyEntry);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('monthly-roster-month-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('monthly-roster-group-field')), findsOneWidget);
    await tester.tap(find.byKey(const Key('monthly-roster-group-field')));
    await tester.pumpAndSettle();
    expect(find.text(group.name), findsWidgets);
    await tester.tap(find.text(group.name).last);
    await tester.pumpAndSettle();
    final emptyRoster = find.text('本月暂无有效人员');
    await tester.scrollUntilVisible(
      emptyRoster,
      450,
      scrollable: find.byType(Scrollable).last,
    );
    expect(emptyRoster, findsOneWidget);
  });

  testWidgets('assigns a default attendance group from the personnel form', (
    tester,
  ) async {
    final group = await AttendanceGroupRepository(database)
        .save(draft: const AttendanceGroupDraft(name: '管业临时工组'));
    await pumpApp(tester, attendanceGroupOverride: [group]);

    await tester.tap(find.text('人员'));
    await tester.pumpAndSettle();
    final createPersonnel = find.text('新增人员');
    await tester.ensureVisible(createPersonnel);
    await tester.tap(createPersonnel);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('personnel-name-field')), '周九');

    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    final groupField = find.text('暂不指定');
    await tester.ensureVisible(groupField);
    await tester.tap(groupField);
    await tester.pumpAndSettle();
    await tester.tap(find.text(group.name).last);
    await tester.pumpAndSettle();

    final savePersonnel = find.text('保存档案');
    await tester.ensureVisible(savePersonnel);
    await tester.tap(savePersonnel);
    await tester.pumpAndSettle();
    final employee = await database.findEmployeeById(1);
    expect(employee?.defaultAttendanceGroupId, group.id);
  });
}
