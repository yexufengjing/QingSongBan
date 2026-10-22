import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/app/theme/app_theme.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';
import 'package:qingsongban/features/assistant/presentation/assistant_result_content.dart';

void main() {
  testWidgets(
    'payroll shows scope, exact metrics and separate issues before source details',
    (tester) async {
      final opened = <String>[];
      await _pump(tester, _payroll(), onOpen: opened.add);
      expect(find.text('工资查询 · 2026-10'), findsOneWidget);
      expect(find.text('周启明 · TEST-901'), findsOneWidget);
      expect(find.text('4,500.25'), findsOneWidget);
      expect(find.text('待核对 2 项'), findsOneWidget);
      expect(find.text('月度考勤汇总尚未确认，不能确认工资'), findsOneWidget);
      expect(find.text('考勤汇总在工资生成后发生变化，请先同步最新考勤'), findsOneWidget);
      expect(find.text('完整的计算说明，默认收起。'), findsNothing);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('assistant_metric_已登记实发合计')))
            .dy,
        lessThan(tester.getTopLeft(find.text('工资待核对')).dy),
      );
      // The primary and warning sources are identical: render one source action.
      expect(find.text('查看工资明细'), findsNothing);
      await tester.ensureVisible(find.text('查看工资待核对来源'));
      await tester.tap(find.text('查看工资待核对来源'));
      expect(opened, ['/reports/payroll']);
      await tester.ensureVisible(find.text('口径与来源'));
      await tester.tap(find.text('口径与来源'));
      await tester.pumpAndSettle();
      expect(find.text('完整的计算说明，默认收起。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing records are explicit instead of implying a zero salary',
    (tester) async {
      final result = AssistantBusinessReadResult(
        domain: AssistantBusinessType.payroll,
        title: '工资查询 · 2026-10',
        summary: '已匹配记录合计为零。',
        queriedAt: DateTime(2026, 10, 22),
        sourceRule: 'test',
        sourcePage: '/reports/payroll',
        emptyMessage: '没有匹配的工资明细，不代表该人员工资为零。',
        metrics: const [
          AssistantResultMetric(label: '匹配工资人数', value: '0', unit: '人'),
        ],
      );
      await _pump(tester, result);
      expect(find.text('没有匹配的工资明细，不代表该人员工资为零。'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'requested result explanation remains visible after a refresh of the card',
    (tester) async {
      await _pump(tester, _payroll(), explanation: '基本工资 4000 元，加补贴 500.25 元。');
      expect(find.text('结果说明'), findsOneWidget);
      expect(find.text('基本工资 4000 元，加补贴 500.25 元。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 720),
    const Size(375, 812),
    const Size(844, 390),
    const Size(768, 1024),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('result adapts without truncation at $size text $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _pump(tester, _payroll(amount: '123,456,789.25'), scale: scale);
        final number = find.text('123,456,789.25');
        expect(number, findsOneWidget);
        final text = tester.widget<Text>(number);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(tester.getTopLeft(number).dx, greaterThanOrEqualTo(0));
        expect(tester.getBottomRight(number).dx, lessThanOrEqualTo(size.width));
        await tester.ensureVisible(find.text('查看工资待核对来源'));
        expect(
          tester.getSize(find.widgetWithText(TextButton, '查看工资待核对来源')).height,
          greaterThanOrEqualTo(48),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}

AssistantBusinessReadResult _payroll({String amount = '4,500.25'}) =>
    AssistantBusinessReadResult(
      domain: AssistantBusinessType.payroll,
      title: '工资查询 · 2026-10',
      scopeLabel: '周启明 · TEST-901',
      summary: '完整的计算说明，默认收起。',
      queriedAt: DateTime(2026, 10, 22),
      sourceRule: 'test',
      sourcePage: '/reports/payroll',
      metrics: [
        AssistantResultMetric(label: '已登记实发合计', value: amount, unit: '元'),
        const AssistantResultMetric(label: '匹配工资人数', value: '1', unit: '人'),
      ],
      facts: const [
        AssistantBusinessFact(
          label: '工资待核对',
          value: '完整的校验说明',
          isWarning: true,
          details: ['月度考勤汇总尚未确认，不能确认工资', '考勤汇总在工资生成后发生变化，请先同步最新考勤'],
          sourcePage: '/reports/payroll',
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester,
  AssistantBusinessReadResult result, {
  ValueChanged<String>? onOpen,
  double scale = 1,
  String? explanation,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Material(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AssistantBusinessResultContent(
                  result: result,
                  explanation: explanation,
                  ruleLabel: '按本地工资明细累计。',
                  onOpenSource: onOpen ?? (_) {},
                  onRefresh: () {},
                  onExplain: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
