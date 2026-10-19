import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/features/assistant/application/assistant_controller.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';

void main() {
  test(
    'vehicle query uses the page snapshot captured before parsing',
    () async {
      final deferred = Completer<AttendanceIntent>();
      final provider = _Provider()..pending = deferred;
      final vehicles = _VehiclePort();
      final controller = AssistantController(
        provider: provider,
        attendance: _AttendancePort(),
        vehicles: vehicles,
        clock: () => DateTime(2026, 10, 18),
      );
      controller.updatePageContext(
        const AssistantPageContext(
          module: 'vehicles',
          page: 'vehicle-detail',
          vehicleId: 11,
          year: 2025,
        ),
      );

      final submitting = controller.submit('查这辆车维修费');
      while (provider.parseCount == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      controller.updatePageContext(
        const AssistantPageContext(
          module: 'vehicles',
          page: 'vehicle-detail',
          vehicleId: 22,
          year: 2024,
        ),
      );
      deferred.complete(
        const AttendanceIntent(
          action: AttendanceAction.queryVehicleAnnualRepair,
          yearReference: YearReference.unspecified,
        ),
      );
      await submitting;

      expect(provider.parseCount, 1);
      expect(provider.explanationCount, 0);
      expect(vehicles.selectors.single.vehicleId, 11);
      expect(vehicles.readQueries.single.vehicle.vehicleId, 11);
      expect(vehicles.readQueries.single.year, 2025);
      expect(controller.state.messages.last.answer!.vehicleSummary, isNotNull);
      expect(controller.state.messages.last.metrics!.parseCalls, 1);
      expect(
        controller.state.messages.last.metrics!.resolutionPath,
        AssistantResolutionPath.modelParsed,
      );

      provider.nextIntent = const AttendanceIntent(
        action: AttendanceAction.queryVehicleAnnualRepair,
        yearReference: YearReference.unspecified,
      );
      await controller.submit('再查这辆车今年维修费');

      expect(vehicles.readQueries.last.vehicle.vehicleId, 22);
      expect(vehicles.readQueries.last.year, 2024);
    },
  );

  test(
    'entering a new vehicle page replaces the completed vehicle context',
    () async {
      final provider = _Provider()
        ..nextIntent = const AttendanceIntent(
          action: AttendanceAction.queryVehicleAnnualRepair,
          yearReference: YearReference.unspecified,
        );
      final vehicles = _VehiclePort();
      final controller = AssistantController(
        provider: provider,
        attendance: _AttendancePort(),
        vehicles: vehicles,
        clock: () => DateTime(2026, 10, 18),
      );
      controller.updatePageContext(
        const AssistantPageContext(
          module: 'vehicles',
          page: 'vehicle-detail',
          vehicleId: 11,
          year: 2025,
        ),
      );

      await controller.submit('这辆车今年维修费多少');
      controller.updatePageContext(
        const AssistantPageContext(
          module: 'vehicles',
          page: 'vehicle-detail',
          vehicleId: 22,
          year: 2024,
        ),
      );
      await controller.submit('这辆车今年维修费多少');

      expect(vehicles.readQueries.map((query) => query.vehicle.vehicleId), [
        11,
        22,
      ]);
      expect(vehicles.readQueries.map((query) => query.year), [2025, 2024]);
    },
  );

  test(
    'an explicit vehicle on the new page becomes the follow-up context',
    () async {
      final provider = _Provider()
        ..nextIntent = const AttendanceIntent(
          action: AttendanceAction.queryVehicleAnnualRepair,
          vehicleText: 'A车',
          year: 2025,
          yearReference: YearReference.explicit,
        );
      final vehicles = _VehiclePort();
      final controller = AssistantController(
        provider: provider,
        attendance: _AttendancePort(),
        vehicles: vehicles,
        clock: () => DateTime(2026, 10, 18),
      );
      controller.updatePageContext(
        const AssistantPageContext(
          module: 'vehicles',
          page: 'vehicle-detail',
          vehicleId: 22,
          year: 2024,
        ),
      );

      await controller.submit('查A车2025年维修费');
      provider.nextIntent = const AttendanceIntent(
        action: AttendanceAction.changeYear,
        yearReference: YearReference.current,
      );
      await controller.submit('改看今年的');

      expect(vehicles.readQueries.map((query) => query.vehicle.vehicleId), [
        11,
        11,
      ]);
      expect(vehicles.readQueries.map((query) => query.year), [2025, 2026]);
    },
  );

  test(
    'a new ranking request bypasses a pending vehicle clarification',
    () async {
      final provider = _Provider()
        ..nextIntent = const AttendanceIntent(
          action: AttendanceAction.queryVehicleAnnualRepair,
          yearReference: YearReference.current,
        );
      final vehicles = _VehiclePort();
      final controller = AssistantController(
        provider: provider,
        attendance: _AttendancePort(),
        vehicles: vehicles,
        clock: () => DateTime(2026, 10, 18),
      );

      await controller.submit('查维修费用');
      expect(controller.state.messages.last.text, '要查哪辆车？');
      provider.nextIntent = const AttendanceIntent(
        action: AttendanceAction.allVehicles,
        allVehicles: true,
        yearReference: YearReference.current,
      );
      await controller.submit('今年全车维修费排名');

      expect(provider.parseCount, 2);
      expect(vehicles.rankingQueries.single.year, 2026);
      expect(controller.state.messages.last.answer!.vehicleRanking, isNotNull);
    },
  );

  test(
    'a vehicle number reply still resolves the pending vehicle locally',
    () async {
      final provider = _Provider()
        ..nextIntent = const AttendanceIntent(
          action: AttendanceAction.queryVehicleAnnualRepair,
          yearReference: YearReference.current,
        );
      final vehicles = _VehiclePort();
      final controller = AssistantController(
        provider: provider,
        attendance: _AttendancePort(),
        vehicles: vehicles,
        clock: () => DateTime(2026, 10, 18),
      );

      await controller.submit('查维修费用');
      await controller.submit('V03');

      expect(provider.parseCount, 1);
      expect(vehicles.selectors.single.vehicleText, 'V03');
      expect(vehicles.readQueries.single.vehicle.vehicleId, 11);
    },
  );

  test(
    'a vehicle ranking task replaces a pending attendance person prompt',
    () async {
      final provider = _Provider()
        ..nextIntent = const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          yearReference: YearReference.current,
          month: 9,
        );
      final vehicles = _VehiclePort();
      final controller = AssistantController(
        provider: provider,
        attendance: _AttendancePort(),
        vehicles: vehicles,
        clock: () => DateTime(2026, 10, 18),
      );

      await controller.submit('查张三9月考勤');
      expect(controller.state.messages.last.text, '要查哪位人员？');
      provider.nextIntent = const AttendanceIntent(
        action: AttendanceAction.allVehicles,
        allVehicles: true,
        yearReference: YearReference.current,
      );
      await controller.submit('今年全车维修费排名');

      expect(provider.parseCount, 2);
      expect(vehicles.rankingQueries.single.year, 2026);
      expect(controller.state.messages.last.answer!.vehicleRanking, isNotNull);
    },
  );

  test(
    'ranking query formats locally and never requests model explanation',
    () async {
      final provider = _Provider()
        ..nextIntent = const AttendanceIntent(
          action: AttendanceAction.allVehicles,
          allVehicles: true,
          year: 2026,
          yearReference: YearReference.explicit,
        );
      final vehicles = _VehiclePort();
      final controller = AssistantController(
        provider: provider,
        attendance: _AttendancePort(),
        vehicles: vehicles,
        clock: () => DateTime(2026, 10, 18),
      );

      await controller.submit('查全部车辆2026年的维修费排名');

      expect(provider.parseCount, 1);
      expect(provider.explanationCount, 0);
      expect(vehicles.rankingQueries.single.year, 2026);
      expect(controller.state.messages.last.answer!.vehicleRanking, isNotNull);
      expect(controller.state.messages.last.text, contains('2026 年车辆维修费用排名'));
    },
  );

  test(
    'ranking pages are local and refresh invalidates old result references',
    () async {
      final provider = _Provider()
        ..nextIntent = const AttendanceIntent(
          action: AttendanceAction.allVehicles,
          allVehicles: true,
          year: 2025,
          yearReference: YearReference.explicit,
        );
      final vehicles = _VehiclePort()
        ..initialRankingPage = _rankingPage(
          resultRef: 'old-result',
          row: _rankingRow(vehicleId: 11, alias: 'V001', amountCents: 5000),
          hasMore: true,
          nextCursor: 'old-cursor',
        )
        ..nextRankingPage = _rankingPage(
          resultRef: 'old-result',
          row: _rankingRow(vehicleId: 22, alias: 'V002', amountCents: 1000),
        )
        ..refreshedRankingPage = _rankingPage(
          resultRef: 'fresh-result',
          row: _rankingRow(vehicleId: 22, alias: 'V001', amountCents: 9000),
        );
      final controller = AssistantController(
        provider: provider,
        attendance: _AttendancePort(),
        vehicles: vehicles,
        clock: () => DateTime(2026, 10, 18),
      );

      await controller.submit('查2025年全车维修费排名');
      final messageId = controller.state.messages.last.id.toString();
      expect(
        controller.state.messages.last.answer!.vehicleRanking!.resultRef,
        'old-result',
      );
      await controller.loadNextVehicleRankingPage('old-result', 'old-cursor');
      expect(vehicles.nextPageReadCount, 1);
      expect(
        controller.state.messages.last.answer!.vehicleRanking!.rows.map(
          (row) => row.vehicleId,
        ),
        [11, 22],
      );

      await controller.refreshResult(messageId);
      expect(vehicles.rankingReadCount, 2);
      expect(
        controller.state.messages.last.answer!.vehicleRanking!.resultRef,
        'fresh-result',
      );
      await controller.loadNextVehicleRankingPage('old-result', 'old-cursor');
      await controller.openRankedVehicle('old-result', 11);

      expect(vehicles.nextPageReadCount, 1);
      expect(vehicles.readQueries, isEmpty);
      expect(provider.parseCount, 1);
      expect(provider.explanationCount, 0);
    },
  );
}

VehicleRankingPage _rankingPage({
  required String resultRef,
  required VehicleRankingRow row,
  bool hasMore = false,
  String? nextCursor,
}) => VehicleRankingPage(
  resultRef: resultRef,
  year: 2025,
  queriedAt: DateTime(2026, 10, 18),
  rows: [row],
  totalVehicleCount: 2,
  returnedCount: hasMore ? 1 : 2,
  hasMore: hasMore,
  hasRepairRecords: true,
  nextCursor: nextCursor,
);

VehicleRankingRow _rankingRow({
  required int vehicleId,
  required String alias,
  required int amountCents,
}) => VehicleRankingRow(
  vehicleId: vehicleId,
  vehicleLabel: '测试车$vehicleId',
  vehicleNumber: 'T$vehicleId',
  rank: 1,
  completedRepairCount: 1,
  actualAmountCents: amountCents,
  alias: alias,
);

class _Provider implements AIProvider {
  AttendanceIntent nextIntent = const AttendanceIntent(
    action: AttendanceAction.queryVehicleAnnualRepair,
    yearReference: YearReference.unspecified,
  );
  Completer<AttendanceIntent>? pending;
  var parseCount = 0;
  var explanationCount = 0;

  @override
  Future<AttendanceIntent> parseIntent(
    IntentRequest request,
    RequestToken token,
  ) async {
    parseCount++;
    final currentPending = pending;
    if (currentPending != null) {
      pending = null;
      return currentPending.future;
    }
    return nextIntent;
  }

  @override
  Future<SummaryExplanation> explainSummary(
    AttendanceOutboundSummary summary,
    RequestToken token,
  ) async {
    explanationCount++;
    return const SummaryExplanation(text: 'model explanation');
  }

  @override
  Future<ConnectionCheck> checkConnection(RequestToken token) async =>
      const ConnectionCheck(success: true);
}

class _AttendancePort implements AttendanceReadPort {
  @override
  Future<EmployeeResolution> resolveEmployee(EmployeeSelector selector) async =>
      const EmployeeResolution(status: EmployeeResolutionStatus.notFound);

  @override
  Future<EmployeeResolution> resolveCandidate(String candidateRef) async =>
      const EmployeeResolution(status: EmployeeResolutionStatus.notFound);

  @override
  Future<AttendanceReadResult> readMonth(ResolvedAttendanceQuery query) async =>
      AttendanceReadResult(
        status: AttendanceReadStatus.failure,
        employeeLabel: '',
        yearMonth: query.yearMonth,
        queriedAt: DateTime(2026),
        completeness: AttendanceCompleteness.notEvaluated,
      );
}

class _VehiclePort implements VehicleReadPort {
  final selectors = <VehicleSelector>[];
  final readQueries = <ResolvedVehicleAnnualRepairQuery>[];
  final rankingQueries = <ResolvedVehicleRankingQuery>[];
  VehicleRankingPage? initialRankingPage;
  VehicleRankingPage? nextRankingPage;
  VehicleRankingPage? refreshedRankingPage;
  var rankingReadCount = 0;
  var nextPageReadCount = 0;

  @override
  Future<VehicleResolution> resolveVehicle(VehicleSelector selector) async {
    selectors.add(selector);
    final id = selector.vehicleId ?? 11;
    return VehicleResolution(
      status: VehicleResolutionStatus.unique,
      vehicle: ResolvedVehicle(
        vehicleId: id,
        label: id == 11 ? 'A车' : 'B车',
        vehicleNumber: id == 11 ? 'A01' : 'B02',
      ),
    );
  }

  @override
  Future<VehicleResolution> resolveVehicleCandidate(
    String candidateRef,
  ) async => const VehicleResolution(status: VehicleResolutionStatus.notFound);

  @override
  Future<VehicleAnnualRepairResult> readVehicleAnnualRepairs(
    ResolvedVehicleAnnualRepairQuery query,
  ) async {
    readQueries.add(query);
    return VehicleAnnualRepairResult(
      status: VehicleAnnualRepairReadStatus.success,
      vehicle: query.vehicle,
      year: query.year,
      queriedAt: DateTime(2026, 10, 18),
      completedRepairCount: 1,
      actualAmountCents: 12_300,
    );
  }

  @override
  Future<VehicleRankingPage> readAnnualVehicleRanking(
    ResolvedVehicleRankingQuery query,
  ) async {
    rankingQueries.add(query);
    rankingReadCount++;
    return (rankingReadCount == 1
            ? initialRankingPage
            : refreshedRankingPage) ??
        VehicleRankingPage(
          resultRef: 'ranking-ref',
          year: query.year,
          queriedAt: DateTime(2026, 10, 18),
          rows: [_rankingRow(vehicleId: 11, alias: 'V001', amountCents: 12000)],
          totalVehicleCount: 1,
          returnedCount: 1,
          hasMore: false,
          hasRepairRecords: true,
        );
  }

  @override
  Future<VehicleRankingPage> readNextVehicleRankingPage({
    required String resultRef,
    required String cursor,
  }) async {
    nextPageReadCount++;
    return nextRankingPage ?? (throw UnimplementedError());
  }
}
