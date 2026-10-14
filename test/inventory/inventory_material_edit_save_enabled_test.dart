import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/app/app.dart';
import 'package:qingsongban/app/router/app_router.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/core/database/inventory_demo_data_seeder.dart';

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDownAll(appRouter.dispose);

  testWidgets('existing material edit enables save without dropdown input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final database = AppDatabase.forTesting();
    try {
      final seededMaterial = await tester.runAsync(() async {
        await InventoryDemoDataSeeder.seed(database);
        final materials = await database
            .select(database.inventoryMaterials)
            .get();
        if (materials.isEmpty) {
          throw StateError('Inventory demo seeder did not create a material.');
        }
        return (id: materials.first.id, name: materials.first.materialName);
      });
      if (seededMaterial == null) {
        throw StateError('Inventory demo seeder did not return a material ID.');
      }
      final materialId = seededMaterial.id;
      final updatedName = '${seededMaterial.name} 回归编辑';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const QingSongBanApp(),
        ),
      );
      appRouter.go('/inventory/materials');
      await _pumpFrames(tester);
      await tester.enterText(find.byType(TextField).first, seededMaterial.name);
      await _pumpFrames(tester);
      final materialRow = find.byKey(Key('inventory-material-$materialId'));
      expect(materialRow, findsOneWidget);

      await tester.tap(
        find.descendant(of: materialRow, matching: find.byTooltip('物资操作')),
      );
      await _pumpFrames(tester);
      await tester.tap(find.text('编辑物资'));
      await _pumpFrames(tester);

      expect(find.text('编辑物资'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('inventory-material-submit')),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextFormField).first, updatedName);
      await tester.tap(find.byKey(const Key('inventory-material-submit')));
      await _pumpFrames(tester);

      final updatedMaterial = await tester.runAsync(
        () async => (await database.select(database.inventoryMaterials).get())
            .firstWhere((row) => row.id == materialId),
      );
      expect(updatedMaterial?.materialName, updatedName);
      expect(appRouter.state.name, 'inventory-materials');
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.idle();
      await database.close();
    }
  });
}
