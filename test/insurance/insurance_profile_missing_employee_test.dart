import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/app/app.dart';
import 'package:qingsongban/app/router/app_router.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/core/database/demo_data_seeder.dart';

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

  testWidgets(
    'unknown employee ID shows a safe missing state and cannot save',
    (tester) async {
      final database = AppDatabase.forTesting();
      try {
        await tester.runAsync(() => DemoDataSeeder.seed(database));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(database)],
            child: const QingSongBanApp(),
          ),
        );
        appRouter.go('/settings/insurance/profile?employeeId=999999');
        await _pumpFrames(tester);

        expect(
          find.byKey(const Key('insurance-profile-missing-employee')),
          findsOneWidget,
        );
        expect(find.text('所选人员档案不存在或已删除，无法维护参保信息。'), findsOneWidget);
        expect(
          find.byKey(const Key('insurance-profile-employee-field')),
          findsNothing,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('insurance-profile-save-button')),
              )
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.idle();
        appRouter.dispose();
        await database.close();
      }
    },
  );
}
