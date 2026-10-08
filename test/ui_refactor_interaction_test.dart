import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/app/theme/app_theme.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/attendance/application/daily_attendance_providers.dart';
import 'package:qingsongban/features/attendance/data/attendance_group_repository.dart';
import 'package:qingsongban/features/attendance/data/daily_attendance_repository.dart';
import 'package:qingsongban/features/attendance/data/monthly_roster_repository.dart';
import 'package:qingsongban/features/attendance/domain/attendance_group_options.dart';
import 'package:qingsongban/features/attendance/domain/daily_attendance_options.dart';
import 'package:qingsongban/features/attendance/presentation/daily_attendance_page.dart';
import 'package:qingsongban/features/personnel/data/personnel_repository.dart';
import 'package:qingsongban/features/personnel/domain/personnel_options.dart';
import 'package:qingsongban/features/personnel/presentation/personnel_list_page.dart';
import 'package:qingsongban/features/reminders/data/reminder_repository.dart';
import 'package:qingsongban/features/reminders/domain/reminder_options.dart';
import 'package:qingsongban/features/reports/presentation/reports_page.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_repository.dart';
import 'package:qingsongban/features/vehicles/domain/vehicle_options.dart';
import 'package:qingsongban/features/vehicles/presentation/vehicle_reminder_page.dart';

class _FailOnceAttendanceRepository extends DailyAttendanceRepository {
  _FailOnceAttendanceRepository(super.database);
  bool fail = true;

  @override
  Future<void> save(DailyAttendanceDraft draft) async {
    if (fail) {
      fail = false;
      throw StateError('test write failure');
    }
    await super.save(draft);
  }
}

Future<void> _pump(
  WidgetTester tester,
  AppDatabase db,
  Widget page, {
  DailyAttendanceRepository? attendanceRepository,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        if (attendanceRepository != null)
          dailyAttendanceRepositoryProvider.overrideWithValue(
            attendanceRepository,
          ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting());
  tearDown(() async => db.close());

  for (final (size, scale) in [
    (const Size(375, 844), 2.0),
    (const Size(844, 390), 1.0),
  ]) {
    testWidgets('half-day save and retry at $size, scale $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.now();
      final group = await AttendanceGroupRepository(db)
          .save(draft: const AttendanceGroupDraft(name: '测试考勤组'));
      final employee = await PersonnelRepository(db).save(
        draft: EmployeeDraft(
          employeeNo: 'UI-001',
          name: '测试人员',
          hireDate: DateTime(now.year, 1, 1),
          status: EmployeeStatus.active,
        ),
      );
      await MonthlyRosterRepository(db).addEmployee(
        yearMonth: '${now.year}-${now.month.toString().padLeft(2, '0')}',
        groupId: group.id,
        employeeId: employee.id,
      );
      await _pump(
        tester,
        db,
        const DailyAttendancePage(),
        attendanceRepository: _FailOnceAttendanceRepository(db),
        scale: scale,
      );
      for (final key in [
        'daily-attendance-date-button',
        'daily-attendance-group-${group.id}',
      ]) {
        final bounds = tester.getSize(find.byKey(Key(key)));
        expect(bounds.width, greaterThanOrEqualTo(48));
        expect(bounds.height, greaterThanOrEqualTo(48));
      }
      final morning = find.byKey(
        Key('daily-attendance-morning-${employee.id}'),
      );
      Future<void> selectPresent() async {
        await tester.ensureVisible(morning);
        await tester.pumpAndSettle();
        await tester.tap(morning);
        await tester.pumpAndSettle();
        final option = find.widgetWithText(
          PopupMenuItem<AttendanceHalfStatus>,
          '出勤',
        );
        expect(option, findsOneWidget);
        await tester.tap(option);
        await tester.pumpAndSettle();
      }

      await selectPresent();
      expect(find.text('保存失败，请重新选择或编辑后重试'), findsOneWidget);
      expect(await db.select(db.attendanceRecords).get(), isEmpty);
      await selectPresent();
      expect(find.text('已自动保存'), findsOneWidget);
      final record = (await db.select(db.attendanceRecords).get()).single;
      expect(record.morningStatus, AttendanceHalfStatus.present);
      expect(record.afternoonStatus, AttendanceHalfStatus.unregistered);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('reports remember a separate month for each module', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester, db, const ReportsPage());
    String month() =>
        tester.widget<Text>(find.byKey(const Key('summary-month-label'))).data!;
    final initial = month();
    await tester.tap(find.byKey(const Key('summary-previous-month')));
    await tester.pumpAndSettle();
    final attendance = month();
    expect(attendance, isNot(initial));
    await tester.tap(find.text('车辆').first);
    await tester.pumpAndSettle();
    expect(month(), initial);
    await tester.tap(find.byKey(const Key('summary-next-month')));
    await tester.pumpAndSettle();
    final vehicle = month();
    for (final tab in ['库存', '工资']) {
      await tester.tap(find.text(tab).first);
      await tester.pumpAndSettle();
      expect(month(), initial);
    }
    await tester.tap(find.text('车辆').first);
    await tester.pumpAndSettle();
    expect(month(), vehicle);
    await tester.tap(find.text('考勤').first);
    await tester.pumpAndSettle();
    expect(month(), attendance);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('vehicle panel filters reminders by the linked vehicle', (
    tester,
  ) async {
    final repo = VehicleRepository(db);
    final vehicles = [
      for (var index = 1; index <= 2; index++)
        await repo.save(
          draft: VehicleDraft(
            name: '车辆$index',
            vehicleNo: 'UI-$index',
            licensePlate: 'UI000$index',
            vehicleType: VehicleType.waterTruck,
          ),
        ),
    ];
    for (final vehicle in vehicles) {
      await ReminderRepository(db).save(
        draft: ReminderDraft(
          title: '${vehicle.name}保养',
          reminderType: 'custom',
          leadDays: 0,
          isEnabled: true,
          dueDate: DateTime.now(),
          links: [
            ReminderLinkDraft(
              entityType: 'vehicle',
              entityId: vehicle.id,
              displayName: vehicle.name,
            ),
          ],
        ),
      );
    }
    await ReminderRepository(db).save(
      draft: ReminderDraft(
        title: '停用车辆提醒',
        reminderType: 'custom',
        leadDays: 0,
        isEnabled: false,
        dueDate: DateTime.now(),
        links: [
          ReminderLinkDraft(
            entityType: 'vehicle',
            entityId: vehicles.first.id,
            displayName: vehicles.first.name,
          ),
        ],
      ),
    );
    final now = DateTime.now();
    await ReminderRepository(db).save(
      draft: ReminderDraft(
        title: '第七天提醒',
        reminderType: 'custom',
        leadDays: 0,
        isEnabled: true,
        dueDate: DateTime(now.year, now.month, now.day + 7, 18),
        links: [
          ReminderLinkDraft(
            entityType: 'vehicle',
            entityId: vehicles.first.id,
            displayName: vehicles.first.name,
          ),
        ],
      ),
    );
    await _pump(
      tester,
      db,
      Scaffold(body: VehicleReminderPage(vehicleId: vehicles.first.id)),
    );
    expect(find.text('车辆1保养'), findsOneWidget);
    expect(find.text('车辆2保养'), findsNothing);
    expect(find.text('停用车辆提醒'), findsNothing);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.text('即将到期'));
    await tester.pumpAndSettle();
    expect(find.text('第七天提醒'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('personnel no-match state clears the input and filters', (
    tester,
  ) async {
    await PersonnelRepository(db).save(
      draft: EmployeeDraft(
        employeeNo: 'UI-001',
        name: '测试人员',
        hireDate: DateTime(2026, 1, 1),
        status: EmployeeStatus.active,
      ),
    );
    await _pump(tester, db, const PersonnelListPage());
    await tester.enterText(find.byType(TextField).first, '不存在的姓名');
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的人员'), findsOneWidget);
    expect(find.text('暂无人员档案'), findsNothing);
    await tester.tap(find.text('清除搜索与筛选'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
    expect(find.text('没有匹配的人员'), findsNothing);
    expect(find.text('测试人员'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
