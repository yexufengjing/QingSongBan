import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/features/assistant/application/assistant_controller.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';
import 'package:qingsongban/features/assistant/domain/assistant_quick_query.dart';

void main() {
  final now = DateTime(2026, 10, 22, 12);

  test(
    'quick queries are local and keep their selected employee and month',
    () async {
      final provider = _NoopProvider();
      final attendance = _AttendanceReader();
      final business = _BusinessReader();
      final controller = AssistantController(
        provider: provider,
        attendance: attendance,
        businessReader: business,
        clock: () => now,
      );

      await controller.runQuickQuery(
        const AssistantQuickQuery(
          kind: AssistantQuickQueryKind.attendance,
          employeeId: 41,
          yearMonth: '2026-03',
        ),
      );
      await controller.runQuickQuery(
        const AssistantQuickQuery(
          kind: AssistantQuickQueryKind.payroll,
          employeeId: 52,
          yearMonth: '2026-04',
        ),
      );

      expect(provider.parseCalls, 0);
      expect(attendance.reads.single.employee.employeeId, 41);
      expect(attendance.reads.single.yearMonth, '2026-03');
      expect(business.reads.single.domain, AssistantBusinessType.payroll);
      expect(business.reads.single.employeeId, 52);
      expect(business.reads.single.yearMonth, '2026-04');
      expect(business.reads.single.subject, isNull);
      expect(business.reads.single.operation, 'summary');
    },
  );

  test(
    'follow-up uses the selected result scope after a different quick query',
    () async {
      final provider = _NoopProvider();
      final attendance = _AttendanceReader();
      final business = _BusinessReader();
      final controller = AssistantController(
        provider: provider,
        attendance: attendance,
        businessReader: business,
        clock: () => now,
      );

      await controller.runQuickQuery(
        const AssistantQuickQuery(
          kind: AssistantQuickQueryKind.payroll,
          employeeId: 52,
          yearMonth: '2026-04',
        ),
      );
      final payrollMessageId = controller.state.messages.last.id;
      await controller.runQuickQuery(
        const AssistantQuickQuery(
          kind: AssistantQuickQueryKind.purchasePending,
        ),
      );
      await controller.runQuickQuery(
        const AssistantQuickQuery(
          kind: AssistantQuickQueryKind.inventoryLowStock,
        ),
      );
      await controller.runQuickQuery(
        const AssistantQuickQuery(
          kind: AssistantQuickQueryKind.distribution,
          yearMonth: '2026-06',
        ),
      );
      await controller.runFollowUp(
        payrollMessageId,
        yearMonth: '2026-05',
        operation: 'summary',
      );

      expect(provider.parseCalls, 0);
      expect(business.reads.map((query) => query.domain), [
        AssistantBusinessType.payroll,
        AssistantBusinessType.purchase,
        AssistantBusinessType.inventory,
        AssistantBusinessType.distribution,
        AssistantBusinessType.payroll,
      ]);
      final followUp = business.reads.last;
      expect(followUp.employeeId, 52);
      expect(followUp.subject, isNull);
      expect(followUp.yearMonth, '2026-05');
      expect(followUp.operation, 'summary');
    },
  );

  test(
    'vehicle repair shortcut and month follow-up keep the selected vehicle',
    () async {
      final provider = _NoopProvider();
      final business = _BusinessReader();
      final controller = AssistantController(
        provider: provider,
        attendance: _AttendanceReader(),
        businessReader: business,
        clock: () => now,
      );

      await controller.runQuickQuery(
        const AssistantQuickQuery(
          kind: AssistantQuickQueryKind.vehicleRepair,
          vehicleId: 711,
          yearMonth: '2026-02',
        ),
      );
      final resultId = controller.state.messages.last.id;
      await controller.runFollowUp(resultId, yearMonth: '2026-03');

      expect(provider.parseCalls, 0);
      expect(
        business.reads.map((query) => (query.vehicleId, query.yearMonth)),
        [(711, '2026-02'), (711, '2026-03')],
      );
      expect(
        business.reads.every(
          (query) => query.domain == AssistantBusinessType.vehicleMaintenance,
        ),
        isTrue,
      );
    },
  );

  test(
    'quick shortcut clears pending follow-up scope and serialization is stable',
    () async {
      final provider = _NoopProvider();
      final attendance = _AttendanceReader();
      final business = _BusinessReader();
      final controller = AssistantController(
        provider: provider,
        attendance: attendance,
        businessReader: business,
        clock: () => now,
      );
      controller.updatePageContext(
        const AssistantPageContext(
          module: 'attendance',
          page: 'monthly-table',
          employeeId: 99,
          yearMonth: '2024-01',
        ),
      );

      await controller.runQuickQuery(
        const AssistantQuickQuery(
          kind: AssistantQuickQueryKind.attendance,
          employeeId: 41,
          yearMonth: '2026-03',
        ),
      );
      await controller.runQuickQuery(
        const AssistantQuickQuery(
          kind: AssistantQuickQueryKind.purchasePending,
        ),
      );

      expect(attendance.reads.single.employee.employeeId, 41);
      expect(attendance.reads.single.yearMonth, '2026-03');
      expect(
        business.reads.map(
          (query) => (query.domain, query.operation, query.yearMonth),
        ),
        [(AssistantBusinessType.purchase, 'pending', null)],
      );
      expect(provider.parseCalls, 0);
      const saved = AssistantQuickQuery(
        kind: AssistantQuickQueryKind.distribution,
        yearMonth: '2026-02',
      );
      expect(
        AssistantQuickQuery.fromJson(saved.toJson()).toJson(),
        saved.toJson(),
      );
      expect(saved.title, '查看福利领取 · 2026-02');
    },
  );
}

class _NoopProvider implements AIProvider {
  int parseCalls = 0;

  @override
  Future<AttendanceIntent> parseIntent(
    IntentRequest request,
    RequestToken token,
  ) async {
    parseCalls++;
    throw StateError('quick queries must not parse through the provider');
  }

  @override
  Future<SummaryExplanation> explainSummary(
    AttendanceOutboundSummary summary,
    RequestToken token,
  ) async => const SummaryExplanation(text: '');

  @override
  Future<ConnectionCheck> checkConnection(RequestToken token) async =>
      const ConnectionCheck(success: true);
}

class _AttendanceReader implements AttendanceReadPort {
  final reads = <ResolvedAttendanceQuery>[];

  @override
  Future<EmployeeResolution> resolveEmployee(EmployeeSelector selector) async =>
      EmployeeResolution(
        status: EmployeeResolutionStatus.unique,
        employee: ResolvedEmployee(
          employeeId: selector.employeeId!,
          label: 'Employee ${selector.employeeId}',
        ),
      );

  @override
  Future<EmployeeResolution> resolveCandidate(String candidateRef) async =>
      const EmployeeResolution(status: EmployeeResolutionStatus.notFound);

  @override
  Future<AttendanceReadResult> readMonth(ResolvedAttendanceQuery query) async {
    reads.add(query);
    return AttendanceReadResult(
      status: AttendanceReadStatus.success,
      employeeLabel: query.employee.label,
      yearMonth: query.yearMonth,
      queriedAt: DateTime(2026, 10, 22),
      completeness: AttendanceCompleteness.notEvaluated,
    );
  }
}

class _BusinessReader implements AssistantBusinessReadPort {
  final reads = <AssistantBusinessQuery>[];

  @override
  Future<AssistantBusinessReadResult> read(AssistantBusinessQuery query) async {
    reads.add(query);
    return AssistantBusinessReadResult(
      domain: query.domain,
      title: 'Result',
      summary: 'Result',
      queriedAt: query.now ?? DateTime(2026, 10, 22),
      sourceRule: 'test',
      sourcePage: '/',
    );
  }
}
