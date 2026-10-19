import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:qingsongban/app/app.dart';
import 'package:qingsongban/app/router/app_router.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/assistant/application/assistant_providers.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(appRouter.dispose);

  testWidgets(
    'production shell assistant opens the attendance source and returns with draft',
    (tester) async {
      final database = AppDatabase.forTesting();
      try {
        await database
            .into(database.attendanceGroups)
            .insert(AttendanceGroupsCompanion.insert(name: '来源第一组'));
        final verifiedGroupId = await database
            .into(database.attendanceGroups)
            .insert(AttendanceGroupsCompanion.insert(name: '来源第二组'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(database),
              assistantKeyStoreProvider.overrideWithValue(_TestKeyStore()),
              assistantAIProvider.overrideWithValue(_TestAIProvider()),
              assistantAttendanceReaderProvider.overrideWithValue(
                _TestAttendanceReader(verifiedGroupId: verifiedGroupId),
              ),
            ],
            child: const QingSongBanApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(NavigationDestination, '我的'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('settings-assistant-entry')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('settings-assistant-entry')));
        await tester.pumpAndSettle();
        expect(appRouter.state.name, 'assistant');
        expect(find.text('智能助手'), findsOneWidget);

        await tester.enterText(find.byType(TextField), '查王敏9月考勤');
        await tester.tap(find.byTooltip('发送'));
        await tester.pumpAndSettle();
        expect(find.textContaining('王敏在'), findsOneWidget);

        const draft = '返回后继续编辑';
        await tester.enterText(find.byType(TextField), draft);
        await tester.ensureVisible(find.text('打开月考勤表'));
        await tester.tap(find.text('打开月考勤表'));
        await tester.pumpAndSettle();

        expect(find.text('月考勤表'), findsOneWidget);
        expect(appRouter.state.name, 'assistant');
        final groupField = tester.widget<DropdownButtonFormField<int>>(
          find.byKey(const Key('monthly-attendance-table-group-field')),
        );
        expect(groupField.initialValue, verifiedGroupId);
        expect(tester.takeException(), isNull);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.pumpAndSettle();

        expect(find.text('智能助手'), findsOneWidget);
        expect(find.textContaining('王敏在'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          draft,
        );
        expect(appRouter.state.name, 'assistant');
        expect(tester.takeException(), isNull);
      } finally {
        await _disposeApp(tester, database);
      }
    },
  );

  testWidgets(
    'global floating assistant opens the attendance source above its route and returns',
    (tester) async {
      appRouter.go('/home');
      final database = AppDatabase.forTesting();
      try {
        final verifiedGroupId = await database
            .into(database.attendanceGroups)
            .insert(AttendanceGroupsCompanion.insert(name: '浮窗来源考勤组'));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(database),
              assistantKeyStoreProvider.overrideWithValue(_TestKeyStore()),
              assistantAIProvider.overrideWithValue(_TestAIProvider()),
              assistantAttendanceReaderProvider.overrideWithValue(
                _TestAttendanceReader(verifiedGroupId: verifiedGroupId),
              ),
            ],
            child: const QingSongBanApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home-assistant-entry')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('assistant-composer-input')),
          '查王敏9月考勤',
        );
        await tester.tap(find.byTooltip('发送'));
        await tester.pumpAndSettle();
        expect(find.textContaining('王敏在'), findsOneWidget);

        const draft = '浮窗来源返回后继续编辑';
        await tester.enterText(
          find.byKey(const Key('assistant-composer-input')),
          draft,
        );
        await tester.ensureVisible(find.text('打开月考勤表'));
        await tester.tap(find.text('打开月考勤表'));
        await tester.pumpAndSettle();

        expect(find.text('月考勤表'), findsOneWidget);
        expect(appRouter.routeInformationProvider.value.uri.path, '/home');
        final groupField = tester.widget<DropdownButtonFormField<int>>(
          find.byKey(const Key('monthly-attendance-table-group-field')),
        );
        expect(groupField.initialValue, verifiedGroupId);
        expect(find.byKey(const Key('assistant-floating-page')), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('月考勤表'), findsNothing);
        expect(
          find.byKey(const Key('assistant-floating-page')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(
                find.byKey(const Key('assistant-composer-input')),
              )
              .controller!
              .text,
          draft,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await _disposeApp(tester, database);
      }
    },
  );

  testWidgets(
    'global floating vehicle source hides over 2025 expense page and restores draft on return',
    (tester) async {
      appRouter.go('/home');
      final database = AppDatabase.forTesting();
      final notifier = _StaticVehicleAnswerNotifier();
      try {
        final vehicleId = await database
            .into(database.vehicles)
            .insert(
              VehiclesCompanion.insert(
                name: '来源测试车辆',
                vehicleNo: 'TEST-SOURCE-2025',
                vehicleType: const Value(VehicleType.sweeper),
              ),
            );
        notifier.vehicleId = vehicleId;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(database),
              assistantControllerProvider.overrideWith(() => notifier),
            ],
            child: const QingSongBanApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home-assistant-entry')));
        await tester.pumpAndSettle();
        const draft = '车辆来源返回后保留的草稿';
        await tester.enterText(
          find.byKey(const Key('assistant-composer-input')),
          draft,
        );
        await tester.ensureVisible(find.text('车辆费用分析'));
        await tester.tap(find.text('车辆费用分析'));
        await tester.pumpAndSettle();

        expect(appRouter.state.uri.path, '/vehicles/$vehicleId');
        expect(find.text('2025 年'), findsOneWidget);
        expect(find.byKey(const Key('assistant-floating-page')), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(appRouter.state.uri.path, '/home');
        expect(
          find.byKey(const Key('assistant-floating-page')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(
                find.byKey(const Key('assistant-composer-input')),
              )
              .controller!
              .text,
          draft,
        );

        await tester.tap(find.byTooltip('转为全屏'));
        await tester.pumpAndSettle();
        expect(appRouter.state.uri.path, '/assistant');
        expect(find.byKey(const Key('assistant-floating-page')), findsNothing);
        await tester.ensureVisible(find.text('车辆费用分析'));
        await tester.tap(find.text('车辆费用分析'));
        await tester.pumpAndSettle();

        expect(appRouter.state.uri.path, '/vehicles/$vehicleId');
        expect(find.text('2025 年'), findsOneWidget);
        expect(find.byKey(const Key('assistant-floating-page')), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(appRouter.state.uri.path, '/assistant');
        expect(find.byKey(const Key('assistant-floating-page')), findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          draft,
        );
        expect(notifier.submitCalls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await _disposeApp(tester, database);
      }
    },
  );
}

Future<void> _disposeApp(WidgetTester tester, AppDatabase database) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await tester.runAsync(database.close);
  await tester.pump(const Duration(milliseconds: 1));
}

class _TestKeyStore implements AssistantKeyStore {
  @override
  Future<bool> hasKey() async => false;

  @override
  Future<String?> readKey() async => null;

  @override
  Future<void> saveKey(String key) async {}

  @override
  Future<void> removeKey() async {}
}

class _TestAIProvider implements AIProvider {
  @override
  Future<AttendanceIntent> parseIntent(
    IntentRequest request,
    RequestToken token,
  ) async => const AttendanceIntent(
    action: AttendanceAction.queryAttendance,
    employeeText: '王敏',
    yearReference: YearReference.current,
    month: 9,
  );

  @override
  Future<SummaryExplanation> explainSummary(
    AttendanceOutboundSummary summary,
    RequestToken token,
  ) async => const SummaryExplanation(text: '本地汇总解释');

  @override
  Future<ConnectionCheck> checkConnection(RequestToken token) async =>
      const ConnectionCheck(success: true);
}

class _TestAttendanceReader implements AttendanceReadPort {
  _TestAttendanceReader({required this.verifiedGroupId});

  final int verifiedGroupId;

  @override
  Future<EmployeeResolution> resolveEmployee(EmployeeSelector selector) async =>
      const EmployeeResolution(
        status: EmployeeResolutionStatus.unique,
        employee: ResolvedEmployee(employeeId: 1, label: '王敏'),
      );

  @override
  Future<EmployeeResolution> resolveCandidate(String candidateRef) async =>
      const EmployeeResolution(status: EmployeeResolutionStatus.notFound);

  @override
  Future<AttendanceReadResult> readMonth(ResolvedAttendanceQuery query) async =>
      AttendanceReadResult(
        status: AttendanceReadStatus.success,
        employeeLabel: '王敏',
        yearMonth: query.yearMonth,
        queriedAt: DateTime(2026, 10, 18),
        completeness: AttendanceCompleteness.notEvaluated,
        groupLabels: const ['来源第二组'],
        groupIds: [verifiedGroupId],
        attendanceDays: 20,
        leaveAndRestDays: 2,
        overtimeMinutes: 60,
      );
}

class _StaticVehicleAnswerNotifier extends AssistantSessionNotifier {
  var submitCalls = 0;
  int vehicleId = 1;

  @override
  AssistantState build() => AssistantState(
    messages: [
      AssistantMessage(
        id: 1,
        text: '来源测试车辆 2025 年维修费用已读取。',
        isUser: false,
        answer: AssistantAnswer(
          text: '来源测试车辆 2025 年维修费用已读取。',
          employeeLabel: '',
          yearMonth: '',
          queriedAt: DateTime(2025, 12, 31),
          completeness: AttendanceCompleteness.notEvaluated,
          yearMonthSource: AssistantFieldSource.none,
          vehicleSummary: VehicleAnnualRepairResult(
            status: VehicleAnnualRepairReadStatus.success,
            vehicle: ResolvedVehicle(
              vehicleId: vehicleId,
              label: '来源测试车辆',
              vehicleNumber: 'TEST-SOURCE-2025',
            ),
            year: 2025,
            queriedAt: DateTime(2025, 12, 31),
            completedRepairCount: 1,
            actualAmountCents: 12500,
          ),
        ),
      ),
    ],
  );

  @override
  void updatePageContext(AssistantPageContext? context) {}

  @override
  Future<void> submit(String utterance) async {
    submitCalls++;
  }
}
