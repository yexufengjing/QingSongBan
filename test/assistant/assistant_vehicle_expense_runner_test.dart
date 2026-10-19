import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/features/assistant/application/assistant_vehicle_expense_runner.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';

void main() {
  group('AssistantVehicleExpenseRunner', () {
    test(
      'chooses a driver inspection after reading the first aggregate',
      () async {
        final reader = _FakeReader();
        final provider = _AdaptiveProvider((messages) {
          if (messages.last.role == 'user') {
            return _call(
              'summary-1',
              AssistantAgentToolName.summarizeVehicleExpenses,
              {'period': 'recent30Days', 'scope': 'all'},
            );
          }
          final toolText = messages.last.content!;
          final alreadyInspected = messages.any(
            (message) => message.toolCalls.any(
              (call) =>
                  call.name ==
                  AssistantAgentToolName.inspectVehicleExpenseDrivers,
            ),
          );
          if (toolText.contains('250000') && !alreadyInspected) {
            return _call(
              'drivers-1',
              AssistantAgentToolName.inspectVehicleExpenseDrivers,
              {
                'period': 'recent30Days',
                'comparisonPeriod': 'previous30Days',
                'scope': 'all',
              },
            );
          }
          return const AssistantAgentTurn(text: '维修登记金额是主要变化来源。');
        });
        final result =
            await AssistantVehicleExpenseRunner(
              provider: provider,
              reader: reader,
              clock: () => DateTime(2026, 10, 18),
            ).run(
              utterance: '最近费用怎么变了？',
              vehicleId: 42,
              period: AssistantAgentPeriod.recent30Days,
              scope: VehicleExpenseCategoryScope.all,
              token: RequestToken(100),
            );

        expect(result.failure, isNull);
        expect(result.executedTools, [
          AssistantAgentToolName.summarizeVehicleExpenses,
          AssistantAgentToolName.inspectVehicleExpenseDrivers,
        ]);
        expect(result.toolCalls, 2);
        expect(provider.turnCount, 3);
        expect(reader.requests, hasLength(3));
        expect(reader.requests[1].period, AssistantAgentPeriod.recent30Days);
        expect(reader.requests[2].period, AssistantAgentPeriod.previous30Days);
        final repairEvidence = result.evidence.firstWhere(
          (evidence) => evidence.label == 'repair',
        );
        expect(repairEvidence.deltaCents, 150000);
        expect(repairEvidence.contributionPercent, 93.75);
        expect(
          result.evidence
              .firstWhere((evidence) => evidence.label == 'manual')
              .contributionPercent,
          6.25,
        );

        final inspectedMessages = provider.receivedMessages.last;
        expect(
          inspectedMessages.any((message) => message.role == 'tool'),
          isTrue,
        );
        expect(
          inspectedMessages.any(
            (message) =>
                message.role == 'assistant' &&
                message.toolCalls.isNotEmpty &&
                message.toolCalls.first.name ==
                    AssistantAgentToolName.summarizeVehicleExpenses,
          ),
          isTrue,
        );
      },
    );

    test(
      'ends after sufficient first result without a fixed follow-up tool',
      () async {
        final reader = _FakeReader();
        final provider = _AdaptiveProvider((messages) {
          if (messages.last.role == 'user') {
            return _call(
              'summary-early',
              AssistantAgentToolName.summarizeVehicleExpenses,
              {'period': 'recent30Days', 'scope': 'all'},
            );
          }
          expect(messages.last.role, 'tool');
          return const AssistantAgentTurn(text: '近期已读取登记汇总。');
        });

        final result =
            await AssistantVehicleExpenseRunner(
              provider: provider,
              reader: reader,
              clock: () => DateTime(2026, 10, 18),
            ).run(
              utterance: '看看最近费用',
              vehicleId: 42,
              period: AssistantAgentPeriod.recent30Days,
              scope: VehicleExpenseCategoryScope.all,
              token: RequestToken(101),
            );

        expect(result.failure, isNull);
        expect(result.executedTools, [
          AssistantAgentToolName.summarizeVehicleExpenses,
        ]);
        expect(result.toolCalls, 1);
        expect(provider.turnCount, 2);
        expect(reader.requests, hasLength(1));
      },
    );

    test(
      'normalizes previous month into consecutive calendar months',
      () async {
        final reader = _FakeReader();
        final provider = _AdaptiveProvider((messages) {
          if (messages.last.role == 'user') {
            return _call(
              'compare-month',
              AssistantAgentToolName.compareVehicleExpensePeriods,
              {
                'period': 'previousMonth',
                'comparisonPeriod': 'previousMonth',
                'scope': 'fuel',
              },
            );
          }
          return const AssistantAgentTurn(text: '油费只代表登记记录。');
        });

        await AssistantVehicleExpenseRunner(
          provider: provider,
          reader: reader,
          clock: () => DateTime(2026, 10, 18),
        ).run(
          utterance: '对比上个月油费',
          vehicleId: 42,
          period: AssistantAgentPeriod.previousMonth,
          scope: VehicleExpenseCategoryScope.fuel,
          token: RequestToken(102),
        );

        expect(reader.requests.map((request) => request.yearMonth), [
          '2026-09',
          '2026-08',
        ]);
      },
    );

    test('retains the first read when the user stops the task', () async {
      final reader = _FakeReader();
      final provider = _AdaptiveProvider((messages) {
        return _call(
          'summary-stop',
          AssistantAgentToolName.summarizeVehicleExpenses,
          {'period': 'recent30Days', 'scope': 'all'},
        );
      });
      final token = RequestToken(103);

      final result =
          await AssistantVehicleExpenseRunner(
            provider: provider,
            reader: reader,
            clock: () => DateTime(2026, 10, 18),
          ).run(
            utterance: '最近费用',
            vehicleId: 42,
            period: AssistantAgentPeriod.recent30Days,
            scope: VehicleExpenseCategoryScope.all,
            token: token,
            onPartial: (_) => token.cancel(),
          );

      expect(result.stopped, isTrue);
      expect(result.periods, hasLength(1));
      expect(result.executedTools, [
        AssistantAgentToolName.summarizeVehicleExpenses,
      ]);
    });

    test(
      'respects the shared model request budget and keeps read evidence',
      () async {
        final reader = _FakeReader();
        final provider = _AdaptiveProvider((messages) {
          if (messages.last.role == 'user') {
            return _call(
              'summary-budget',
              AssistantAgentToolName.summarizeVehicleExpenses,
              {'period': 'recent30Days', 'scope': 'all'},
            );
          }
          return const AssistantAgentTurn(text: '继续追查');
        });

        final result =
            await AssistantVehicleExpenseRunner(
              provider: provider,
              reader: reader,
              clock: () => DateTime(2026, 10, 18),
            ).run(
              utterance: '最近费用',
              vehicleId: 42,
              period: AssistantAgentPeriod.recent30Days,
              scope: VehicleExpenseCategoryScope.all,
              token: RequestToken(104),
              priorModelRequests: 5,
            );

        expect(provider.turnCount, 1);
        expect(result.failure, AssistantErrorCode.unsupported);
        expect(result.periods, hasLength(1));
        expect(result.executedTools, [
          AssistantAgentToolName.summarizeVehicleExpenses,
        ]);
      },
    );

    test(
      'enforces the overall deadline and retains completed local reads',
      () async {
        var now = DateTime(2026, 10, 18);
        final reader = _FakeReader(
          onRead: () => now = now.add(const Duration(seconds: 121)),
        );
        final provider = _AdaptiveProvider((messages) {
          return _call(
            'summary-timeout',
            AssistantAgentToolName.summarizeVehicleExpenses,
            {'period': 'recent30Days', 'scope': 'all'},
          );
        });

        final result =
            await AssistantVehicleExpenseRunner(
              provider: provider,
              reader: reader,
              clock: () => now,
            ).run(
              utterance: '最近费用',
              vehicleId: 42,
              period: AssistantAgentPeriod.recent30Days,
              scope: VehicleExpenseCategoryScope.all,
              token: RequestToken(105),
            );

        expect(result.failure, AssistantErrorCode.timeout);
        expect(result.periods, hasLength(1));
        expect(result.executedTools, [
          AssistantAgentToolName.summarizeVehicleExpenses,
        ]);
      },
    );

    test(
      'requires local evidence and discards model supplied numeric claims',
      () async {
        final reader = _FakeReader();
        final provider = _AdaptiveProvider((messages) {
          if (messages.last.role == 'user' &&
              messages.last.content!.contains('Use a read-only')) {
            return _call(
              'summary-grounding',
              AssistantAgentToolName.summarizeVehicleExpenses,
              {'period': 'recent30Days', 'scope': 'all'},
            );
          }
          if (messages.last.role == 'user') {
            return const AssistantAgentTurn(text: '这辆车增加500元。');
          }
          return const AssistantAgentTurn(text: '这辆车增加五百元。');
        });

        final result =
            await AssistantVehicleExpenseRunner(
              provider: provider,
              reader: reader,
              clock: () => DateTime(2026, 10, 18),
            ).run(
              utterance: '最近这车费钱吗？',
              vehicleId: 42,
              period: AssistantAgentPeriod.recent30Days,
              scope: VehicleExpenseCategoryScope.all,
              token: RequestToken(106),
            );

        expect(result.executedTools, [
          AssistantAgentToolName.summarizeVehicleExpenses,
        ]);
        expect(result.summaryText, isNot(contains('五百')));
        expect(result.summaryText, contains('具体金额'));
      },
    );
  });
}

AssistantAgentTurn _call(
  String id,
  AssistantAgentToolName name,
  Map<String, Object?> arguments,
) => AssistantAgentTurn(
  text: '准备执行本地聚合工具。',
  toolCalls: [AssistantAgentToolCall(id: id, name: name, arguments: arguments)],
);

class _AdaptiveProvider implements VehicleExpenseAgentProvider {
  _AdaptiveProvider(this.nextTurn);

  final AssistantAgentTurn Function(List<AssistantAgentMessage>) nextTurn;
  final receivedMessages = <List<AssistantAgentMessage>>[];

  int get turnCount => receivedMessages.length;

  @override
  Future<AssistantAgentTurn> completeAgentTurn(
    List<AssistantAgentMessage> messages,
    RequestToken token,
  ) async {
    receivedMessages.add(List.of(messages));
    return nextTurn(messages);
  }
}

class _FakeReader implements VehicleExpenseReadPort {
  _FakeReader({this.onRead});

  final void Function()? onRead;
  final requests = <VehicleExpenseToolRequest>[];

  @override
  Future<VehicleExpensePeriodResult> readVehicleExpenses(
    VehicleExpenseToolRequest request,
  ) async {
    requests.add(request);
    onRead?.call();
    final isCurrent = request.period == AssistantAgentPeriod.recent30Days;
    final isMonthly = request.yearMonth != null;
    return VehicleExpensePeriodResult(
      startInclusive: isMonthly
          ? DateTime.parse('${request.yearMonth}-01')
          : isCurrent
          ? DateTime(2026, 9, 19)
          : DateTime(2026, 8, 20),
      endExclusive: isMonthly
          ? DateTime(
              int.parse(request.yearMonth!.substring(0, 4)),
              int.parse(request.yearMonth!.substring(5, 7)) + 1,
            )
          : isCurrent
          ? DateTime(2026, 10, 19)
          : DateTime(2026, 9, 19),
      granularity: isMonthly
          ? VehicleExpenseGranularity.monthly
          : VehicleExpenseGranularity.daily,
      coverage: VehicleExpenseCoverage.partial,
      categories: [
        VehicleExpenseCategoryResult(
          category: VehicleExpenseCategoryScope.repair,
          amountCents: isCurrent ? 250000 : 100000,
          recordCount: 1,
          coverage: VehicleExpenseCoverage.partial,
        ),
        VehicleExpenseCategoryResult(
          category: VehicleExpenseCategoryScope.manual,
          amountCents: isCurrent ? 10000 : 0,
          recordCount: isCurrent ? 1 : 0,
          coverage: VehicleExpenseCoverage.partial,
        ),
      ],
    );
  }

  @override
  Future<VehicleExpensePeerResult> comparePeerVehicleExpenses(
    VehicleExpenseToolRequest request,
  ) async {
    requests.add(request);
    return VehicleExpensePeerResult(
      period: await readVehicleExpenses(request),
      category: request.scope,
      comparableVehicleCount: 0,
      peerAmountCents: null,
      targetAmountCents: null,
      comparability: VehicleExpenseCoverage.unknown,
    );
  }
}
