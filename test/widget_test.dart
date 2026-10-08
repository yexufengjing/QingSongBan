import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/app/app.dart';
import 'package:qingsongban/core/widgets/design_canvas.dart';
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
import 'package:qingsongban/features/personnel/presentation/personnel_list_page.dart';
import 'package:qingsongban/features/reports/application/monthly_summary_providers.dart';
import 'package:qingsongban/features/reports/domain/monthly_summary_options.dart';
import 'package:qingsongban/features/insurance/application/insurance_providers.dart';
import 'package:qingsongban/features/insurance/domain/insurance_options.dart';
import 'package:qingsongban/features/reminders/application/reminder_providers.dart';
import 'package:qingsongban/features/reminders/domain/reminder_options.dart';
import 'package:qingsongban/features/operation_logs/application/operation_log_providers.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_repository.dart';
import 'package:qingsongban/features/vehicles/domain/vehicle_options.dart';
import 'package:qingsongban/features/vehicles/application/vehicle_providers.dart';
import 'package:qingsongban/features/home/application/home_providers.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
  });

  void widgetTest(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.idle();
        await tester.pump(const Duration(milliseconds: 1));
        await database.close();
        await tester.idle();
        await tester.pump(const Duration(milliseconds: 1));
      }
    });
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    List<AttendanceGroup>? attendanceGroupOverride,
    bool useDatabasePersonnelGroups = false,
    MonthlyAttendanceTableView? monthlyTableOverride,
    List<LeaveRecordView>? leaveOverride,
    List<Employee>? personnelOverride,
    List<OvertimeRecordView>? overtimeOverride,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          allPersonnelProvider.overrideWith(
            (ref) => Stream.value(personnelOverride ?? <Employee>[]),
          ),
          if (!useDatabasePersonnelGroups)
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
          overtimeRecordsForMonthProvider.overrideWith(
            (ref, month) =>
                Stream.value(overtimeOverride ?? <OvertimeRecordView>[]),
          ),
          homeDashboardProvider.overrideWith(
            (ref) async => const HomeDashboardStats(
              activeEmployees: 0,
              newEmployees: 0,
              terminatedEmployees: 0,
              todayAttendance: 0,
              anomalies: 0,
              pendingReminders: 0,
            ),
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
          reminderItemsProvider.overrideWith(
            (ref) => Stream.value(<ReminderItem>[]),
          ),
          operationLogsProvider.overrideWith(
            (ref) => Stream.value(<OperationLog>[]),
          ),
          allVehiclesProvider.overrideWith((ref) => Stream.value(<Vehicle>[])),
          vehicleListProvider.overrideWith((ref) => Stream.value(<Vehicle>[])),
          vehicleConditionItemsProvider.overrideWith(
            (ref, vehicleId) => Stream.value(<VehicleConditionItem>[]),
          ),
          vehicleTireInstallationsProvider.overrideWith(
            (ref, vehicleId) => Stream.value(<TireInstallation>[]),
          ),
          vehicleRepairOrdersProvider.overrideWith(
            (ref, vehicleId) => Stream.value(<RepairOrder>[]),
          ),
          vehicleMaintenanceItemsProvider.overrideWith(
            (ref, vehicleId) => Stream.value(<VehicleMaintenanceItem>[]),
          ),
          vehicleLifecycleRecordsProvider.overrideWith(
            (ref, vehicleId) => Stream.value(<ComponentLifecycleRecord>[]),
          ),
          vehicleAttachmentsProvider.overrideWith(
            (ref, key) => Stream.value(<VehicleAttachment>[]),
          ),
        ],
        child: const QingSongBanApp(),
      ),
    );
    appRouter.go('/home');
    await tester.pumpAndSettle();
  }

  widgetTest('starts on the overview with four primary destinations', (
    tester,
  ) async {
    await pumpApp(tester);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp(r'^轻松办$')), findsOneWidget);
      expect(find.text('首页'), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      expect(find.text('人员'), findsNothing);
      expect(find.text('关键指标'), findsOneWidget);
      expect(find.text('考勤'), findsOneWidget);
      expect(find.text('汇总'), findsOneWidget);
      expect(find.text('我的'), findsOneWidget);
      expect(find.text('今日概览'), findsNothing);
      expect(find.text('查看汇总'), findsOneWidget);
      expect(find.text('设计基线'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  widgetTest(
    'counts only real attendance, leave, and upcoming reminder records on home',
    (_) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final attendingId = await database.insertEmployee(
        EmployeesCompanion.insert(
          employeeNo: 'EMP-DASH-1',
          name: '出勤人员',
          hireDate: today,
        ),
      );
      final restingId = await database.insertEmployee(
        EmployeesCompanion.insert(
          employeeNo: 'EMP-DASH-2',
          name: '公休人员',
          hireDate: today,
        ),
      );
      await database
          .into(database.attendanceRecords)
          .insert(
            AttendanceRecordsCompanion.insert(
              employeeId: attendingId,
              attendanceDate: today,
              morningStatus: const Value(AttendanceHalfStatus.present),
              afternoonStatus: const Value(AttendanceHalfStatus.unregistered),
            ),
          );
      await database
          .into(database.attendanceRecords)
          .insert(
            AttendanceRecordsCompanion.insert(
              employeeId: restingId,
              attendanceDate: today,
              morningStatus: const Value(AttendanceHalfStatus.rest),
              afternoonStatus: const Value(AttendanceHalfStatus.rest),
            ),
          );
      await database
          .into(database.leaveRecords)
          .insert(
            LeaveRecordsCompanion.insert(
              employeeId: restingId,
              startDate: today.subtract(const Duration(days: 1)),
              endDate: today,
            ),
          );

      Future<int> addReminder({
        required String title,
        required DateTime due,
        String reminderType = 'custom',
        bool enabled = true,
        bool completed = false,
      }) => database
          .into(database.reminders)
          .insert(
            RemindersCompanion.insert(
              title: title,
              reminderType: reminderType,
              dueDate: Value(due),
              isEnabled: Value(enabled),
              isCompleted: Value(completed),
            ),
          );

      Future<void> addOccurrence(int reminderId, DateTime scheduledAt) async {
        await database
            .into(database.reminderOccurrences)
            .insert(
              ReminderOccurrencesCompanion.insert(
                reminderId: reminderId,
                scheduledAt: scheduledAt,
              ),
            );
      }

      final withinRange = await addReminder(
        title: '三十天内',
        due: today.add(const Duration(days: 5)),
      );
      final beyondRange = await addReminder(
        title: '三十一天后',
        due: today.add(const Duration(days: 31)),
      );
      final disabled = await addReminder(
        title: '已停用',
        due: today.add(const Duration(days: 5)),
        enabled: false,
      );
      final completed = await addReminder(
        title: '已完成',
        due: today.add(const Duration(days: 5)),
        completed: true,
      );
      final legacyInsurance = await addReminder(
        title: '历史离职停保提醒',
        due: today.subtract(const Duration(days: 5)),
        reminderType: 'terminationInsurance',
      );
      await addOccurrence(withinRange, today.add(const Duration(days: 30)));
      await addOccurrence(beyondRange, today.add(const Duration(days: 31)));
      await addOccurrence(disabled, today.add(const Duration(days: 5)));
      await addOccurrence(completed, today.add(const Duration(days: 5)));
      await addOccurrence(
        legacyInsurance,
        today.subtract(const Duration(days: 1)),
      );

      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      try {
        final result = await container.read(homeDashboardProvider.future);
        expect(result.todayAttendance, 1);
        expect(result.todayLeave, 1);
        expect(result.upcomingReminders, 1);
        expect(result.pendingReminders, 1);
      } finally {
        container.dispose();
      }
    },
  );

  widgetTest('shows the home shortcuts', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('处理'));
    await tester.pumpAndSettle();

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

  widgetTest('shows the pending reminder card in the first 411dp viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 840);
    try {
      await pumpApp(tester);
      await tester.tap(find.text('处理'));
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byType(SingleChildScrollView).first);
      final reminderHeading = tester.getRect(find.text('待办提醒'));
      expect(viewport.contains(reminderHeading.topLeft), isTrue);
    } finally {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  widgetTest('opens vehicle management from the home shortcuts', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('处理'));
    await tester.pumpAndSettle();

    final vehicleAction = find.byKey(const Key('home-action-车辆管理'));
    await tester.ensureVisible(vehicleAction);
    await tester.tap(vehicleAction);
    await tester.pumpAndSettle();

    expect(find.text('车辆管理'), findsOneWidget);
    expect(find.text('业务入口'), findsOneWidget);
    await tester.tap(find.byTooltip('新增车辆').first);
    await tester.pumpAndSettle();
    expect(find.text('车辆名称 *'), findsOneWidget);
    appRouter.go('/home');
    await tester.pumpAndSettle();
  });

  widgetTest('opens vehicle condition and repair tabs', (tester) async {
    final vehicle = await VehicleRepository(database).save(
      draft: const VehicleDraft(
        name: '测试洒水车',
        vehicleNo: 'WT-TEST',
        vehicleType: VehicleType.waterTruck,
      ),
    );
    await pumpApp(tester);
    appRouter.go('/vehicles/${vehicle.id}');
    await tester.pumpAndSettle();

    expect(find.text('车辆详情'), findsOneWidget);
    await tester.tap(find.text('车况'));
    await tester.pumpAndSettle();
    expect(find.text('部件车况'), findsOneWidget);
    await tester.tap(find.text('维修'));
    await tester.pumpAndSettle();
    expect(find.text('暂无维修记录'), findsOneWidget);
    await tester.tap(find.text('新建报修').first);
    await tester.pumpAndSettle();
    expect(find.text('新建报修/维修单'), findsOneWidget);
    appRouter.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  widgetTest('opens vehicle fuel summary and attachment pages', (tester) async {
    final vehicle = await VehicleRepository(database).save(
      draft: const VehicleDraft(
        name: '汇总测试车',
        vehicleNo: 'SW-SUMMARY',
        vehicleType: VehicleType.sweeper,
      ),
    );
    await pumpApp(tester);
    appRouter.go('/vehicles/fuel-summary');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('年度油耗汇总'), findsOneWidget);
    expect(find.text('汇总测试车'), findsOneWidget);
    expect(find.text('数据完整度'), findsOneWidget);

    appRouter.go('/vehicles/${vehicle.id}/attachments');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('附件资料'), findsOneWidget);
    expect(find.text('暂无附件资料'), findsOneWidget);
  });

  widgetTest('navigates from every home dashboard metric', (tester) async {
    await pumpApp(tester);

    const markers = {
      '当前在岗': '人员名单',
      '本月新增': '人员名单',
      '本月离职': '离职管理',
      '今日出勤': '每日考勤',
      '今日请假': '请假记录',
      '即将到期': '备忘提醒',
    };

    for (final entry in markers.entries) {
      appRouter.go('/home');
      await tester.pumpAndSettle();
      final mode = const {'本月离职', '即将到期'}.contains(entry.key) ? '处理' : '概览';
      await tester.ensureVisible(find.text(mode));
      await tester.tap(find.text(mode));
      await tester.pumpAndSettle();
      final metric = find.byKey(Key('home-metric-${entry.key}'));
      expect(metric, findsOneWidget);
      await tester.ensureVisible(metric);
      await tester.tap(metric);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      if (entry.key == '当前在岗') {
        final listPage = find.byType(PersonnelListPage);
        final container = ProviderScope.containerOf(tester.element(listPage));
        expect(
          tester.widget<PersonnelListPage>(listPage).initialStatus,
          EmployeeStatus.active,
        );
        expect(
          container.read(personnelStatusFilterProvider),
          EmployeeStatus.active,
        );
      } else if (entry.key == '本月新增') {
        final listPage = find.byType(PersonnelListPage);
        final container = ProviderScope.containerOf(tester.element(listPage));
        final now = DateTime.now();
        final expectedMonth =
            '${now.year}-${now.month.toString().padLeft(2, '0')}';
        expect(
          tester.widget<PersonnelListPage>(listPage).initialHireMonth,
          expectedMonth,
        );
        expect(container.read(personnelHireMonthFilterProvider), expectedMonth);
      }
    }

    appRouter.go('/home');
    await tester.pumpAndSettle();
  });

  widgetTest('switches between all four primary tabs', (tester) async {
    await pumpApp(tester);

    const markers = {'考勤': '名单设置', '汇总': '汇总中心', '我的': '社保保险', '首页': '关键指标'};

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

  widgetTest('navigates personnel overview cards to filtered lists', (
    tester,
  ) async {
    await pumpApp(tester);
    appRouter.go('/personnel');
    await tester.pumpAndSettle();

    const statusCards = {
      '在岗': EmployeeStatus.active,
      '暂停工作': EmployeeStatus.paused,
      '已离职': EmployeeStatus.terminated,
    };
    for (final entry in statusCards.entries) {
      appRouter.go('/personnel');
      await tester.pumpAndSettle();
      final card = find.byKey(Key('personnel-stat-${entry.key}'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('人员名单'), findsOneWidget);
      final statusLabel = find.text(entry.key);
      final statusChip = find.ancestor(
        of: statusLabel,
        matching: find.byType(ChoiceChip),
      );
      expect(statusChip, findsOneWidget);
      expect(tester.widget<ChoiceChip>(statusChip).selected, isTrue);
      final listPage = find.byType(PersonnelListPage);
      final container = ProviderScope.containerOf(tester.element(listPage));
      expect(
        tester.widget<PersonnelListPage>(listPage).initialStatus,
        entry.value,
      );
      expect(container.read(personnelStatusFilterProvider), entry.value);
    }

    appRouter.go('/personnel');
    await tester.pumpAndSettle();
    final newCard = find.byKey(const Key('personnel-stat-本月新增'));
    await tester.ensureVisible(newCard);
    await tester.tap(newCard);
    await tester.pumpAndSettle();
    expect(find.text('人员名单'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PersonnelListPage)),
    );
    final listPage = tester.widget<PersonnelListPage>(
      find.byType(PersonnelListPage),
    );
    final now = DateTime.now();
    final expectedMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    expect(listPage.initialHireMonth, expectedMonth);
    expect(container.read(personnelHireMonthFilterProvider), expectedMonth);
    await tester.tap(find.text('筛选'));
    await tester.pumpAndSettle();
    expect(find.textContaining('入职月份：$expectedMonth'), findsOneWidget);

    appRouter.go('/personnel');
    await tester.pumpAndSettle();
  });

  widgetTest(
    'filters personnel by the requested hire month using database rows',
    (tester) async {
      final now = DateTime.now();
      final selectedMonth = DateTime(now.year, now.month);
      final previousMonth = DateTime(now.year, now.month - 1);
      final monthText =
          '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';
      await database.insertEmployee(
        EmployeesCompanion.insert(
          employeeNo: 'EMP-MONTH-1',
          name: '本月入职人员',
          hireDate: DateTime(selectedMonth.year, selectedMonth.month, 2),
        ),
      );
      await database.insertEmployee(
        EmployeesCompanion.insert(
          employeeNo: 'EMP-MONTH-2',
          name: '上月入职人员',
          hireDate: DateTime(previousMonth.year, previousMonth.month, 2),
        ),
      );
      await pumpApp(tester);

      appRouter.go('/personnel/list?hireMonth=$monthText');
      await tester.pumpAndSettle();

      expect(find.text('本月入职人员'), findsOneWidget);
      expect(find.text('上月入职人员'), findsNothing);
      await tester.tap(find.text('筛选'));
      await tester.pumpAndSettle();
      expect(find.textContaining('入职月份：$monthText'), findsOneWidget);
    },
  );

  widgetTest(
    'filters personnel by a real attendance group and keeps the add FAB circular',
    (tester) async {
      final firstGroup = await AttendanceGroupRepository(database)
          .save(draft: const AttendanceGroupDraft(name: '东区班组'));
      final secondGroup = await AttendanceGroupRepository(database)
          .save(draft: const AttendanceGroupDraft(name: '西区班组'));
      await database.insertEmployee(
        EmployeesCompanion.insert(
          employeeNo: 'EMP-GROUP-1',
          name: '东区人员',
          hireDate: DateTime(2026, 9, 1),
          defaultAttendanceGroupId: Value(firstGroup.id),
        ),
      );
      await database.insertEmployee(
        EmployeesCompanion.insert(
          employeeNo: 'EMP-GROUP-2',
          name: '西区人员',
          hireDate: DateTime(2026, 9, 1),
          defaultAttendanceGroupId: Value(secondGroup.id),
        ),
      );
      await pumpApp(
        tester,
        attendanceGroupOverride: [firstGroup, secondGroup],
        useDatabasePersonnelGroups: true,
      );

      appRouter.go('/personnel/list');
      await tester.pumpAndSettle();
      final fab = tester.widget<FloatingActionButton>(
        find.byKey(const Key('personnel-add-fab')),
      );
      expect(fab.shape, isA<CircleBorder>());
      expect(find.text('东区人员'), findsOneWidget);
      expect(find.text('西区人员'), findsOneWidget);

      await tester.tap(find.byType(DropdownButton<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(firstGroup.name).last);
      await tester.pumpAndSettle();

      expect(find.text('东区人员'), findsOneWidget);
      expect(find.text('西区人员'), findsNothing);
    },
  );

  widgetTest('uses the selected reference component baseline', (tester) async {
    await pumpApp(tester);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.colorScheme.primary, const Color(0xFF2563EB));
    expect(materialApp.theme?.scaffoldBackgroundColor, Colors.transparent);
    expect(find.byType(DesignCanvas), findsOneWidget);
    final cardShape =
        materialApp.theme?.cardTheme.shape as RoundedRectangleBorder;
    expect(cardShape.borderRadius, BorderRadius.circular(12));
    final buttonShape =
        materialApp.theme?.filledButtonTheme.style?.shape?.resolve({})
            as RoundedRectangleBorder;
    expect(buttonShape.borderRadius, BorderRadius.circular(8));
    expect(materialApp.locale, const Locale('zh', 'CN'));
    expect(materialApp.supportedLocales, const [Locale('zh', 'CN')]);
  });

  widgetTest('creates and edits a personnel record', (tester) async {
    await pumpApp(tester);

    appRouter.go('/personnel');
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

    expect(find.text('张三'), findsWidgets);
    expect(find.textContaining('EMP-0001'), findsOneWidget);
    expect((await database.findEmployeeById(1))?.employeeNo, 'EMP-0001');

    await tester.tap(find.byKey(const Key('personnel-detail-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('personnel-name-field')), '李四');
    final secondSave = find.text('保存档案');
    await tester.ensureVisible(secondSave);
    await tester.tap(secondSave);
    await tester.pumpAndSettle();

    expect(find.text('李四'), findsWidgets);
    expect(find.text('张三'), findsNothing);
    expect((await database.findEmployeeById(1))?.name, '李四');
  });

  widgetTest('creates an attendance group and opens its detail page', (
    tester,
  ) async {
    await pumpApp(tester);

    appRouter.go('/attendance');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attendance-groups-entry')));
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

  widgetTest('opens the monthly roster from the attendance tab', (
    tester,
  ) async {
    await pumpApp(tester);

    appRouter.go('/attendance');
    await tester.pumpAndSettle();
    final monthlyEntry = find.byKey(
      const Key('attendance-monthly-roster-entry'),
    );
    await tester.ensureVisible(monthlyEntry);
    await tester.tap(monthlyEntry);
    await tester.pumpAndSettle();

    expect(find.text('月度考勤名单'), findsOneWidget);
    expect(find.text('暂无考勤组'), findsOneWidget);
    expect(find.text('去管理考勤组'), findsOneWidget);
  });

  widgetTest('opens monthly summary and exposes direct Excel export', (
    tester,
  ) async {
    await pumpApp(tester);

    appRouter.go('/attendance');
    await tester.pumpAndSettle();
    final reportsEntry = find.byKey(const Key('attendance-reports-entry'));
    await tester.ensureVisible(reportsEntry);
    await tester.tap(reportsEntry);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('summary-export-button')), findsOneWidget);
    expect(find.byKey(const Key('summary-back-to-attendance')), findsOneWidget);

    await tester.tap(find.byKey(const Key('summary-back-to-attendance')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attendance-groups-entry')), findsOneWidget);
  });

  widgetTest('opens the employee attachment center from personnel detail', (
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

    expect(find.text('人员附件'), findsOneWidget);
    expect(find.text('暂无附件资料'), findsOneWidget);
  });

  widgetTest('opens daily attendance with selectors and empty state', (
    tester,
  ) async {
    final group = await AttendanceGroupRepository(database)
        .save(draft: const AttendanceGroupDraft(name: '每日登记组'));
    await pumpApp(tester, attendanceGroupOverride: [group]);

    appRouter.go('/attendance');
    await tester.pumpAndSettle();
    final dailyEntry = find.byKey(const Key('attendance-daily-entry'));
    await tester.ensureVisible(dailyEntry);
    await tester.tap(dailyEntry);
    await tester.pumpAndSettle();

    expect(find.text('每日考勤'), findsOneWidget);
    expect(
      find.byKey(const Key('daily-attendance-date-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('daily-attendance-group-${group.id}')),
      findsOneWidget,
    );
    for (final action in [
      DailyAttendanceAction.allPresent,
      DailyAttendanceAction.copyPrevious,
      DailyAttendanceAction.rest,
      DailyAttendanceAction.stopped,
    ]) {
      expect(
        find.byKey(Key('daily-attendance-action-${action.name}')),
        findsOneWidget,
      );
      expect(
        find.text(DailyAttendanceOptions.actionLabel(action)),
        findsOneWidget,
      );
    }

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
    expect(find.text('每日考勤'), findsOneWidget);
  });

  widgetTest('opens the monthly attendance table with an empty roster', (
    tester,
  ) async {
    final group = await AttendanceGroupRepository(database)
        .save(draft: const AttendanceGroupDraft(name: '月表入口组'));
    await pumpApp(tester, attendanceGroupOverride: [group]);

    appRouter.go('/attendance');
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

  widgetTest('opens the leave page with an empty state', (tester) async {
    await pumpApp(tester);

    appRouter.go('/attendance');
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

  widgetTest('creates a leave record from the leave form', (tester) async {
    final employeeId = await database.insertEmployee(
      EmployeesCompanion.insert(
        employeeNo: 'EMP-LW01',
        name: '张三',
        hireDate: DateTime(2026, 1, 1),
      ),
    );
    final employee = (await database.findEmployeeById(employeeId))!;
    await pumpApp(tester, personnelOverride: [employee]);

    appRouter.go('/attendance');
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

  widgetTest('opens the overtime page with an empty state', (tester) async {
    await pumpApp(tester);

    appRouter.go('/attendance');
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

  widgetTest('opens the insurance page from settings', (tester) async {
    await pumpApp(tester);

    appRouter.go('/settings');
    await tester.pumpAndSettle();
    final insuranceEntry = find.text('社保保险');
    await tester.scrollUntilVisible(
      insuranceEntry,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(insuranceEntry);
    await tester.pumpAndSettle();

    expect(find.text('社保保险'), findsOneWidget);
    expect(find.text('还没有参保档案'), findsOneWidget);
    expect(find.text('本月暂无保险变更'), findsOneWidget);
  });

  widgetTest('opens Excel import and export from settings', (tester) async {
    await pumpApp(tester);

    appRouter.go('/settings');
    await tester.pumpAndSettle();
    final excelEntry = find.text('Excel 导入导出');
    await tester.ensureVisible(excelEntry);
    await tester.tap(excelEntry);
    await tester.pumpAndSettle();

    expect(find.text('Excel 导入导出'), findsOneWidget);
    expect(find.byKey(const Key('excel-export-button')), findsOneWidget);
    expect(find.byKey(const Key('excel-import-button')), findsOneWidget);
  });

  widgetTest('opens local reminders from settings', (tester) async {
    await pumpApp(tester);

    appRouter.go('/settings');
    await tester.pumpAndSettle();
    final reminderEntry = find.text('备忘提醒');
    await tester.ensureVisible(reminderEntry);
    await tester.tap(reminderEntry);
    await tester.pumpAndSettle();

    expect(find.text('备忘提醒'), findsOneWidget);
    expect(find.byKey(const Key('reminder-add-button')), findsOneWidget);
    expect(find.byKey(const Key('reminder-filter-pending')), findsOneWidget);
    expect(find.text('把事情记下来，到点提醒'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('业务提醒偏好'), findsOneWidget);
    final reminderTestButton = find.byKey(
      const Key('reminder-test-button'),
      skipOffstage: false,
    );
    await tester.ensureVisible(reminderTestButton);
    expect(reminderTestButton, findsOneWidget);
  });

  widgetTest('opens backup and restore from settings', (tester) async {
    await pumpApp(tester);

    appRouter.go('/settings');
    await tester.pumpAndSettle();
    final backupEntry = find.text('备份与恢复');
    await tester.ensureVisible(backupEntry);
    await tester.tap(backupEntry);
    await tester.pumpAndSettle();

    expect(find.text('备份与恢复'), findsOneWidget);
    expect(find.byKey(const Key('backup-create-button')), findsOneWidget);
    expect(find.byKey(const Key('backup-restore-button')), findsOneWidget);
  });

  widgetTest('opens operation logs from settings', (tester) async {
    await pumpApp(tester);

    appRouter.go('/settings');
    await tester.pumpAndSettle();
    final logEntry = find.text('操作日志');
    await tester.ensureVisible(logEntry);
    await tester.tap(logEntry);
    await tester.pumpAndSettle();

    expect(find.text('操作日志'), findsOneWidget);
    expect(find.text('暂无操作日志'), findsOneWidget);
  });

  widgetTest('renders month cells and opens the cell editor', (tester) async {
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

    appRouter.go('/attendance');
    await tester.pumpAndSettle();
    appRouter.go('/attendance/monthly-table?month=2026-09');
    await tester.pumpAndSettle();

    expect(find.text('张三'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    final cell = find.byKey(const Key('monthly-attendance-cell-1-1'));
    expect(find.descendant(of: cell, matching: find.text('半')), findsOneWidget);
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

  widgetTest('shows monthly roster selectors and an empty state for a group', (
    tester,
  ) async {
    final group = await AttendanceGroupRepository(database)
        .save(draft: const AttendanceGroupDraft(name: '月度名单组'));
    await pumpApp(tester, attendanceGroupOverride: [group]);

    appRouter.go('/attendance');
    await tester.pumpAndSettle();
    final monthlyEntry = find.byKey(
      const Key('attendance-monthly-roster-entry'),
    );
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

  widgetTest('assigns a default attendance group from the personnel form', (
    tester,
  ) async {
    final group = await AttendanceGroupRepository(database)
        .save(draft: const AttendanceGroupDraft(name: '管业临时工组'));
    await pumpApp(tester, attendanceGroupOverride: [group]);

    appRouter.go('/personnel');
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
