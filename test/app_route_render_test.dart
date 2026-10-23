import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/app/app.dart';
import 'package:qingsongban/app/router/app_router.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/database/demo_data_seeder.dart';
import 'package:qingsongban/core/database/inventory_demo_data_seeder.dart';
import 'package:qingsongban/core/database/purchase_demo_data_seeder.dart';
import 'package:qingsongban/core/database/vehicle_demo_data_seeder.dart';
import 'package:qingsongban/features/assistant/application/assistant_providers.dart';
import 'package:qingsongban/features/assistant/domain/assistant_models.dart';
import 'package:qingsongban/features/garden_tool_repairs/data/garden_tool_repair_repository.dart';
import 'package:qingsongban/features/garden_tool_repairs/domain/repair_models.dart';
import 'package:qingsongban/features/home/presentation/home_page.dart';

import 'support/app_route_cases.dart';

void _routeLog(String message) {
  // ignore: avoid_print
  print('ROUTE_FIXTURE $message');
}

Future<void> _pumpRouteFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  // Yield to Drift's executor so each route sees real query results.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  for (var frame = 0; frame < 2; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<Map<String, int>> _seedAndReadRouteIds(AppDatabase database) async {
  await DemoDataSeeder.seed(database);
  _routeLog('seeded personnel, attendance, reminders, payroll, insurance');
  await InventoryDemoDataSeeder.seed(database);
  _routeLog('seeded inventory');
  await PurchaseDemoDataSeeder.seed(database);
  _routeLog('seeded purchase');
  await VehicleDemoDataSeeder.seed(database);
  _routeLog('seeded vehicles');

  final employees = await database.select(database.employees).get();
  final employee = employees.firstWhere((row) => row.employeeNo == 'DEMO-001');
  final attendanceGroups = await database
      .select(database.attendanceGroups)
      .get();
  final attendanceGroup = attendanceGroups.firstWhere(
    (row) => row.name == '生产一组',
  );
  final leaves = await database.select(database.leaveRecords).get();
  final overtime = await database.select(database.overtimeRecords).get();
  final terminations = await database.select(database.terminationRecords).get();
  final insuranceChanges = await database
      .select(database.insuranceChangeRecords)
      .get();
  final reminders = await database.select(database.reminders).get();

  final payrollBatches = await database.select(database.payrollBatches).get();
  final draftBatch = payrollBatches.firstWhere(
    (row) => row.status == PayrollStatus.draft,
  );
  final payrollItems = await database.select(database.payrollItems).get();
  final payrollItem = payrollItems.firstWhere(
    (row) => row.payrollBatchId == draftBatch.id,
  );

  final purchaseRequestItems = await database
      .select(database.purchaseRequestItems)
      .get();
  final purchaseLinkedMaterialId = purchaseRequestItems
      .firstWhere((row) => row.inventoryMaterialId != null)
      .inventoryMaterialId!;
  final receipts = await database.select(database.inventoryReceipts).get();
  final issues = await database.select(database.inventoryIssues).get();
  final stocktakes = await database.select(database.inventoryStocktakes).get();

  final purchaseRequests = await database
      .select(database.purchaseRequests)
      .get();
  final pendingReceive = purchaseRequests.firstWhere(
    (row) => row.status == 'pending_receive',
  );
  final editablePurchase = purchaseRequests.firstWhere(
    (row) => row.status == 'pending_apply',
  );

  final vehicles = await database.select(database.vehicles).get();
  final vehicle = vehicles.firstWhere((row) => row.vehicleNo == 'DEMO-VH-002');
  final repairOrders = await database.select(database.repairOrders).get();
  final repairOrder = repairOrders.firstWhere(
    (row) => row.vehicleId == vehicle.id,
  );

  final gardenRepairs = GardenToolRepairRepository(database);
  final gardenUnit = await gardenRepairs.saveUnit(
    name: '路由渲染测试维修单位',
    sortOrder: 1,
    isActive: true,
  );
  final now = DateTime.now();
  final gardenRepairGroup = await gardenRepairs.saveGroup(
    GardenToolRepairGroupDraft(
      repairMonth: '${now.year}-${now.month.toString().padLeft(2, '0')}',
      repairDate: now,
      unitId: gardenUnit.id,
      repairerName: '测试维修员',
      items: const [
        GardenToolRepairItemDraft(
          projectName: '割草机刀片',
          specModel: '300mm',
          countUnit: '片',
          quantity: 2,
          unitPriceCents: 800,
        ),
      ],
    ),
  );
  _routeLog('read dynamic route IDs and inserted garden repair fixture');

  return {
    'employeeId': employee.id,
    'attendanceGroupId': attendanceGroup.id,
    'leaveId': leaves.first.id,
    'overtimeId': overtime.first.id,
    'terminationId': terminations.first.id,
    'changeId': insuranceChanges.first.id,
    'id': reminders.first.id,
    'batchId': draftBatch.id,
    'itemId': payrollItem.id,
    'materialId': purchaseLinkedMaterialId,
    'receiptId': receipts.first.id,
    'issueId': issues.first.id,
    'stocktakeId': stocktakes.first.id,
    'requestId': pendingReceive.id,
    'editRequestId': editablePurchase.id,
    'vehicleId': vehicle.id,
    'repairOrderId': repairOrder.id,
    'gardenRepairGroupId': gardenRepairGroup.id,
  };
}

Future<void> _visitRoute(
  WidgetTester tester, {
  required AppRouteCase route,
  required Map<String, int> ids,
  required String expectedName,
  required String stateLabel,
}) async {
  final location = route.locationFor(ids);
  appRouter.go(location);
  await _pumpRouteFrames(tester);

  expect(appRouter.state.name, expectedName, reason: '$stateLabel: $location');
  expect(
    find.byType(ErrorWidget),
    findsNothing,
    reason: '$stateLabel: $location',
  );
  expect(find.byType(Scaffold), findsWidgets, reason: '$stateLabel: $location');
  expect(
    find.byType(CircularProgressIndicator),
    findsNothing,
    reason: '$stateLabel remained in a loading state: $location',
  );
  expect(tester.takeException(), isNull, reason: '$stateLabel: $location');

  // StatefulShell intentionally keeps branch stacks offstage. Verify the
  // active page can return to home instead of asserting those branches die.
  appRouter.go('/home');
  await _pumpRouteFrames(tester);
  expect(appRouter.state.name, 'home', reason: '$stateLabel return: $location');
  expect(
    find.byType(HomePage),
    findsOneWidget,
    reason: '$stateLabel return: $location',
  );
  expect(
    tester.takeException(),
    isNull,
    reason: '$stateLabel return: $location',
  );
  // ignore: avoid_print
  print('ROUTE_RENDER_OK $stateLabel ${route.name} $location');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDownAll(appRouter.dispose);

  testWidgets('production router renders missing and seeded-record states', (
    tester,
  ) async {
    expect(appRouteCases, hasLength(94));
    expect(appRouteCases.map((route) => route.name).toSet(), hasLength(94));
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final database = AppDatabase.forTesting();
    Object? testError;
    StackTrace? testStackTrace;
    try {
      Map<String, int>? routeIds;
      Object? fixtureError;
      StackTrace? fixtureStackTrace;
      await tester.runAsync(() async {
        try {
          _routeLog('fixture setup started');
          routeIds = await _seedAndReadRouteIds(database);
        } catch (error, stackTrace) {
          fixtureError = error;
          fixtureStackTrace = stackTrace;
        }
      });
      if (fixtureError != null) {
        Error.throwWithStackTrace(fixtureError!, fixtureStackTrace!);
      }
      final populatedRouteIds = routeIds;
      if (populatedRouteIds == null) {
        throw StateError('Fixture setup did not produce route IDs.');
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            assistantKeyStoreProvider.overrideWithValue(
              _RouteAssistantKeyStore(),
            ),
          ],
          child: const QingSongBanApp(),
        ),
      );
      await _pumpRouteFrames(tester);

      for (final route in appRouteCases) {
        await _visitRoute(
          tester,
          route: route,
          ids: const {},
          expectedName: route.missingRecordRedirect ?? route.name,
          stateLabel: 'missing-record',
        );
      }

      for (final route in appRouteCases.where(
        (route) => route.location.contains(':'),
      )) {
        await _visitRoute(
          tester,
          route: route,
          ids: populatedRouteIds,
          expectedName: route.name,
          stateLabel: 'seeded-record',
        );
      }

    } catch (error, stackTrace) {
      testError = error;
      testStackTrace = stackTrace;
    } finally {
      try {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.idle();
      } catch (error, stackTrace) {
        if (testError == null) {
          testError = error;
          testStackTrace = stackTrace;
        } else {
          _routeLog('widget cleanup also failed: $error');
        }
      } finally {
        try {
          await tester.runAsync(() => database.close());
        } catch (error, stackTrace) {
          if (testError == null) {
            testError = error;
            testStackTrace = stackTrace;
          } else {
            _routeLog('database cleanup also failed: $error');
          }
        }
      }
    }
    final capturedError = testError;
    final capturedStackTrace = testStackTrace;
    if (capturedError != null && capturedStackTrace != null) {
      Error.throwWithStackTrace(capturedError, capturedStackTrace);
    }
  });
}

class _RouteAssistantKeyStore implements AssistantKeyStore {
  @override
  Future<bool> hasKey() async => false;

  @override
  Future<String?> readKey() async => null;

  @override
  Future<void> removeKey() async {}

  @override
  Future<void> saveKey(String key) async {}
}
