import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_repository.dart';
import 'package:qingsongban/features/vehicles/domain/vehicle_options.dart';
import 'package:qingsongban/features/vehicles/presentation/vehicle_detail_page.dart';

void main() {
  testWidgets(
    'vehicle detail survives repeated query-tab entry and route exit',
    (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      var vehicleId = 0;
      await tester.runAsync(() async {
        final vehicle = await VehicleRepository(database).save(
          draft: const VehicleDraft(
            name: '生命周期测试车',
            vehicleNo: 'LIFE-001',
            licensePlate: '京A10001',
            vehicleType: VehicleType.waterTruck,
          ),
        );
        vehicleId = vehicle.id;
      });

      final router = GoRouter(
        initialLocation: '/vehicles/$vehicleId',
        routes: [
          GoRoute(
            path: '/vehicles/:vehicleId',
            builder: (context, state) => VehicleDetailPage(
              vehicleId: vehicleId,
              initialTab: state.uri.queryParameters['tab'],
            ),
          ),
          GoRoute(
            path: '/outside',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('详情外')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.idle();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      _expectNoInheritedDependentsAssertion(tester, 'initial detail');

      for (final tab in [
        '维修',
        '车况',
        '油耗',
        '提醒',
        '费用分析',
        '档案',
        '维修',
        '提醒',
      ]) {
        await tester.ensureVisible(find.text(tab).first);
        await tester.tap(find.text(tab).first);
        await tester.pump(const Duration(milliseconds: 16));
        _expectNoInheritedDependentsAssertion(tester, 'tap tab $tab');
      }

      for (final tab in [
        'repair',
        'condition',
        'maintenance',
        'fuel',
        'expense',
        'reminder',
        'repair',
        'reminder',
      ]) {
        router.go('/vehicles/$vehicleId?tab=$tab');
        await tester.pumpAndSettle();
        _expectNoInheritedDependentsAssertion(tester, 'query tab $tab');
      }

      router.go('/outside');
      await tester.pumpAndSettle();
      _expectNoInheritedDependentsAssertion(tester, 'leave detail');

      router.go('/vehicles/$vehicleId?tab=reminder');
      await tester.pumpAndSettle();
      _expectNoInheritedDependentsAssertion(tester, 're-enter reminder');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      _expectNoInheritedDependentsAssertion(tester, 'dispose detail');
    },
  );
}

void _expectNoInheritedDependentsAssertion(WidgetTester tester, String step) {
  final exception = tester.takeException();
  expect(
    exception?.toString(),
    isNot(contains('_dependents.isEmpty')),
    reason: 'Flutter inherited-element assertion at $step: $exception',
  );
  expect(exception, isNull, reason: 'unexpected widget failure at $step');
}
