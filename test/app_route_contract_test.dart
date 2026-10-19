import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/app/app.dart';
import 'package:qingsongban/app/router/app_router.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/personnel/presentation/personnel_page.dart';

import 'support/app_route_cases.dart';

Future<void> _pumpRouteFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDownAll(appRouter.dispose);

  testWidgets('all production route patterns resolve to their named pages', (
    tester,
  ) async {
    expect(appRouteCases, hasLength(93));
    expect(appRouteCases.map((route) => route.name).toSet(), hasLength(93));

    final database = AppDatabase.forTesting();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const QingSongBanApp(),
        ),
      );
      await _pumpRouteFrames(tester);

      for (final route in appRouteCases) {
        final location = route.locationFor();
        appRouter.go(location);
        await _pumpRouteFrames(tester);
        expect(
          appRouter.state.name,
          route.missingRecordRedirect ?? route.name,
          reason: '$location must resolve to ${route.name}',
        );
        expect(tester.takeException(), isNull, reason: location);
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.idle();
      await database.close();
    }
  });

  testWidgets('invalid IDs and unknown paths are distinct from known routes', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const QingSongBanApp(),
        ),
      );
      await _pumpRouteFrames(tester);

      appRouter.go('/personnel/not-a-number');
      await _pumpRouteFrames(tester);
      expect(appRouter.state.name, 'personnel-detail');
      expect(find.text('无效的人员编号'), findsOneWidget);
      expect(tester.takeException(), isNull);

      appRouter.go('/purchase/detail');
      await _pumpRouteFrames(tester);
      expect(appRouter.routerDelegate.currentConfiguration.error, isNotNull);

      appRouter.go('/__route_contract_missing__');
      await _pumpRouteFrames(tester);
      expect(appRouter.routerDelegate.currentConfiguration.error, isNotNull);
      expect(find.byType(PersonnelPage), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.idle();
      await database.close();
    }
  });
}
