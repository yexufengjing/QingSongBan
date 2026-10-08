import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/attendance/application/daily_attendance_providers.dart';
import 'package:qingsongban/features/attendance/data/attendance_group_repository.dart';
import 'package:qingsongban/features/attendance/data/monthly_roster_repository.dart';
import 'package:qingsongban/features/attendance/domain/attendance_group_options.dart';
import 'package:qingsongban/features/attendance/presentation/daily_attendance_page.dart';
import 'package:qingsongban/features/overtime/application/overtime_providers.dart';
import 'package:qingsongban/features/overtime/data/overtime_repository.dart';
import 'package:qingsongban/features/overtime/domain/overtime_options.dart';
import 'package:qingsongban/features/personnel/data/personnel_repository.dart';
import 'package:qingsongban/features/personnel/domain/personnel_options.dart';

void main() {
  testWidgets(
    'daily attendance requests the selected month and shows only that day\'s overtime',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      final database = AppDatabase.forTesting();
      try {
        final group = await AttendanceGroupRepository(database)
            .save(draft: const AttendanceGroupDraft(name: '跨月加班组'));
        final employee = await PersonnelRepository(database).save(
          draft: EmployeeDraft(
            employeeNo: 'EMP-OT-MONTH',
            name: '跨月人员',
            hireDate: DateTime(2026, 1, 1),
            status: EmployeeStatus.active,
          ),
        );
        final rosterRepository = MonthlyRosterRepository(database);
        await rosterRepository.addEmployee(
          yearMonth: '2026-01',
          groupId: group.id,
          employeeId: employee.id,
        );
        await rosterRepository.addEmployee(
          yearMonth: '2026-02',
          groupId: group.id,
          employeeId: employee.id,
        );

        final overtimeRepository = OvertimeRepository(database);
        Future<void> addOvertime(
          DateTime date,
          int startHour,
          int minutes,
        ) async {
          final start = DateTime(date.year, date.month, date.day, startHour);
          await overtimeRepository.save(
            draft: OvertimeRecordDraft(
              employeeId: employee.id,
              overtimeDate: date,
              startTime: start,
              endTime: start.add(Duration(minutes: minutes)),
              overtimeType: 'weekday',
            ),
          );
        }

        await addOvertime(DateTime(2026, 1, 30), 18, 240);
        await addOvertime(DateTime(2026, 1, 31), 18, 90);
        await addOvertime(DateTime(2026, 2, 1), 18, 195);
        await addOvertime(DateTime(2026, 2, 2), 18, 240);

        final requestedMonths = <String>{};
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(database),
              dailyAttendanceDateProvider.overrideWith(
                (ref) => DateTime(2026, 1, 31),
              ),
              overtimeRecordsForMonthProvider.overrideWith((ref, month) {
                requestedMonths.add(
                  '${month.year}-${month.month.toString().padLeft(2, '0')}',
                );
                return OvertimeRepository(ref.watch(appDatabaseProvider))
                    .watchOvertime(month: month);
              }),
            ],
            child: const MaterialApp(home: DailyAttendancePage()),
          ),
        );
        await tester.pumpAndSettle();

        final overtimeButton = find.byKey(
          Key('daily-attendance-overtime-${employee.id}'),
        );
        expect(find.textContaining('2026-01-31'), findsOneWidget);
        expect(requestedMonths, contains('2026-01'));
        expect(
          find.descendant(of: overtimeButton, matching: find.text('加班 1小时30分')),
          findsOneWidget,
        );
        expect(find.text('加班 4小时'), findsNothing);

        await tester.tap(find.byKey(const Key('daily-attendance-next-day')));
        await tester.pumpAndSettle();

        expect(find.textContaining('2026-02-01'), findsOneWidget);
        expect(requestedMonths, contains('2026-02'));
        expect(
          find.descendant(of: overtimeButton, matching: find.text('加班 3小时15分')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: overtimeButton, matching: find.text('加班 1小时30分')),
          findsNothing,
        );
        expect(find.text('加班 4小时'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.idle();
        await tester.pump(const Duration(milliseconds: 1));
        await database.close();
        await tester.idle();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.binding.setSurfaceSize(null);
      }
    },
  );
}
