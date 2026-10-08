import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/attendance/data/attendance_group_repository.dart';
import 'package:qingsongban/features/attendance/data/daily_attendance_repository.dart';
import 'package:qingsongban/features/attendance/data/monthly_roster_repository.dart';
import 'package:qingsongban/features/attendance/domain/attendance_group_options.dart';
import 'package:qingsongban/features/attendance/domain/daily_attendance_options.dart';
import 'package:qingsongban/features/home/application/home_providers.dart';
import 'package:qingsongban/features/personnel/data/personnel_repository.dart';
import 'package:qingsongban/features/personnel/domain/personnel_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'home attendance counts eligible people and refreshes by half-day',
    () async {
      final database = AppDatabase.forTesting();
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      final values = <HomeAttendanceProgress>[];
      final subscription = container.listen(homeAttendanceProgressProvider, (
        previous,
        next,
      ) {
        final value = next.valueOrNull;
        if (value != null) values.add(value);
      });
      try {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final month = '${today.year}-${today.month.toString().padLeft(2, '0')}';
        final groups = AttendanceGroupRepository(database);
        final firstGroup = await groups.save(
          draft: const AttendanceGroupDraft(name: '进度组一'),
        );
        final secondGroup = await groups.save(
          draft: const AttendanceGroupDraft(name: '进度组二'),
        );
        final people = PersonnelRepository(database);
        final eligible = await people.save(
          draft: EmployeeDraft(
            employeeNo: 'EMP-HOME-1',
            name: '重复组人员',
            hireDate: today.subtract(const Duration(days: 30)),
            status: EmployeeStatus.active,
          ),
        );
        final futureHire = await people.save(
          draft: EmployeeDraft(
            employeeNo: 'EMP-HOME-2',
            name: '未入职人员',
            hireDate: today.add(const Duration(days: 1)),
            status: EmployeeStatus.active,
          ),
        );
        final terminated = await people.save(
          draft: EmployeeDraft(
            employeeNo: 'EMP-HOME-3',
            name: '已离职人员',
            hireDate: today.subtract(const Duration(days: 90)),
            status: EmployeeStatus.terminated,
          ),
        );
        final rosters = MonthlyRosterRepository(database);
        for (final group in [firstGroup, secondGroup]) {
          await rosters.addEmployee(
            yearMonth: month,
            groupId: group.id,
            employeeId: eligible.id,
          );
        }
        for (final person in [futureHire, terminated]) {
          await rosters.addEmployee(
            yearMonth: month,
            groupId: firstGroup.id,
            employeeId: person.id,
          );
        }

        await _waitFor(() => values.any((value) => value.rosterCount == 1));
        expect(values.last.rosterCount, 1);
        expect(values.last.morningRegistered, 0);
        expect(values.last.afternoonRegistered, 0);

        await DailyAttendanceRepository(database).save(
          DailyAttendanceDraft(
            employeeId: eligible.id,
            attendanceDate: today,
            morningStatus: AttendanceHalfStatus.present,
            afternoonStatus: AttendanceHalfStatus.unregistered,
          ),
        );
        await _waitFor(
          () => values.any(
            (value) =>
                value.rosterCount == 1 &&
                value.morningRegistered == 1 &&
                value.afternoonRegistered == 0,
          ),
        );
        expect(values.last.rosterCount, 1);
        expect(values.last.morningRegistered, 1);
        expect(values.last.afternoonRegistered, 0);
      } finally {
        subscription.close();
        container.dispose();
        await database.close();
      }
    },
  );
}

Future<void> _waitFor(bool Function() predicate) async {
  final timeout = DateTime.now().add(const Duration(seconds: 3));
  while (!predicate()) {
    if (DateTime.now().isAfter(timeout)) {
      throw TimeoutException('Home attendance progress did not update.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
