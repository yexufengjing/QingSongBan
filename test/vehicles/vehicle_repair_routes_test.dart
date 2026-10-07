import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/app/router/app_router.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/vehicles/data/repair_repository.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_repository.dart';
import 'package:qingsongban/features/vehicles/domain/repair_options.dart';
import 'package:qingsongban/features/vehicles/domain/vehicle_options.dart';
import 'package:qingsongban/features/vehicles/presentation/vehicle_repair_detail_page.dart';
import 'package:qingsongban/features/vehicles/presentation/vehicle_repair_form_page.dart';

void main() {
  testWidgets('vehicle repair routes open list, real detail, and edit form', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    final database = AppDatabase.forTesting();
    try {
      final vehicle = await VehicleRepository(database).save(
        draft: const VehicleDraft(
          name: '路由测试车辆',
          vehicleNo: 'ROUTE-001',
          licensePlate: '京R00001',
          vehicleType: VehicleType.waterTruck,
        ),
      );
      final order = await RepairRepository(database).save(
        draft: RepairOrderDraft(
          vehicleId: vehicle.id,
          reportDate: DateTime(2026, 9, 1),
          faultFoundAt: DateTime(2026, 9, 1),
          symptom: '路由回归故障现象',
          ticketStatus: RepairTicketStatus.notIssued,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );
      appRouter.go('/vehicles/repairs');
      await tester.pumpAndSettle();
      expect(find.text('全车维修单'), findsOneWidget);
      expect(find.text('路由测试车辆'), findsOneWidget);

      await tester.tap(find.text('路由测试车辆'));
      await tester.pumpAndSettle();
      expect(find.text('维修单详情'), findsOneWidget);
      expect(find.text('路由回归故障现象'), findsOneWidget);
      expect(find.text(vehicle.licensePlate!), findsOneWidget);
      final detail = tester.widget<VehicleRepairDetailPage>(
        find.byType(VehicleRepairDetailPage),
      );
      expect(detail.repairOrderId, order.id);

      await tester.tap(find.byTooltip('编辑维修单'));
      await tester.pumpAndSettle();
      expect(find.text('编辑维修单'), findsOneWidget);
      expect(find.text('维修单不存在或已删除'), findsNothing);
      final form = tester.widget<VehicleRepairFormPage>(
        find.byType(VehicleRepairFormPage),
      );
      expect(form.vehicleId, vehicle.id);
      expect(form.repairOrderId, order.id);
      expect(
        tester
            .widgetList<TextFormField>(find.byType(TextFormField))
            .first
            .controller
            ?.text,
        '路由回归故障现象',
      );
      expect(tester.takeException(), isNull);
    } finally {
      appRouter.go('/home');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await database.close();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.binding.setSurfaceSize(null);
    }
  });
}
