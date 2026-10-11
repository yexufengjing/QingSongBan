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

  testWidgets('missing material routes render their empty state', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    try {
      await tester.runAsync(() => InventoryDemoDataSeeder.seed(database));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const QingSongBanApp(),
        ),
      );
      appRouter.go('/inventory/materials/999999/edit');
      await _pumpFrames(tester);

      expect(find.text('物资不存在'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('inventory-material-submit')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);

      appRouter.go('/inventory/adjust?materialId=999999');
      await _pumpFrames(tester);

      expect(find.text('物资不存在'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.idle();
      appRouter.dispose();
      await database.close();
    }
  });
}
