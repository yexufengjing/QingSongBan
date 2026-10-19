import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/assistant/application/assistant_providers.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';
import 'package:qingsongban/features/assistant/presentation/assistant_page.dart';
import 'package:qingsongban/features/assistant/presentation/assistant_settings_page.dart';
import 'package:qingsongban/features/attendance/presentation/monthly_attendance_table_page.dart';

void main() {
  testWidgets(
    'one submission returns a local answer and expands local details',
    (tester) async {
      final provider = _FakeAIProvider([
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          employeeText: '王敏',
          yearReference: YearReference.current,
          month: 9,
        ),
      ]);
      final attendance = _FakeAttendanceReadPort();
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpAssistant(tester, provider, attendance, textScale: 1.3);

      await tester.enterText(find.byType(TextField), '查王敏9月考勤');
      await tester.tap(find.byTooltip('发送'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('王敏在 ${DateTime.now().year} 年 09 月'),
        findsOneWidget,
      );
      expect(find.textContaining('出勤 20 天'), findsOneWidget);
      expect(provider.parseCalls, 1);
      expect(attendance.readCalls, 1);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('查看本地明细'));
      await tester.tap(find.text('查看本地明细'));
      await tester.pumpAndSettle();
      expect(find.textContaining('9/1  上午'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selecting a candidate continues directly without another parse',
    (tester) async {
      final provider = _FakeAIProvider([
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          employeeText: '重复姓名',
          yearReference: YearReference.current,
          month: 9,
        ),
      ]);
      final attendance = _FakeAttendanceReadPort(ambiguousNames: {'重复姓名'});
      await _pumpAssistant(tester, provider, attendance);

      await tester.enterText(find.byType(TextField), '查重复姓名9月考勤');
      await tester.tap(find.byTooltip('发送'));
      await tester.pumpAndSettle();
      expect(find.text('重复姓名 · 编号 1001 · 一组'), findsOneWidget);

      await tester.tap(find.text('重复姓名 · 编号 1001 · 一组'));
      await tester.pumpAndSettle();

      expect(find.textContaining('出勤 20 天'), findsOneWidget);
      expect(provider.parseCalls, 1);
      expect(attendance.candidateCalls, 1);
      expect(attendance.readCalls, 1);
    },
  );

  testWidgets('single employee candidate asks for confirmation', (
    tester,
  ) async {
    final provider = _FakeAIProvider([
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        employeeText: '确认姓名',
        yearReference: YearReference.current,
        month: 9,
      ),
    ]);
    final attendance = _FakeAttendanceReadPort(
      ambiguousNames: {'确认姓名'},
      candidateCount: 1,
    );
    await _pumpAssistant(tester, provider, attendance);

    await tester.enterText(find.byType(TextField), '查确认姓名9月考勤');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();

    expect(find.text('找到可能的人员，请确认。'), findsOneWidget);
    expect(find.text('确认姓名 · 编号 1001 · 一组'), findsOneWidget);
    expect(attendance.readCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'candidate selection scrolls the newest answer into view after a long session',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final intents = [
        for (var index = 0; index < 8; index++)
          AttendanceIntent(
            action: AttendanceAction.queryAttendance,
            employeeText: '历史人员$index',
            year: DateTime.now().year,
            month: 9,
            yearReference: YearReference.explicit,
          ),
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          employeeText: '重复姓名',
          yearReference: YearReference.current,
          month: 9,
        ),
      ];
      final provider = _FakeAIProvider(intents);
      final attendance = _FakeAttendanceReadPort(ambiguousNames: {'重复姓名'});
      await _pumpAssistant(tester, provider, attendance);

      for (var index = 0; index < 8; index++) {
        await tester.enterText(find.byType(TextField), '查询历史人员$index的9月考勤');
        await tester.tap(find.byTooltip('发送'));
        await tester.pumpAndSettle();
      }

      final details = find.text('查看本地明细').last;
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '查重复姓名9月考勤');
      await tester.tap(find.byTooltip('发送'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重复姓名 · 编号 1001 · 一组'));
      await tester.pumpAndSettle();

      expect(find.textContaining('重复姓名在').hitTestable(), findsOneWidget);
      expect(provider.parseCalls, 9);
      expect(attendance.readCalls, 9);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'local candidate reply scrolls into view after source-page round trip',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase.forTesting();
      final intents = [
        for (var index = 0; index < 8; index++)
          AttendanceIntent(
            action: AttendanceAction.queryAttendance,
            employeeText: '历史人员$index',
            year: DateTime.now().year,
            month: 9,
            yearReference: YearReference.explicit,
          ),
      ];
      final provider = _FakeAIProvider(intents);
      final attendance = _FakeAttendanceReadPort(ambiguousNames: {'李四'});
      final router = _assistantTestRouter();
      addTearDown(router.dispose);
      await _pumpAssistantRouter(
        tester,
        provider,
        attendance,
        keyStore: _FakeKeyStore(),
        router: router,
        database: database,
      );

      for (var index = 0; index < 8; index++) {
        await tester.enterText(find.byType(TextField), '查询历史人员$index的9月考勤');
        await tester.tap(find.byTooltip('发送'));
        await tester.pumpAndSettle();
      }

      final details = find.text('查看本地明细').last;
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('打开月考勤表').last);
      await tester.tap(find.text('打开月考勤表').last);
      await tester.pumpAndSettle();
      expect(find.text('月考勤表'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '那李四呢');
      await tester.tap(find.byTooltip('发送'));
      await tester.pumpAndSettle();

      expect(provider.parseCalls, 8);
      expect(find.text('找到多位可能的人员，请选择一位。'), findsOneWidget);
      expect(find.text('李四 · 编号 1001 · 一组').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await database.close();
    },
  );

  testWidgets('month clarification buttons continue the pending query', (
    tester,
  ) async {
    final provider = _FakeAIProvider([
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        employeeText: '王敏',
        yearReference: YearReference.current,
      ),
    ]);
    final attendance = _FakeAttendanceReadPort();
    await _pumpAssistant(tester, provider, attendance);

    await tester.enterText(find.byType(TextField), '查王敏考勤');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(find.text('查哪个月？'), findsOneWidget);

    await tester.tap(find.text('本月'));
    await tester.pumpAndSettle();

    expect(attendance.lastQuery?.yearMonth, _currentYearMonth());
    expect(find.textContaining('王敏在'), findsOneWidget);
    expect(provider.parseCalls, 1);
  });

  testWidgets('settings round trip preserves the answer and unsent draft', (
    tester,
  ) async {
    final provider = _FakeAIProvider([
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        employeeText: '王敏',
        yearReference: YearReference.current,
        month: 9,
      ),
    ]);
    final attendance = _FakeAttendanceReadPort();
    final keyStore = _FakeKeyStore();
    final router = _assistantTestRouter();
    addTearDown(router.dispose);
    await _pumpAssistantRouter(
      tester,
      provider,
      attendance,
      keyStore: keyStore,
      router: router,
    );

    await tester.enterText(find.byType(TextField), '查王敏9月考勤');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    final answerText = '王敏在 ${DateTime.now().year} 年 09 月';
    expect(find.textContaining(answerText), findsOneWidget);

    const draft = '这段草稿不应发送';
    await tester.enterText(find.byType(TextField), draft);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI 设置'));
    await tester.pumpAndSettle();
    expect(find.text('智能助手设置'), findsOneWidget);
    expect(provider.parseCalls, 1);
    expect(attendance.readCalls, 1);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('智能助手设置'), findsNothing);
    expect(find.textContaining(answerText), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      draft,
    );
    expect(provider.parseCalls, 1);
    expect(attendance.readCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving and removing a key refreshes the existing welcome page', (
    tester,
  ) async {
    final keyStore = _FakeKeyStore(value: null);
    final router = _assistantTestRouter();
    addTearDown(router.dispose);
    await _pumpAssistantRouter(
      tester,
      _FakeAIProvider([]),
      _FakeAttendanceReadPort(),
      keyStore: keyStore,
      router: router,
    );
    expect(find.text('需要先配置 DeepSeek API Key'), findsOneWidget);

    final keyPrompt = find.ancestor(
      of: find.text('需要先配置 DeepSeek API Key'),
      matching: find.byType(ListTile),
    );
    await tester.ensureVisible(keyPrompt);
    await tester.pumpAndSettle();
    await tester.tap(keyPrompt);
    await tester.pumpAndSettle();
    expect(find.text('智能助手设置'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'test-key-value');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(keyStore.value, 'test-key-value');
    expect(find.text('test-key-value'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('智能助手设置'), findsNothing);
    expect(find.text('需要先配置 DeepSeek API Key'), findsNothing);

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI 设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除 Key'));
    await tester.pumpAndSettle();
    expect(keyStore.value, isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('需要先配置 DeepSeek API Key'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'clearing a session preserves the API key and does not read again',
    (tester) async {
      final provider = _FakeAIProvider([
        const AttendanceIntent(
          action: AttendanceAction.queryAttendance,
          employeeText: '王敏',
          yearReference: YearReference.current,
          month: 9,
        ),
      ]);
      final attendance = _FakeAttendanceReadPort();
      final keyStore = _FakeKeyStore(value: 'retained-test-key');
      await _pumpAssistant(tester, provider, attendance, keyStore: keyStore);

      await tester.enterText(find.byType(TextField), '查王敏9月考勤');
      await tester.tap(find.byTooltip('发送'));
      await tester.pumpAndSettle();
      final readsBeforeClear = attendance.readCalls;
      final resolvesBeforeClear = attendance.resolveCalls;

      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清空当前对话'));
      await tester.pumpAndSettle();

      expect(find.text('查询常用业务信息'), findsOneWidget);
      expect(keyStore.value, 'retained-test-key');
      expect(keyStore.removeCalls, 0);
      expect(attendance.readCalls, readsBeforeClear);
      expect(attendance.resolveCalls, resolvesBeforeClear);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large keyboard insets keep the composer visible at 320dp', (
    tester,
  ) async {
    final provider = _FakeAIProvider([]);
    final attendance = _FakeAttendanceReadPort();
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpAssistant(
      tester,
      provider,
      attendance,
      textScale: 1.3,
      viewInsets: const EdgeInsets.only(bottom: 360),
    );

    final input = tester.getRect(find.byType(TextField));
    final send = tester.getRect(find.byTooltip('发送'));
    expect(input.top, greaterThanOrEqualTo(0));
    expect(input.bottom, lessThanOrEqualTo(360));
    expect(send.bottom, lessThanOrEqualTo(360));
    await tester.enterText(find.byType(TextField), '键盘遮挡检查');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '键盘遮挡检查',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('source action opens the month table with verified source data', (
    tester,
  ) async {
    final provider = _FakeAIProvider([
      const AttendanceIntent(
        action: AttendanceAction.queryAttendance,
        employeeText: '王敏',
        yearReference: YearReference.current,
        month: 9,
      ),
    ]);
    final attendance = _FakeAttendanceReadPort();
    final database = AppDatabase.forTesting();
    final router = GoRouter(
      initialLocation: '/assistant',
      routes: [
        GoRoute(path: '/assistant', builder: (_, _) => const AssistantPage()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          assistantAIProvider.overrideWithValue(provider),
          assistantAttendanceReaderProvider.overrideWithValue(attendance),
          assistantKeyStoreProvider.overrideWithValue(_FakeKeyStore()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '查王敏9月考勤');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('打开月考勤表'));
    await tester.tap(find.text('打开月考勤表'));
    await tester.pumpAndSettle();

    final tablePage = tester.widget<MonthlyAttendanceTablePage>(
      find.byType(MonthlyAttendanceTablePage),
    );
    expect(tablePage.initialMonth, DateTime(DateTime.now().year, 9));
    expect(tablePage.initialGroupId, 10);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await database.close();
  });
}

Future<void> _pumpAssistant(
  WidgetTester tester,
  _FakeAIProvider provider,
  _FakeAttendanceReadPort attendance, {
  double textScale = 1,
  EdgeInsets viewInsets = EdgeInsets.zero,
  _FakeKeyStore? keyStore,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        assistantAIProvider.overrideWithValue(provider),
        assistantAttendanceReaderProvider.overrideWithValue(attendance),
        assistantVehicleExpenseReaderProvider.overrideWithValue(
          _UnusedExpenseReader(),
        ),
        assistantKeyStoreProvider.overrideWithValue(
          keyStore ?? _FakeKeyStore(),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            viewInsets: viewInsets,
          ),
          child: child!,
        ),
        home: const AssistantPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpAssistantRouter(
  WidgetTester tester,
  _FakeAIProvider provider,
  _FakeAttendanceReadPort attendance, {
  required _FakeKeyStore keyStore,
  required GoRouter router,
  AppDatabase? database,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (database != null) appDatabaseProvider.overrideWithValue(database),
        assistantAIProvider.overrideWithValue(provider),
        assistantAttendanceReaderProvider.overrideWithValue(attendance),
        assistantVehicleExpenseReaderProvider.overrideWithValue(
          _UnusedExpenseReader(),
        ),
        assistantKeyStoreProvider.overrideWithValue(keyStore),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _UnusedExpenseReader implements VehicleExpenseReadPort {
  @override
  Future<VehicleExpensePeriodResult> readVehicleExpenses(
    VehicleExpenseToolRequest request,
  ) => throw UnimplementedError();

  @override
  Future<VehicleExpensePeerResult> comparePeerVehicleExpenses(
    VehicleExpenseToolRequest request,
  ) => throw UnimplementedError();
}

GoRouter _assistantTestRouter() => GoRouter(
  initialLocation: '/assistant',
  routes: [
    GoRoute(
      path: '/assistant',
      builder: (_, _) => const AssistantPage(),
      routes: [
        GoRoute(
          path: 'settings',
          builder: (_, _) => const AssistantSettingsPage(),
        ),
      ],
    ),
  ],
);

String _currentYearMonth() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
}

class _FakeAIProvider implements AIProvider {
  _FakeAIProvider(this._intents);

  final List<AttendanceIntent> _intents;
  var parseCalls = 0;

  @override
  Future<AttendanceIntent> parseIntent(
    IntentRequest request,
    RequestToken token,
  ) async {
    parseCalls++;
    return _intents.removeAt(0);
  }

  @override
  Future<SummaryExplanation> explainSummary(
    AttendanceOutboundSummary summary,
    RequestToken token,
  ) async => const SummaryExplanation(text: '本地汇总解释');

  @override
  Future<ConnectionCheck> checkConnection(RequestToken token) async =>
      const ConnectionCheck(success: true);
}

class _FakeAttendanceReadPort implements AttendanceReadPort {
  _FakeAttendanceReadPort({
    this.ambiguousNames = const {},
    this.candidateCount = 2,
  });

  final Set<String> ambiguousNames;
  final int candidateCount;
  var candidateCalls = 0;
  var readCalls = 0;
  var resolveCalls = 0;
  ResolvedAttendanceQuery? lastQuery;

  @override
  Future<EmployeeResolution> resolveEmployee(EmployeeSelector selector) async {
    resolveCalls++;
    if (ambiguousNames.contains(selector.employeeText)) {
      final candidateLabel = selector.employeeText ?? '重复姓名';
      return EmployeeResolution(
        status: EmployeeResolutionStatus.candidates,
        candidates: [
          EmployeeCandidate(
            candidateRef: 'candidate-1',
            employeeId: 1,
            label: candidateLabel,
            employeeNumber: '1001',
            groupLabel: '一组',
          ),
          EmployeeCandidate(
            candidateRef: 'candidate-2',
            employeeId: 2,
            label: candidateLabel,
            employeeNumber: '1002',
            groupLabel: '二组',
          ),
        ].take(candidateCount).toList(),
      );
    }
    return const EmployeeResolution(
      status: EmployeeResolutionStatus.unique,
      employee: ResolvedEmployee(employeeId: 1, label: '王敏'),
    );
  }

  @override
  Future<EmployeeResolution> resolveCandidate(String candidateRef) async {
    candidateCalls++;
    return const EmployeeResolution(
      status: EmployeeResolutionStatus.unique,
      employee: ResolvedEmployee(employeeId: 1, label: '重复姓名'),
    );
  }

  @override
  Future<AttendanceReadResult> readMonth(ResolvedAttendanceQuery query) async {
    readCalls++;
    lastQuery = query;
    return AttendanceReadResult(
      status: AttendanceReadStatus.success,
      employeeLabel: query.employee.label,
      yearMonth: query.yearMonth,
      queriedAt: DateTime(2026, 10, 17, 12),
      completeness: AttendanceCompleteness.notEvaluated,
      groupLabels: const ['一组'],
      groupIds: const [10],
      attendanceDays: 20,
      leaveAndRestDays: 2,
      overtimeMinutes: 95,
      details: AttendanceLocalDetails(
        attendanceDaysByDate: [
          AttendanceDayDetail(
            date: DateTime(DateTime.now().year, 9, 1),
            morningStatus: '出勤',
            afternoonStatus: '出勤',
          ),
        ],
        overtime: [
          OvertimeDetail(
            date: DateTime(DateTime.now().year, 9, 2),
            durationMinutes: 95,
          ),
        ],
      ),
    );
  }
}

class _FakeKeyStore implements AssistantKeyStore {
  _FakeKeyStore({this.value = 'test-key'});

  String? value;
  var removeCalls = 0;

  @override
  Future<bool> hasKey() async => value != null;

  @override
  Future<String?> readKey() async => value;

  @override
  Future<void> removeKey() async {
    removeCalls++;
    value = null;
  }

  @override
  Future<void> saveKey(String key) async => value = key;
}
