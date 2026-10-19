import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/features/assistant/application/assistant_controller.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';

void main() {
  final fixedNow = DateTime(2026, 10, 18, 12);

  test('expense follow-ups preserve category and month through parsing and local tools', () async {
    final provider = _FakeAssistantProvider(
      parseResults: [
        const AttendanceIntent(
          action: AttendanceAction.queryVehicleExpenseAnalysis,
          vehicleText: '巡查车',
          expensePeriod: AssistantAgentPeriod.recent30Days,
        ),
        const AttendanceIntent(
          action: AttendanceAction.queryVehicleExpenseAnalysis,
          expenseCategory: VehicleExpenseCategoryScope.repair,
          expensePeriod: AssistantAgentPeriod.recent30Days,
        ),
        const AttendanceIntent(
          action: AttendanceAction.queryVehicleExpenseAnalysis,
          expenseCategory: VehicleExpenseCategoryScope.repair,
          expensePeriod: AssistantAgentPeriod.previousMonth,
          expenseYearMonth: '2026-09',
        ),
        const AttendanceIntent(
          action: AttendanceAction.queryVehicleExpenseAnalysis,
          expenseCategory: VehicleExpenseCategoryScope.repair,
          expensePeriod: AssistantAgentPeriod.previousMonth,
          expenseYearMonth: '2026-09',
        ),
      ],
      agentTurns: [
        _summaryTool(VehicleExpenseCategoryScope.all),
        _finalTurn,
        _summaryTool(VehicleExpenseCategoryScope.repair),
        _finalTurn,
        _summaryTool(
          VehicleExpenseCategoryScope.repair,
          period: AssistantAgentPeriod.previousMonth,
          yearMonth: '2026-09',
        ),
        _finalTurn,
        _peerTool(
          VehicleExpenseCategoryScope.repair,
          period: AssistantAgentPeriod.previousMonth,
          yearMonth: '2026-09',
        ),
        _finalTurn,
      ],
    );
    final vehicles = _FakeVehiclePort();
    final expenseReader = _FakeExpenseReader();
    final controller = _controller(provider, vehicles, expenseReader, fixedNow);

    await controller.submit('分析巡查车费用');
    await controller.submit('只看维修');
    await controller.submit('换上个月');
    await controller.submit('和同类车比呢');

    expect(provider.parseRequests, hasLength(4));
    expect(provider.parseRequests[0].previousExpenseCategory, isNull);
    expect(
      provider.parseRequests[1].previousExpenseCategory,
      VehicleExpenseCategoryScope.all,
    );
    expect(
      provider.parseRequests[1].previousExpensePeriod,
      AssistantAgentPeriod.recent30Days,
    );
    expect(
      provider.parseRequests[2].previousExpenseCategory,
      VehicleExpenseCategoryScope.repair,
    );
    expect(
      provider.parseRequests[2].previousExpensePeriod,
      AssistantAgentPeriod.recent30Days,
    );
    expect(
      provider.parseRequests[3].previousExpenseCategory,
      VehicleExpenseCategoryScope.repair,
    );
    expect(
      provider.parseRequests[3].previousExpensePeriod,
      AssistantAgentPeriod.previousMonth,
    );
    expect(provider.parseRequests[3].previousExpenseYearMonth, '2026-09');

    expect(
      expenseReader.readRequests.map(
        (request) => (request.scope, request.period, request.yearMonth),
      ),
      [
        (
          VehicleExpenseCategoryScope.all,
          AssistantAgentPeriod.recent30Days,
          null,
        ),
        (
          VehicleExpenseCategoryScope.repair,
          AssistantAgentPeriod.recent30Days,
          null,
        ),
        (
          VehicleExpenseCategoryScope.repair,
          AssistantAgentPeriod.previousMonth,
          '2026-09',
        ),
      ],
    );
    expect(expenseReader.peerRequests, hasLength(1));
    expect(
      expenseReader.peerRequests.single.scope,
      VehicleExpenseCategoryScope.repair,
    );
    expect(
      expenseReader.peerRequests.single.period,
      AssistantAgentPeriod.previousMonth,
    );
    expect(expenseReader.peerRequests.single.yearMonth, '2026-09');
    expect(
      controller.state.session.lastVehicleExpenseQuery?.scope,
      VehicleExpenseCategoryScope.repair,
    );
    expect(
      controller.state.session.lastVehicleExpenseQuery?.period,
      AssistantAgentPeriod.previousMonth,
    );
    expect(
      controller.state.session.lastVehicleExpenseQuery?.yearMonth,
      '2026-09',
    );
  });

  test('page vehicle is snapshotted for an in-flight parse and a later turn uses the new page', () async {
    final delayedParse = Completer<AttendanceIntent>();
    final provider = _FakeAssistantProvider(
      parseResults: [
        delayedParse,
        const AttendanceIntent(
          action: AttendanceAction.queryVehicleExpenseAnalysis,
        ),
      ],
      agentTurns: [
        _summaryTool(VehicleExpenseCategoryScope.all),
        _finalTurn,
        _summaryTool(VehicleExpenseCategoryScope.all),
        _finalTurn,
      ],
    );
    final vehicles = _FakeVehiclePort();
    final expenseReader = _FakeExpenseReader();
    final controller = _controller(provider, vehicles, expenseReader, fixedNow);

    controller.updatePageContext(_vehiclePage(11));
    final inFlight = controller.submit('分析这辆车的费用');
    await provider.parseStarted.future;
    controller.updatePageContext(_vehiclePage(22));
    delayedParse.complete(
      const AttendanceIntent(
        action: AttendanceAction.queryVehicleExpenseAnalysis,
      ),
    );
    await inFlight;
    await controller.submit('继续分析这辆车费用');

    expect(vehicles.selectors.map((selector) => selector.vehicleId), [11, 22]);
    expect(expenseReader.readRequests.map((request) => request.vehicleId), [
      11,
      22,
    ]);
    expect(provider.parseRequests[0].hasPageVehicle, isTrue);
    expect(provider.parseRequests[0].pageVehicleYear, 2025);
    expect(provider.parseRequests[1].hasPageVehicle, isTrue);
    expect(provider.parseRequests[1].pageVehicleYear, 2024);
  });

  test('stopping after a tool keeps facts and query context without another tool call', () async {
    final provider = _FakeAssistantProvider(
      parseResults: [
        const AttendanceIntent(
          action: AttendanceAction.queryVehicleExpenseAnalysis,
          vehicleText: '巡查车',
        ),
        const AttendanceIntent(
          action: AttendanceAction.queryVehicleExpenseAnalysis,
          expenseCategory: VehicleExpenseCategoryScope.repair,
          expensePeriod: AssistantAgentPeriod.recent30Days,
        ),
      ],
      agentTurns: [
        _summaryTool(VehicleExpenseCategoryScope.all),
        _finalTurn,
        _summaryTool(VehicleExpenseCategoryScope.repair),
        _finalTurn,
      ],
      blockAgentCall: 2,
    );
    final vehicles = _FakeVehiclePort();
    final expenseReader = _FakeExpenseReader();
    final controller = _controller(provider, vehicles, expenseReader, fixedNow);

    final inFlight = controller.submit('分析巡查车费用');
    await provider.blockedAgentCallStarted.future;
    controller.cancelCurrentTask();
    provider.releaseBlockedAgentCall.complete();
    await inFlight;

    final analysis = controller.state.messages
        .map((message) => message.answer?.vehicleExpenseAnalysis)
        .whereType<VehicleExpenseAnalysisAnswer>()
        .last;
    expect(analysis.stopped, isTrue);
    expect(analysis.periods, hasLength(1));
    expect(analysis.periods.single.categories.single.amountCents, 123400);
    expect(analysis.executedTools, [
      AssistantAgentToolName.summarizeVehicleExpenses,
    ]);
    expect(expenseReader.readRequests, hasLength(1));
    expect(expenseReader.peerRequests, isEmpty);
    expect(provider.agentCallCount, 2);
    expect(
      controller.state.session.lastVehicleExpenseQuery?.scope,
      VehicleExpenseCategoryScope.all,
    );
    expect(
      controller.state.session.lastVehicleExpenseQuery?.period,
      AssistantAgentPeriod.recent30Days,
    );
    await controller.submit('只看维修');
    expect(provider.parseRequests, hasLength(2));
    expect(
      provider.parseRequests.last.previousExpenseCategory,
      VehicleExpenseCategoryScope.all,
    );
    expect(expenseReader.readRequests, hasLength(2));
    expect(expenseReader.readRequests.last.vehicleId, 42);
    expect(
      expenseReader.readRequests.last.scope,
      VehicleExpenseCategoryScope.repair,
    );
  });

  test(
    'vehicle candidate selection resumes the original expense task',
    () async {
      final provider = _FakeAssistantProvider(
        parseResults: [
          const AttendanceIntent(
            action: AttendanceAction.queryVehicleExpenseAnalysis,
            vehicleText: '重名车辆',
            expenseCategory: VehicleExpenseCategoryScope.repair,
            expensePeriod: AssistantAgentPeriod.previousMonth,
            expenseYearMonth: '2026-09',
          ),
        ],
        agentTurns: [
          _summaryTool(
            VehicleExpenseCategoryScope.repair,
            period: AssistantAgentPeriod.previousMonth,
            yearMonth: '2026-09',
          ),
          _finalTurn,
        ],
      );
      final vehicles = _FakeVehiclePort(returnCandidates: true);
      final expenseReader = _FakeExpenseReader();
      final controller = _controller(
        provider,
        vehicles,
        expenseReader,
        fixedNow,
      );

      await controller.submit('分析重名车辆上个月维修费用');
      expect(controller.state.messages.last.vehicleCandidates, hasLength(2));
      await controller.selectCandidate('vehicle-candidate-22');

      expect(provider.parseRequests, hasLength(1));
      expect(vehicles.candidateRefs, ['vehicle-candidate-22']);
      expect(expenseReader.readRequests, hasLength(1));
      expect(expenseReader.readRequests.single.vehicleId, 22);
      expect(
        expenseReader.readRequests.single.scope,
        VehicleExpenseCategoryScope.repair,
      );
      expect(
        expenseReader.readRequests.single.period,
        AssistantAgentPeriod.previousMonth,
      );
      expect(expenseReader.readRequests.single.yearMonth, '2026-09');
      expect(provider.agentUserTexts, hasLength(2));
      expect(provider.agentUserTexts.toSet(), {'分析重名车辆上个月维修费用'});
      expect(provider.agentCallCount, 2);
    },
  );
}

AssistantController _controller(
  _FakeAssistantProvider provider,
  _FakeVehiclePort vehicles,
  _FakeExpenseReader expenseReader,
  DateTime now,
) => AssistantController(
  provider: provider,
  attendance: _UnusedAttendancePort(),
  vehicles: vehicles,
  expenseReader: expenseReader,
  clock: () => now,
);

AssistantPageContext _vehiclePage(int vehicleId) => AssistantPageContext(
  module: 'vehicles',
  page: 'vehicle-detail',
  vehicleId: vehicleId,
  year: vehicleId == 11 ? 2025 : 2024,
);

AssistantAgentTurn get _finalTurn =>
    const AssistantAgentTurn(text: '已根据本地汇总完成分析。');

AssistantAgentTurn _summaryTool(
  VehicleExpenseCategoryScope scope, {
  AssistantAgentPeriod period = AssistantAgentPeriod.recent30Days,
  String? yearMonth,
}) => AssistantAgentTurn(
  toolCalls: [
    AssistantAgentToolCall(
      id: 'summary-${scope.name}-${period.name}-${yearMonth ?? 'default'}',
      name: AssistantAgentToolName.summarizeVehicleExpenses,
      arguments: {
        'period': period.name,
        'scope': scope.name,
        ...?(yearMonth == null ? null : {'yearMonth': yearMonth}),
      },
    ),
  ],
);

AssistantAgentTurn _peerTool(
  VehicleExpenseCategoryScope scope, {
  AssistantAgentPeriod period = AssistantAgentPeriod.recent30Days,
  String? yearMonth,
}) => AssistantAgentTurn(
  toolCalls: [
    AssistantAgentToolCall(
      id: 'peer-${scope.name}-${period.name}-${yearMonth ?? 'default'}',
      name: AssistantAgentToolName.comparePeerVehicleExpenses,
      arguments: {
        'period': period.name,
        'scope': scope.name,
        ...?(yearMonth == null ? null : {'yearMonth': yearMonth}),
      },
    ),
  ],
);

class _FakeAssistantProvider
    implements AIProvider, VehicleExpenseAgentProvider {
  _FakeAssistantProvider({
    required Iterable<Object> parseResults,
    required Iterable<AssistantAgentTurn> agentTurns,
    this.blockAgentCall,
  }) : _parseResults = Queue<Object>.of(parseResults),
       _agentTurns = Queue<AssistantAgentTurn>.of(agentTurns);

  final Queue<Object> _parseResults;
  final Queue<AssistantAgentTurn> _agentTurns;
  final int? blockAgentCall;
  final parseRequests = <IntentRequest>[];
  final agentUserTexts = <String?>[];
  final parseStarted = Completer<void>();
  final blockedAgentCallStarted = Completer<void>();
  final releaseBlockedAgentCall = Completer<void>();
  var agentCallCount = 0;

  @override
  Future<AttendanceIntent> parseIntent(
    IntentRequest request,
    RequestToken token,
  ) async {
    parseRequests.add(request);
    if (!parseStarted.isCompleted) parseStarted.complete();
    final next = _parseResults.removeFirst();
    if (next is Completer<AttendanceIntent>) return next.future;
    return next as AttendanceIntent;
  }

  @override
  Future<AssistantAgentTurn> completeAgentTurn(
    List<AssistantAgentMessage> messages,
    RequestToken token,
  ) async {
    agentCallCount++;
    agentUserTexts.add(
      messages.where((message) => message.role == 'user').firstOrNull?.content,
    );
    if (agentCallCount == blockAgentCall) {
      if (!blockedAgentCallStarted.isCompleted) {
        blockedAgentCallStarted.complete();
      }
      await releaseBlockedAgentCall.future;
    }
    return _agentTurns.removeFirst();
  }

  @override
  Future<SummaryExplanation> explainSummary(
    AttendanceOutboundSummary summary,
    RequestToken token,
  ) async => const SummaryExplanation(text: '本地摘要说明');

  @override
  Future<ConnectionCheck> checkConnection(RequestToken token) async =>
      const ConnectionCheck(success: true);
}

class _UnusedAttendancePort implements AttendanceReadPort {
  @override
  Future<EmployeeResolution> resolveEmployee(EmployeeSelector selector) =>
      throw UnimplementedError();

  @override
  Future<EmployeeResolution> resolveCandidate(String candidateRef) =>
      throw UnimplementedError();

  @override
  Future<AttendanceReadResult> readMonth(ResolvedAttendanceQuery query) =>
      throw UnimplementedError();
}

class _FakeVehiclePort implements VehicleReadPort {
  _FakeVehiclePort({this.returnCandidates = false});

  final bool returnCandidates;
  final selectors = <VehicleSelector>[];
  final candidateRefs = <String>[];
  final annualQueries = <ResolvedVehicleAnnualRepairQuery>[];
  final rankingQueries = <ResolvedVehicleRankingQuery>[];

  @override
  Future<VehicleResolution> resolveVehicle(VehicleSelector selector) async {
    selectors.add(selector);
    if (returnCandidates) {
      return const VehicleResolution(
        status: VehicleResolutionStatus.candidates,
        candidates: [
          VehicleCandidate(
            candidateRef: 'vehicle-candidate-11',
            vehicleId: 11,
            label: '重名车辆甲',
            vehicleNumber: 'A-11',
          ),
          VehicleCandidate(
            candidateRef: 'vehicle-candidate-22',
            vehicleId: 22,
            label: '重名车辆乙',
            vehicleNumber: 'B-22',
          ),
        ],
      );
    }
    final id = selector.vehicleId ?? 42;
    return VehicleResolution(
      status: VehicleResolutionStatus.unique,
      vehicle: ResolvedVehicle(
        vehicleId: id,
        label: '测试车辆$id',
        vehicleNumber: 'TEST-$id',
      ),
    );
  }

  @override
  Future<VehicleResolution> resolveVehicleCandidate(String candidateRef) async {
    candidateRefs.add(candidateRef);
    final id = candidateRef.endsWith('22') ? 22 : 11;
    return VehicleResolution(
      status: VehicleResolutionStatus.unique,
      vehicle: ResolvedVehicle(
        vehicleId: id,
        label: '重名车辆${id == 22 ? '乙' : '甲'}',
        vehicleNumber: 'TEST-$id',
      ),
    );
  }

  @override
  Future<VehicleAnnualRepairResult> readVehicleAnnualRepairs(
    ResolvedVehicleAnnualRepairQuery query,
  ) async {
    annualQueries.add(query);
    throw UnimplementedError();
  }

  @override
  Future<VehicleRankingPage> readAnnualVehicleRanking(
    ResolvedVehicleRankingQuery query,
  ) async {
    rankingQueries.add(query);
    throw UnimplementedError();
  }

  @override
  Future<VehicleRankingPage> readNextVehicleRankingPage({
    required String resultRef,
    required String cursor,
  }) => throw UnimplementedError();
}

class _FakeExpenseReader implements VehicleExpenseReadPort {
  final readRequests = <VehicleExpenseToolRequest>[];
  final peerRequests = <VehicleExpenseToolRequest>[];

  @override
  Future<VehicleExpensePeriodResult> readVehicleExpenses(
    VehicleExpenseToolRequest request,
  ) async {
    readRequests.add(request);
    return _periodResult(request);
  }

  @override
  Future<VehicleExpensePeerResult> comparePeerVehicleExpenses(
    VehicleExpenseToolRequest request,
  ) async {
    peerRequests.add(request);
    return VehicleExpensePeerResult(
      period: _periodResult(request),
      category: request.scope,
      comparableVehicleCount: 2,
      peerAmountCents: 80000,
      targetAmountCents: 123400,
      comparability: VehicleExpenseCoverage.partial,
      note: '仅用于session流程测试。',
    );
  }

  VehicleExpensePeriodResult _periodResult(VehicleExpenseToolRequest request) {
    final month = request.yearMonth == null
        ? DateTime(2026, 9)
        : DateTime.parse('${request.yearMonth}-01');
    final end = DateTime(month.year, month.month + 1);
    return VehicleExpensePeriodResult(
      startInclusive: month,
      endExclusive: end,
      granularity: request.scope == VehicleExpenseCategoryScope.fuel
          ? VehicleExpenseGranularity.monthly
          : VehicleExpenseGranularity.daily,
      coverage: VehicleExpenseCoverage.partial,
      categories: [
        VehicleExpenseCategoryResult(
          category: request.scope,
          amountCents: 123400,
          recordCount: 2,
          coverage: VehicleExpenseCoverage.unknown,
        ),
      ],
      coverageNotes: const ['油费按月登记，缺失月份不按零费用处理。'],
    );
  }
}
