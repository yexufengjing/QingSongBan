import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('business fact sources open their matching record or month', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    final notifier = _StaticBusinessSourceNotifier();
    try {
      final employeeId = await database.into(database.employees).insert(
        EmployeesCompanion.insert(
          employeeNo: 'TEST-SOURCE-EMP',
          name: '来源测试员工',
          hireDate: DateTime(2024, 1, 1),
        ),
      );
      final batchId = await database.into(database.payrollBatches).insert(
        PayrollBatchesCompanion.insert(
          payrollMonth: '2026-09',
          name: '来源工资批次',
        ),
      );
      final payrollItemId = await database.into(database.payrollItems).insert(
        PayrollItemsCompanion.insert(
          payrollBatchId: batchId,
          employeeId: employeeId,
          displayOrder: 0,
          employeeNameSnapshot: '来源测试员工',
          employeeNoSnapshot: 'TEST-SOURCE-EMP',
          attendanceHalfDaysSnapshot: 40,
          finalWage: const Value(4500),
        ),
      );
      final materialId = await database.into(database.inventoryMaterials).insert(
        InventoryMaterialsCompanion.insert(
          materialCode: 'TEST-SOURCE-MATERIAL',
          materialName: '来源测试物资',
          unitName: '个',
        ),
      );
      final purchaseId = await database.into(database.purchaseRequests).insert(
        PurchaseRequestsCompanion.insert(title: '来源测试采购单'),
      );
      final vehicleId = await database.into(database.vehicles).insert(
        VehiclesCompanion.insert(name: '来源测试车辆', vehicleNo: 'TEST-SOURCE-CAR'),
      );
      final repairId = await database.into(database.repairOrders).insert(
        RepairOrdersCompanion.insert(
          repairNo: 'TEST-SOURCE-REPAIR',
          vehicleId: vehicleId,
          reportDate: DateTime(2026, 9, 5),
          faultFoundAt: DateTime(2026, 9, 5),
          symptom: '测试异响',
          ticketStatus: RepairTicketStatus.notRequired,
        ),
      );
      final reminderId = await database.into(database.reminders).insert(
        RemindersCompanion.insert(
          title: '来源测试提醒',
          reminderType: 'maintenance',
          category: const Value('vehicle'),
          dueDate: Value(DateTime(2026, 9, 20)),
          sourceEntityType: const Value('vehicle'),
          sourceEntityId: Value(vehicleId),
        ),
      );
      await database.into(database.reminderLinks).insert(
        ReminderLinksCompanion.insert(
          reminderId: reminderId,
          entityType: 'vehicle',
          entityId: vehicleId,
          displayNameSnapshot: '来源测试车辆',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            assistantControllerProvider.overrideWith(() => notifier),
          ],
          child: const QingSongBanApp(),
        ),
      );
      await _pumpRouteFrames(tester);
      appRouter.go('/assistant');
      await _pumpRouteFrames(tester);

      final targets = <_SourceCase>[
        _SourceCase(
          domain: AssistantBusinessType.payroll,
          source: '/reports/payroll/item/$payrollItemId',
          routeName: 'payroll-item-detail',
        ),
        _SourceCase(
          domain: AssistantBusinessType.inventory,
          source: '/inventory/materials/$materialId',
          routeName: 'inventory-material-detail',
        ),
        _SourceCase(
          domain: AssistantBusinessType.purchase,
          source: '/purchase/detail/$purchaseId',
          routeName: 'purchase-detail',
        ),
        _SourceCase(
          domain: AssistantBusinessType.vehicleMaintenance,
          source: '/vehicles/repairs/$repairId',
          routeName: 'vehicle-repair-detail',
        ),
        _SourceCase(
          domain: AssistantBusinessType.vehicleReminders,
          source: '/settings/reminders/$reminderId/edit',
          routeName: 'reminder-edit',
        ),
        const _SourceCase(
          domain: AssistantBusinessType.distribution,
          source: '/items?year=2026&month=09',
          routeName: 'item-distribution',
          year: 2026,
          month: 9,
        ),
        const _SourceCase(
          domain: AssistantBusinessType.gardenRepair,
          source: '/garden-tool-repairs/analysis?year=2026&month=09',
          routeName: 'garden-tool-repair-analysis',
          year: 2026,
          month: 9,
        ),
      ];

      for (var index = 0; index < targets.length; index++) {
        final target = targets[index];
        notifier.showSource(target);
        await tester.pump();
        final sourceButton = find.byKey(
          Key('assistant_business_fact_source_${target.domain.name}_0'),
        );
        await tester.ensureVisible(sourceButton);
        await tester.tap(sourceButton);
        await _pumpRouteFrames(tester);

        expect(appRouter.state.name, target.routeName);
        expect(appRouter.state.uri.path, Uri.parse(target.source).path);
        expect(tester.takeException(), isNull);
        if (target.year != null && target.month != null) {
          expect(appRouter.state.uri.queryParameters, {
            'year': '${target.year}',
            'month': target.month!.toString().padLeft(2, '0'),
          });
          if (target.domain == AssistantBusinessType.gardenRepair) {
            final monthFields = tester.widgetList<DropdownButtonFormField<int>>(
              find.byType(DropdownButtonFormField<int>),
            );
            expect(monthFields.map((field) => field.initialValue), contains(9));
          } else {
            expect(find.textContaining('2026年09月'), findsWidgets);
          }
        }

        appRouter.pop();
        await _pumpRouteFrames(tester);
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.runAsync(database.close);
    }
  });

  testWidgets(
    'payroll warning source opens from assistant above the existing shell and returns',
    (tester) async {
      final database = AppDatabase.forTesting();
      final notifier = _StaticBusinessSourceNotifier();
      try {
        appRouter.go('/home');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(database),
              assistantControllerProvider.overrideWith(() => notifier),
            ],
            child: const QingSongBanApp(),
          ),
        );
        await _pumpRouteFrames(tester);
        appRouter.push<void>('/assistant');
        await _pumpRouteFrames(tester);
        notifier.showSource(
          const _SourceCase(
            domain: AssistantBusinessType.payroll,
            source: '/reports/payroll',
            routeName: 'payroll',
          ),
        );
        await tester.pump();
        await tester.ensureVisible(find.text('查看工资待核对来源'));
        await tester.tap(find.text('查看工资待核对来源'));
        await _pumpRouteFrames(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
        expect(find.text('临时工薪资'), findsOneWidget);
        await tester.tap(find.byTooltip('工种与日薪设置'));
        await _pumpRouteFrames(tester);
        expect(appRouter.state.name, 'payroll-settings');
        expect(tester.takeException(), isNull);
        appRouter.pop();
        await _pumpRouteFrames(tester);
        expect(find.text('临时工薪资'), findsOneWidget);
        appRouter.pop();
        await _pumpRouteFrames(tester);
        expect(find.text('查看工资待核对来源'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('查看工资待核对来源'));
        await tester.tap(find.text('查看工资待核对来源'));
        await _pumpRouteFrames(tester);
        expect(find.text('临时工薪资'), findsOneWidget);
        expect(tester.takeException(), isNull);
        appRouter.pop();
        await _pumpRouteFrames(tester);
        expect(find.text('查看工资待核对来源'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
        await tester.runAsync(database.close);
      }
    },
  );
}

Future<void> _pumpRouteFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _SourceCase {
  const _SourceCase({
    required this.domain,
    required this.source,
    required this.routeName,
    this.year,
    this.month,
  });

  final AssistantBusinessType domain;
  final String source;
  final String routeName;
  final int? year;
  final int? month;
}

class _StaticBusinessSourceNotifier extends AssistantSessionNotifier {
  @override
  AssistantState build() => const AssistantState();

  void showSource(_SourceCase target) {
    final result = AssistantBusinessReadResult(
      domain: target.domain,
      title: target.domain.name,
      summary: '本地来源路由验收',
      queriedAt: DateTime(2026, 10, 19),
      sourceRule: 'test_source_route_v1',
      sourcePage: target.source,
      facts: [
        AssistantBusinessFact(
          label: target.source == '/reports/payroll' ? '工资待核对' : '测试记录',
          isWarning: target.source == '/reports/payroll',
          value: '4500.00 元',
          sourcePage: target.source,
        ),
      ],
    );
    final answer = AssistantAnswer(
      text: '测试记录：4500.00 元',
      employeeLabel: '来源路由验收',
      yearMonth: target.year == null
          ? ''
          : '${target.year}-${target.month.toString().padLeft(2, '0')}',
      queriedAt: DateTime(2026, 10, 19),
      completeness: AttendanceCompleteness.notEvaluated,
      yearMonthSource: AssistantFieldSource.input,
      sourcePage: target.source,
      businessResult: result,
    );
    state = AssistantState(
      messages: [
        AssistantMessage(
          id: target.domain.index + 1,
          text: answer.text,
          isUser: false,
          answer: answer,
        ),
      ],
      session: AssistantSessionContext(lastBusinessType: target.domain),
    );
  }

  @override
  void updatePageContext(AssistantPageContext? context) {}

  @override
  Future<void> submit(String utterance) async {}
}
