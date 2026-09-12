import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/app/app.dart';
import 'package:qingsongban/features/attendance/application/attendance_group_providers.dart';
import 'package:qingsongban/features/attendance/application/monthly_roster_providers.dart';
import 'package:qingsongban/features/attendance/data/attendance_group_repository.dart';
import 'package:qingsongban/features/attendance/domain/attendance_group_options.dart';
import 'package:qingsongban/features/attendance/domain/monthly_roster_options.dart';
import 'package:qingsongban/features/personnel/application/personnel_providers.dart';

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
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          allPersonnelProvider.overrideWith(
            (ref) => Stream.value(<Employee>[]),
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
        ],
        child: const QingSongBanApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the home tab with five destinations', (tester) async {
    await pumpApp(tester);

    expect(find.text('轻松办'), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('人员'), findsOneWidget);
    expect(find.text('考勤'), findsOneWidget);
    expect(find.text('汇总'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('阶段 0 已就绪'), findsOneWidget);
  });

  testWidgets('switches between all five tabs', (tester) async {
    await pumpApp(tester);

    const markers = {
      '人员': '档案概览',
      '考勤': '考勤组管理',
      '汇总': '汇总入口已建立',
      '我的': '个人中心入口已建立',
      '首页': '阶段 0 已就绪',
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

  testWidgets('uses the stage zero visual baseline', (tester) async {
    await pumpApp(tester);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.colorScheme.primary, const Color(0xFF00C16B));
    expect(materialApp.theme?.scaffoldBackgroundColor, const Color(0xFFF6F9FC));
  });

  testWidgets('creates and edits a personnel record', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('人员'));
    await tester.pumpAndSettle();
    final createAction = find.text('新增人员');
    await tester.ensureVisible(createAction);
    await tester.tap(createAction);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('personnel-name-field')), '张三');
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
