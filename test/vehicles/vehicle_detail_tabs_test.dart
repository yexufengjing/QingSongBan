import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_repository.dart';
import 'package:qingsongban/features/vehicles/domain/vehicle_options.dart';
import 'package:qingsongban/features/vehicles/presentation/vehicle_detail_page.dart';

void main() {
  testWidgets('vehicle detail app bar title follows the selected tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final vehicle = await VehicleRepository(database).save(
      draft: const VehicleDraft(
        name: '标题测试车',
        vehicleNo: 'TITLE-001',
        licensePlate: '京A00001',
        vehicleType: VehicleType.waterTruck,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(home: VehicleDetailPage(vehicleId: vehicle.id)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('车辆详情'), findsOneWidget);

    for (final (tab, title) in [
      ('车况', '车辆车况检查'),
      ('维修', '车辆维修管理'),
      ('保养/备件', '车辆保养/备件'),
      ('油耗', '车辆油耗记录'),
      ('费用分析', '车辆费用分析'),
      ('档案', '车辆详情'),
    ]) {
      await tester.ensureVisible(find.text(tab).first);
      await tester.tap(find.text(tab).first);
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget, reason: 'tab $tab');
    }

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
