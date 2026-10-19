import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qingsongban/features/assistant/application/assistant_providers.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';
import 'package:qingsongban/features/assistant/presentation/assistant_page.dart';

void main() {
  testWidgets('agent progress is brief and can be stopped', (tester) async {
    final controller = _ExpenseProbeNotifier(busy: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantControllerProvider.overrideWith(() => controller),
          assistantKeyConfiguredProvider.overrideWith((ref) async => true),
        ],
        child: const MaterialApp(home: AssistantPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('正在对比前后费用'), findsOneWidget);
    await tester.tap(find.text('停止'));
    await tester.pump();

    expect(controller.cancelCalls, 1);
  });

  testWidgets('stopped analysis explains retained evidence', (tester) async {
    await _pump(tester, _ExpenseProbeNotifier(stopped: true));
    expect(find.text('已停止查询；以下依据只包含停止前已查到的事实。'), findsOneWidget);
    expect(find.textContaining('贡献净增长 82.0%'), findsOneWidget);
  });

  testWidgets('failed analysis explains retained evidence', (tester) async {
    await _pump(
      tester,
      _ExpenseProbeNotifier(failure: AssistantErrorCode.timeout),
    );
    expect(find.text('分析未完整完成（请求超时）；以下为已取得的依据。'), findsOneWidget);
    expect(find.textContaining('贡献净增长 82.0%'), findsOneWidget);
  });

  testWidgets('short vehicle follow-ups are submitted directly', (
    tester,
  ) async {
    final controller = _ExpenseProbeNotifier();
    await _pump(tester, controller);

    for (final prompt in ['只看维修', '换上个月', '和同类车比呢']) {
      await tester.enterText(
        find.byKey(const Key('assistant-composer-input')),
        prompt,
      );
      await tester.tap(find.byTooltip('发送'));
      await tester.pump();
    }

    expect(controller.submitted, ['只看维修', '换上个月', '和同类车比呢']);
    expect(find.text('选择费用类别'), findsNothing);
    expect(find.text('选择查询月份'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(390, 840), Size(320, 720)]) {
    testWidgets(
      'expense evidence fits at ${size.width.toInt()}dp and source return keeps answer',
      (tester) async {
        final controller = _ExpenseProbeNotifier();
        tester.view.physicalSize = Size(size.width * 2, size.height * 2);
        tester.view.devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final router = GoRouter(
          initialLocation: '/assistant',
          routes: [
            GoRoute(
              path: '/assistant',
              builder: (_, _) => const AssistantPage(),
            ),
            GoRoute(
              path: '/vehicles/:vehicleId',
              builder: (_, state) => Scaffold(
                body: Text(
                  '车辆来源页 ${state.pathParameters['vehicleId']} ${state.uri}',
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              assistantControllerProvider.overrideWith(() => controller),
              assistantKeyConfiguredProvider.overrideWith((ref) async => true),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('按日统计：2026-09-19 至 2026-10-18 · 部分登记'),
          findsOneWidget,
        );
        expect(find.textContaining('维修'), findsWidgets);
        expect(find.textContaining('贡献净增长 82.0%'), findsOneWidget);
        expect(find.textContaining('本车 ¥0.50 元/公里'), findsOneWidget);
        expect(find.textContaining('比同类高100.0%'), findsOneWidget);
        expect(find.textContaining('维修：'), findsNothing);
        expect(find.textContaining('油费：¥1230.00 · 1 笔'), findsNothing);
        expect(find.text('直接说你的需求…'), findsOneWidget);
        expect(find.textContaining('未登记的零行依据'), findsNothing);
        expect(find.textContaining('详细规则说明不应默认显示'), findsNothing);
        expect(find.textContaining('其他手工费用'), findsNothing);
        expect(find.text('查看分析依据'), findsOneWidget);
        expect(find.textContaining('本地费用工具计算'), findsNothing);
        expect(find.textContaining('/vehicles/42'), findsNothing);
        expect(find.textContaining('vehicle_expense_tab'), findsNothing);
        expect(find.textContaining('油费按月登记'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.text('查看分析依据'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('查看分析依据'));
        await tester.pumpAndSettle();
        expect(find.textContaining('维修：'), findsOneWidget);
        expect(find.textContaining('油费：¥1230.00 · 1 笔'), findsOneWidget);
        expect(find.textContaining('里程、工作日和工时均未登记'), findsOneWidget);
        expect(find.textContaining('本地费用工具计算'), findsNothing);
        expect(find.textContaining('同类登记均值：¥2000.00'), findsOneWidget);
        expect(find.textContaining('同期台账登记完整性未知'), findsOneWidget);
        expect(find.textContaining('未登记的零行依据'), findsOneWidget);
        expect(find.textContaining('详细规则说明不应默认显示'), findsOneWidget);
        expect(find.textContaining('第四条超出默认关键依据上限'), findsOneWidget);

        await tester.ensureVisible(find.text('打开车辆费用页面'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('打开车辆费用页面'));
        await tester.pumpAndSettle();
        expect(
          find.text('车辆来源页 42 /vehicles/42?tab=expense&expenseYear=2026'),
          findsOneWidget,
        );

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/assistant');
        expect(
          controller.state.messages.where(
            (message) => message.answer?.vehicleExpenseAnalysis != null,
          ),
          hasLength(1),
        );
        expect(controller.submitted, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  _ExpenseProbeNotifier controller,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        assistantControllerProvider.overrideWith(() => controller),
        assistantKeyConfiguredProvider.overrideWith((ref) async => true),
      ],
      child: const MaterialApp(home: AssistantPage()),
    ),
  );
  await tester.pumpAndSettle();
}

class _ExpenseProbeNotifier extends AssistantSessionNotifier {
  _ExpenseProbeNotifier({
    this.busy = false,
    this.stopped = false,
    this.failure,
  });

  final bool busy;
  final bool stopped;
  final AssistantErrorCode? failure;
  final submitted = <String>[];
  var cancelCalls = 0;

  @override
  AssistantState build() => AssistantState(
    phase: busy ? AssistantTurnPhase.reading : AssistantTurnPhase.idle,
    agentProgress: busy ? '正在对比前后费用' : null,
    messages: [
      AssistantMessage(
        id: 1,
        text: '当前费用高于前期，维修贡献了主要增量。',
        isUser: false,
        resultRef: 'expense-result-1',
        answer: AssistantAnswer(
          text: '当前费用高于前期，维修贡献了主要增量。',
          employeeLabel: '',
          yearMonth: '',
          queriedAt: DateTime(2026, 10, 18),
          completeness: AttendanceCompleteness.notEvaluated,
          yearMonthSource: AssistantFieldSource.none,
          vehicleExpenseAnalysis: VehicleExpenseAnalysisAnswer(
            vehicleId: 42,
            vehicleLabel: '示例车辆',
            resultRef: 'expense-result-1',
            summaryText: '当前费用高于前期，维修贡献了主要增量。',
            periods: [
              VehicleExpensePeriodResult(
                startInclusive: DateTime(2026, 9, 19),
                endExclusive: DateTime(2026, 10, 19),
                granularity: VehicleExpenseGranularity.daily,
                coverage: VehicleExpenseCoverage.partial,
                categories: [
                  VehicleExpenseCategoryResult(
                    category: VehicleExpenseCategoryScope.repair,
                    amountCents: 456700,
                    recordCount: 4,
                    coverage: VehicleExpenseCoverage.partial,
                  ),
                  VehicleExpenseCategoryResult(
                    category: VehicleExpenseCategoryScope.fuel,
                    amountCents: 123000,
                    recordCount: 1,
                    coverage: VehicleExpenseCoverage.unknown,
                  ),
                ],
                fuelMonths: [
                  VehicleFuelMonthResult(
                    year: 2026,
                    month: 10,
                    amountCents: 123000,
                    liters: 150.5,
                    coverage: VehicleExpenseCoverage.unknown,
                  ),
                ],
                workload: VehicleExpenseWorkload(
                  coverage: VehicleExpenseCoverage.unknown,
                ),
                coverageNotes: ['油费按月登记，本期不作日级折算。'],
              ),
            ],
            evidence: [
              VehicleExpenseEvidence(
                label: 'repair',
                amountCents: 456700,
                recordCount: 4,
                previousAmountCents: 180000,
                deltaCents: 276700,
                contributionBasis: '按本地维修费用登记变化计算。',
                contributionPercent: 82,
              ),
              VehicleExpenseEvidence(
                label: 'maintenance',
                amountCents: 0,
                recordCount: 0,
                previousAmountCents: 0,
                deltaCents: 0,
                contributionBasis: '未登记的零行依据；详细规则说明不应默认显示。',
              ),
              VehicleExpenseEvidence(
                label: 'fuel',
                amountCents: 123000,
                recordCount: 1,
                previousAmountCents: 90000,
                deltaCents: 33000,
                contributionBasis: '油费按月台账记录变化。',
              ),
              VehicleExpenseEvidence(
                label: 'maintenance',
                amountCents: 0,
                recordCount: 0,
                previousAmountCents: 5000,
                deltaCents: -5000,
                contributionBasis: '历史有登记的变化。',
              ),
              VehicleExpenseEvidence(
                label: 'manual',
                amountCents: 3000,
                recordCount: 1,
                previousAmountCents: 0,
                deltaCents: 3000,
                contributionBasis: '第四条超出默认关键依据上限。',
              ),
            ],
            peerComparisons: [
              VehicleExpensePeerResult(
                period: VehicleExpensePeriodResult(
                  startInclusive: DateTime(2026, 9, 19),
                  endExclusive: DateTime(2026, 10, 19),
                  granularity: VehicleExpenseGranularity.daily,
                  coverage: VehicleExpenseCoverage.partial,
                  categories: const [],
                  fuelMonths: const [],
                  coverageNotes: const [],
                ),
                category: VehicleExpenseCategoryScope.repair,
                comparableVehicleCount: 3,
                peerAmountCents: 200000,
                targetAmountCents: 456700,
                comparability: VehicleExpenseCoverage.partial,
                note: '同期台账登记完整性未知。',
                metricUnit: VehicleExpenseWorkloadMetric.mileage,
                targetUnitCost: 50,
                peerUnitCost: 25,
              ),
            ],
            sourceRule: '本地费用工具计算',
            sourcePage: 'vehicle_expense_tab',
            stopped: stopped,
            failure: failure,
          ),
        ),
      ),
    ],
  );

  @override
  void updatePageContext(AssistantPageContext? context) {}

  @override
  Future<void> submit(String utterance) async {
    submitted.add(utterance);
  }

  @override
  void cancelCurrentTask() => cancelCalls++;
}
