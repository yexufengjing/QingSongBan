import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/features/assistant/application/assistant_context_resolver.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';

void main() {
  const resolver = AssistantContextResolver();
  const employee = ResolvedEmployee(employeeId: 7, label: '张三');

  AssistantSessionContext sessionAt(String month) => AssistantSessionContext(
    lastQuery: ResolvedAttendanceQuery(
      employee: employee,
      yearMonth: month,
      yearMonthSource: AssistantFieldSource.turn,
      groupId: 3,
    ),
  );

  test(
    'new year keeps the prior month instead of the prior full year-month',
    () {
      final resolved = resolver.resolveContext(
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          yearReference: YearReference.current,
        ),
        sessionAt('2025-09'),
        null,
        DateTime(2026, 10, 17),
      );

      expect(resolved.yearMonth, '2026-09');
      expect(resolved.yearMonthSource, AssistantFieldSource.input);
    },
  );

  test('unspecified year precedence is turn, page, then device year', () {
    final cases = [
      (
        'device year',
        const AssistantSessionContext(),
        null,
        8,
        '2026-08',
        AssistantFieldSource.currentYear,
      ),
      (
        'page year',
        const AssistantSessionContext(),
        const AssistantPageContext(
          module: 'attendance',
          page: 'monthly',
          yearMonth: '2025-11',
        ),
        8,
        '2025-08',
        AssistantFieldSource.page,
      ),
      (
        'turn year before page year',
        sessionAt('2024-09'),
        const AssistantPageContext(
          module: 'attendance',
          page: 'monthly',
          yearMonth: '2025-11',
        ),
        8,
        '2024-08',
        AssistantFieldSource.turn,
      ),
    ];

    for (final testCase in cases) {
      final resolved = resolver.resolveContext(
        AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          month: testCase.$4,
        ),
        testCase.$2,
        testCase.$3,
        DateTime(2026, 10, 17),
      );

      expect(resolved.yearMonth, testCase.$5, reason: testCase.$1);
      expect(resolved.yearMonthSource, testCase.$6, reason: testCase.$1);
    }
  });

  test('explicit year combines with prior month and outranks page year', () {
    final resolved = resolver.resolveContext(
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        year: 2023,
        yearReference: YearReference.explicit,
      ),
      sessionAt('2024-09'),
      const AssistantPageContext(
        module: 'attendance',
        page: 'monthly',
        yearMonth: '2025-10',
      ),
      DateTime(2026, 10, 17),
    );

    expect(resolved.yearMonth, '2023-09');
    expect(resolved.yearMonthSource, AssistantFieldSource.input);
  });

  test('current input month wins over turn and page month', () {
    final resolved = resolver.resolveContext(
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        month: 4,
        yearReference: YearReference.unspecified,
      ),
      sessionAt('2024-09'),
      const AssistantPageContext(
        module: 'attendance',
        page: 'monthly',
        yearMonth: '2025-10',
      ),
      DateTime(2026, 10, 17),
    );

    expect(resolved.yearMonth, '2024-04');
    expect(resolved.yearMonthSource, AssistantFieldSource.turn);
  });

  test(
    'previous year is based on injected device date and stays idempotent',
    () {
      final first = resolver.resolveContext(
        const AttendanceIntent(
          action: AttendanceAction.changeYear,
          yearReference: YearReference.previous,
        ),
        sessionAt('2026-09'),
        null,
        DateTime(2026, 10, 17),
      );
      final second = resolver.resolveContext(
        const AttendanceIntent(
          action: AttendanceAction.changeYear,
          yearReference: YearReference.previous,
        ),
        sessionAt(first.yearMonth!),
        null,
        DateTime(2026, 10, 17),
      );

      expect(first.yearMonth, '2025-09');
      expect(second.yearMonth, '2025-09');
    },
  );

  test(
    'previous year handles January boundary and missing month stays missing',
    () {
      final previous = resolver.resolveContext(
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          month: 12,
          yearReference: YearReference.previous,
        ),
        const AssistantSessionContext(),
        null,
        DateTime(2027, 1, 1),
      );
      final missing = resolver.resolveContext(
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          employeeText: '张三',
        ),
        const AssistantSessionContext(),
        null,
        DateTime(2026, 10, 17),
      );

      expect(previous.yearMonth, '2026-12');
      expect(missing.yearMonth, isNull);
    },
  );

  test('new employee text clears previous employee and group binding', () {
    final resolved = resolver.resolveContext(
      const AttendanceIntent(
        action: AttendanceAction.changeEmployee,
        employeeText: '李四',
        yearReference: YearReference.inherit,
      ),
      sessionAt('2025-09'),
      null,
      DateTime(2026, 10, 17),
    );

    expect(resolved.yearMonth, '2025-09');
    expect(resolved.employeeText, '李四');
    expect(resolved.employeeId, isNull);
    expect(resolved.groupId, isNull);
  });

  test(
    'personnel and payroll context carries employee and month to attendance',
    () {
      for (final domain in [
        AssistantBusinessType.personnel,
        AssistantBusinessType.payroll,
      ]) {
        final resolved = resolver.resolveContext(
          const AttendanceIntent(
            action: AttendanceAction.queryAttendance,
            yearReference: YearReference.inherit,
          ),
          AssistantSessionContext(
            lastBusinessType: domain,
            lastBusinessQuery: AssistantBusinessQuery(
              domain: domain,
              question: '查询张三的业务信息',
              yearMonth: '2025-09',
              subject: '张三',
            ),
          ),
          null,
          DateTime(2026, 10, 17),
        );

        expect(resolved.businessType, AssistantBusinessType.attendance);
        expect(resolved.employeeText, '张三', reason: '$domain subject');
        expect(resolved.yearMonth, '2025-09', reason: '$domain month');
        expect(resolved.yearMonthSource, AssistantFieldSource.turn);
        expect(resolved.employeeId, isNull);
        expect(resolved.groupId, isNull);
      }
    },
  );

  test(
    'attendance honors a new employee instead of inherited person subject',
    () {
      final resolved = resolver.resolveContext(
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          employeeText: '李四',
          month: 6,
          yearReference: YearReference.inherit,
        ),
        const AssistantSessionContext(
          lastBusinessType: AssistantBusinessType.payroll,
          lastBusinessQuery: AssistantBusinessQuery(
            domain: AssistantBusinessType.payroll,
            question: '查询张三的工资',
            yearMonth: '2025-09',
            subject: '张三',
          ),
        ),
        null,
        DateTime(2026, 10, 17),
      );

      expect(resolved.employeeText, '李四');
      expect(resolved.yearMonth, '2025-06');
      expect(resolved.employeeId, isNull);
      expect(resolved.groupId, isNull);
    },
  );

  test('unrelated business subject does not leak into attendance', () {
    final resolved = resolver.resolveContext(
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        yearReference: YearReference.inherit,
      ),
      const AssistantSessionContext(
        lastBusinessType: AssistantBusinessType.inventory,
        lastBusinessQuery: AssistantBusinessQuery(
          domain: AssistantBusinessType.inventory,
          question: '查询绿篱刀片库存',
          subject: '绿篱刀片',
        ),
      ),
      null,
      DateTime(2026, 10, 17),
    );

    expect(resolved.employeeText, isNull);
    expect(resolved.employeeId, isNull);
    expect(resolved.groupId, isNull);
    expect(resolved.yearMonth, isNull);
  });

  test('rejects invalid explicit month and inconsistent relative year', () {
    final invalidMonth = resolver.resolveContext(
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        month: 13,
      ),
      const AssistantSessionContext(),
      null,
      DateTime(2026, 10, 17),
    );
    final inconsistentYear = resolver.resolveContext(
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        year: 2023,
        yearReference: YearReference.previous,
      ),
      const AssistantSessionContext(),
      null,
      DateTime(2026, 10, 17),
    );
    final invalidVehicleYear = resolver.resolveContext(
      const AttendanceIntent(
        action: AttendanceAction.queryVehicleAnnualRepair,
        vehicleText: '一号车',
        year: 10000,
        yearReference: YearReference.explicit,
      ),
      const AssistantSessionContext(),
      null,
      DateTime(2026, 10, 17),
    );

    expect(invalidMonth.error, AssistantErrorCode.invalidArgument);
    expect(inconsistentYear.error, AssistantErrorCode.invalidArgument);
    expect(invalidVehicleYear.error, AssistantErrorCode.invalidArgument);
    expect(
      invalidVehicleYear.businessType,
      AssistantBusinessType.vehicleAnnualRepair,
    );
  });

  test('vehicle year context carries between single and ranking scopes', () {
    final singleVehicle = ResolvedVehicle(
      vehicleId: 41,
      label: 'A车',
      vehicleNumber: 'A01',
    );
    final singleSession = AssistantSessionContext(
      lastBusinessType: AssistantBusinessType.vehicleAnnualRepair,
      lastVehicleQuery: ResolvedVehicleAnnualRepairQuery(
        vehicle: singleVehicle,
        year: 2025,
      ),
    );
    final ranking = resolver.resolveContext(
      const AttendanceIntent(
        action: AttendanceAction.allVehicles,
        allVehicles: true,
      ),
      singleSession,
      null,
      DateTime(2026, 10, 18),
    );
    expect(ranking.businessType, AssistantBusinessType.vehicleAnnualRanking);
    expect(ranking.requestedYear, 2025);

    final rankingSession = AssistantSessionContext(
      lastBusinessType: AssistantBusinessType.vehicleAnnualRanking,
      lastRankingQuery: const ResolvedVehicleRankingQuery(year: 2024),
    );
    final single = resolver.resolveContext(
      const AttendanceIntent(
        action: AttendanceAction.queryVehicleAnnualRepair,
        vehicleText: 'B车',
      ),
      rankingSession,
      null,
      DateTime(2026, 10, 18),
    );
    expect(single.businessType, AssistantBusinessType.vehicleAnnualRepair);
    expect(single.requestedYear, 2024);
  });

  test('vehicle task does not inherit an older attendance query', () {
    final resolved = resolver.resolveContext(
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        employeeText: '李四',
        month: 9,
      ),
      AssistantSessionContext(
        lastBusinessType: AssistantBusinessType.vehicleAnnualRepair,
        lastQuery: ResolvedAttendanceQuery(
          employee: employee,
          yearMonth: '2024-03',
          yearMonthSource: AssistantFieldSource.turn,
          groupId: 8,
        ),
        lastVehicleQuery: ResolvedVehicleAnnualRepairQuery(
          vehicle: ResolvedVehicle(
            vehicleId: 41,
            label: 'A车',
            vehicleNumber: 'A01',
          ),
          year: 2025,
        ),
      ),
      null,
      DateTime(2026, 10, 18),
    );

    expect(resolved.businessType, AssistantBusinessType.attendance);
    expect(resolved.yearMonth, '2026-09');
    expect(resolved.employeeText, '李四');
    expect(resolved.employeeId, isNull);
    expect(resolved.groupId, isNull);
  });
}
