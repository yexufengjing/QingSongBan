import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/app/theme/app_theme.dart';
import 'package:qingsongban/features/vehicles/application/vehicle_providers.dart';
import 'package:qingsongban/features/vehicles/presentation/vehicle_page.dart';
import 'package:qingsongban/features/vehicles/domain/expense_options.dart';

void main() {
  for (final width in [411.0, 390.0, 320.0]) {
    testWidgets('vehicle dashboard uses reference grid at ${width.toInt()}dp', (
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

      expect(find.text('车辆总数'), findsNothing);
      await tester.tap(find.text('车辆统计'));
      await tester.pumpAndSettle();
      final firstStat = tester.getTopLeft(find.text('车辆总数'));
      final lastStat = tester.getTopLeft(find.text('油耗异常'));
      // The final 054 reference uses four metrics on the first row and
      // the fifth on a continuation row. Small phones use two columns.
      expect(lastStat.dy, greaterThan(firstStat.dy));
      expect(lastStat.dx, firstStat.dx);
      final fourthStat = tester.getTopLeft(find.text('保养到期'));
      if (width >= 370) {
        expect(fourthStat.dy, firstStat.dy);
      } else {
        expect(fourthStat.dy, greaterThan(firstStat.dy));
      }

      final firstEntry = tester.getTopLeft(find.text('车辆档案'));
      final fourthEntry = tester.getTopLeft(find.text('车况检查'));
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
  for (final width in [320.0, 360.0, 375.0, 390.0, 844.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('vehicle controls fit ${width}dp at text scale $scale', (
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
            child: MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: child!,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('车辆总数'), findsNothing);
        if (scale == 1 && width >= 360) {
          expect(
            tester.getTopLeft(find.text('本月维修费')).dy,
            tester.getTopLeft(find.text('本月费用')).dy,
          );
        }
        await tester.ensureVisible(find.byType(ChoiceChip).last);
        await tester.pumpAndSettle();
        final chips = find.byType(ChoiceChip);
        expect(chips, findsNWidgets(6));
        final firstY = tester.getTopLeft(chips.first).dy;
        for (var i = 0; i < 6; i++) {
          final rect = tester.getRect(chips.at(i));
          expect(rect.left, greaterThanOrEqualTo(16));
          expect(rect.right, lessThanOrEqualTo(width - 16));
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          if (scale == 1 && width >= 360) expect(rect.top, firstY);
        }
        expect(
          find.ancestor(
            of: chips,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.right,
            ),
          ),
          findsNothing,
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(VehiclePage)),
        );
        await tester.tap(find.widgetWithText(ChoiceChip, '扫路车'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, '维修中'));
        await tester.pumpAndSettle();
        expect(container.read(vehicleTypeFilterProvider), VehicleType.sweeper);
        expect(
          container.read(vehicleStatusFilterProvider),
          VehicleStatus.repairing,
        );
        await tester.tap(find.widgetWithText(ChoiceChip, '维修中'));
        await tester.pumpAndSettle();
        expect(container.read(vehicleStatusFilterProvider), isNull);
        await tester.tap(find.widgetWithText(ChoiceChip, '全部'));
        await tester.pumpAndSettle();
        expect(container.read(vehicleTypeFilterProvider), isNull);
        await tester.ensureVisible(find.text('车辆统计'));
        await tester.tap(find.text('车辆统计'));
        await tester.pumpAndSettle();
        expect(find.text('车辆总数'), findsOneWidget);
        await tester.tap(find.text('车辆统计'));
        await tester.pumpAndSettle();
        expect(find.text('车辆总数'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'large monthly amounts remain complete and exclude older expenses',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.now();
      final vehicle = Vehicle(
        id: 1,
        name: '测试车',
        vehicleNo: 'TEST-1',
        vehicleType: VehicleType.sweeper,
        status: VehicleStatus.normal,
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      );
      VehicleExpenseItem expense(int cents, DateTime date, String category) =>
          VehicleExpenseItem(
            vehicleId: 1,
            date: date,
            sourceType: 'test',
            sourceId: 1,
            category: category,
            subCategory: null,
            amountCents: cents,
            description: '测试费用',
          );
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const VehiclePage())],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allVehiclesProvider.overrideWith((ref) => Stream.value([vehicle])),
            vehicleListProvider.overrideWith(
              (ref) => Stream.value(<Vehicle>[]),
            ),
            vehicleExpenseItemsProvider(1).overrideWith(
              (ref) async => [
                expense(888888888, now, '维修费用'),
                expense(100, now, '其他'),
                expense(99999, DateTime(now.year, now.month - 1, 1), '维修费用'),
              ],
            ),
            vehicleMaintenanceItemsProvider(
              1,
            ).overrideWith((ref) => Stream.value(<VehicleMaintenanceItem>[])),
            vehicleCurrentFuelAnomalyProvider(1)
                .overrideWith((ref) async => null),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('8888888.88 元'), findsOneWidget);
      expect(find.text('8888889.88 元'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('本月费用')).dy,
        greaterThan(tester.getTopLeft(find.text('本月维修费')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
