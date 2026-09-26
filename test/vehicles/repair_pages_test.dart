import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/vehicles/data/repair_repository.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_repository.dart';
import 'package:qingsongban/features/vehicles/domain/repair_options.dart';
import 'package:qingsongban/features/vehicles/domain/vehicle_options.dart';
import 'package:qingsongban/features/vehicles/presentation/vehicle_repair_detail_page.dart';
import 'package:qingsongban/features/vehicles/presentation/vehicle_repair_list_page.dart';

void main() {
  testWidgets('repair list opens detail and saves settlement marker', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final vehicle = await VehicleRepository(database).save(
      draft: const VehicleDraft(
        name: '维修测试车',
        vehicleNo: 'R-001',
        licensePlate: '京A00001',
        vehicleType: VehicleType.waterTruck,
      ),
    );
    final order = await RepairRepository(database).save(
      draft: RepairOrderDraft(
        vehicleId: vehicle.id,
        reportDate: DateTime(2026, 9, 1),
        faultFoundAt: DateTime(2026, 9, 1),
        symptom: '水泵异响',
        ticketStatus: RepairTicketStatus.notIssued,
      ),
    );
    final router = GoRouter(
      initialLocation: '/vehicles/repairs',
      routes: [
        GoRoute(
          path: '/vehicles/repairs',
          builder: (_, _) => const VehicleRepairListPage(),
        ),
        GoRoute(
          path: '/vehicles/repairs/:repairOrderId',
          builder: (_, state) => VehicleRepairDetailPage(
            repairOrderId: int.parse(state.pathParameters['repairOrderId']!),
          ),
        ),
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
    expect(find.text(order.repairNo), findsNothing);
    expect(find.text('维修测试车'), findsOneWidget);
    expect(find.text('未填写'), findsOneWidget);
    await tester.tap(find.text('维修测试车'));
    await tester.pumpAndSettle();
    expect(find.text('水泵异响'), findsOneWidget);
    expect(find.text('更新业务状态'), findsOneWidget);
    expect(find.text('维修进度'), findsOneWidget);
    expect(find.text('三联票据'), findsOneWidget);
    expect(find.text('未结算'), findsAtLeastNWidgets(1));
    expect(find.text('未结账'), findsAtLeastNWidgets(1));
    expect(find.text('维修记录'), findsOneWidget);
    expect(find.textContaining('故障：水泵异响'), findsNothing);
    await tester.tap(find.text('维修记录'));
    await tester.pumpAndSettle();
    expect(find.textContaining('故障：水泵异响'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(
      (await RepairRepository(database).findById(order.id))?.isSettled,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('repair list filters apply, reset, and discard temporary edits', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final repository = VehicleRepository(database);
    final firstVehicle = await repository.save(
      draft: const VehicleDraft(
        name: '洒水车甲',
        vehicleNo: 'A-001',
        licensePlate: '京A00001',
        vehicleType: VehicleType.waterTruck,
      ),
    );
    final secondVehicle = await repository.save(
      draft: const VehicleDraft(
        name: '清扫车乙',
        vehicleNo: 'B-002',
        licensePlate: '京B00002',
        vehicleType: VehicleType.sweeper,
      ),
    );
    final repairs = RepairRepository(database);
    final firstOrder = await repairs.save(
      draft: RepairOrderDraft(
        vehicleId: firstVehicle.id,
        reportDate: DateTime(2026, 9, 2),
        faultFoundAt: DateTime(2026, 9, 2),
        symptom: '水泵异响',
        cause: '叶轮磨损导致持续异响，检查后需要更换',
        ticketStatus: RepairTicketStatus.issued,
        status: VehicleRepairStatus.repairing,
        vendor: '广源汽车维修站',
        reportedAmountCents: 12000,
      ),
    );
    await repairs.save(
      draft: RepairOrderDraft(
        vehicleId: secondVehicle.id,
        reportDate: DateTime(2026, 9, 1),
        faultFoundAt: DateTime(2026, 9, 1),
        symptom: '扫盘松动',
        ticketStatus: RepairTicketStatus.notIssued,
        status: VehicleRepairStatus.reported,
      ),
    );
    await repairs.updateMarkers(
      id: firstOrder.id,
      isSettled: true,
      isPaid: true,
    );
    final router = GoRouter(
      initialLocation: '/vehicles/repairs',
      routes: [
        GoRoute(
          path: '/vehicles/repairs',
          builder: (_, _) => const VehicleRepairListPage(),
        ),
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

    expect(find.text('1'), findsOneWidget);
    expect(find.text('洒水车甲'), findsOneWidget);
    expect(find.text('京A00001'), findsNothing);
    expect(find.text('故障原因'), findsAtLeastNWidgets(1));
    expect(find.text('叶轮磨损导致持续异响，检查后需要更换'), findsOneWidget);
    expect(find.text('广源汽车维修站'), findsOneWidget);
    expect(find.text('¥0.00'), findsAtLeastNWidgets(1));
    expect(find.textContaining(firstOrder.repairNo), findsNothing);

    expect(find.text('筛选'), findsOneWidget);
    await tester.tap(find.text('筛选'));
    await tester.pumpAndSettle();
    expect(find.text('筛选维修单'), findsOneWidget);
    for (final heading in ['车辆', '维修状态', '三联票', '结算', '结账']) {
      expect(find.text(heading), findsOneWidget);
    }
    await tester.tap(find.text('全部车辆'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('洒水车甲').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部状态'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('维修中').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部票据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已开').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('已结算'));
    await tester.tap(find.text('已结账'));
    await tester.tap(find.text('应用筛选'));
    await tester.pumpAndSettle();
    expect(find.text('5'), findsOneWidget);
    expect(find.text('洒水车甲'), findsOneWidget);
    expect(find.text('清扫车乙'), findsNothing);

    // A staged edit is discarded when the filter page is closed with back.
    await tester.tap(find.text('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('维修中'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已报修').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('洒水车甲'), findsOneWidget);
    expect(find.text('清扫车乙'), findsNothing);
    expect(find.text('5'), findsOneWidget);

    await tester.tap(find.text('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用筛选'));
    await tester.pumpAndSettle();
    expect(find.text('洒水车甲'), findsOneWidget);
    expect(find.text('清扫车乙'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '扫盘');
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('清扫车乙'), findsOneWidget);
    expect(find.text('洒水车甲'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('repair list cards fit narrow screens without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final vehicle = await VehicleRepository(database).save(
      draft: const VehicleDraft(
        name: '这是一辆名称很长的城市道路洒水清洁专用车辆',
        vehicleNo: 'R-001',
        licensePlate: '京A00001',
        vehicleType: VehicleType.waterTruck,
      ),
    );
    await RepairRepository(database).save(
      draft: RepairOrderDraft(
        vehicleId: vehicle.id,
        reportDate: DateTime(2026, 9, 1),
        faultFoundAt: DateTime(2026, 9, 1),
        symptom: '检查发动机和水泵后发现多处零件损坏，维修内容较长需要换件',
        ticketStatus: RepairTicketStatus.notRequired,
        vendor: '这是一个特别长的维修供应商名称用于验证卡片在窄屏情况下不会横向溢出',
        reportedAmountCents: 987654321,
      ),
    );
    final router = GoRouter(
      initialLocation: '/vehicles/repairs',
      routes: [
        GoRoute(
          path: '/vehicles/repairs',
          builder: (_, _) => const VehicleRepairListPage(),
        ),
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
    expect(tester.takeException(), isNull);
    final cardRect = tester.getRect(find.byType(Card).first);
    final actualAmountRect = tester.getRect(find.text('¥0.00').first);
    final dateRect = tester.getRect(find.text('2026-09-01'));
    final reportedAmountRect = tester.getRect(find.text('申报 ¥9876543.21'));
    expect(cardRect.right - actualAmountRect.right, closeTo(12, 3));
    expect(reportedAmountRect.left - dateRect.right, greaterThanOrEqualTo(12));
    expect(cardRect.right - reportedAmountRect.right, closeTo(12, 3));
    expect(find.text('维修供应商'), findsOneWidget);
    expect(find.byIcon(Icons.storefront_outlined), findsNothing);
    expect(find.textContaining('这是一个特别长的维修供应商名称'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
