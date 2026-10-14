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
  testWidgets('cancel and system back close category dialog without saving', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    try {
      await tester.runAsync(() => InventoryDemoDataSeeder.seed(database));
      final categoryCountBefore = await tester.runAsync(
        () => database.select(database.inventoryCategories).get(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const QingSongBanApp(),
        ),
      );
      appRouter.go('/inventory/materials/new');
      await _pumpFrames(tester);
      expect(find.byKey(const Key('inventory-category-add')), findsOneWidget);

      await tester.tap(find.byKey(const Key('inventory-category-add')));
      await _pumpFrames(tester);
      expect(find.text('新增物资分类'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '应取消的分类');
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await _pumpFrames(tester);
      expect(find.text('新增物资分类'), findsNothing);
      expect(find.text('新增物资'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'cancel button');

      await tester.tap(find.byKey(const Key('inventory-category-add')));
      await _pumpFrames(tester);
      expect(find.text('新增物资分类'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '系统返回取消的分类');
      await tester.binding.handlePopRoute();
      await _pumpFrames(tester);
      expect(find.text('新增物资分类'), findsNothing);
      expect(find.text('新增物资'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'system back');

      final categoryCountAfter = await tester.runAsync(
        () => database.select(database.inventoryCategories).get(),
      );
      expect(categoryCountAfter, hasLength(categoryCountBefore!.length));

      await tester.tap(find.byKey(const Key('inventory-category-add')));
      await _pumpFrames(tester);
      await tester.enterText(find.byType(TextField).last, '回归新增分类');
      await tester.tap(find.widgetWithText(FilledButton, '新增'));
      await _pumpFrames(tester);
      expect(find.text('新增物资分类'), findsNothing);
      expect(find.text('新增物资'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'create category');
      final categoriesAfterCreate = await tester.runAsync(
        () => database.select(database.inventoryCategories).get(),
      );
      expect(categoriesAfterCreate, hasLength(categoryCountBefore.length + 1));
      expect(
        categoriesAfterCreate!.map((category) => category.name),
        contains('回归新增分类'),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.idle();
      appRouter.dispose();
      await database.close();
    }
  });
}
