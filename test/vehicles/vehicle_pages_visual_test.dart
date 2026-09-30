import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_repository.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_expense_repository.dart';
import 'package:qingsongban/features/vehicles/data/fuel_repository.dart';
import 'package:qingsongban/features/vehicles/domain/expense_options.dart';
import 'package:qingsongban/features/vehicles/domain/vehicle_options.dart';
import 'package:qingsongban/features/vehicles/presentation/vehicle_archive_page.dart';
import 'package:qingsongban/features/vehicles/presentation/vehicle_expense_tab.dart';
import 'package:qingsongban/features/vehicles/presentation/vehicle_fuel_tab.dart';
import 'package:qingsongban/features/vehicles/presentation/vehicle_metric_grid.dart';
import 'package:qingsongban/features/vehicles/presentation/vehicle_reminder_page.dart';
import 'package:qingsongban/features/reminders/data/reminder_repository.dart';
import 'package:qingsongban/features/reminders/domain/reminder_options.dart';

void main() {
  testWidgets('vehicle metrics stay in one row at phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: VehicleMetricGrid(
              items: [
                VehicleMetricData(
                  label: '待维修',
                  value: '3',
                  icon: Icons.build,
                  color: Colors.orange,
                ),
                VehicleMetricData(
                  label: '维修中',
                  value: '4',
                  icon: Icons.settings,
                  color: Colors.blue,
                ),
                VehicleMetricData(
                  label: '已完成',
                  value: '5',
                  icon: Icons.check,
                  color: Colors.green,
                ),
                VehicleMetricData(
                  label: '本月费用',
                  value: '¥24860',
                  icon: Icons.money,
                  color: Colors.purple,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.text('待维修')).dy,
      tester.getTopLeft(find.text('本月费用')).dy,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('archive shows vehicle identity and metadata', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    await VehicleRepository(database).save(
      draft: const VehicleDraft(
        name: '测试档案车',
        vehicleNo: 'SW-001',
        vehicleType: VehicleType.sweeper,
        licensePlate: '京A12345',
        workArea: '城区主干道',
        responsiblePerson: '张师傅',
      ),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const VehicleArchivePage()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('测试档案车'), findsOneWidget);
    expect(find.textContaining('京A12345'), findsOneWidget);
    expect(find.textContaining('城区主干道'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('archive filters the live list by work area', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final repository = VehicleRepository(database);
    await repository.save(
      draft: const VehicleDraft(
        name: '城区车辆',
        vehicleNo: 'AREA-1',
        vehicleType: VehicleType.sweeper,
        workArea: '城区主干道',
      ),
    );
    await repository.save(
      draft: const VehicleDraft(
        name: '开发区车辆',
        vehicleNo: 'AREA-2',
        vehicleType: VehicleType.waterTruck,
        workArea: '开发区',
      ),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const VehicleArchivePage()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('共 2 辆'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('城区主干道').last);
    await tester.pumpAndSettle();
    expect(find.text('共 1 辆'), findsOneWidget);
    expect(find.text('城区车辆'), findsOneWidget);
    expect(find.text('开发区车辆'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('expense page renders trend and composition from records', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final vehicle = await VehicleRepository(database).save(
      draft: const VehicleDraft(
        name: '费用测试车',
        vehicleNo: 'COST-1',
        vehicleType: VehicleType.sweeper,
      ),
    );
    await VehicleExpenseRepository(database).saveManual(
      ManualVehicleExpenseDraft(
        vehicleId: vehicle.id,
        expenseDate: DateTime(DateTime.now().year, 3, 1),
        expenseType: VehicleManualExpenseType.other,
        amountCents: 24000,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: Scaffold(body: VehicleExpenseTab(vehicle: vehicle)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('本年累计总费用'), findsOneWidget);
    expect(find.text('月度费用趋势'), findsOneWidget);
    expect(find.text('费用构成'), findsOneWidget);
    expect(find.text('单位：元'), findsOneWidget);
    expect(find.text('¥240'), findsNWidgets(2));
    expect(find.text('¥240  100%'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${DateTime.now().year - 1} 年').last);
    await tester.pumpAndSettle();
    expect(find.text('本年度还没有费用流水'), findsOneWidget);
    expect(find.text('月度费用趋势'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('inline fuel entry saves the selected month', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final vehicle = await VehicleRepository(database).save(
      draft: const VehicleDraft(
        name: '油耗测试车',
        vehicleNo: 'FUEL-1',
        vehicleType: VehicleType.sweeper,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: Scaffold(body: VehicleFuelTab(vehicle: vehicle)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('车辆月度油耗录入'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '120');
    await tester.enterText(find.byType(TextFormField).at(1), '850');
    await tester.tap(find.text('保存录入'));
    await tester.pumpAndSettle();
    final saved = await FuelRepository(database)
        .findByMonth(vehicle.id, DateTime.now().year, DateTime.now().month);
    expect(saved?.liters, 120);
    expect(saved?.amountCents, 85000);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('vehicle reminder center shows linked vehicle reminders', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final vehicle = await VehicleRepository(database).save(
      draft: const VehicleDraft(
        name: '提醒测试车',
        vehicleNo: 'REM-1',
        vehicleType: VehicleType.sweeper,
      ),
    );
    await ReminderRepository(database).save(
      draft: ReminderDraft(
        title: '主机机油保养即将到期',
        reminderType: 'vehicleMaintenance',
        leadDays: 3,
        isEnabled: true,
        dueDate: DateTime.now().add(const Duration(days: 2)),
        links: [
          ReminderLinkDraft(
            entityType: 'vehicle',
            entityId: vehicle.id,
            displayName: vehicle.name,
          ),
        ],
      ),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const VehicleReminderPage()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('提醒测试车'), findsOneWidget);
    expect(find.text('主机机油保养即将到期'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
