import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/features/vehicles/application/vehicle_providers.dart';
import 'package:qingsongban/features/vehicles/presentation/vehicle_page.dart';

void main() {
  for (final width in [411.0, 320.0]) {
    testWidgets('vehicle dashboard is compact at ${width.toInt()}dp', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const VehiclePage())],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allVehiclesProvider.overrideWith(
              (ref) => Stream.value(<Vehicle>[]),
            ),
            vehicleListProvider.overrideWith(
              (ref) => Stream.value(<Vehicle>[]),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final firstStat = tester.getTopLeft(find.text('车辆总数'));
      final lastStat = tester.getTopLeft(find.text('油耗异常'));
      expect(firstStat.dy, lastStat.dy);
      expect(lastStat.dx, greaterThan(firstStat.dx));

      final firstEntry = tester.getTopLeft(find.text('车辆档案'));
      final fourthEntry = tester.getTopLeft(find.text('保养/备件'));
      if (width >= 370) {
        expect(firstEntry.dy, fourthEntry.dy);
        final firstCard = find
            .ancestor(of: find.text('车辆档案'), matching: find.byType(InkWell))
            .first;
        final lastCard = find
            .ancestor(of: find.text('提醒中心'), matching: find.byType(InkWell))
            .first;
        expect(
          tester.getSize(lastCard).width,
          greaterThan(tester.getSize(firstCard).width),
        );
      } else {
        expect(fourthEntry.dy, greaterThan(firstEntry.dy));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
