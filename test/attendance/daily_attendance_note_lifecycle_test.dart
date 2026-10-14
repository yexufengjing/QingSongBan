import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/app/app.dart';
import 'package:qingsongban/app/router/app_router.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/attendance/data/attendance_group_repository.dart';
import 'package:qingsongban/features/attendance/data/daily_attendance_repository.dart';
import 'package:qingsongban/features/attendance/data/monthly_roster_repository.dart';
import 'package:qingsongban/features/attendance/domain/attendance_group_options.dart';
import 'package:qingsongban/features/attendance/domain/daily_attendance_options.dart';
import 'package:qingsongban/features/personnel/data/personnel_repository.dart';
import 'package:qingsongban/features/personnel/domain/personnel_options.dart';

void main() {
  testWidgets(
    'attendance note dialog opens, closes, and saves through the real route',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      final now = DateTime.now();
      final attendanceDate = DateTime(now.year, now.month, now.day);
      var groupId = 0;
      var employeeId = 0;
      await tester.runAsync(() async {
        final group = await AttendanceGroupRepository(database)
            .save(draft: const AttendanceGroupDraft(name: '备注生命周期组'));
        groupId = group.id;
        final employee = await PersonnelRepository(database).save(
          draft: EmployeeDraft(
            employeeNo: 'NOTE-001',
            name: '备注测试人员',
            hireDate: DateTime(now.year, 1, 1),
            status: EmployeeStatus.active,
          ),
        );
        employeeId = employee.id;
        await MonthlyRosterRepository(database).addEmployee(
          yearMonth: '${now.year}-${now.month.toString().padLeft(2, '0')}',
          groupId: group.id,
          employeeId: employee.id,
        );
        await DailyAttendanceRepository(database).save(
          DailyAttendanceDraft(
            employeeId: employee.id,
            attendanceDate: attendanceDate,
            morningStatus: AttendanceHalfStatus.unregistered,
            afternoonStatus: AttendanceHalfStatus.unregistered,
            remark: '原备注',
          ),
        );
      });

      appRouter.go('/attendance');
      addTearDown(appRouter.dispose);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.idle();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const QingSongBanApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('考勤'), findsWidgets);

      await tester.tap(find.byKey(const Key('attendance-daily-entry')));
      await tester.pumpAndSettle();
      final noteButton = find.byKey(Key('daily-attendance-remark-$employeeId'));
      await tester.ensureVisible(noteButton);
      await tester.pumpAndSettle();
      expect(noteButton, findsOneWidget);

      Future<void> openNote() async {
        await tester.tap(noteButton);
        await tester.pumpAndSettle();
        expect(find.text('考勤备注'), findsOneWidget);
        _expectNoInheritedDependentsAssertion(tester, 'open note dialog');
      }

      for (var index = 0; index < 3; index++) {
        await tester.tap(noteButton);
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.text('考勤备注'), findsOneWidget);
        _expectNoInheritedDependentsAssertion(tester, 'rapid open note');
        if (index == 0) {
          await tester.enterText(find.byType(TextField), '取消不保存的改动');
        }
        await tester.tap(find.text('取消'));
        await tester.pump(const Duration(milliseconds: 16));
        _expectNoInheritedDependentsAssertion(tester, 'rapid cancel note');
        await tester.pumpAndSettle();
      }
      expect(find.text('考勤备注'), findsNothing);
      expect(
        await readPersistedRemark(tester, database, attendanceDate, groupId),
        '原备注',
      );

      await openNote();
      await tester.enterText(find.byType(TextField), '连续点击后保存的备注');
      await tester.tap(find.text('保存备注'));
      await tester.pumpAndSettle();
      _expectNoInheritedDependentsAssertion(tester, 'save note dialog');
      expect(
        await readPersistedRemark(tester, database, attendanceDate, groupId),
        '连续点击后保存的备注',
      );

      await openNote();
      await tester.enterText(find.byType(TextField), '返回时不保存');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('考勤备注'), findsNothing);
      _expectNoInheritedDependentsAssertion(tester, 'system-back close');
      expect(
        await readPersistedRemark(tester, database, attendanceDate, groupId),
        '连续点击后保存的备注',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      _expectNoInheritedDependentsAssertion(tester, 'dispose daily attendance');
    },
  );
}

Future<String?> readPersistedRemark(
  WidgetTester tester,
  AppDatabase database,
  DateTime attendanceDate,
  int groupId,
) async {
  String? remark;
  await tester.runAsync(() async {
    final entries = await DailyAttendanceRepository(database)
        .watchEntries(attendanceDate: attendanceDate, groupId: groupId)
        .first;
    remark = entries.single.remark;
  });
  return remark;
}

void _expectNoInheritedDependentsAssertion(WidgetTester tester, String step) {
  final exception = tester.takeException();
  expect(
    exception?.toString(),
    isNot(contains('_dependents.isEmpty')),
    reason: 'Flutter inherited-element assertion at $step: $exception',
  );
  expect(exception, isNull, reason: 'unexpected widget failure at $step');
}
