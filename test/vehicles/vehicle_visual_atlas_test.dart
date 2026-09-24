import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingsongban/core/database/app_database.dart';
import 'package:qingsongban/core/database/database_enums.dart';
import 'package:qingsongban/core/database/database_provider.dart';
import 'package:qingsongban/features/vehicles/data/vehicle_repository.dart';
import 'package:qingsongban/features/vehicles/domain/vehicle_options.dart';
import 'package:qingsongban/features/vehicles/presentation/vehicle_visual_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('vehicle atlas mapping', () {
    test('all four views crop the documented atlas quadrant', () {
      expect(
        vehicleAtlasQuadrantForAngle(VehicleViewAngle.frontLeft),
        const Rect.fromLTWH(0.5, 0, 0.5, 0.5),
      );
      expect(
        vehicleAtlasQuadrantForAngle(VehicleViewAngle.frontRight),
        const Rect.fromLTWH(0, 0, 0.5, 0.5),
      );
      expect(
        vehicleAtlasQuadrantForAngle(VehicleViewAngle.rearRight),
        const Rect.fromLTWH(0, 0.5, 0.5, 0.5),
      );
      expect(
        vehicleAtlasQuadrantForAngle(VehicleViewAngle.rearLeft),
        const Rect.fromLTWH(0.5, 0.5, 0.5, 0.5),
      );
      expect(
        vehicleAtlasQuadrantForAngle(
          VehicleViewAngle.rearLeft,
          atlasWidth: 1254,
          atlasHeight: 1254,
        ),
        const Rect.fromLTWH(627, 627, 627, 627),
      );
      expect(
        vehicleAtlasContentRectForAngle(
          VehicleViewAngle.frontLeft,
          atlasWidth: 1254,
          atlasHeight: 1254,
        ),
        const Rect.fromLTWH(627, 62.7, 627, 501.6),
      );
      expect(
        vehicleAtlasContentRectForAngle(
          VehicleViewAngle.rearLeft,
          atlasWidth: 1254,
          atlasHeight: 1254,
        ),
        const Rect.fromLTWH(627, 689.7, 627, 501.6),
      );
    });

    test('visible wheel nodes use driver-side wheel identities per view', () {
      final leftFront = vehicleVisualNodesFor(
        VehicleViewAngle.frontLeft,
        VehicleType.sweeper,
      );
      expect(
        leftFront.where((node) => node.isTire).map((node) => node.tirePosition),
        containsAll([TirePosition.leftFront, TirePosition.leftRearOuter]),
      );
      expect(
        leftFront.where((node) => node.isTire).map((node) => node.x),
        containsAll([0.48, 0.82]),
      );
      expect(
        leftFront.where((node) => node.isTire).map((node) => node.tirePosition),
        isNot(contains(TirePosition.leftRearInner)),
      );

      final rearRight = vehicleVisualNodesFor(
        VehicleViewAngle.rearRight,
        VehicleType.waterTruck,
      );
      expect(
        rearRight.where((node) => node.isTire).map((node) => node.tirePosition),
        containsAll([TirePosition.rightRearOuter, TirePosition.rightFront]),
      );
      expect(
        rearRight.where((node) => node.isTire).map((node) => node.tirePosition),
        isNot(contains(TirePosition.leftRearOuter)),
      );
      expect(
        rearRight.where((node) => node.componentKey == 'engineMain'),
        isEmpty,
      );
      expect(
        rearRight.where((node) => node.componentKey == 'waterMain'),
        hasLength(1),
      );

      final rightFront = vehicleVisualNodesFor(
        VehicleViewAngle.frontRight,
        VehicleType.sweeper,
      );
      expect(
        rightFront
            .where((node) => node.isTire)
            .map((node) => node.tirePosition),
        containsAll([TirePosition.rightFront, TirePosition.rightRearOuter]),
      );
    });

    test('condition lookup requires both type and exact component key', () {
      final engine = _condition(
        id: 1,
        type: 'engine',
        key: 'engineMain',
        status: VehicleConditionStatus.pendingRepair,
      );
      final otherEngine = _condition(
        id: 2,
        type: 'engine',
        key: 'engineOil',
        status: VehicleConditionStatus.normal,
      );

      expect(
        findVehicleConditionNode([engine, otherEngine], 'engine', 'engineMain'),
        same(engine),
      );
      expect(
        findVehicleConditionNode([engine, otherEngine], 'engine', 'engineOil'),
        same(otherEngine),
      );
      expect(
        findVehicleConditionNode([engine, otherEngine], 'engine', 'lighting'),
        isNull,
      );
    });

    test('missing condition or tire records remain unknown, not normal', () {
      expect(vehicleConditionNodeColor(null), vehicleUnknownNodeColor);
      expect(vehicleTireNodeColor(null, null), vehicleUnknownNodeColor);
      final spare = _tire(TireAssetStatus.spare);
      expect(
        vehicleTireNodeColor(_installation(), spare),
        vehicleUnknownNodeColor,
      );
      expect(
        vehicleTireNodeColor(_installation(), _tire(TireAssetStatus.inUse)),
        isNot(vehicleUnknownNodeColor),
      );
    });
  });

  testWidgets('atlas loads and each swipe advances one view at phone widths', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final vehicle = await VehicleRepository(database).save(
      draft: const VehicleDraft(
        name: '多视角测试车',
        vehicleNo: 'ATLAS-1',
        vehicleType: VehicleType.sweeper,
      ),
    );

    for (final width in [320.0, 411.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: VehicleVisualView(
                  key: ValueKey(width),
                  vehicle: vehicle,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('车辆左前方'), findsOneWidget);
      expect(find.byKey(const ValueKey('vehicle-atlas')), findsOneWidget);
      expect(tester.takeException(), isNull);

      final atlas = find.byKey(const ValueKey('vehicle-atlas'));
      await tester.dragFrom(
        tester.getTopLeft(atlas) + const Offset(24, 24),
        const Offset(-120, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('车辆右前方'), findsOneWidget);
      await tester.drag(atlas, const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(find.text('车辆右后方'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Tire _tire(TireAssetStatus status) => Tire(
  id: 1,
  tireNo: 'T-1',
  condition: TireCondition.newTire,
  status: status,
  repairCount: 0,
  wearLevel: TireWearLevel.good,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  isDeleted: false,
);

TireInstallation _installation() => TireInstallation(
  id: 1,
  vehicleId: 7,
  tireId: 1,
  position: TirePosition.leftFront,
  installDate: DateTime(2026),
  installReason: TireInstallReason.newReplacement,
  removeDate: null,
  note: null,
  isActive: true,
  createdAt: DateTime(2026),
);

VehicleConditionItem _condition({
  required int id,
  required String type,
  required String key,
  required VehicleConditionStatus status,
}) {
  final now = DateTime(2026, 9, 24);
  return VehicleConditionItem(
    id: id,
    vehicleId: 7,
    componentType: type,
    componentKey: key,
    status: status,
    observedAt: now,
    isCurrent: true,
    createdAt: now,
    updatedAt: now,
    isDeleted: false,
  );
}
